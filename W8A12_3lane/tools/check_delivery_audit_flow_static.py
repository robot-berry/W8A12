#!/usr/bin/env python3
"""Static checks for the contest delivery audit definition."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "delivery_audit" / "audit_flow_static"


def main() -> int:
    audit_tool = BASE / "tools" / "audit_contest_delivery.py"
    gate_runner = BASE / "scripts" / "run_delivery_gates.ps1"
    text = audit_tool.read_text(encoding="utf-8", errors="ignore") if audit_tool.exists() else ""
    gate_text = gate_runner.read_text(encoding="utf-8", errors="ignore") if gate_runner.exists() else ""
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    add("file:audit_tool", audit_tool.exists(), audit_tool.relative_to(ROOT).as_posix())
    add("file:gate_runner", gate_runner.exists(), gate_runner.relative_to(ROOT).as_posix())
    add("manifest_not_forced_incomplete", '"delivery_manifest", "W8A12_3lane/evidence/delivery_manifest/manifest.md", "Status:"' in text and '"submission_manifest", "W8A12_3lane/evidence/submission_package/submission_manifest.md", "Status:"' in text, "final PASS manifests remain valid")
    add("includes_all_flow_static_gates", all(token in text for token in [
        "missing_plan_flow_static",
        "top.accel_shell_flow_static",
        "a4.scheduler_flow_static",
        "x2.flow_static",
        "board.flow_static",
        "board.stagehash_flow_static",
        "board.validation_readiness",
        "submission_scope_static",
        "repository_scope_manifest",
        "hard_gate_execution_queue",
    ]), "flow-static audit gates")
    add("includes_core_reference_gates", all(token in text for token in [
        "a0.rtl_sim",
        "a1.rtl_sim",
        "a2.rtl_sim",
        "a3.rtl_sim",
    ]), "A0-A3 gates")
    add("includes_mac_dsp_mapping_doc", "doc.mac_dsp_mapping" in text and "mac_dsp_mapping_policy.md" in text, "MAC/DSP mapping policy doc gate")
    add("includes_submission_scope_doc", "doc.submission_scope" in text and "submission_scope_policy.md" in text, "submission scope policy doc gate")
    add("includes_contest_report_gate", "doc.contest_submission_report" in text and "contest_submission_report.md" in text, "contest report doc gate")
    add("includes_report_static_gate", "report.static" in text and "evidence/report_static/summary.md" in text, "contest report static evidence gate")
    add("includes_report_pdf_gate", "report.pdf" in text and "evidence/report_pdf/summary.md" in text, "contest report PDF evidence gate")
    add("includes_report_docx_gate", "report.docx" in text and "evidence/report_docx/summary.md" in text and "report.docx_artifact" in text, "contest report DOCX evidence gate")
    add("includes_ppa_summary_gate", "ppa.summary" in text and "evidence/ppa_summary/summary.md" in text, "PPA summary evidence gate")
    add("includes_sim_fps_estimate_gate", "sim.fps_estimate" in text and "evidence/sim_fps_estimate/summary.md" in text, "simulated FPS estimate evidence gate")
    add("includes_quality_metric_completion_gate", "quality.metric_completion_static" in text and "evidence/quality_metric_completion/summary.md" in text, "quality metric completion evidence gate")
    add("includes_vivado_ooc_gates", all(token in text for token in [
        "top.accel_shell_sim",
        "top.accel_shell_ooc",
        "a4.single_lane_sim",
        "a4.3lane_sim",
        "a4.single_lane_ooc",
        "a4.3lane_ooc",
    ]), "Vivado/xsim/OOC gates")
    add("includes_board_gates", all(token in text for token in [
        "board.stagehash_flow_static",
        "board.validation_readiness",
        "a5.board_32x32",
        "a6.board_64x64",
        "a7.board_720p_x4",
        "x2.board",
    ]), "board gates")
    add("includes_x2_gates", all(token in text for token in [
        "x2.w8a12_export",
        "x2.fixed_reference",
        "x2.fixed_reference_validation",
    ]), "x2 W8A12 gates")
    gate_order = [match.split('"')[1] for match in gate_text.split("-Name ")[1:]]
    def before(left: str, right: str) -> bool:
        return left in gate_order and right in gate_order and gate_order.index(left) < gate_order.index(right)

    add("gate_order_support_before_audit", all(before(left, "delivery_audit") for left in [
        "missing_plan_flow_static",
        "audit_flow_static",
        "submission_scope_static",
        "repository_scope_manifest",
        "missing_evidence_plan",
        "hard_gate_execution_queue",
        "delivery_manifest",
        "submission_manifest",
        "submission_archive",
        "contest_report_docx",
    ]), "support files are generated before strict audit")
    add("gate_order_final_manifests_after_audit", all(before("delivery_audit", right) for right in [
        "submission_manifest_final",
        "submission_archive_final",
        "delivery_manifest_final",
    ]), "final manifests refresh after strict audit")
    add("gate_order_final_archive_after_final_submission", before("submission_manifest_final", "submission_archive_final") and before("submission_archive_final", "delivery_manifest_final"), "final archive is regenerated before final delivery manifest")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Delivery Audit Flow Static Check",
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
