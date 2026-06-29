#!/usr/bin/env python3
"""Estimate simulated FPS from the current W8A12 3-lane MAC schedule.

This is a simulation/model-level estimate. It is deliberately separated from
real board FPS: failing or passing this gate must not be used as board
validation evidence.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "sim_fps_estimate"

VALIDATION_JSON = BASE / "evidence" / "board_reports" / "validation_readiness" / "summary.json"
OOC_JSON = BASE / "evidence" / "resource" / "A4_3lane_mac_scheduler_ooc" / "ooc_summary.json"

CLOCK_MHZ = 100.0
TARGET_PERIOD_NS = 10.0
FEATURE_CHANNELS = 48
KERNEL_TAPS = 9
TAP_PAR = 8
EQUIVALENT_48X48_CONV_STAGES = 22
TILE_OVERHEAD_CYCLES = 1024


def load_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8-sig"))


def fps_for(clock_mhz: float, cycles: int) -> float:
    if cycles <= 0:
        return 0.0
    return clock_mhz * 1_000_000.0 / cycles


def estimate_row(item: dict[str, Any], timing_clock_mhz: float | None) -> dict[str, Any]:
    tag = item["tag"]
    lr_w, lr_h = item["lr_size"]
    tile_x, tile_y = item["tile_count"]
    target_fps = float(item["target_fps"])
    pixels = int(lr_w) * int(lr_h)
    tiles = int(tile_x) * int(tile_y)
    cycles_per_conv_pixel = math.ceil(FEATURE_CHANNELS * KERNEL_TAPS / TAP_PAR)
    compute_cycles = pixels * EQUIVALENT_48X48_CONV_STAGES * cycles_per_conv_pixel
    overhead_cycles = tiles * TILE_OVERHEAD_CYCLES
    total_cycles = compute_cycles + overhead_cycles
    fps_100 = fps_for(CLOCK_MHZ, total_cycles)
    fps_timing = fps_for(timing_clock_mhz, total_cycles) if timing_clock_mhz else None
    required_clock_mhz = total_cycles * target_fps / 1_000_000.0
    spatial_parallel_factor_for_100mhz = max(1, math.ceil(required_clock_mhz / CLOCK_MHZ))
    pass_100 = fps_100 >= target_fps
    pass_timing = bool(fps_timing is not None and fps_timing >= target_fps)
    return {
        "tag": tag,
        "lr_size": item["lr_size"],
        "hr_size": item["hr_size"],
        "tile_count": item["tile_count"],
        "target_fps": target_fps,
        "pixels": pixels,
        "tiles": tiles,
        "cycles_per_conv_pixel": cycles_per_conv_pixel,
        "equivalent_48x48_conv_stages": EQUIVALENT_48X48_CONV_STAGES,
        "compute_cycles": compute_cycles,
        "tile_overhead_cycles": overhead_cycles,
        "total_cycles": total_cycles,
        "fps_at_100mhz": fps_100,
        "fps_at_timing_inferred_clock": fps_timing,
        "required_clock_mhz_for_target": required_clock_mhz,
        "required_spatial_parallel_factor_at_100mhz": spatial_parallel_factor_for_100mhz,
        "pass_at_100mhz": pass_100,
        "pass_at_timing_inferred_clock": pass_timing,
    }


def render_md(data: dict[str, Any]) -> str:
    lines = [
        "# Simulated FPS Estimate",
        "",
        f"Status: {data['status']}",
        "",
        "This is a model-level throughput estimate from the current A4 3-lane MAC schedule. It is not board-measured FPS and does not replace board validation.",
        "",
        "## Assumptions",
        "",
        "| Field | Value |",
        "| --- | ---: |",
        f"| clock_mhz | {data['assumptions']['clock_mhz']:.3f} |",
        f"| timing_inferred_clock_mhz | {data['assumptions']['timing_inferred_clock_mhz']:.3f} |",
        f"| feature_channels | {data['assumptions']['feature_channels']} |",
        f"| kernel_taps | {data['assumptions']['kernel_taps']} |",
        f"| tap_par | {data['assumptions']['tap_par']} |",
        f"| cycles_per_conv_pixel | {data['assumptions']['cycles_per_conv_pixel']} |",
        f"| equivalent_48x48_conv_stages | {data['assumptions']['equivalent_48x48_conv_stages']} |",
        f"| tile_overhead_cycles | {data['assumptions']['tile_overhead_cycles']} |",
        "",
        "## Results",
        "",
        "| Tag | LR | Tiles | Total cycles | FPS @100MHz | FPS @timing clock | Target FPS | Sim gate @100MHz | Needed clock MHz | Needed spatial factor @100MHz |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |",
    ]
    for row in data["rows"]:
        fps_timing = row["fps_at_timing_inferred_clock"]
        lines.append(
            f"| `{row['tag']}` | `{row['lr_size'][0]}x{row['lr_size'][1]}` | "
            f"`{row['tile_count'][0]}x{row['tile_count'][1]}` | {row['total_cycles']} | "
            f"{row['fps_at_100mhz']:.3f} | {fps_timing:.3f} | {row['target_fps']:.1f} | "
            f"{'PASS' if row['pass_at_100mhz'] else 'FAIL'} | "
            f"{row['required_clock_mhz_for_target']:.1f} | {row['required_spatial_parallel_factor_at_100mhz']} |"
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- A PASS here only means the current simulation/model estimate meets the configured FPS target.",
            "- A FAIL here identifies a performance gap in the modeled 3-lane schedule; it is not a correctness failure.",
            "- Board FPS remains pending until `evidence/board_reports/<tag>/validation.md` is produced from real board output and runtime logs.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    readiness = load_json(VALIDATION_JSON, {"items": []})
    ooc = load_json(OOC_JSON, {"timing": {}})
    wns = ooc.get("timing", {}).get("wns_ns")
    timing_clock_mhz = None
    if isinstance(wns, (int, float)) and TARGET_PERIOD_NS - float(wns) > 0:
        timing_clock_mhz = 1000.0 / (TARGET_PERIOD_NS - float(wns))
    if timing_clock_mhz is None:
        timing_clock_mhz = CLOCK_MHZ

    rows = [estimate_row(item, timing_clock_mhz) for item in readiness.get("items", [])]
    all_pass_100 = bool(rows) and all(row["pass_at_100mhz"] for row in rows)
    data = {
        "status": "PASS" if all_pass_100 else "FAIL",
        "scope": "simulation/model estimate only; not board-measured FPS",
        "assumptions": {
            "clock_mhz": CLOCK_MHZ,
            "target_period_ns": TARGET_PERIOD_NS,
            "timing_wns_ns": wns,
            "timing_inferred_clock_mhz": timing_clock_mhz,
            "feature_channels": FEATURE_CHANNELS,
            "kernel_taps": KERNEL_TAPS,
            "tap_par": TAP_PAR,
            "cycles_per_conv_pixel": math.ceil(FEATURE_CHANNELS * KERNEL_TAPS / TAP_PAR),
            "equivalent_48x48_conv_stages": EQUIVALENT_48X48_CONV_STAGES,
            "tile_overhead_cycles": TILE_OVERHEAD_CYCLES,
        },
        "rows": rows,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"SIM_FPS_ESTIMATE_STATUS={data['status']}")
    print(f"SIM_FPS_ESTIMATE_MD={OUT / 'summary.md'}")
    print(f"SIM_FPS_ESTIMATE_JSON={OUT / 'summary.json'}")
    return 0 if rows else 1


if __name__ == "__main__":
    raise SystemExit(main())
