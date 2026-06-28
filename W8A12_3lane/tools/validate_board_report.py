#!/usr/bin/env python3
"""Validate a W8A12_3lane board report against PASS criteria."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("summary_json", type=Path)
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--md-out", type=Path)
    args = parser.parse_args()

    data = json.loads(args.summary_json.read_text(encoding="utf-8"))
    checks = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    correctness = data.get("correctness", {})
    resource = data.get("resource_gate", {})
    timing = data.get("timing", {})
    performance = data.get("performance", {})
    quality = data.get("quality", {})
    files = data.get("files", {})
    base_dir = args.summary_json.resolve().parent

    def file_exists(value: object) -> bool:
        if not value:
            return False
        p = Path(str(value))
        if p.is_absolute():
            return p.exists()
        return (base_dir / p).exists() or (ROOT / p).exists()

    add("status_pass", data.get("status") == "PASS", data.get("status"))
    add("frame_done", correctness.get("frame_done") is True, correctness.get("frame_done"))
    add("error_false", correctness.get("error") is False, correctness.get("error"))
    add(
        "output_pixels_match",
        correctness.get("output_pixels") == correctness.get("expected_output_pixels"),
        {
            "output_pixels": correctness.get("output_pixels"),
            "expected_output_pixels": correctness.get("expected_output_pixels"),
        },
    )
    add("mismatch_zero", correctness.get("mismatch") == 0, correctness.get("mismatch"))
    add(
        "bit_exact_to_fixed_reference",
        correctness.get("bit_exact_to_fixed_reference") is True,
        correctness.get("bit_exact_to_fixed_reference"),
    )
    add("resource_gate_pass", resource.get("status") == "PASS", resource.get("status"))
    for used_key, limit_key in (
        ("lut_used", "lut_limit"),
        ("ff_used", "ff_limit"),
        ("bram_tile_used", "bram_tile_limit"),
        ("dsp_used", "dsp_limit"),
    ):
        used = resource.get(used_key)
        limit = resource.get(limit_key)
        add(
            f"resource:{used_key}_within_limit",
            used is not None and limit is not None and 0 <= used <= limit,
            {"used": used, "limit": limit},
        )
    add("timing_pass", timing.get("status") == "PASS", timing.get("status"))
    add("wns_nonnegative", timing.get("wns_ns") is not None and timing.get("wns_ns") >= 0, timing.get("wns_ns"))
    add("whs_nonnegative", timing.get("whs_ns") is not None and timing.get("whs_ns") >= 0, timing.get("whs_ns"))
    add("clock_present", performance.get("clock_mhz") is not None, performance.get("clock_mhz"))
    add("latency_present", performance.get("latency_ms") is not None, performance.get("latency_ms"))
    add("fps_present", performance.get("fps") is not None, performance.get("fps"))
    fps = performance.get("fps")
    target_fps = performance.get("target_fps", 15.0)
    add(
        "fps_meets_target",
        fps is not None and target_fps is not None and fps >= target_fps,
        {"fps": fps, "target_fps": target_fps},
    )
    add("power_present", performance.get("power_w") is not None, performance.get("power_w"))
    psnr = quality.get("psnr_db")
    scale = data.get("scale")
    psnr_target = 30.0 if scale == 2 else 28.0 if scale == 4 else None
    add("quality_psnr_present", psnr is not None, psnr)
    add(
        "quality_psnr_meets_target",
        psnr is not None and psnr_target is not None and psnr >= psnr_target,
        {"psnr_db": psnr, "target_db": psnr_target, "scale": scale},
    )
    for key in ("bitstream", "utilization_report", "timing_report", "fixed_reference", "board_output"):
        add(f"file:{key}", file_exists(files.get(key)), files.get(key))

    ok = all(check["pass"] for check in checks)
    result = {"status": "PASS" if ok else "FAIL", "summary": str(args.summary_json), "checks": checks}

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    if args.md_out:
        args.md_out.parent.mkdir(parents=True, exist_ok=True)
        args.md_out.write_text(render_md(result), encoding="utf-8")
    return 0 if ok else 1


def render_md(result: dict) -> str:
    lines = [
        "# Board Report Validation",
        "",
        f"Status: {result['status']}",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in result["checks"]:
        lines.append(f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | {check['detail']} |")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
