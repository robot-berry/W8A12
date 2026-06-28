#!/usr/bin/env python3
"""Create audit summaries from Vivado xsim simulate.log files."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]

PRESETS = {
    "a4_single_lane": {
        "stage": "A4_single_lane_mac_scheduler",
        "top": "tb_w8a12_single_lane_mac_scheduler",
        "pass_pattern": r"PASS w8a12_single_lane_mac_scheduler[^\r\n]*",
        "default_log": "build/vivado_w8a12_single_lane_mac_scheduler_sim/w8a12_single_lane_mac_scheduler_sim.sim/sim_1/behav/xsim/simulate.log",
        "default_out": "W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler",
        "summary_name": "single_lane_scheduler_sim_summary",
        "expected": "lane0 channels 0..15 bit-exact against A0 full48_output.txt",
    },
    "a4_3lane": {
        "stage": "A4_3lane_mac_scheduler",
        "top": "tb_w8a12_3lane_mac_scheduler",
        "pass_pattern": r"PASS w8a12_3lane_mac_scheduler[^\r\n]*",
        "default_log": "build/vivado_w8a12_3lane_mac_scheduler_sim/w8a12_3lane_mac_scheduler_sim.sim/sim_1/behav/xsim/simulate.log",
        "default_out": "W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler",
        "summary_name": "a4_3lane_sim_summary",
        "expected": "lane0/1/2 stitched channels 0..47 bit-exact against A0 full48_output.txt",
    },
    "accel_top": {
        "stage": "w8a12_3lane_accel_top",
        "top": "tb_w8a12_3lane_accel_top",
        "pass_pattern": r"PASS w8a12_3lane_accel_top[^\r\n]*",
        "default_log": "build/vivado_w8a12_3lane_accel_top_sim/w8a12_3lane_accel_top_sim.sim/sim_1/behav/xsim/simulate.log",
        "default_out": "W8A12_3lane/evidence/top/accel_top_sim",
        "summary_name": "summary",
        "expected": "control/status shell sequences load, conv1, 6 SPAB blocks, tail, write and latches done/irq",
    },
}


def resolve(path: str | Path) -> Path:
    p = Path(path)
    return p if p.is_absolute() else REPO / p


def render_md(payload: dict) -> str:
    lines = [
        f"# {payload['stage']} Simulation",
        "",
        f"Status: {payload['status']}",
        "",
        "| Item | Value |",
        "| --- | --- |",
        f"| `top` | `{payload['top']}` |",
        f"| `pass_line` | `{payload['pass_line']}` |",
        f"| `simulate_log` | `{payload['simulate_log']}` |",
        f"| `expected` | `{payload['expected']}` |",
    ]
    if payload.get("vivado_log"):
        lines.append(f"| `vivado_log` | `{payload['vivado_log']}` |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize Vivado xsim PASS logs for audit.")
    parser.add_argument("--preset", choices=sorted(PRESETS), required=True)
    parser.add_argument("--simulate-log", type=Path)
    parser.add_argument("--out-dir", type=Path)
    parser.add_argument("--vivado-log", type=Path)
    args = parser.parse_args()

    cfg = PRESETS[args.preset]
    simulate_log = resolve(args.simulate_log or cfg["default_log"])
    out_dir = resolve(args.out_dir or cfg["default_out"])

    if not simulate_log.exists():
        raise FileNotFoundError(f"simulate.log not found: {simulate_log}")
    text = simulate_log.read_text(encoding="utf-8", errors="ignore")
    match = re.search(cfg["pass_pattern"], text)
    if not match:
        raise RuntimeError(f"PASS line not found in {simulate_log}")

    out_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "status": "PASS",
        "stage": cfg["stage"],
        "top": cfg["top"],
        "pass_line": match.group(0),
        "simulate_log": str(simulate_log),
        "vivado_log": str(resolve(args.vivado_log)) if args.vivado_log else "",
        "expected": cfg["expected"],
    }
    stem = cfg["summary_name"]
    (out_dir / f"{stem}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    (out_dir / f"{stem}.md").write_text(render_md(payload), encoding="utf-8")
    print(json.dumps({"status": "PASS", "summary": str(out_dir / f"{stem}.md")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
