#!/usr/bin/env python3
"""Static checks for quality metric completion plan and report wording."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "quality_metric_completion"

PLAN = BASE / "docs" / "quality_metric_completion_plan.md"
COMPARISON = BASE / "evidence" / "quality_comparison" / "summary.md"
REPORT = BASE / "docs" / "contest_submission_report.md"


def main() -> int:
    plan = read(PLAN)
    comparison = read(COMPARISON)
    report = read(REPORT)
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    add("file:quality_metric_completion_plan", PLAN.exists(), PLAN.relative_to(ROOT).as_posix())
    add("file:quality_comparison", COMPARISON.exists(), COMPARISON.relative_to(ROOT).as_posix())
    add("file:contest_submission_report", REPORT.exists(), REPORT.relative_to(ROOT).as_posix())

    add("states_metric_layers", all(token in plan for token in [
        "传统插值 baseline",
        "SPAN FP32",
        "W8A12 fixed-point",
        "RTL",
        "Board",
    ]), "metric layers separated")
    add("states_existing_quality_values", all(token in plan for token in [
        "26.2949",
        "30.8645",
        "28.3118",
        "34.4297",
        "+2.0169",
        "+3.5652",
    ]), "current interpolation and FP32 values")
    add("states_no_board_output_impact", all(token in plan for token in [
        "没有板端输出图像时",
        "不能声称板端 PSNR/SSIM/FPS/功耗",
        "不能写作“板端 x4/x2 已达到目标 PSNR”",
    ]), "board-output limitation")
    add("states_fixed_metric_contract", all(token in plan for token in [
        "tools/evaluate_w8a12_fixed_quality.py",
        "evidence/quality_fixed/x4_w8a12/summary.md",
        "evidence/quality_fixed/x2_w8a12/summary.md",
        "REDS_val 全量 3000 images",
        "psnr_rgb_avg >= 28.0",
        "psnr_rgb_avg >= 30.0",
    ]), "W8A12 fixed full-metric contract")
    add("states_board_metric_contract", all(token in plan for token in [
        "a5_32x32",
        "a6_64x64",
        "a7_720p_x4",
        "x2_720p",
        "FPS >= 15",
        "power",
        "PSNR/SSIM",
    ]), "board metric contract")
    add("quality_comparison_keeps_pending_fixed_board", all(token in comparison for token in [
        "| x4 | W8A12 fixed | 待跑",
        "| x4 | board | 待跑",
        "| x2 | W8A12 fixed | 待跑",
        "| x2 | board | 待跑",
    ]), "fixed and board rows remain pending")
    add("report_does_not_claim_board_measured_quality", all(token in report for token in [
        "没有真实板图输出前",
        "不将模型/RTL 等效指标写成板端实测指标",
        "板端实测待补",
    ]), "report separates model/board metrics")
    add("report_links_quality_evidence", all(token in report for token in [
        "evidence/quality_comparison/summary.md",
        "REDS val 全量 baseline",
        "传统插值",
    ]), "report links quality evidence")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"QUALITY_METRIC_COMPLETION_STATUS={data['status']}")
    print(f"QUALITY_METRIC_COMPLETION_MD={OUT / 'summary.md'}")
    print(f"QUALITY_METRIC_COMPLETION_JSON={OUT / 'summary.json'}")
    return 0 if ok else 1


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def render_md(data: dict) -> str:
    lines = [
        "# Quality Metric Completion Static Check",
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
