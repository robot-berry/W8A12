#!/usr/bin/env python3
"""Static checks for missing-evidence command generation."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "delivery_audit" / "missing_plan_flow_static"


def main() -> int:
    tool = BASE / "tools" / "generate_missing_evidence_plan.py"
    text = tool.read_text(encoding="utf-8", errors="ignore") if tool.exists() else ""
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    add("file:generate_missing_evidence_plan", tool.exists(), tool.relative_to(ROOT).as_posix())
    add("self_bootstrap_audit", "load_or_compute_audit" in text and "AUDIT_TOOL" in text, "can compute audit items without existing audit JSON")
    add("skips_self_missing_plan", 'name == "missing_evidence_plan"' in text, "does not require its own output before creation")
    add("accel_cmd_fallbacks", "run_vivado_sim_w8a12_3lane_accel_top.cmd" in text and "run_vivado_synth_w8a12_3lane_accel_top_ooc.cmd" in text, "accel top cmd fallbacks")
    add("a4_cmd_fallbacks", all(token in text for token in [
        "run_vivado_sim_w8a12_single_lane_mac_scheduler.cmd",
        "run_vivado_sim_w8a12_3lane_mac_scheduler.cmd",
        "run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.cmd",
        "run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.cmd",
    ]), "A4 cmd fallbacks")
    add("board_resource_args", all(token in text for token in ["--lut-used", "--ff-used", "--bram-tile-used", "--dsp-used"]), "board report resource used arguments")
    add("vivado_probe_gate_mapped", all(token in text for token in ["board.vivado_hw_probe", "probe_vivado_hw_targets.ps1", "check_vivado_hw_probe_log.cmd"]), "Vivado JTAG probe pre-board gate")
    add("board_psnr_targets", "<psnr_ge_28>" in text and "<psnr_ge_30>" in text, "x4/x2 PSNR placeholders")
    add("x2_export_is_separate", '"x2.w8a12_export"' in text and "export_x2_w8a12_to_rtl.cmd" in text, "x2 export commands")
    add("x2_reference_validation_is_separate", '"x2.fixed_reference_validation"' in text and "check_x2_fixed_reference.py" in text, "x2 validation command")
    add("quality_baseline_commands", all(token in text for token in [
        "quality.x4_interpolation_baseline",
        "quality.x2_interpolation_baseline",
        "quality.comparison_report",
        "evaluate_interpolation_baseline.py",
        "generate_quality_comparison_report.py",
        "--span-fp32-psnr-db 28.3118",
        "--span-fp32-psnr-db 34.4297",
    ]), "traditional interpolation baseline commands")
    add("board_tags_mapped", all(token in text for token in ["a5.board_32x32", "a6.board_64x64", "a7.board_720p_x4", "x2.board"]), "board tags")
    add("manifest_commands_mapped", "collect_delivery_manifest.py" in text and "collect_submission_package.py" in text, "manifest commands")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Missing Evidence Plan Flow Static Check",
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
