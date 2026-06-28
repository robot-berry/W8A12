#!/usr/bin/env python3
"""Finalize multiple board reports from a real-board evidence manifest."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
FINALIZE = BASE / "tools" / "finalize_board_report_from_outputs.py"
OUT = BASE / "evidence" / "board_reports" / "validation_closure"


REQUIRED_TOP = ("summary_json", "board_output", "fixed_reference", "frame_done", "error")
REQUIRED_RESOURCE = ("lut_used", "ff_used", "bram_tile_used", "dsp_used")
REQUIRED_TIMING = ("wns_ns", "whs_ns")
REQUIRED_PERFORMANCE = ("clock_mhz", "latency_ms", "fps", "power_w")
REQUIRED_FILES = ("bitstream", "utilization_report", "timing_report")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--continue-on-error", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--summary-dir", type=Path, default=OUT)
    return parser.parse_args()


def has_placeholder(value: object) -> bool:
    return isinstance(value, str) and "<" in value and ">" in value


def field(report: dict, dotted: str) -> object:
    cur: object = report
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            raise KeyError(dotted)
        cur = cur[part]
    return cur


def check_report(report: dict) -> list[str]:
    missing: list[str] = []
    for key in REQUIRED_TOP:
        if key not in report or report[key] in (None, "") or has_placeholder(report[key]):
            missing.append(key)
    for prefix, keys in (
        ("resource", REQUIRED_RESOURCE),
        ("timing", REQUIRED_TIMING),
        ("performance", REQUIRED_PERFORMANCE),
        ("files", REQUIRED_FILES),
    ):
        section = report.get(prefix, {})
        if not isinstance(section, dict):
            missing.append(prefix)
            continue
        for key in keys:
            value = section.get(key)
            if value in (None, "") or has_placeholder(value):
                missing.append(f"{prefix}.{key}")
    return missing


def bool_arg(value: object) -> str:
    return "true" if value is True else "false" if value is False else str(value)


def build_command(report: dict) -> list[str]:
    files = report.get("files", {})
    cmd = [
        sys.executable,
        str(FINALIZE),
        str(report["summary_json"]),
        "--board-output",
        str(report["board_output"]),
        "--fixed-reference",
        str(report["fixed_reference"]),
        "--frame-done",
        bool_arg(report["frame_done"]),
        "--error",
        bool_arg(report["error"]),
        "--lut-used",
        str(field(report, "resource.lut_used")),
        "--ff-used",
        str(field(report, "resource.ff_used")),
        "--bram-tile-used",
        str(field(report, "resource.bram_tile_used")),
        "--dsp-used",
        str(field(report, "resource.dsp_used")),
        "--wns-ns",
        str(field(report, "timing.wns_ns")),
        "--whs-ns",
        str(field(report, "timing.whs_ns")),
        "--clock-mhz",
        str(field(report, "performance.clock_mhz")),
        "--latency-ms",
        str(field(report, "performance.latency_ms")),
        "--fps",
        str(field(report, "performance.fps")),
        "--power-w",
        str(field(report, "performance.power_w")),
        "--bitstream",
        str(files["bitstream"]),
        "--utilization-report",
        str(files["utilization_report"]),
        "--timing-report",
        str(files["timing_report"]),
    ]
    for manifest_key, cli_key in (
        ("power_report", "--power-report"),
        ("resource_gate", "--resource-gate"),
        ("preview", "--preview"),
    ):
        if files.get(manifest_key):
            cmd.extend([cli_key, str(files[manifest_key])])
    if report.get("ssim") is not None:
        cmd.extend(["--ssim", str(report["ssim"])])
    return cmd


def command_for_display(cmd: list[str]) -> str:
    return " ".join(f'"{part}"' if " " in part else part for part in cmd)


def main() -> int:
    args = parse_args()
    manifest_path = args.manifest
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    reports = data.get("reports", [])
    if not isinstance(reports, list):
        raise TypeError("manifest field 'reports' must be a list")

    results = []
    for report in reports:
        tag = report.get("tag") or Path(str(report.get("summary_json", ""))).parent.name or "unknown"
        missing = check_report(report)
        if missing:
            results.append({"tag": tag, "status": "BLOCKED", "missing": missing})
            if not args.continue_on_error:
                break
            continue

        cmd = build_command(report)
        if args.dry_run:
            results.append({"tag": tag, "status": "DRY_RUN", "command": command_for_display(cmd)})
            continue

        proc = subprocess.run(cmd, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        results.append(
            {
                "tag": tag,
                "status": "PASS" if proc.returncode == 0 else "FAIL",
                "exit_code": proc.returncode,
                "command": command_for_display(cmd),
                "output_tail": "\n".join(proc.stdout.splitlines()[-20:]),
            }
        )
        if proc.returncode != 0 and not args.continue_on_error:
            break

    ok = bool(results) and all(item["status"] in ("PASS", "DRY_RUN") for item in results)
    status = "PASS" if ok else "FAIL"
    summary_dir = args.summary_dir if args.summary_dir.is_absolute() else ROOT / args.summary_dir
    summary_dir.mkdir(parents=True, exist_ok=True)
    summary = {
        "status": status,
        "manifest": str(manifest_path),
        "dry_run": args.dry_run,
        "continue_on_error": args.continue_on_error,
        "results": results,
    }
    (summary_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    (summary_dir / "summary.md").write_text(render_md(summary), encoding="utf-8")
    print(f"BOARD_VALIDATION_CLOSURE_STATUS={status}")
    print(f"BOARD_VALIDATION_CLOSURE_SUMMARY={summary_dir / 'summary.md'}")
    return 0 if ok else 1


def render_md(summary: dict) -> str:
    lines = [
        "# Board Validation Closure",
        "",
        f"Status: {summary['status']}",
        "",
        f"Manifest: `{summary['manifest']}`",
        "",
        f"Dry run: `{summary['dry_run']}`",
        "",
        "| Tag | Status | Detail |",
        "| --- | --- | --- |",
    ]
    for item in summary["results"]:
        detail = item.get("missing") or item.get("exit_code") or item.get("command") or ""
        detail_text = str(detail).replace("|", "/")
        lines.append(f"| `{item['tag']}` | `{item['status']}` | `{detail_text}` |")
    lines.append("")
    lines.append("This closure runner does not generate final PASS evidence unless each referenced board output, fixed reference, resource report, timing report, and measured performance value is real and passes `validate_board_report.py`.")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())

