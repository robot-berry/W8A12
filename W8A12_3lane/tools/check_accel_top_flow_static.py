#!/usr/bin/env python3
"""Static checks for accelerator-top simulation and OOC scripts."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "top" / "accel_top_flow_static"


FILES = {
    "top": BASE / "rtl" / "top" / "w8a12_3lane_accel_top.v",
    "ooc_top": BASE / "rtl" / "top" / "w8a12_3lane_accel_top_ooc_top.v",
    "tile_shell": BASE / "rtl" / "span" / "w8a12_3lane_tile_pipeline_shell.v",
    "tb": BASE / "sim" / "tb_w8a12_3lane_accel_top.sv",
    "sim_tcl": BASE / "scripts" / "run_vivado_sim_w8a12_3lane_accel_top.tcl",
    "sim_ps1": BASE / "scripts" / "run_vivado_sim_w8a12_3lane_accel_top.ps1",
    "sim_cmd": BASE / "scripts" / "run_vivado_sim_w8a12_3lane_accel_top.cmd",
    "ooc_tcl": BASE / "scripts" / "run_vivado_synth_w8a12_3lane_accel_top_ooc.tcl",
    "ooc_ps1": BASE / "scripts" / "run_vivado_synth_w8a12_3lane_accel_top_ooc.ps1",
    "ooc_cmd": BASE / "scripts" / "run_vivado_synth_w8a12_3lane_accel_top_ooc.cmd",
    "xsim_summary": BASE / "tools" / "summarize_xsim_result.py",
}


def main() -> int:
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    texts: dict[str, str] = {}
    for name, path in FILES.items():
        exists = path.exists()
        add(f"file:{name}", exists, path.relative_to(ROOT).as_posix())
        texts[name] = path.read_text(encoding="utf-8") if exists else ""

    add("sim_tcl_adds_tile_shell", "w8a12_3lane_tile_pipeline_shell.v" in texts["sim_tcl"], "tile shell source")
    add("sim_tcl_adds_accel_top", "w8a12_3lane_accel_top.v" in texts["sim_tcl"], "accel top source")
    add("sim_tcl_adds_tb", "tb_w8a12_3lane_accel_top.sv" in texts["sim_tcl"], "testbench")
    add("sim_ps1_checks_pass", "PASS w8a12_3lane_accel_top" in texts["sim_ps1"], "PASS line")
    add("sim_ps1_writes_summary", "summary.md" in texts["sim_ps1"] and "summary.json" in texts["sim_ps1"], "summary outputs")
    add("sim_cmd_summarizes", "summarize_xsim_result.py" in texts["sim_cmd"] and "--preset accel_top" in texts["sim_cmd"], "cmd fallback summary")
    add("xsim_summary_has_accel_preset", '"accel_top"' in texts["xsim_summary"] and "PASS w8a12_3lane_accel_top" in texts["xsim_summary"], "accel xsim preset")

    add("tb_checks_spab_count", "spab_count != 6" in texts["tb"], "six SPAB starts")
    add("tb_checks_status_bits", "status[1]" in texts["tb"] and "status[3]" in texts["tb"], "done/irq status bits")
    add("tb_checks_clear", "clear did not reset" in texts["tb"], "clear path")
    add("tb_has_pass_line", "PASS w8a12_3lane_accel_top" in texts["tb"], "PASS line")

    add("ooc_tcl_adds_tile_shell", "w8a12_3lane_tile_pipeline_shell.v" in texts["ooc_tcl"], "tile shell source")
    add("ooc_tcl_adds_accel_top", "w8a12_3lane_accel_top.v" in texts["ooc_tcl"], "accel top source")
    add("ooc_tcl_adds_ooc_top", "w8a12_3lane_accel_top_ooc_top.v" in texts["ooc_tcl"], "OOC wrapper source")
    add("ooc_tcl_reports_util", "report_utilization" in texts["ooc_tcl"], "utilization report")
    add("ooc_tcl_reports_timing", "report_timing_summary" in texts["ooc_tcl"], "timing report")
    add("ooc_ps1_checks_reports", "utilization_ooc.rpt" in texts["ooc_ps1"] and "timing_ooc.rpt" in texts["ooc_ps1"], "report existence checks")
    add("ooc_cmd_summarizes", "summarize_ooc_result.py" in texts["ooc_cmd"] and "--tag accel_top" in texts["ooc_cmd"], "cmd fallback summary")

    add("ooc_wrapper_instantiates_top", "w8a12_3lane_accel_top" in texts["ooc_top"], "top instance")
    add("ooc_wrapper_no_errors", ".load_error_i(1'b0)" in texts["ooc_top"] and ".write_error_i(1'b0)" in texts["ooc_top"], "error ties")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Accelerator Top Flow Static Check",
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
