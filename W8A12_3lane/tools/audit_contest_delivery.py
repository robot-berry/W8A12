#!/usr/bin/env python3
"""Audit W8A12_3lane contest delivery evidence.

The audit is a checklist, not a replacement for the actual Vivado/board gates.
It exits non-zero until every required delivery evidence file exists.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "evidence" / "delivery_audit"

ITEMS = [
    ("doc.workflow", "W8A12_3lane/WORKFLOW.md", None),
    ("doc.delivery_index", "W8A12_3lane/DELIVERY_INDEX.md", None),
    ("doc.status", "W8A12_3lane/STATUS.md", None),
    ("doc.architecture", "W8A12_3lane/docs/w8a12_3lane_architecture.md", None),
    ("doc.accel_top_shell", "W8A12_3lane/docs/accelerator_top_shell.md", None),
    ("doc.bank_mapping", "W8A12_3lane/docs/bank_mapping_rules.md", None),
    ("doc.mac_dsp_mapping", "W8A12_3lane/docs/mac_dsp_mapping_policy.md", None),
    ("doc.rollback", "W8A12_3lane/docs/failure_rollback_flow.md", None),
    ("doc.board_report", "W8A12_3lane/docs/board_report_flow.md", None),
    ("doc.a4_scheduler", "W8A12_3lane/docs/a4_scheduler_acceptance_flow.md", None),
    ("doc.delivery_gate_runner", "W8A12_3lane/docs/delivery_gate_runner.md", None),
    ("doc.a2_a3_tile_contract", "W8A12_3lane/docs/a2_a3_tile_scheduler_contract.md", None),
    ("doc.x2_contract", "W8A12_3lane/docs/x2_fixed_reference_contract.md", None),
    ("doc.x2_export_plan", "W8A12_3lane/docs/x2_w8a12_export_plan.md", None),
    ("doc.interpolation_baseline", "W8A12_3lane/docs/interpolation_baseline_flow.md", None),
    ("doc.submission_scope", "W8A12_3lane/docs/submission_scope_policy.md", None),
    ("doc.github_upload_plan", "W8A12_3lane/docs/github_upload_plan.md", None),
    ("doc.delivery_audit", "W8A12_3lane/docs/contest_delivery_audit.md", None),
    ("doc.contest_submission_report", "W8A12_3lane/docs/contest_submission_report.md", "W8A12_3lane"),
    ("report.static", "W8A12_3lane/evidence/report_static/summary.md", "Status: PASS"),
    ("report.pdf", "W8A12_3lane/evidence/report_pdf/summary.md", "Status: PASS"),
    ("doc.contest_submission", "W8A12_3lane/docs/contest_submission_readme.md", None),
    ("delivery_manifest", "W8A12_3lane/evidence/delivery_manifest/manifest.md", "Status:"),
    ("submission_manifest", "W8A12_3lane/evidence/submission_package/submission_manifest.md", "Status:"),
    ("submission_manifest_flow_static", "W8A12_3lane/evidence/submission_package/flow_static/summary.md", "Status: PASS"),
    ("submission_scope_static", "W8A12_3lane/evidence/submission_scope/summary.md", "Status: PASS"),
    ("repository_scope_manifest", "W8A12_3lane/evidence/submission_scope/repository_scope_manifest.md", "Status: PASS"),
    ("missing_evidence_plan", "W8A12_3lane/evidence/delivery_audit/missing_evidence_plan.md", "Missing count:"),
    ("hard_gate_execution_queue", "W8A12_3lane/evidence/delivery_audit/hard_gate_execution_queue.md", "Status: PASS"),
    ("hard_gate_runner_static", "W8A12_3lane/evidence/delivery_audit/hard_gate_runner_static/summary.md", "Status: PASS"),
    ("missing_plan_flow_static", "W8A12_3lane/evidence/delivery_audit/missing_plan_flow_static/summary.md", "Status: PASS"),
    ("audit_flow_static", "W8A12_3lane/evidence/delivery_audit/audit_flow_static/summary.md", "Status: PASS"),
    ("a0.rtl_sim", "W8A12_3lane/evidence/reference/A0_single_conv/a0_rtl_sim_summary.md", "PASS"),
    ("a1.rtl_sim", "W8A12_3lane/evidence/reference/A1_single_block/a1_rtl_sim_summary.md", "PASS"),
    ("a2.rtl_sim", "W8A12_3lane/evidence/reference/A2_six_blocks/a2_rtl_sim_summary.md", "PASS"),
    ("a2.tile_shell_static", "W8A12_3lane/evidence/reference/A2_tile_pipeline_shell/tile_pipeline_shell_static_check.md", "PASS"),
    ("top.accel_shell_static", "W8A12_3lane/evidence/top/accel_top_static/summary.md", "Status: PASS"),
    ("top.accel_shell_flow_static", "W8A12_3lane/evidence/top/accel_top_flow_static/summary.md", "Status: PASS"),
    ("top.accel_shell_sim", "W8A12_3lane/evidence/top/accel_top_sim/summary.md", "Status: PASS"),
    ("top.accel_shell_ooc", "W8A12_3lane/evidence/top/accel_top_ooc/utilization_ooc.rpt", None),
    ("top.accel_shell_ooc_summary", "W8A12_3lane/evidence/top/accel_top_ooc/ooc_summary.md", "Status: PASS"),
    ("a3.rtl_sim", "W8A12_3lane/evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md", "PASS"),
    ("a4.mac_core_ooc", "W8A12_3lane/evidence/resource/A4_lane_mac_core_ooc/mac_core_ooc_summary.md", "PASS"),
    ("a4.ooc_parser_selfcheck", "W8A12_3lane/evidence/resource/A4_ooc_parser_selfcheck/summary.md", "Status: PASS"),
    ("a4.single_out_sim", "W8A12_3lane/evidence/resource/A4_single_out_mac_scheduler/single_out_scheduler_sim_summary.md", "PASS"),
    ("a4.3lane_static", "W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_static_check.md", "PASS"),
    ("a4.scheduler_vector_check", "W8A12_3lane/evidence/resource/A4_scheduler_vector_check/summary.md", "Status: PASS"),
    ("a4.scheduler_flow_static", "W8A12_3lane/evidence/resource/A4_scheduler_flow_static/summary.md", "Status: PASS"),
    ("a4.single_lane_sim", "W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md", "PASS"),
    ("a4.3lane_sim", "W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md", "PASS"),
    ("a4.single_lane_ooc", "W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler_ooc/utilization_ooc.rpt", None),
    ("a4.3lane_ooc", "W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler_ooc/utilization_ooc.rpt", None),
    ("a4.single_lane_ooc_summary", "W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.md", "Status: PASS"),
    ("a4.3lane_ooc_summary", "W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.md", "Status: PASS"),
    ("ppa.summary", "W8A12_3lane/evidence/ppa_summary/summary.md", "Status: PASS"),
    ("board.vivado_hw_probe", "W8A12_3lane/evidence/board_probe/vivado_hw_probe.md", "Status: PASS"),
    ("a5.board_32x32", "W8A12_3lane/evidence/board_reports/a5_32x32/validation.md", "Status: PASS"),
    ("a6.board_64x64", "W8A12_3lane/evidence/board_reports/a6_64x64/validation.md", "Status: PASS"),
    ("a7.board_720p_x4", "W8A12_3lane/evidence/board_reports/a7_720p_x4/validation.md", "Status: PASS"),
    ("x2.readiness", "W8A12_3lane/evidence/x2/reference_readiness/readiness.md", None),
    ("x2.asset_search", "W8A12_3lane/evidence/x2/asset_search/x2_asset_search.md", None),
    ("x2.flow_static", "W8A12_3lane/evidence/x2/flow_static/summary.md", "Status: PASS"),
    ("quality.x4_interpolation_baseline", "W8A12_3lane/evidence/quality_baseline/x4_interpolation/summary.md", "Status: PASS"),
    ("quality.x2_interpolation_baseline", "W8A12_3lane/evidence/quality_baseline/x2_interpolation/summary.md", "Status: PASS"),
    ("quality.comparison_report", "W8A12_3lane/evidence/quality_comparison/summary.md", "Status: PASS"),
    ("quality.metric_completion_static", "W8A12_3lane/evidence/quality_metric_completion/summary.md", "Status: PASS"),
    ("x2.w8a12_export", "W8A12_3lane/evidence/x2/w8a12_export/summary.md", "Status: PASS"),
    ("x2.fixed_reference", "W8A12_3lane/evidence/x2/reference/summary.md", "Status: PASS"),
    ("x2.fixed_reference_validation", "W8A12_3lane/evidence/x2/reference_validation/validation.md", "Status: PASS"),
    ("board.flow_static", "W8A12_3lane/evidence/board_reports/flow_static/summary.md", "Status: PASS"),
    ("board.stagehash_flow_static", "W8A12_3lane/evidence/board_reports/stagehash_flow_static/summary.md", "Status: PASS"),
    ("board.validation_readiness", "W8A12_3lane/evidence/board_reports/validation_readiness/summary.md", "Status: PASS"),
    ("x2.board", "W8A12_3lane/evidence/board_reports/x2_720p/validation.md", "Status: PASS"),
]


def main() -> int:
    rows = []
    for name, rel, required_text in ITEMS:
        path = ROOT / rel
        exists = path.exists()
        text_ok = True
        if exists and required_text:
            text_ok = required_text in path.read_text(encoding="utf-8", errors="ignore")
        rows.append(
            {
                "name": name,
                "path": rel,
                "exists": exists,
                "required_text": required_text,
                "pass": exists and text_ok,
            }
        )

    ok = all(row["pass"] for row in rows)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "INCOMPLETE", "items": rows}
    (OUT / "contest_delivery_audit.json").write_text(json.dumps(data, indent=2), encoding="utf-8")

    lines = [
        "# Contest Delivery Audit",
        "",
        f"状态：{'PASS' if ok else 'INCOMPLETE'}",
        "",
        "| 项目 | 状态 | 路径 |",
        "| --- | --- | --- |",
    ]
    for row in rows:
        if not row["exists"]:
            status = "MISSING"
        elif not row["pass"]:
            status = "BAD_STATUS"
        else:
            status = "OK"
        lines.append(f"| `{row['name']}` | {status} | `{row['path']}` |")
    (OUT / "contest_delivery_audit.md").write_text("\n".join(lines), encoding="utf-8")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
