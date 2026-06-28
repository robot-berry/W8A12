#!/usr/bin/env python3
"""Static checks for A4 scheduler simulation and OOC flows."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "resource" / "A4_scheduler_flow_static"


FILES = {
    "mac_core": BASE / "rtl" / "span" / "w8a12_lane_mac_core.v",
    "single_out": BASE / "rtl" / "span" / "w8a12_single_out_mac_scheduler.v",
    "single_lane": BASE / "rtl" / "span" / "w8a12_single_lane_mac_scheduler.v",
    "three_lane": BASE / "rtl" / "span" / "w8a12_3lane_mac_scheduler.v",
    "single_lane_ooc_top": BASE / "rtl" / "span" / "w8a12_single_lane_mac_scheduler_ooc_top.v",
    "three_lane_ooc_top": BASE / "rtl" / "span" / "w8a12_3lane_mac_scheduler_ooc_top.v",
    "single_lane_tb": BASE / "sim" / "tb_w8a12_single_lane_mac_scheduler.sv",
    "three_lane_tb": BASE / "sim" / "tb_w8a12_3lane_mac_scheduler.sv",
    "single_lane_sim_tcl": BASE / "scripts" / "run_vivado_sim_w8a12_single_lane_mac_scheduler.tcl",
    "single_lane_sim_ps1": BASE / "scripts" / "run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1",
    "single_lane_ooc_tcl": BASE / "scripts" / "run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.tcl",
    "single_lane_ooc_ps1": BASE / "scripts" / "run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.ps1",
    "single_lane_ooc_cmd": BASE / "scripts" / "run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.cmd",
    "three_lane_sim_tcl": BASE / "scripts" / "run_vivado_sim_w8a12_3lane_mac_scheduler.tcl",
    "three_lane_sim_ps1": BASE / "scripts" / "run_vivado_sim_w8a12_3lane_mac_scheduler.ps1",
    "three_lane_ooc_tcl": BASE / "scripts" / "run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.tcl",
    "three_lane_ooc_ps1": BASE / "scripts" / "run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1",
    "three_lane_ooc_cmd": BASE / "scripts" / "run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.cmd",
    "a0_include": BASE / "evidence" / "reference" / "A0_single_conv" / "a0_3lane_files.vh",
}


def main() -> int:
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    texts: dict[str, str] = {}
    for name, file_path in FILES.items():
        exists = file_path.exists()
        add(f"file:{name}", exists, file_path.relative_to(ROOT).as_posix())
        texts[name] = file_path.read_text(encoding="utf-8", errors="ignore") if exists else ""

    add("single_lane_tb_reads_a0_vectors", "`W8A12_3LANE_A0_INPUT_TXT" in texts["single_lane_tb"] and "`W8A12_3LANE_A0_EXPECTED_TXT" in texts["single_lane_tb"], "A0 input/expected")
    add("single_lane_tb_checks_lane0", "expected_full[out_pix*CH + ch]" in texts["single_lane_tb"], "lane0 ch0..15")
    add("single_lane_tb_has_timeout", "timeout waiting outputs" in texts["single_lane_tb"], "output watchdog")
    add("single_lane_tb_has_pass_line", "PASS w8a12_single_lane_mac_scheduler" in texts["single_lane_tb"], "PASS line")

    add("three_lane_tb_reads_a0_vectors", "`W8A12_3LANE_A0_INPUT_TXT" in texts["three_lane_tb"] and "`W8A12_3LANE_A0_EXPECTED_TXT" in texts["three_lane_tb"], "A0 input/expected")
    add("three_lane_tb_checks_full48", "for (ch = 0; ch < CH; ch = ch + 1)" in texts["three_lane_tb"] and "expected_full[out_pix*CH + ch]" in texts["three_lane_tb"], "full48 channel loop")
    add("three_lane_tb_has_timeout", "timeout waiting outputs" in texts["three_lane_tb"], "output watchdog")
    add("three_lane_tb_has_pass_line", "PASS w8a12_3lane_mac_scheduler" in texts["three_lane_tb"], "PASS line")

    add("single_lane_sim_tcl_sources", all(token in texts["single_lane_sim_tcl"] for token in [
        "span_w8a12_requant.v",
        "w8a12_lane_mac_core.v",
        "w8a12_single_out_mac_scheduler.v",
        "w8a12_single_lane_mac_scheduler.v",
        "tb_w8a12_single_lane_mac_scheduler.sv",
    ]), "single-lane sim source list")
    add("three_lane_sim_tcl_sources", all(token in texts["three_lane_sim_tcl"] for token in [
        "span_w8a12_requant.v",
        "w8a12_lane_mac_core.v",
        "w8a12_single_out_mac_scheduler.v",
        "w8a12_single_lane_mac_scheduler.v",
        "w8a12_3lane_mac_scheduler.v",
        "tb_w8a12_3lane_mac_scheduler.sv",
    ]), "3-lane sim source list")
    add("single_lane_sim_ps1_summary", "single_lane_scheduler_sim_summary.md" in texts["single_lane_sim_ps1"] and "PASS w8a12_single_lane_mac_scheduler" in texts["single_lane_sim_ps1"], "summary/PASS extraction")
    add("three_lane_sim_ps1_summary", "a4_3lane_sim_summary.md" in texts["three_lane_sim_ps1"] and "PASS w8a12_3lane_mac_scheduler" in texts["three_lane_sim_ps1"], "summary/PASS extraction")

    add("single_lane_ooc_tcl_reports", "report_utilization" in texts["single_lane_ooc_tcl"] and "report_timing_summary" in texts["single_lane_ooc_tcl"], "util/timing reports")
    add("three_lane_ooc_tcl_reports", "report_utilization" in texts["three_lane_ooc_tcl"] and "report_timing_summary" in texts["three_lane_ooc_tcl"], "util/timing reports")
    add("single_lane_ooc_tcl_top", "w8a12_single_lane_mac_scheduler_ooc_top" in texts["single_lane_ooc_tcl"], "OOC top")
    add("three_lane_ooc_tcl_top", "w8a12_3lane_mac_scheduler_ooc_top" in texts["three_lane_ooc_tcl"], "OOC top")
    add("single_lane_ooc_ps1_checks_reports", "utilization_ooc.rpt" in texts["single_lane_ooc_ps1"] and "timing_ooc.rpt" in texts["single_lane_ooc_ps1"], "report existence checks")
    add("three_lane_ooc_ps1_checks_reports", "utilization_ooc.rpt" in texts["three_lane_ooc_ps1"] and "timing_ooc.rpt" in texts["three_lane_ooc_ps1"], "report existence checks")
    add("single_lane_ooc_cmd_summarizes", "summarize_ooc_result.py" in texts["single_lane_ooc_cmd"] and "--tag single_lane" in texts["single_lane_ooc_cmd"], "cmd fallback summary")
    add("three_lane_ooc_cmd_summarizes", "summarize_ooc_result.py" in texts["three_lane_ooc_cmd"] and "--tag 3lane" in texts["three_lane_ooc_cmd"], "cmd fallback summary")

    add("single_lane_ooc_wrapper_instantiates_scheduler", "w8a12_single_lane_mac_scheduler" in texts["single_lane_ooc_top"], "scheduler instance")
    add("three_lane_ooc_wrapper_instantiates_scheduler", "w8a12_3lane_mac_scheduler" in texts["three_lane_ooc_top"], "scheduler instance")
    add("single_lane_ooc_wrapper_uses_a0_lane0", "`W8A12_3LANE_A0_LANE0_WEIGHT_MEM" in texts["single_lane_ooc_top"], "lane0 constants")
    add("three_lane_ooc_wrapper_uses_all_lanes", all(token in texts["three_lane_ooc_top"] for token in [
        "`W8A12_3LANE_A0_LANE0_WEIGHT_MEM",
        "`W8A12_3LANE_A0_LANE1_WEIGHT_MEM",
        "`W8A12_3LANE_A0_LANE2_WEIGHT_MEM",
    ]), "lane0/1/2 constants")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# A4 Scheduler Flow Static Check",
        "",
        f"Status: {data['status']}",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in data["checks"]:
        detail = str(check["detail"]).replace("|", "/")
        lines.append(f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | `{detail}` |")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
