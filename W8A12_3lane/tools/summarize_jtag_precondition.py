#!/usr/bin/env python3
"""Summarize board/JTAG preconditions from USB diagnostics."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
DEFAULT_OUT = BASE / "evidence" / "board_probe" / "jtag_precondition"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--usb-json", required=True, help="Path to usb_jtag_devices.json")
    parser.add_argument("--vivado-probe-dir", default="", help="Optional Vivado probe directory")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT), help="Output evidence directory")
    return parser.parse_args()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_vivado_target_count(probe_dir: Path | None) -> int | None:
    if not probe_dir:
        return None
    candidates = [
        probe_dir / "probe_vivado_hw_targets.stdout.log",
        probe_dir / "probe_vivado_hw_targets.log",
    ]
    for path in candidates:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("VIVADO_HW_TARGET_COUNT="):
                try:
                    return int(line.split("=", 1)[1].strip())
                except ValueError:
                    return None
    return None


def status_from_counts(known_count: int, target_count: int | None) -> str:
    if target_count is not None:
        return "READY" if target_count >= 1 else "BLOCKED"
    return "USB_READY" if known_count >= 1 else "BLOCKED"


def render_md(data: dict) -> str:
    lines = [
        "# JTAG Precondition Summary",
        "",
        f"Status: {data['status']}",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Generated at | `{data['generated_at']}` |",
        f"| USB match count | `{data['usb_match_count']}` |",
        f"| USB known JTAG candidate count | `{data['usb_known_jtag_candidate_count']}` |",
        f"| PnP history known candidate count | `{data['pnp_history_known_jtag_candidate_count']}` |",
        f"| PnP history known VID/PID count | `{data['pnp_history_known_vidpid_count']}` |",
        f"| Vivado target count | `{data['vivado_target_count']}` |",
        f"| USB evidence | `{data['usb_json']}` |",
        f"| Vivado probe dir | `{data['vivado_probe_dir']}` |",
        "",
        "## Interpretation",
        "",
    ]
    if data["status"] == "READY":
        lines.append("Vivado sees at least one hardware target. Stage-hash programming and register readback can proceed.")
    elif data["status"] == "USB_READY":
        lines.append("Windows sees a known JTAG-class USB device. Run the Vivado target probe before programming.")
    else:
        lines.append(
            "Board programming is currently blocked before Vivado/JTAG use: no online known Xilinx/FTDI JTAG candidate "
            "is visible, or Vivado target count is zero."
        )
    lines.extend(
        [
            "",
            "## Required Next Step",
            "",
            "Restore board power/cable/JTAG mode/driver until the USB known candidate count is nonzero and "
            "`probe_vivado_hw_targets.ps1` reports `VIVADO_HW_TARGET_COUNT=1` or higher. Then run the stage-hash "
            "true2x2 acceptance wrapper.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    usb_json = Path(args.usb_json)
    probe_dir = Path(args.vivado_probe_dir) if args.vivado_probe_dir else None
    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = ROOT / out_dir

    diag = read_json(usb_json)
    known_count = int(diag.get("KnownJtagCandidateCount", 0))
    target_count = read_vivado_target_count(probe_dir)
    data = {
        "status": status_from_counts(known_count, target_count),
        "generated_at": diag.get("GeneratedAt", ""),
        "usb_match_count": int(diag.get("MatchCount", 0)),
        "usb_known_jtag_candidate_count": known_count,
        "pnp_history_known_jtag_candidate_count": int(diag.get("PnpHistoryKnownJtagCandidateCount", 0)),
        "pnp_history_known_vidpid_count": int(diag.get("PnpHistoryKnownVidPidCount", 0)),
        "vivado_target_count": target_count if target_count is not None else "not_checked",
        "usb_json": str(usb_json),
        "vivado_probe_dir": str(probe_dir) if probe_dir else "not_checked",
    }

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"JTAG_PRECONDITION_STATUS={data['status']}")
    print(f"JTAG_PRECONDITION_MD={out_dir / 'summary.md'}")
    print(f"JTAG_PRECONDITION_JSON={out_dir / 'summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
