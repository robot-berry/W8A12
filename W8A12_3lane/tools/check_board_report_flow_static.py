#!/usr/bin/env python3
"""Static checks for board report creation, update, and validation flow."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "board_reports" / "flow_static"


FILES = {
    "create": BASE / "tools" / "create_board_report.py",
    "update": BASE / "tools" / "update_board_report.py",
    "finalize": BASE / "tools" / "finalize_board_report_from_outputs.py",
    "validate": BASE / "tools" / "validate_board_report.py",
    "doc": BASE / "docs" / "board_report_flow.md",
    "audit": BASE / "tools" / "audit_contest_delivery.py",
    "missing_plan": BASE / "tools" / "generate_missing_evidence_plan.py",
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

    create = texts["create"]
    update = texts["update"]
    finalize = texts["finalize"]
    validate = texts["validate"]
    doc = texts["doc"]
    audit = texts["audit"]
    missing = texts["missing_plan"]

    add("create_defaults_pending", '"status": args.status' in create and "PENDING" in create, "skeleton cannot pass by default")
    add("create_uses_board_part", "xczu19eg-ffvc1760-2-i" in create, "actual board part")
    add("create_uses_xc7z045_limits", "218600" in create and "437200" in create and "545" in create and "900" in create, "ZC706/XC7Z045 equivalent limits")
    add("create_records_output_pixels", "expected_output_pixels" in create and "hr_width * hr_height" in create, "output size")
    add("create_records_tile_pipeline", all(token in create for token in ["--tile-width", "--tile-height", "--halo", "downsample_on_ps", "tile_count_x", "stitch_output"]), "SD/downsample/tile+halo metadata")
    add("create_records_perf_quality", "latency_ms" in create and "fps" in create and "power_w" in create and "psnr_db" in create and "ssim" in create, "perf/quality fields")

    add("update_accepts_resource_used", all(token in update for token in ["--lut-used", "--ff-used", "--bram-tile-used", "--dsp-used"]), "resource used CLI")
    add("update_accepts_timing_perf_quality", all(token in update for token in ["--wns-ns", "--whs-ns", "--clock-mhz", "--latency-ms", "--fps", "--target-fps", "--power-w", "--psnr-db", "--ssim"]), "timing/perf/quality CLI")
    add("update_accepts_required_files", all(token in update for token in ["--bitstream", "--utilization-report", "--timing-report", "--fixed-reference", "--board-output"]), "evidence file CLI")

    add("finalize_computes_mismatch_from_files", all(token in finalize for token in ["compare_bytes", "mismatch_bytes", "--board-output", "--fixed-reference"]), "computed board/reference compare")
    add("finalize_computes_psnr", "math.log10" in finalize and "psnr_db" in finalize, "computed PSNR")
    add("finalize_requires_real_metrics", all(token in finalize for token in ["required=True", "--lut-used", "--wns-ns", "--fps", "--power-w"]), "required resource/timing/perf metrics")
    add("finalize_runs_validator", "validate_board_report.py" in finalize and "validation.md" in finalize, "final validation emission")

    add("validate_rejects_nonpass", "status_pass" in validate, "status PASS")
    add("validate_requires_frame_done", "frame_done" in validate and "error_false" in validate, "frame done/error")
    add("validate_requires_bit_exact", "bit_exact_to_fixed_reference" in validate, "bit exact")
    add("validate_requires_resource_limits", "_within_limit" in validate and "lut_used" in validate and "bram_tile_used" in validate and "dsp_used" in validate, "resource values within limits")
    add("validate_requires_timing", "wns_nonnegative" in validate and "whs_nonnegative" in validate, "timing slack")
    add("validate_requires_perf_power", "clock_present" in validate and "latency_present" in validate and "fps_present" in validate and "fps_meets_target" in validate and "power_present" in validate, "perf/power")
    add("validate_requires_psnr_targets", "quality_psnr_meets_target" in validate and "30.0 if scale == 2" in validate and "28.0 if scale == 4" in validate, "x2/x4 PSNR targets")
    add("validate_requires_files", all(token in validate for token in ["bitstream", "utilization_report", "timing_report", "fixed_reference", "board_output"]), "required evidence files")

    add("doc_lists_four_required_reports", all(token in doc for token in ["a5_32x32", "a6_64x64", "a7_720p_x4", "x2_720p"]), "required board report tags")
    add("doc_states_x4_x2_targets", ">= 28 dB" in doc and ">= 30 dB" in doc, "quality targets")
    add("doc_requires_board_summary", "summary.md" in doc and "validation.md" in doc, "report and validation outputs")
    add("doc_lists_finalize_tool", "finalize_board_report_from_outputs.py" in doc and "自动计算 byte mismatch" in doc, "auto finalize flow")
    add("doc_requires_resource_perf_quality", all(token in doc for token in ["资源消耗", "FPS", "target_fps", "延迟", "PSNR", "SSIM"]), "reporting cadence")
    add("doc_separates_fps_and_psnr", "x4 >= 28 dB" in doc and "不是 FPS" in doc and "15" in doc and "20" in doc and "30" in doc, "FPS and PSNR separated")

    add("audit_requires_board_validations", all(token in audit for token in ["a5.board_32x32", "a6.board_64x64", "a7.board_720p_x4", "x2.board"]), "audit board gates")
    add("missing_plan_maps_board_commands", all(token in missing for token in ["create_board_report.py", "finalize_board_report_from_outputs.py", "validate_board_report.py"]), "missing plan commands")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Board Report Flow Static Check",
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
