#!/usr/bin/env python3
"""Static completeness checks for the contest submission report."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "report_static"


REPORT = BASE / "docs" / "contest_submission_report.md"


def main() -> int:
    text = REPORT.read_text(encoding="utf-8", errors="ignore") if REPORT.exists() else ""
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    add("file:contest_submission_report", REPORT.exists(), REPORT.relative_to(ROOT).as_posix())
    add("has_title", text.startswith("# W8A12"), "report title")

    required_sections = [
        "## 1. 摘要",
        "## 2. 赛题目标对应关系",
        "## 3. 数据集和训练验证口径",
        "## 4. 模型结构",
        "## 5. W8A12 量化与硬件转换",
        "## 6. 三路并行硬件架构",
        "## 7. RTL 仿真验证",
        "## 8. 综合资源与 PPA",
        "## 9. 画质指标与传统插值对比",
        "## 10. 板端状态和 mismatch 风险",
        "## 11. 当前交付审计状态",
        "## 12. 可复现实验命令",
        "## 13. 交付文件索引",
        "## 14. 结论",
    ]
    add("has_required_sections", all(section in text for section in required_sections), required_sections)

    add("states_full_reds_train_val", all(token in text for token in [
        "24000 images",
        "3000 images",
        "REDS train 官方全量",
        "REDS val 官方全量",
    ]), "full train/val dataset scope")
    add("states_model_and_quantization", all(token in text for token in [
        "SPAN x4/F48",
        "SPAN x2/F48",
        "W8A12",
        "INT8",
        "12-bit",
    ]), "model and W8A12 quantization")
    add("states_3lane_architecture", all(token in text for token in [
        "3 lanes x 16ch",
        "48 output channels",
        "block_1 -> block_6",
    ]), "3-lane architecture")
    add("states_quality_targets_and_results", all(token in text for token in [
        "28.3118",
        "34.4297",
        "+2.0169",
        "+3.5652",
        "26.2949",
        "30.8645",
    ]), "quality comparison values")
    add("states_ppa_summary_and_limits", all(token in text for token in [
        "evidence/ppa_summary/summary.md",
        "XC7Z045",
        "218600",
        "437200",
        "545",
        "900",
        "74.67%",
    ]), "PPA evidence and XC7Z045 limits")
    add("states_rtl_evidence_hashes", all(token in text for token in [
        "0x080D3C47",
        "0xD12E1B43",
        "0xD2AC6553",
        "0x280F9356",
        "0xBC30F107",
    ]), "RTL/fixed reference hashes")
    add("states_board_pending_not_measured", all(token in text for token in [
        "板端实测",
        "待测",
        "不将模型/RTL 等效指标写成板端实测指标",
    ]), "board metrics remain pending")
    add("states_mismatch_risk", all(token in text for token in [
        "153 / 192",
        "44.0265",
        "0x61d3ea1d",
        "writeback_hash",
    ]), "mismatch and debug hash plan")
    add("states_audit_remaining_gates", all(token in text for token in [
        "69 / 73",
        "a5.board_32x32",
        "a6.board_64x64",
        "a7.board_720p_x4",
        "x2.board",
    ]), "audit count and remaining board gates")
    add("states_quality_metric_completion_plan", all(token in text for token in [
        "docs/quality_metric_completion_plan.md",
        "evidence/quality_metric_completion/summary.md",
        "W8A12 fixed-point 和 board 输出的全量 REDS val PSNR/SSIM 仍待补充",
    ]), "quality metric completion plan")
    add("states_pdf_export", all(token in text for token in [
        "output/pdf/W8A12_3lane_contest_submission_report.pdf",
        "evidence/report_pdf/summary.md",
        "PDF 报告导出",
    ]), "PDF report export evidence")
    add("links_repro_commands", all(token in text for token in [
        "run_delivery_gates.ps1",
        "audit_contest_delivery.py",
        "generate_missing_evidence_plan.py",
        "create_submission_archive.py",
        "run_w8a12_board_recovery_preflight.ps1",
        "-RunStageHashAcceptance",
    ]), "reproducible commands")
    add("lists_submission_archive_summary", "evidence/submission_package/archive/summary.md" in text, "submission archive summary evidence")
    add("lists_latest_board_and_upload_evidence", all(token in text for token in [
        "evidence/board_probe/latest_board_progress_20260628.md",
        "evidence/github_upload_push/summary.md",
    ]), "latest board progress and GitHub draft upload evidence")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"CONTEST_REPORT_STATIC_STATUS={data['status']}")
    print(f"CONTEST_REPORT_STATIC_MD={OUT / 'summary.md'}")
    print(f"CONTEST_REPORT_STATIC_JSON={OUT / 'summary.json'}")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Contest Submission Report Static Check",
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
