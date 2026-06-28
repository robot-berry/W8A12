#!/usr/bin/env python3
"""Convert a Vivado hardware-target probe run into board-probe evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
DEFAULT_OUT = BASE / "evidence" / "board_probe"


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def first_int(pattern: str, text: str) -> int | None:
    match = re.search(pattern, text)
    if not match:
        return None
    return int(match.group(1))


def active_error_present(text: str, needle: str) -> bool:
    """Return True only for emitted error lines, not Tcl source echoed as comments."""
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if needle in stripped:
            return True
    return False


def render_md(data: dict) -> str:
    lines = [
        "# Vivado Hardware Probe",
        "",
        f"Status: {data['status']}",
        "",
        f"Probe directory: `{data['probe_dir']}`",
        f"Target count: {data.get('target_count')}",
        f"Device count: {data.get('device_count')}",
        "",
        "| Check | Pass | Detail |",
        "| --- | --- | --- |",
    ]
    for check in data["checks"]:
        lines.append(f"| {check['name']} | {check['pass']} | {check['detail']} |")
    lines.extend(
        [
            "",
            "Required PASS marker: `VIVADO_HW_TARGET_PROBE_PASS=1`.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--probe-dir",
        type=Path,
        default=ROOT / "board_runs" / "vivado_hw_target_probe_w8a12_3lane",
    )
    parser.add_argument("--json-out", type=Path, default=DEFAULT_OUT / "vivado_hw_probe.json")
    parser.add_argument("--md-out", type=Path, default=DEFAULT_OUT / "vivado_hw_probe.md")
    args = parser.parse_args()

    probe_dir = args.probe_dir
    files = {
        "vivado_log": probe_dir / "probe_vivado_hw_targets.log",
        "stdout_log": probe_dir / "probe_vivado_hw_targets.stdout.log",
        "stderr_log": probe_dir / "probe_vivado_hw_targets.stderr.log",
        "usb_diag": probe_dir / "usb_jtag_devices.txt",
    }
    text = "\n".join(read_text(path) for path in files.values())
    target_count = first_int(r"VIVADO_HW_TARGET_COUNT=(\d+)", text)
    device_count = first_int(r"VIVADO_HW_DEVICE_COUNT=(\d+)", text)

    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    add("probe_dir_exists", probe_dir.exists(), probe_dir.as_posix())
    for name, path in files.items():
        add(f"file:{name}", path.exists(), path.as_posix())
    add("pass_marker", "VIVADO_HW_TARGET_PROBE_PASS=1" in text, "VIVADO_HW_TARGET_PROBE_PASS=1")
    add("target_count_positive", target_count is not None and target_count > 0, target_count)
    add("device_count_positive", device_count is not None and device_count > 0, device_count)
    add("no_no_target_error", not active_error_present(text, "No Vivado hardware target found"), "No Vivado hardware target found")
    add("no_no_device_error", not active_error_present(text, "No Vivado hardware device found"), "No Vivado hardware device found")

    ok = all(check["pass"] for check in checks)
    data = {
        "status": "PASS" if ok else "NOT_READY",
        "probe_dir": probe_dir.as_posix(),
        "target_count": target_count,
        "device_count": device_count,
        "checks": checks,
    }

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(data, indent=2), encoding="utf-8")
    args.md_out.write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
