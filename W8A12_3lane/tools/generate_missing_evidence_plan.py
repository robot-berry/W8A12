#!/usr/bin/env python3
"""Generate command-level next steps for missing delivery evidence."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "W8A12_3lane" / "evidence" / "delivery_audit" / "contest_delivery_audit.json"
AUDIT_TOOL = ROOT / "W8A12_3lane" / "tools" / "audit_contest_delivery.py"
OUT_MD = ROOT / "W8A12_3lane" / "evidence" / "delivery_audit" / "missing_evidence_plan.md"
OUT_JSON = ROOT / "W8A12_3lane" / "evidence" / "delivery_audit" / "missing_evidence_plan.json"

COMMANDS = {
    "top.accel_shell_sim": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\run_vivado_sim_w8a12_3lane_accel_top.ps1",
        "W8A12_3lane\\scripts\\run_vivado_sim_w8a12_3lane_accel_top.cmd",
    ],
    "top.accel_shell_ooc": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\run_vivado_synth_w8a12_3lane_accel_top_ooc.ps1",
        "W8A12_3lane\\scripts\\run_vivado_synth_w8a12_3lane_accel_top_ooc.cmd",
    ],
    "top.accel_shell_ooc_summary": [
        "python W8A12_3lane\\tools\\summarize_ooc_result.py --tag accel_top --report-dir W8A12_3lane\\evidence\\top\\accel_top_ooc",
    ],
    "a4.single_lane_sim": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1",
        "W8A12_3lane\\scripts\\run_vivado_sim_w8a12_single_lane_mac_scheduler.cmd",
    ],
    "a4.3lane_sim": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\run_vivado_sim_w8a12_3lane_mac_scheduler.ps1",
        "W8A12_3lane\\scripts\\run_vivado_sim_w8a12_3lane_mac_scheduler.cmd",
    ],
    "a4.single_lane_ooc": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.ps1",
        "W8A12_3lane\\scripts\\run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.cmd",
    ],
    "a4.3lane_ooc": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1",
        "W8A12_3lane\\scripts\\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.cmd",
    ],
    "a4.single_lane_ooc_summary": [
        "python W8A12_3lane\\tools\\summarize_ooc_result.py --tag single_lane --report-dir W8A12_3lane\\evidence\\resource\\A4_single_lane_mac_scheduler_ooc",
    ],
    "a4.3lane_ooc_summary": [
        "python W8A12_3lane\\tools\\summarize_ooc_result.py --tag 3lane --report-dir W8A12_3lane\\evidence\\resource\\A4_3lane_mac_scheduler_ooc",
    ],
    "board.vivado_hw_probe": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\probe_vivado_hw_targets.ps1 -OutputDir board_runs\\vivado_hw_target_probe_w8a12_3lane",
        "W8A12_3lane\\scripts\\check_vivado_hw_probe_log.cmd --probe-dir board_runs\\vivado_hw_target_probe_w8a12_3lane",
    ],
    "a5.board_32x32": [
        "python W8A12_3lane\\tools\\create_board_report.py --tag a5_32x32 --scale 4 --lr-width 32 --lr-height 32 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode \"tile+halo crop-stitch\"",
        "python W8A12_3lane\\tools\\update_board_report.py W8A12_3lane\\evidence\\board_reports\\a5_32x32\\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_28> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>",
        "python W8A12_3lane\\tools\\validate_board_report.py W8A12_3lane\\evidence\\board_reports\\a5_32x32\\summary.json --json-out W8A12_3lane\\evidence\\board_reports\\a5_32x32\\validation.json --md-out W8A12_3lane\\evidence\\board_reports\\a5_32x32\\validation.md",
    ],
    "a6.board_64x64": [
        "python W8A12_3lane\\tools\\create_board_report.py --tag a6_64x64 --scale 4 --lr-width 64 --lr-height 64 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode \"tile+halo crop-stitch\"",
        "python W8A12_3lane\\tools\\update_board_report.py W8A12_3lane\\evidence\\board_reports\\a6_64x64\\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_28> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>",
        "python W8A12_3lane\\tools\\validate_board_report.py W8A12_3lane\\evidence\\board_reports\\a6_64x64\\summary.json --json-out W8A12_3lane\\evidence\\board_reports\\a6_64x64\\validation.json --md-out W8A12_3lane\\evidence\\board_reports\\a6_64x64\\validation.md",
    ],
    "a7.board_720p_x4": [
        "python W8A12_3lane\\tools\\create_board_report.py --tag a7_720p_x4 --scale 4 --lr-width 320 --lr-height 180 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode \"tile+halo crop-stitch\"",
        "python W8A12_3lane\\tools\\update_board_report.py W8A12_3lane\\evidence\\board_reports\\a7_720p_x4\\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_28> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>",
        "python W8A12_3lane\\tools\\validate_board_report.py W8A12_3lane\\evidence\\board_reports\\a7_720p_x4\\summary.json --json-out W8A12_3lane\\evidence\\board_reports\\a7_720p_x4\\validation.json --md-out W8A12_3lane\\evidence\\board_reports\\a7_720p_x4\\validation.md",
    ],
    "x2.w8a12_export": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\\scripts\\export_x2_w8a12_to_rtl.ps1",
        "W8A12_3lane\\scripts\\export_x2_w8a12_to_rtl.cmd",
        "python W8A12_3lane\\tools\\check_x2_reference_readiness.py",
        "python W8A12_3lane\\tools\\find_x2_assets.py",
        "python W8A12_3lane\\tools\\check_x2_w8a12_export.py",
    ],
    "x2.fixed_reference": [
        "python W8A12_3lane\\tools\\w8a12_3lane_reference.py a3-tail-rgb --rtl-manifest rtl\\generated\\reds_span_x2_f48_w8a12\\span_w8a12_rtl_manifest.json --postprocess-manifest rtl\\generated\\reds_span_x2_f48_w8a12\\postprocess\\span_w8a12_postprocess_manifest.json --out-dir W8A12_3lane\\evidence\\x2\\reference",
    ],
    "x2.fixed_reference_validation": [
        "python W8A12_3lane\\tools\\check_x2_fixed_reference.py",
    ],
    "quality.x4_interpolation_baseline": [
        "python W8A12_3lane\\tools\\evaluate_interpolation_baseline.py --scale 4 --gt-dir G:\\REDS\\val_sharp --lq-dir G:\\REDS\\val\\val_sharp_bicubic\\X4 --span-fp32-psnr-db 28.3118 --out-dir W8A12_3lane\\evidence\\quality_baseline\\x4_interpolation",
    ],
    "quality.x2_interpolation_baseline": [
        "python W8A12_3lane\\tools\\evaluate_interpolation_baseline.py --scale 2 --gt-dir G:\\REDS\\val_sharp --lq-dir G:\\REDS\\val\\val_sharp_bicubic\\X2 --span-fp32-psnr-db 34.4297 --out-dir W8A12_3lane\\evidence\\quality_baseline\\x2_interpolation",
    ],
    "quality.comparison_report": [
        "python W8A12_3lane\\tools\\generate_quality_comparison_report.py",
    ],
    "quality.metric_completion_static": [
        "python W8A12_3lane\\tools\\check_quality_metric_completion_static.py",
    ],
    "x2.board": [
        "python W8A12_3lane\\tools\\create_board_report.py --tag x2_720p --scale 2 --lr-width 640 --lr-height 360 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode \"tile+halo crop-stitch\"",
        "python W8A12_3lane\\tools\\update_board_report.py W8A12_3lane\\evidence\\board_reports\\x2_720p\\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_30> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>",
        "python W8A12_3lane\\tools\\validate_board_report.py W8A12_3lane\\evidence\\board_reports\\x2_720p\\summary.json --json-out W8A12_3lane\\evidence\\board_reports\\x2_720p\\validation.json --md-out W8A12_3lane\\evidence\\board_reports\\x2_720p\\validation.md",
    ],
    "delivery_manifest": [
        "python W8A12_3lane\\tools\\collect_delivery_manifest.py",
    ],
    "submission_manifest": [
        "python W8A12_3lane\\tools\\collect_submission_package.py",
    ],
}

NOTES = {
    "top.accel_shell_sim": "Requires Vivado/xsim to validate accelerator top control/status sequencing.",
    "top.accel_shell_ooc": "Requires Vivado synthesis for the board-facing control/status top.",
    "top.accel_shell_ooc_summary": "Summarizes accelerator top OOC utilization/timing against XC7Z045 limits.",
    "a4.single_lane_sim": "Requires Vivado/xsim to produce PASS log and single_lane_scheduler_sim_summary.md.",
    "a4.3lane_sim": "Run only after single-lane sim passes.",
    "a4.single_lane_ooc": "Requires Vivado synthesis; then summarize OOC.",
    "a4.3lane_ooc": "Requires Vivado synthesis; then summarize OOC.",
    "board.vivado_hw_probe": "Board reports require Vivado to see at least one hardware target and device first.",
    "a5.board_32x32": "Skeleton report is not enough; replace placeholders in update_board_report.py command with real board data/files before validation can PASS.",
    "a6.board_64x64": "Depends on A5 passing.",
    "a7.board_720p_x4": "Depends on A6 and full-frame/tile integration.",
    "x2.fixed_reference": "Requires successful x2 W8A12 export first; a3-tail-rgb reads scale from the x2 RTL manifest.",
    "quality.x4_interpolation_baseline": "Run REDS_val x4 interpolation baseline to report SPAN/W8A12 improvement over bicubic.",
    "quality.x2_interpolation_baseline": "Run REDS_val x2 interpolation baseline to report SPAN/W8A12 improvement over bicubic.",
    "quality.comparison_report": "Depends on x4/x2 interpolation baseline summaries; produces final PSNR improvement table.",
    "quality.metric_completion_static": "Checks that the report separates FP32, W8A12 fixed, RTL, and board quality metrics and keeps pending board metrics explicit.",
    "x2.board": "Depends on x2 fixed reference and board integration; replace placeholders with real board data/files.",
}


def main() -> int:
    audit = load_or_compute_audit()
    missing = [item for item in audit["items"] if not item.get("pass", False)]
    plan = []
    for item in missing:
        name = item["name"]
        if name == "missing_evidence_plan":
            continue
        plan.append(
            {
                "name": name,
                "path": item["path"],
                "required_text": item.get("required_text"),
                "commands": COMMANDS.get(name, []),
                "note": NOTES.get(name, ""),
            }
        )
    OUT_JSON.write_text(json.dumps({"status": "INCOMPLETE", "missing_count": len(plan), "items": plan}, indent=2), encoding="utf-8")
    OUT_MD.write_text(render_md(plan), encoding="utf-8")
    return 0 if not plan else 1


def load_or_compute_audit() -> dict:
    """Return a current audit-like item list without requiring audit JSON.

    This avoids a bootstrap cycle: the strict audit checks that
    missing_evidence_plan.md exists, while this tool creates that file.
    """
    if not AUDIT_TOOL.exists():
        if AUDIT.exists():
            return json.loads(AUDIT.read_text(encoding="utf-8"))
        return {"status": "INCOMPLETE", "items": []}

    text = AUDIT_TOOL.read_text(encoding="utf-8", errors="ignore")
    pattern = re.compile(r'\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(None|"[^"]*")\s*\)')
    rows = []
    for name, rel, required_raw in pattern.findall(text):
        if not rel.startswith("W8A12_3lane/"):
            continue
        required_text = None if required_raw == "None" else required_raw.strip('"')
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
    return {"status": "PASS" if all(row["pass"] for row in rows) else "INCOMPLETE", "items": rows}


def render_md(plan: list[dict]) -> str:
    lines = [
        "# Missing Evidence Plan",
        "",
        f"Missing count: {len(plan)}",
        "",
        "该文件把当前交付审计中未通过的项目映射到下一步命令。命令执行成功后仍需重新运行 `audit_contest_delivery.py`。",
        "",
    ]
    for item in plan:
        lines.extend(
            [
                f"## {item['name']}",
                "",
                f"- required path: `{item['path']}`",
                f"- required text: `{item['required_text']}`",
            ]
        )
        if item["note"]:
            lines.append(f"- note: {item['note']}")
        if item["commands"]:
            lines.extend(["", "```powershell"])
            lines.extend(item["commands"])
            lines.append("```")
        else:
            lines.append("- command: not mapped yet")
        lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
