#!/usr/bin/env python3
"""Check contest-scope readiness separately from strict board validation."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "contest_scope_readiness"

BOARD_VALIDATION_GAPS = [
    "evidence/board_reports/a5_32x32/validation.md",
    "evidence/board_reports/a6_64x64/validation.md",
    "evidence/board_reports/a7_720p_x4/validation.md",
    "evidence/board_reports/x2_720p/validation.md",
]


def read_json(rel: str) -> dict | None:
    path = BASE / rel
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def read_text(rel: str) -> str:
    path = BASE / rel
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def exists(rel: str) -> bool:
    return (BASE / rel).exists()


def json_status(rel: str, allowed: set[str]) -> tuple[bool, str]:
    data = read_json(rel)
    if data is None:
        return False, "missing or invalid json"
    status = str(data.get("status", ""))
    return status in allowed, status


def all_exist(paths: list[str]) -> tuple[bool, str]:
    missing = [path for path in paths if not exists(path)]
    return not missing, "missing: " + ", ".join(missing) if missing else "all present"


def add(checks: list[dict], name: str, passed: bool, evidence: str, detail: object) -> None:
    checks.append(
        {
            "name": name,
            "pass": bool(passed),
            "evidence": evidence,
            "detail": detail,
        }
    )


def check_quality_metrics() -> tuple[bool, dict]:
    data = read_json("evidence/quality_comparison/summary.json")
    if data is None or data.get("status") != "PASS":
        return False, {"status": "missing"}
    rows = data.get("rows", [])
    x4 = next((row for row in rows if row.get("scale") == 4 and row.get("method") == "SPAN FP32"), {})
    x2 = next((row for row in rows if row.get("scale") == 2 and row.get("method") == "SPAN FP32"), {})
    x4_psnr = float(x4.get("psnr_rgb_db") or 0.0)
    x2_psnr = float(x2.get("psnr_rgb_db") or 0.0)
    detail = {"x4_span_fp32_psnr_rgb_db": x4_psnr, "x2_span_fp32_psnr_rgb_db": x2_psnr}
    return x4_psnr >= 28.0 and x2_psnr >= 30.0, detail


def check_full_reds_scope() -> tuple[bool, str]:
    text = read_text("docs/contest_submission_report.md") + "\n" + read_text("docs/python_reference_plan.md")
    tokens = ["24000 images", "3000 images", "REDS train", "REDS val", "28.3118", "34.4297"]
    missing = [token for token in tokens if token not in text]
    return not missing, "missing tokens: " + ", ".join(missing) if missing else "full train/val scope stated"


def check_x4_fps() -> tuple[bool, dict]:
    data = read_json("evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.json")
    if data is None:
        return False, {"status": "missing"}
    rec = data.get("recommended_closure_candidate", {})
    low = data.get("minimum_resource_candidate", {})
    passed = (
        data.get("status") == "PASS"
        and data.get("closure_level") == "scheduler/performance-model"
        and rec.get("candidate") == "24x72"
        and bool(rec.get("passes_15fps"))
        and int(rec.get("estimated_dsp", 99999)) <= 900
        and low.get("candidate") == "24x64"
        and bool(low.get("passes_15fps"))
    )
    return passed, {
        "status": data.get("status"),
        "closure_level": data.get("closure_level"),
        "recommended": rec,
        "minimum_resource": low,
    }


def check_x2_fps() -> tuple[bool, dict]:
    data = read_json("evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.json")
    if data is None:
        return False, {"status": "missing"}
    rec = data.get("recommended_closure_candidate", {})
    boundary = data.get("resource_boundary_candidate", {})
    passed = (
        data.get("status") == "PASS"
        and data.get("closure_level") == "scheduler/performance-model"
        and rec.get("candidate") == "24x72"
        and bool(rec.get("passes_4fps"))
        and not bool(rec.get("passes_20fps"))
        and int(rec.get("estimated_dsp", 99999)) <= 900
        and boundary.get("candidate") == "24x64"
    )
    return passed, {
        "status": data.get("status"),
        "closure_level": data.get("closure_level"),
        "recommended": rec,
        "resource_boundary": boundary,
        "scope_boundary": data.get("scope_boundary"),
    }


def check_strict_audit_gap_scope() -> tuple[bool, dict]:
    data = read_json("evidence/delivery_audit/contest_delivery_audit.json")
    if data is None:
        return False, {"status": "missing"}
    failed = [
        item.get("path", "")
        for item in data.get("items", [])
        if not item.get("pass", False)
    ]
    normalized = sorted(path.replace("\\", "/").removeprefix("W8A12_3lane/") for path in failed)
    expected = sorted(BOARD_VALIDATION_GAPS)
    return normalized == expected, {
        "strict_audit_status": data.get("status"),
        "strict_failed_paths": normalized,
        "non_blocking_for_contest_scope": expected,
    }


def check_submission_missing_scope() -> tuple[bool, dict]:
    data = read_json("evidence/submission_package/submission_manifest.json")
    if data is None:
        return False, {"status": "missing"}
    missing = sorted(str(item).replace("\\", "/") for item in data.get("missing_final_evidence", []))
    expected = sorted(BOARD_VALIDATION_GAPS)
    return missing == expected, {
        "submission_manifest_status": data.get("status"),
        "missing_final_evidence": missing,
    }


def build_summary() -> dict:
    checks: list[dict] = []

    for rel in [
        "README.md",
        "WORKFLOW.md",
        "DELIVERY_INDEX.md",
        "docs/contest_submission_readme.md",
        "docs/contest_submission_report.md",
        "docs/w8a12_3lane_architecture.md",
        "docs/bank_mapping_rules.md",
        "docs/board_report_flow.md",
        "docs/failure_rollback_flow.md",
    ]:
        add(checks, f"file:{rel}", exists(rel), rel, "required contest document")

    passed, detail = check_full_reds_scope()
    add(checks, "model.full_reds_train_val_scope", passed, "docs/contest_submission_report.md", detail)

    passed, detail = check_quality_metrics()
    add(checks, "quality.fp32_targets", passed, "evidence/quality_comparison/summary.json", detail)

    for rel in [
        "evidence/quality_baseline/x4_interpolation/summary.md",
        "evidence/quality_baseline/x2_interpolation/summary.md",
        "evidence/quality_comparison/summary.md",
        "evidence/quality_metric_completion/summary.md",
    ]:
        add(checks, f"quality.file:{rel}", exists(rel), rel, "quality/baseline evidence")

    for rel in [
        "evidence/x2/w8a12_export/summary.json",
        "evidence/x2/reference/summary.json",
        "evidence/x2/reference_validation/validation.json",
        "evidence/x2/flow_static/summary.json",
    ]:
        passed, detail = json_status(rel, {"PASS", "READY"})
        add(checks, f"x2.status:{rel}", passed, rel, detail)

    rtl_paths = [
        "evidence/reference/A0_single_conv/a0_rtl_sim_summary.md",
        "evidence/reference/A1_single_block/a1_rtl_sim_summary.md",
        "evidence/reference/A2_six_blocks/a2_rtl_sim_summary.md",
        "evidence/reference/A2_tile_pipeline_shell/tile_pipeline_shell_static_check.md",
        "evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md",
        "evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md",
        "evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md",
        "evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.md",
        "evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.md",
        "evidence/top/accel_top_sim/summary.md",
        "evidence/top/accel_top_ooc/ooc_summary.md",
    ]
    passed, detail = all_exist(rtl_paths)
    add(checks, "rtl.layered_sim_and_ooc_evidence", passed, "evidence/reference + evidence/resource + evidence/top", detail)

    for rel, allowed in [
        ("evidence/ppa_summary/summary.json", {"PASS"}),
        ("evidence/bitstream_ppa_gate/summary.json", {"PASS_WITH_SCOPE"}),
        ("evidence/report_static/summary.json", {"PASS"}),
        ("evidence/report_pdf/summary.json", {"PASS"}),
        ("evidence/report_docx_complete_20260701/summary.json", {"PASS"}),
        ("evidence/delivery_matrix/summary.json", {"PASS"}),
        ("evidence/github_upload_preflight/summary.json", {"PASS"}),
    ]:
        passed, detail = json_status(rel, allowed)
        add(checks, f"gate.status:{rel}", passed, rel, detail)

    docx = read_json("evidence/report_docx_complete_20260701/summary.json") or {}
    color_audit = docx.get("text_color_audit", {})
    add(
        checks,
        "report.docx_black_font_audit",
        color_audit.get("status") == "PASS" and color_audit.get("non_black_text_color_count") == 0,
        "evidence/report_docx_complete_20260701/summary.json",
        color_audit,
    )

    passed, detail = check_x4_fps()
    add(checks, "fps.x4_720p15_scheduler_closure", passed, "evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.json", detail)

    passed, detail = check_x2_fps()
    add(checks, "fps.x2_720p4_scheduler_closure", passed, "evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.json", detail)

    passed, detail = check_strict_audit_gap_scope()
    add(checks, "scope.strict_audit_gaps_are_board_only", passed, "evidence/delivery_audit/contest_delivery_audit.json", detail)

    passed, detail = check_submission_missing_scope()
    add(checks, "scope.submission_missing_is_board_only", passed, "evidence/submission_package/submission_manifest.json", detail)

    ok = all(item["pass"] for item in checks)
    return {
        "status": "PASS_WITH_SCOPE" if ok else "FAIL",
        "scope": "Contest report / RTL simulation / bitstream-PPA evidence. Physical board validation remains an engineering follow-up.",
        "strict_board_validation_status": "INCOMPLETE",
        "non_blocking_board_validation_gaps": BOARD_VALIDATION_GAPS,
        "claims": {
            "x4_720p15_scheduler_fps": "PASS_WITH_SCOPE",
            "x2_720p4_scheduler_fps": "PASS_WITH_SCOPE",
            "x2_720p20_scheduler_fps": "NOT_CLAIMED",
            "true2x2_bitstream_ppa": "PASS_WITH_SCOPE",
            "physical_board_720p_output": "NOT_CLAIMED",
        },
        "checks": checks,
    }


def render_md(data: dict) -> str:
    lines = [
        "# Contest Scope Readiness",
        "",
        f"Status: {data['status']}",
        "",
        f"Scope: {data['scope']}",
        "",
        "This gate is intentionally separate from the stricter board-validation audit.",
        "",
        "## Claims",
        "",
        "| Claim | Status |",
        "| --- | --- |",
    ]
    for name, status in data["claims"].items():
        lines.append(f"| `{name}` | `{status}` |")
    lines.extend(
        [
            "",
            "## Non-Blocking Board Validation Gaps",
            "",
        ]
    )
    for gap in data["non_blocking_board_validation_gaps"]:
        lines.append(f"- `{gap}`")
    lines.extend(
        [
            "",
            "## Checks",
            "",
            "| Check | Result | Evidence | Detail |",
            "| --- | --- | --- | --- |",
        ]
    )
    for check in data["checks"]:
        detail = json.dumps(check["detail"], ensure_ascii=False, sort_keys=True)
        detail = detail.replace("|", "/")
        lines.append(
            f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | `{check['evidence']}` | `{detail}` |"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    data = build_summary()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"CONTEST_SCOPE_READINESS_STATUS={data['status']}")
    print(f"CONTEST_SCOPE_READINESS_MD={OUT / 'summary.md'}")
    print(f"CONTEST_SCOPE_READINESS_JSON={OUT / 'summary.json'}")
    return 0 if data["status"] == "PASS_WITH_SCOPE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
