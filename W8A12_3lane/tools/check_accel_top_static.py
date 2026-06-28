#!/usr/bin/env python3
"""Static checks for the board-facing accelerator top shell."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOP = ROOT / "W8A12_3lane" / "rtl" / "top" / "w8a12_3lane_accel_top.v"
OUT = ROOT / "W8A12_3lane" / "evidence" / "top" / "accel_top_static"


REQUIRED_TEXT = [
    "module w8a12_3lane_accel_top",
    "w8a12_3lane_tile_pipeline_shell",
    "status_o",
    "frame_done_o",
    "error_o",
    "irq_o",
    "busy_o",
    "load_start_o",
    "conv1_start_o",
    "spab_start_o",
    "tail_start_o",
    "write_start_o",
]

REQUIRED_PORTS = [
    "start_i",
    "clear_i",
    "load_done_i",
    "load_error_i",
    "conv1_done_i",
    "conv1_error_i",
    "spab_done_i",
    "spab_error_i",
    "tail_done_i",
    "tail_error_i",
    "write_done_i",
    "write_error_i",
]


def main() -> int:
    text = TOP.read_text(encoding="utf-8")
    checks = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    for token in REQUIRED_TEXT:
        add(f"text:{token}", token in text, token)
    for port in REQUIRED_PORTS:
        add(f"port:{port}", re.search(rf"\b{re.escape(port)}\b", text) is not None, port)
    add("status_has_phase_bits", "phase_o,               // [7:5]" in text, "phase_o [7:5]")
    add("status_has_block_bits", "block_idx_o,           // [10:8]" in text, "block_idx_o [10:8]")
    add("clear_resets_shell", ".rst(rst | clear_i)" in text, "rst | clear_i")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "top": str(TOP), "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Accelerator Top Static Check",
        "",
        f"Status: {data['status']}",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in data["checks"]:
        lines.append(f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | `{check['detail']}` |")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
