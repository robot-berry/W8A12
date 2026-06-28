#!/usr/bin/env python3
"""Finalize a board report from real board output and fixed-reference bytes.

This tool computes correctness and PSNR from artifacts instead of asking the
user to hand-enter mismatch counts. It still requires real resource, timing,
performance, and file evidence; incomplete evidence produces a FAIL summary and
cannot satisfy the final delivery audit.
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

from create_board_report import render_md


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"


def parse_bool(value: str) -> bool:
    lowered = value.lower()
    if lowered in ("1", "true", "yes", "y", "pass"):
        return True
    if lowered in ("0", "false", "no", "n", "fail"):
        return False
    raise argparse.ArgumentTypeError(f"invalid bool: {value}")


def resolve_path(value: str | Path, base_dir: Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    candidates = [base_dir / path, ROOT / path]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return ROOT / path


def repo_rel(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(resolved)


def read_bytes_checked(path: Path, label: str) -> bytes:
    if not path.exists():
        raise FileNotFoundError(f"{label} not found: {path}")
    if not path.is_file():
        raise IsADirectoryError(f"{label} is not a file: {path}")
    return path.read_bytes()


def compare_bytes(board: bytes, reference: bytes) -> dict:
    max_len = max(len(board), len(reference))
    mismatch = abs(len(board) - len(reference))
    squared_error = 0
    for idx in range(max_len):
        b = board[idx] if idx < len(board) else 0
        r = reference[idx] if idx < len(reference) else 0
        if idx < min(len(board), len(reference)) and b != r:
            mismatch += 1
        diff = b - r
        squared_error += diff * diff
    if max_len == 0:
        psnr = None
    elif squared_error == 0:
        psnr = float("inf")
    else:
        mse = squared_error / max_len
        psnr = 10.0 * math.log10((255.0 * 255.0) / mse)
    return {
        "board_bytes": len(board),
        "reference_bytes": len(reference),
        "mismatch_bytes": mismatch,
        "bit_exact": mismatch == 0 and len(board) == len(reference),
        "psnr_db": psnr,
    }


def file_exists_for_validation(value: str | None, base_dir: Path) -> bool:
    if not value:
        return False
    path = Path(value)
    if path.is_absolute():
        return path.exists()
    return (base_dir / path).exists() or (ROOT / path).exists()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary_json", type=Path)
    parser.add_argument("--board-output", required=True)
    parser.add_argument("--fixed-reference", required=True)
    parser.add_argument("--frame-done", required=True, type=parse_bool)
    parser.add_argument("--error", required=True, type=parse_bool)
    parser.add_argument("--lut-used", required=True, type=int)
    parser.add_argument("--ff-used", required=True, type=int)
    parser.add_argument("--bram-tile-used", required=True, type=int)
    parser.add_argument("--dsp-used", required=True, type=int)
    parser.add_argument("--wns-ns", required=True, type=float)
    parser.add_argument("--whs-ns", required=True, type=float)
    parser.add_argument("--clock-mhz", required=True, type=float)
    parser.add_argument("--latency-ms", required=True, type=float)
    parser.add_argument("--fps", required=True, type=float)
    parser.add_argument("--power-w", required=True, type=float)
    parser.add_argument("--ssim", type=float)
    parser.add_argument("--bitstream", required=True)
    parser.add_argument("--utilization-report", required=True)
    parser.add_argument("--timing-report", required=True)
    parser.add_argument("--power-report")
    parser.add_argument("--resource-gate")
    parser.add_argument("--preview")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--md-out", type=Path)
    parser.add_argument("--skip-validation", action="store_true")
    args = parser.parse_args()

    summary_path = args.summary_json
    data = json.loads(summary_path.read_text(encoding="utf-8"))
    base_dir = summary_path.resolve().parent

    board_output = resolve_path(args.board_output, base_dir)
    fixed_reference = resolve_path(args.fixed_reference, base_dir)
    board_bytes = read_bytes_checked(board_output, "board output")
    reference_bytes = read_bytes_checked(fixed_reference, "fixed reference")
    comparison = compare_bytes(board_bytes, reference_bytes)

    expected_pixels = data.get("correctness", {}).get("expected_output_pixels")
    output_pixels = len(board_bytes) // 3 if len(board_bytes) % 3 == 0 else None
    resource = data.setdefault("resource_gate", {})
    resource.update(
        {
            "lut_used": args.lut_used,
            "ff_used": args.ff_used,
            "bram_tile_used": args.bram_tile_used,
            "dsp_used": args.dsp_used,
        }
    )
    resource_ok = all(
        resource.get(used_key) is not None
        and resource.get(limit_key) is not None
        and 0 <= resource[used_key] <= resource[limit_key]
        for used_key, limit_key in (
            ("lut_used", "lut_limit"),
            ("ff_used", "ff_limit"),
            ("bram_tile_used", "bram_tile_limit"),
            ("dsp_used", "dsp_limit"),
        )
    )
    resource["status"] = "PASS" if resource_ok else "FAIL"

    timing = data.setdefault("timing", {})
    timing.update({"wns_ns": args.wns_ns, "whs_ns": args.whs_ns})
    timing["status"] = "PASS" if args.wns_ns >= 0 and args.whs_ns >= 0 else "FAIL"

    performance = data.setdefault("performance", {})
    performance.update(
        {
            "clock_mhz": args.clock_mhz,
            "latency_ms": args.latency_ms,
            "fps": args.fps,
            "power_w": args.power_w,
        }
    )

    quality = data.setdefault("quality", {})
    psnr = comparison["psnr_db"]
    quality["psnr_infinite"] = bool(psnr is not None and math.isinf(psnr))
    quality["psnr_db"] = None if psnr is None else (99.0 if math.isinf(psnr) else round(float(psnr), 6))
    if args.ssim is not None:
        quality["ssim"] = args.ssim

    correctness = data.setdefault("correctness", {})
    correctness.update(
        {
            "frame_done": args.frame_done,
            "error": args.error,
            "output_pixels": output_pixels,
            "mismatch": comparison["mismatch_bytes"],
            "bit_exact_to_fixed_reference": comparison["bit_exact"],
            "board_bytes": comparison["board_bytes"],
            "reference_bytes": comparison["reference_bytes"],
        }
    )

    files = data.setdefault("files", {})
    path_values = {
        "bitstream": args.bitstream,
        "utilization_report": args.utilization_report,
        "timing_report": args.timing_report,
        "power_report": args.power_report,
        "resource_gate": args.resource_gate,
        "fixed_reference": repo_rel(fixed_reference),
        "board_output": repo_rel(board_output),
        "preview": args.preview,
    }
    for key, value in path_values.items():
        if value:
            files[key] = value

    scale = data.get("scale")
    psnr_target = 30.0 if scale == 2 else 28.0 if scale == 4 else None
    target_fps = performance.get("target_fps", 15.0)
    file_keys = ("bitstream", "utilization_report", "timing_report", "fixed_reference", "board_output")
    files_ok = all(file_exists_for_validation(files.get(key), base_dir) for key in file_keys)
    psnr_ok = psnr is not None and (math.isinf(psnr) or (psnr_target is not None and psnr >= psnr_target))
    pass_ready = all(
        [
            args.frame_done is True,
            args.error is False,
            output_pixels == expected_pixels,
            comparison["bit_exact"],
            resource["status"] == "PASS",
            timing["status"] == "PASS",
            args.fps >= target_fps,
            psnr_ok,
            files_ok,
        ]
    )
    data["status"] = "PASS" if pass_ready else "FAIL"
    data["finalized_from_outputs"] = {
        "board_output": repo_rel(board_output),
        "fixed_reference": repo_rel(fixed_reference),
        "psnr_target_db": psnr_target,
        "target_fps": target_fps,
        "files_ok": files_ok,
    }

    summary_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    (summary_path.parent / "summary.md").write_text(render_md(data), encoding="utf-8")

    validation_json = args.json_out or summary_path.with_name("validation.json")
    validation_md = args.md_out or summary_path.with_name("validation.md")
    if not args.skip_validation:
        validate_script = BASE / "tools" / "validate_board_report.py"
        subprocess.run(
            [
                sys.executable,
                str(validate_script),
                str(summary_path),
                "--json-out",
                str(validation_json),
                "--md-out",
                str(validation_md),
            ],
            check=False,
        )

    print(
        json.dumps(
            {
                "status": data["status"],
                "summary": str(summary_path),
                "validation_json": str(validation_json),
                "validation_md": str(validation_md),
                "mismatch_bytes": comparison["mismatch_bytes"],
                "bit_exact": comparison["bit_exact"],
                "psnr_db": quality["psnr_db"],
            },
            indent=2,
        )
    )
    return 0 if data["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
