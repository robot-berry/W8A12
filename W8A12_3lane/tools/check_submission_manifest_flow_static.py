#!/usr/bin/env python3
"""Static checks for submission and delivery manifest collectors."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "submission_package" / "flow_static"


def main() -> int:
    submission = BASE / "tools" / "collect_submission_package.py"
    delivery = BASE / "tools" / "collect_delivery_manifest.py"
    archive = BASE / "tools" / "create_submission_archive.py"
    matrix = BASE / "tools" / "generate_delivery_evidence_matrix.py"
    sub_text = submission.read_text(encoding="utf-8", errors="ignore") if submission.exists() else ""
    del_text = delivery.read_text(encoding="utf-8", errors="ignore") if delivery.exists() else ""
    archive_text = archive.read_text(encoding="utf-8", errors="ignore") if archive.exists() else ""
    matrix_text = matrix.read_text(encoding="utf-8", errors="ignore") if matrix.exists() else ""
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    add("file:submission_collector", submission.exists(), submission.relative_to(ROOT).as_posix())
    add("file:delivery_collector", delivery.exists(), delivery.relative_to(ROOT).as_posix())
    add("file:submission_archive", archive.exists(), archive.relative_to(ROOT).as_posix())
    add("file:delivery_matrix", matrix.exists(), matrix.relative_to(ROOT).as_posix())
    add("submission_requires_ooc_raw_reports", all(token in sub_text for token in [
        "evidence/top/accel_top_ooc/utilization_ooc.rpt",
        "evidence/top/accel_top_ooc/timing_ooc.rpt",
        "evidence/resource/A4_single_lane_mac_scheduler_ooc/utilization_ooc.rpt",
        "evidence/resource/A4_single_lane_mac_scheduler_ooc/timing_ooc.rpt",
        "evidence/resource/A4_3lane_mac_scheduler_ooc/utilization_ooc.rpt",
        "evidence/resource/A4_3lane_mac_scheduler_ooc/timing_ooc.rpt",
    ]), "OOC raw reports in final requirement list")
    add("submission_includes_ooc_raw_globs", "*_ooc.rpt" in sub_text, "OOC raw report globs")
    add("delivery_includes_ooc_raw_globs", "*_ooc.rpt" in del_text, "delivery raw report globs")
    add("submission_requires_quality_baseline", all(token in sub_text for token in [
        "evidence/quality_baseline/x4_interpolation/summary.md",
        "evidence/quality_baseline/x2_interpolation/summary.md",
        "evidence/quality_comparison/summary.md",
        "evidence/quality_metric_completion/summary.md",
    ]), "traditional interpolation baseline final evidence")
    add("manifests_include_quality_baseline_globs", "evidence/quality_baseline/*/*summary*" in sub_text and "evidence/quality_baseline/*/*summary*" in del_text, "quality baseline globs")
    add("manifests_include_quality_comparison_globs", "evidence/quality_comparison/*summary*" in sub_text and "evidence/quality_comparison/*summary*" in del_text, "quality comparison globs")
    add("manifests_include_quality_metric_completion_globs", "evidence/quality_metric_completion/*" in sub_text and "evidence/quality_metric_completion/*" in del_text, "quality metric completion globs")
    add("manifests_include_delivery_matrix", "evidence/delivery_matrix/*" in sub_text and "evidence/delivery_matrix/summary.md" in del_text, "delivery evidence matrix")
    add("manifests_include_report_pdf", all(token in sub_text and token in del_text for token in [
        "evidence/report_pdf/*",
        "evidence/report_pdf/rendered/*.png",
        "output/pdf/*.pdf",
    ]), "PDF report evidence and artifact globs")
    add("manifests_include_delivery_run_summaries", "evidence/delivery_runs/*/summary.*" in sub_text and "evidence/delivery_runs/*/summary.*" in del_text, "delivery gate run summaries")
    add("manifests_include_board_probe_evidence", "evidence/board_probe/*/*" in sub_text and "evidence/board_probe/*/*" in del_text, "board probe/precondition evidence")
    add("manifests_include_nested_board_probe_evidence", "evidence/board_probe/*/*/*" in sub_text and "evidence/board_probe/*/*/*" in del_text, "nested USB/preflight evidence")
    add("manifests_include_board_report_md_globs", "evidence/board_reports/*.md" in sub_text and "evidence/board_reports/*.md" in del_text, "board report markdown globs")
    add("manifests_include_board_report_summaries", "evidence/board_reports/*/summary.*" in sub_text and "evidence/board_reports/*/summary.*" in del_text, "board report summary globs")
    add("submission_keeps_core_final_evidence", all(token in sub_text for token in [
        "evidence/top/accel_top_sim/summary.md",
        "evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md",
        "evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md",
        "evidence/x2/w8a12_export/summary.md",
        "evidence/x2/reference/summary.md",
        "evidence/x2/reference_validation/validation.md",
        "evidence/report_pdf/summary.md",
        "evidence/board_reports/x2_720p/validation.md",
    ]), "core final evidence")
    add("submission_excludes_large_binaries", all(token in sub_text for token in [".dcp", ".bit", ".xsa", ".pth", ".pt"]), "large binary exclusions")
    add("manifests_exclude_zip_archive", '".zip"' in sub_text and '".zip"' in del_text, "zip archive is not part of recursive manifests")
    add("delivery_manifest_includes_archive_summary", "evidence/submission_package/archive/summary.md" in del_text and "evidence/submission_package/archive/summary.json" in del_text, "archive summary is tracked")
    add("submission_archive_is_deterministic", all(token in archive_text for token in [
        "FIXED_ZIP_DATE",
        "zipfile.ZIP_DEFLATED",
        "sorted(entries",
        "sha256(archive)",
    ]), "fixed timestamp, sorted entries, compressed zip, sha256")
    add("submission_archive_allows_draft_only_explicitly", all(token in archive_text for token in [
        "--allow-incomplete",
        "draft package, not final contest delivery",
    ]), "incomplete archives are explicit drafts")
    add("delivery_matrix_reads_current_evidence", all(token in matrix_text for token in [
        "contest_delivery_audit.json",
        "submission_manifest.json",
        "report_pdf",
        "Remaining Final Evidence",
    ]), "matrix is generated from current audit/submission/PDF evidence")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Submission Manifest Flow Static Check",
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
