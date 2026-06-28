#!/usr/bin/env python3
"""Fill a board report summary with measured board/run evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from create_board_report import render_md


ROOT = Path(__file__).resolve().parents[2]


def parse_bool(value: str) -> bool:
    lowered = value.lower()
    if lowered in ("1", "true", "yes", "y", "pass"):
        return True
    if lowered in ("0", "false", "no", "n", "fail"):
        return False
    raise argparse.ArgumentTypeError(f"invalid bool: {value}")


def set_if_not_none(target: dict, key: str, value: object) -> None:
    if value is not None:
        target[key] = value


def main() -> int:
    parser = argparse.ArgumentParser(description="Update a W8A12_3lane board report with real evidence.")
    parser.add_argument("summary_json", type=Path)
    parser.add_argument("--status", choices=("PENDING", "PASS", "FAIL"), default=None)
    parser.add_argument("--frame-done", type=parse_bool)
    parser.add_argument("--error", type=parse_bool)
    parser.add_argument("--output-pixels", type=int)
    parser.add_argument("--mismatch", type=int)
    parser.add_argument("--bit-exact", type=parse_bool)
    parser.add_argument("--lut-used", type=int)
    parser.add_argument("--ff-used", type=int)
    parser.add_argument("--bram-tile-used", type=int)
    parser.add_argument("--dsp-used", type=int)
    parser.add_argument("--resource-status", choices=("PENDING", "PASS", "FAIL"))
    parser.add_argument("--wns-ns", type=float)
    parser.add_argument("--whs-ns", type=float)
    parser.add_argument("--timing-status", choices=("PENDING", "PASS", "FAIL"))
    parser.add_argument("--clock-mhz", type=float)
    parser.add_argument("--latency-ms", type=float)
    parser.add_argument("--fps", type=float)
    parser.add_argument("--target-fps", type=float)
    parser.add_argument("--power-w", type=float)
    parser.add_argument("--psnr-db", type=float)
    parser.add_argument("--ssim", type=float)
    parser.add_argument("--bitstream")
    parser.add_argument("--utilization-report")
    parser.add_argument("--timing-report")
    parser.add_argument("--power-report")
    parser.add_argument("--resource-gate")
    parser.add_argument("--fixed-reference")
    parser.add_argument("--board-output")
    parser.add_argument("--preview")
    args = parser.parse_args()

    path = args.summary_json
    data = json.loads(path.read_text(encoding="utf-8"))
    if args.status is not None:
        data["status"] = args.status

    correctness = data.setdefault("correctness", {})
    set_if_not_none(correctness, "frame_done", args.frame_done)
    set_if_not_none(correctness, "error", args.error)
    set_if_not_none(correctness, "output_pixels", args.output_pixels)
    set_if_not_none(correctness, "mismatch", args.mismatch)
    set_if_not_none(correctness, "bit_exact_to_fixed_reference", args.bit_exact)

    resource = data.setdefault("resource_gate", {})
    set_if_not_none(resource, "lut_used", args.lut_used)
    set_if_not_none(resource, "ff_used", args.ff_used)
    set_if_not_none(resource, "bram_tile_used", args.bram_tile_used)
    set_if_not_none(resource, "dsp_used", args.dsp_used)
    set_if_not_none(resource, "status", args.resource_status)

    timing = data.setdefault("timing", {})
    set_if_not_none(timing, "wns_ns", args.wns_ns)
    set_if_not_none(timing, "whs_ns", args.whs_ns)
    set_if_not_none(timing, "status", args.timing_status)

    performance = data.setdefault("performance", {})
    set_if_not_none(performance, "clock_mhz", args.clock_mhz)
    set_if_not_none(performance, "latency_ms", args.latency_ms)
    set_if_not_none(performance, "fps", args.fps)
    set_if_not_none(performance, "target_fps", args.target_fps)
    set_if_not_none(performance, "power_w", args.power_w)

    quality = data.setdefault("quality", {})
    set_if_not_none(quality, "psnr_db", args.psnr_db)
    set_if_not_none(quality, "ssim", args.ssim)

    files = data.setdefault("files", {})
    for cli_name, key in (
        ("bitstream", "bitstream"),
        ("utilization_report", "utilization_report"),
        ("timing_report", "timing_report"),
        ("power_report", "power_report"),
        ("resource_gate", "resource_gate"),
        ("fixed_reference", "fixed_reference"),
        ("board_output", "board_output"),
        ("preview", "preview"),
    ):
        set_if_not_none(files, key, getattr(args, cli_name))

    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    (path.parent / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(json.dumps({"status": data.get("status"), "summary": str(path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
