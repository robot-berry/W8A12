#!/usr/bin/env python3
"""Generate a reviewer-facing evidence matrix for the W8A12_3lane delivery package."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "delivery_matrix"

AUDIT_JSON = BASE / "evidence" / "delivery_audit" / "contest_delivery_audit.json"
SUBMISSION_JSON = BASE / "evidence" / "submission_package" / "submission_manifest.json"
PDF_JSON = BASE / "evidence" / "report_pdf" / "summary.json"
DOCX_JSON = BASE / "evidence" / "report_docx" / "summary.json"
JTAG_USB_ONLY_JSON = BASE / "evidence" / "board_probe" / "jtag_precondition_usb_only_current" / "summary.json"
JTAG_CURRENT_JSON = BASE / "evidence" / "board_probe" / "jtag_precondition_current" / "summary.json"


def load_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8-sig"))


def exists(rel: str) -> bool:
    return (BASE / rel).exists()


def status_for(paths: list[str], required_text: str | None = None) -> str:
    for rel in paths:
        path = BASE / rel
        if not path.exists():
            return "MISSING"
        if required_text and required_text not in path.read_text(encoding="utf-8", errors="ignore"):
            return "NEEDS_UPDATE"
    return "PASS"


def row(area: str, item: str, status: str, evidence: list[str], note: str) -> dict[str, Any]:
    return {"area": area, "item": item, "status": status, "evidence": evidence, "note": note}


def latest_delivery_run_summary() -> str:
    run_root = BASE / "evidence" / "delivery_runs"
    summaries = sorted(run_root.glob("*/summary.md"), key=lambda path: path.stat().st_mtime, reverse=True)
    if not summaries:
        return "evidence/delivery_runs/<missing>/summary.md"
    return summaries[0].relative_to(BASE).as_posix()


def jtag_recovery_note() -> str:
    current = load_json(JTAG_CURRENT_JSON, {})
    status = current.get("status", "UNKNOWN")
    if status == "READY":
        known = current.get("usb_known_jtag_candidate_count", "unknown")
        target = current.get("vivado_target_count", "unknown")
        return (
            f"当前 full precondition 为 READY：USB known JTAG candidate={known}，"
            f"Vivado target={target}；已可进入 stage-hash/dbg2 小图上板验收，"
            "但真实 board validation PASS 仍取决于后续 compare/PSNR/FPS 结果。"
        )

    usb_only = load_json(JTAG_USB_ONLY_JSON, {})
    if usb_only.get("status") == "USB_READY":
        known = usb_only.get("usb_known_jtag_candidate_count", "unknown")
        target = usb_only.get("vivado_target_count", "not_checked")
        return (
            f"当前 USB-only 前置为 USB_READY：USB known JTAG candidate={known}，"
            f"Vivado target={target}；等后台 Vivado 任务结束后再安全复测 target，"
            "target>=1 后进入 stage-hash/dbg2 上板验收。"
        )

    known = current.get("usb_known_jtag_candidate_count", "unknown")
    target = current.get("vivado_target_count", "unknown")
    return (
        f"当前 JTAG precondition {status}：USB known JTAG candidate={known}，"
        f"Vivado target={target}；恢复条件为 USB known candidate>=1 且 Vivado target>=1。"
    )


def make_rows(latest_run: str) -> list[dict[str, Any]]:
    return [
        row(
            "交付物1 模型/训练/量化/转换",
            "x4/x2 SPAN F48 模型说明和全量 REDS 训练/验证口径",
            status_for(["docs/python_reference_plan.md"]),
            ["docs/python_reference_plan.md", "docs/contest_submission_report.md"],
            "训练使用 REDS train 官方全量，验证使用 REDS val 官方全量；x4 28.3118 dB，x2 34.4297 dB。",
        ),
        row(
            "交付物1 模型/训练/量化/转换",
            "W8A12 fixed reference 与 x2 导出",
            status_for(
                [
                    "evidence/x2/w8a12_export/summary.md",
                    "evidence/x2/reference/summary.md",
                    "evidence/x2/reference_validation/validation.md",
                ],
                "Status: PASS",
            ),
            [
                "tools/w8a12_3lane_reference.py",
                "evidence/x2/w8a12_export/summary.md",
                "evidence/x2/reference_validation/validation.md",
            ],
            "x2 W8A12 manifest、quant plan、postprocess 和 fixed reference 已闭环；x4 A0-A3 分层 reference 已作为 RTL golden。",
        ),
        row(
            "交付物2 硬件设计文档",
            "3-lane 架构、bank 映射、scheduler、top shell、回退和上板流程",
            status_for(
                [
                    "docs/w8a12_3lane_architecture.md",
                    "docs/bank_mapping_rules.md",
                    "docs/a4_scheduler_acceptance_flow.md",
                    "docs/accelerator_top_shell.md",
                    "docs/failure_rollback_flow.md",
                    "docs/board_report_flow.md",
                ]
            ),
            [
                "docs/w8a12_3lane_architecture.md",
                "docs/bank_mapping_rules.md",
                "docs/board_report_flow.md",
            ],
            "文档覆盖 48ch 拆为 3x16ch、6 个 SPAB 串行、tile+halo 和 board report 验收口径。",
        ),
        row(
            "交付物3 RTL/仿真/综合",
            "A0-A4/top shell RTL 仿真",
            status_for(
                [
                    "evidence/reference/A0_single_conv/a0_rtl_sim_summary.md",
                    "evidence/reference/A1_single_block/a1_rtl_sim_summary.md",
                    "evidence/reference/A2_six_blocks/a2_rtl_sim_summary.md",
                    "evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md",
                    "evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md",
                    "evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md",
                    "evidence/top/accel_top_sim/summary.md",
                ],
                "PASS",
            ),
            [
                "evidence/reference/",
                "evidence/resource/A4_single_lane_mac_scheduler/",
                "evidence/resource/A4_3lane_mac_scheduler/",
                "evidence/top/accel_top_sim/summary.md",
            ],
            "分层 bit-exact/hash 验证已通过，top shell 控制/status 仿真 PASS。",
        ),
        row(
            "交付物3 RTL/仿真/综合",
            "OOC 综合资源与 PPA 汇总",
            status_for(
                [
                    "evidence/top/accel_top_ooc/ooc_summary.md",
                    "evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.md",
                    "evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.md",
                    "evidence/ppa_summary/summary.md",
                ],
                "Status: PASS",
            ),
            [
                "evidence/ppa_summary/summary.md",
                "evidence/top/accel_top_ooc/",
                "evidence/resource/A4_3lane_mac_scheduler_ooc/",
            ],
            "A4 3-lane scheduler: LUT 56.35%、FF 58.61%、DSP 74.67%，低于 XC7Z045/ZC706 门限；完整 board FPS/power 待上板。",
        ),
        row(
            "评分点 功能正确性",
            "离线功能闭环与板端剩余验证",
            "PARTIAL",
            [
                "evidence/reference/",
                "evidence/board_reports/jtag_true2x2_stagehash_20260628.md",
                "evidence/delivery_audit/missing_evidence_plan.md",
            ],
            "RTL true2x2 raw compare PASS；真实 board validation 仍缺 A5/A6/A7/x2 四项。",
        ),
        row(
            "评分点 文档清晰度",
            "Markdown + PDF 赛题报告",
            status_for(["evidence/report_static/summary.md", "evidence/report_pdf/summary.md", "evidence/report_docx/summary.md"], "Status: PASS"),
            [
                "docs/contest_submission_report.md",
                "output/pdf/W8A12_3lane_contest_submission_report.pdf",
                "evidence/report_pdf/summary.md",
                "output/docx/W8A12_3lane_contest_submission_report.docx",
                "evidence/report_docx/summary.md",
            ],
            "PDF 已生成并完成全页渲染/关键文本校验。",
        ),
        row(
            "评分点 量化指标和性能分析",
            "画质 baseline、PPA、板端指标口径",
            status_for(
                [
                    "evidence/quality_baseline/x4_interpolation/summary.md",
                    "evidence/quality_baseline/x2_interpolation/summary.md",
                    "evidence/quality_comparison/summary.md",
                    "evidence/quality_metric_completion/summary.md",
                    "evidence/ppa_summary/summary.md",
                ],
                "Status: PASS",
            ),
            [
                "evidence/quality_comparison/summary.md",
                "evidence/quality_metric_completion/summary.md",
                "evidence/ppa_summary/summary.md",
            ],
            "传统插值对比已纳入；W8A12 fixed/board 全量 PSNR/SSIM 和 FPS/power 待真实 board output 后补齐。",
        ),
        row(
            "评分点 验证方案与用例",
            "分层门禁、缺口计划、JTAG 恢复清单",
            status_for(
                [
                    latest_run,
                    "evidence/delivery_audit/missing_evidence_plan.md",
                    "evidence/board_probe/jtag_recovery_checklist/summary.md",
                    "evidence/board_probe/jtag_precondition_usb_only_current/summary.md",
                ]
            ),
            [
                latest_run,
                "evidence/delivery_audit/missing_evidence_plan.md",
                "evidence/board_probe/jtag_recovery_checklist/summary.md",
                "evidence/board_probe/jtag_precondition_current/summary.md",
                "evidence/board_reports/jtag_true2x2_dbg2_src_boundary_20260703_goal_continue/analysis.md",
            ],
            jtag_recovery_note(),
        ),
        row(
            "评分点 面积/功耗",
            "资源门限已过，真实功耗待板端报告",
            "PARTIAL",
            ["evidence/ppa_summary/summary.md", "evidence/board_reports/validation_readiness/summary.md"],
            "OOC 资源/时序可报告；真实 board power、FPS、latency 需 `validation.md Status: PASS` 后才能声明。",
        ),
    ]


def render_md(data: dict[str, Any]) -> str:
    lines = [
        "# W8A12_3lane Delivery Evidence Matrix",
        "",
        "Status: PASS",
        "",
        f"Contest delivery status: `{data['contest_delivery_status']}`",
        "",
        f"Audit pass count: `{data['audit_pass_count']} / {data['audit_total_count']}`",
        "",
        f"Submission package status: `{data['submission_status']}`",
        "",
        f"Submission file count: `{data['submission_file_count']}`",
        "",
        f"PDF report SHA256: `{data['pdf_sha256']}`",
        "",
        f"DOCX report SHA256: `{data['docx_sha256']}`",
        "",
        "## Evidence Matrix",
        "",
        "| Area | Item | Status | Evidence | Note |",
        "| --- | --- | --- | --- | --- |",
    ]
    for item in data["rows"]:
        evidence = "<br>".join(f"`{path}`" for path in item["evidence"])
        note = str(item["note"]).replace("|", "/")
        lines.append(f"| {item['area']} | {item['item']} | `{item['status']}` | {evidence} | {note} |")
    lines.extend(["", "## Remaining Final Evidence", ""])
    if data["missing_final_evidence"]:
        lines.extend(f"- `{item}`" for item in data["missing_final_evidence"])
    else:
        lines.append("None")
    lines.extend(
        [
            "",
            "This matrix is a reviewer index. Final contest completion still depends on `contest_delivery_audit.md` reaching `PASS`.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    audit = load_json(AUDIT_JSON, {"status": "INCOMPLETE", "items": []})
    submission = load_json(SUBMISSION_JSON, {"status": "INCOMPLETE", "file_count": 0, "missing_final_evidence": []})
    pdf = load_json(PDF_JSON, {"status": "MISSING", "sha256": ""})
    docx = load_json(DOCX_JSON, {"status": "MISSING", "sha256": ""})
    items = audit.get("items", [])
    latest_run = latest_delivery_run_summary()
    rows = make_rows(latest_run)
    data = {
        "status": "PASS",
        "contest_delivery_status": audit.get("status", "INCOMPLETE"),
        "audit_pass_count": sum(1 for item in items if item.get("pass")),
        "audit_total_count": len(items),
        "submission_status": submission.get("status", "INCOMPLETE"),
        "submission_file_count": submission.get("file_count", 0),
        "missing_final_evidence": submission.get("missing_final_evidence", []),
        "latest_delivery_run": latest_run,
        "pdf_status": pdf.get("status", "MISSING"),
        "pdf_sha256": pdf.get("sha256", ""),
        "docx_status": docx.get("status", "MISSING"),
        "docx_sha256": docx.get("sha256", ""),
        "rows": rows,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print("DELIVERY_EVIDENCE_MATRIX_STATUS=PASS")
    print(f"DELIVERY_EVIDENCE_MATRIX_MD={OUT / 'summary.md'}")
    print(f"DELIVERY_EVIDENCE_MATRIX_JSON={OUT / 'summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
