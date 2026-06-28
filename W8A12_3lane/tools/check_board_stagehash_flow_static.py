#!/usr/bin/env python3
"""Static checks for the W8A12 stage-hash board bring-up flow."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "board_reports" / "stagehash_flow_static"

ROOT_SCRIPTS = [
    "scripts/run_w8a12_board_recovery_preflight.ps1",
    "scripts/run_w8a12_stagehash_true2x2_acceptance.ps1",
    "scripts/probe_vivado_hw_targets.ps1",
    "scripts/probe_vivado_hw_targets.tcl",
    "scripts/check_usb_jtag_devices.ps1",
    "scripts/cleanup_vivado_processes.ps1",
    "scripts/run_xsct_psu_init_only.ps1",
    "scripts/run_xsct_psu_init_only.tcl",
    "scripts/run_jtag_w8a12_tile_writer_smoke.ps1",
    "scripts/jtag_rgb_transfer.tcl",
    "scripts/compare_jtag_w8a12_span_output.ps1",
    "scripts/run_read_jtag_w8a12_tile_writer_regs.ps1",
    "scripts/read_jtag_w8a12_tile_writer_regs.tcl",
    "scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.ps1",
    "scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.tcl",
    "scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl",
]

EXPECTED_HASHES = [
    "0x16ede1c2",
    "0xc7a092b8",
    "0xb712a61b",
    "0x61d3ea1d",
]


def main() -> int:
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    delivery_wrapper = BASE / "scripts" / "run_w8a12_stagehash_true2x2_acceptance.ps1"
    delivery_preflight = BASE / "scripts" / "run_w8a12_board_recovery_preflight.ps1"
    root_wrapper = ROOT / "scripts" / "run_w8a12_stagehash_true2x2_acceptance.ps1"
    root_preflight = ROOT / "scripts" / "run_w8a12_board_recovery_preflight.ps1"
    jtag_precondition_tool = BASE / "tools" / "summarize_jtag_precondition.py"
    jtag_recovery_tool = BASE / "tools" / "generate_jtag_recovery_checklist.py"
    jtag_recovery_doc = BASE / "docs" / "jtag_recovery_checklist.md"
    jtag_precondition = BASE / "evidence" / "board_probe" / "jtag_precondition_current" / "summary.md"
    recovery_preflight = BASE / "evidence" / "board_probe" / "recovery_preflight_current" / "board_recovery_preflight_summary.md"
    jtag_recovery = BASE / "evidence" / "board_probe" / "jtag_recovery_checklist" / "summary.md"
    report = BASE / "evidence" / "board_reports" / "jtag_true2x2_stagehash_20260628.md"
    scope_doc = BASE / "docs" / "submission_scope_policy.md"
    upload_doc = BASE / "docs" / "github_upload_plan.md"
    delivery_index = BASE / "DELIVERY_INDEX.md"
    workflow = BASE / "WORKFLOW.md"

    root_wrapper_text = read(root_wrapper)
    delivery_wrapper_text = read(delivery_wrapper)
    root_preflight_text = read(root_preflight)
    delivery_preflight_text = read(delivery_preflight)
    report_text = read(report)
    scope_text = read(scope_doc)
    upload_text = read(upload_doc)
    index_text = read(delivery_index)
    workflow_text = read(workflow)
    jtag_precondition_text = read(jtag_precondition)
    recovery_preflight_text = read(recovery_preflight)
    jtag_recovery_text = read(jtag_recovery)
    jtag_recovery_doc_text = read(jtag_recovery_doc)

    add("file:delivery_wrapper", delivery_wrapper.exists(), delivery_wrapper.relative_to(ROOT).as_posix())
    add("file:delivery_preflight", delivery_preflight.exists(), delivery_preflight.relative_to(ROOT).as_posix())
    add("file:root_wrapper", root_wrapper.exists(), root_wrapper.relative_to(ROOT).as_posix())
    add("file:root_preflight", root_preflight.exists(), root_preflight.relative_to(ROOT).as_posix())
    add("file:jtag_precondition_tool", jtag_precondition_tool.exists(), jtag_precondition_tool.relative_to(ROOT).as_posix())
    add("file:jtag_recovery_tool", jtag_recovery_tool.exists(), jtag_recovery_tool.relative_to(ROOT).as_posix())
    add("file:jtag_recovery_doc", jtag_recovery_doc.exists(), jtag_recovery_doc.relative_to(ROOT).as_posix())
    add("file:jtag_precondition_current", jtag_precondition.exists(), jtag_precondition.relative_to(ROOT).as_posix())
    add("file:recovery_preflight_current", recovery_preflight.exists(), recovery_preflight.relative_to(ROOT).as_posix())
    add("file:jtag_recovery_checklist", jtag_recovery.exists(), jtag_recovery.relative_to(ROOT).as_posix())
    for rel in ROOT_SCRIPTS:
        add(f"file:{rel}", (ROOT / rel).exists(), rel)

    add(
        "delivery_wrapper_delegates_to_root",
        "scripts\\run_w8a12_stagehash_true2x2_acceptance.ps1" in delivery_wrapper_text
        and "Push-Location $Repo" in delivery_wrapper_text,
        "W8A12_3lane wrapper delegates from repo root",
    )
    add(
        "delivery_preflight_delegates_to_root",
        "scripts\\run_w8a12_board_recovery_preflight.ps1" in delivery_preflight_text
        and "Push-Location $Repo" in delivery_preflight_text,
        "W8A12_3lane preflight delegates from repo root",
    )
    add(
        "root_preflight_runs_usb_precondition_and_optional_acceptance",
        all(
            token in root_preflight_text
            for token in [
                "scripts\\check_usb_jtag_devices.ps1",
                "summarize_jtag_precondition.py",
                "scripts\\probe_vivado_hw_targets.ps1",
                "scripts\\run_w8a12_stagehash_true2x2_acceptance.ps1",
                "RunStageHashAcceptance",
            ]
        ),
        "board recovery preflight step chain",
    )
    add(
        "root_wrapper_runs_probe_psu_smoke_regread",
        all(
            token in root_wrapper_text
            for token in [
                "scripts\\probe_vivado_hw_targets.ps1",
                "scripts\\run_xsct_psu_init_only.ps1",
                "scripts\\run_jtag_w8a12_tile_writer_smoke.ps1",
                "scripts\\run_read_jtag_w8a12_tile_writer_regs.ps1",
            ]
        ),
        "root wrapper step chain",
    )
    add(
        "root_wrapper_records_expected_hashes",
        all(token in root_wrapper_text for token in EXPECTED_HASHES),
        "stage-hash expected values",
    )
    add(
        "report_records_bitstream_and_target0",
        all(
            token in report_text
            for token in [
                "stage-hash bitstream",
                "WNS",
                "W8A12_STAGEHASH_ACCEPTANCE_STATUS=FAIL",
                "VIVADO_HW_TARGET_COUNT=0",
            ]
        ),
        "stage-hash report has build and target-fail evidence",
    )
    add(
        "docs_list_board_root_dependencies",
        all(token in scope_text for token in ROOT_SCRIPTS),
        "submission scope lists board root scripts",
    )
    add(
        "upload_plan_mentions_board_root_dependencies",
        "板端 JTAG/stage-hash 脚本" in upload_text
        and "run_w8a12_stagehash_true2x2_acceptance.ps1" in upload_text,
        "upload plan board script scope",
    )
    add(
        "index_mentions_stagehash_wrapper",
        "JTAG-W8A12 stage-hash 一键验收" in index_text
        and "W8A12_3lane/scripts/run_w8a12_stagehash_true2x2_acceptance.ps1" in index_text,
        "delivery index wrapper row",
    )
    add(
        "index_mentions_recovery_preflight",
        "W8A12 board recovery preflight" in index_text
        and "W8A12_3lane/scripts/run_w8a12_board_recovery_preflight.ps1" in index_text,
        "delivery index recovery preflight row",
    )
    add(
        "workflow_mentions_stagehash_wrapper",
        "run_w8a12_stagehash_true2x2_acceptance.ps1" in workflow_text
        and "VIVADO_HW_TARGET_COUNT=0" in workflow_text,
        "workflow current stage-hash wrapper state",
    )
    add(
        "jtag_precondition_has_current_counts",
        all(
            token in jtag_precondition_text
            for token in [
                "Status:",
                "USB known JTAG candidate count",
                "Vivado target count",
                "stage-hash true2x2 acceptance wrapper",
            ]
        ),
        "current board/JTAG precondition evidence",
    )
    add(
        "recovery_preflight_has_current_blocked_evidence",
        all(
            token in recovery_preflight_text
            for token in [
                "Status: BLOCKED",
                "USB known JTAG candidate count",
                "Vivado target count",
                "Restore board power/cable/JTAG mode/driver",
            ]
        ),
        "current board recovery preflight evidence",
    )
    add(
        "jtag_recovery_doc_has_physical_steps",
        all(
            token in jtag_recovery_doc_text
            for token in [
                "USB known JTAG candidate count = 0",
                "VID_0403&PID_6010",
                "run_w8a12_board_recovery_preflight.ps1",
                "stage-hash true2x2 acceptance",
            ]
        ),
        "physical JTAG recovery runbook",
    )
    add(
        "jtag_recovery_evidence_has_current_blocked_state",
        all(
            token in jtag_recovery_text
            for token in [
                "Status: BLOCKED",
                "USB known JTAG candidate count",
                "Historical Known JTAG Candidates",
                "VID_0403",
                "Required Pass Criteria",
            ]
        ),
        "current physical/JTAG recovery evidence",
    )

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"BOARD_STAGEHASH_FLOW_STATIC_STATUS={data['status']}")
    print(f"BOARD_STAGEHASH_FLOW_STATIC_MD={OUT / 'summary.md'}")
    print(f"BOARD_STAGEHASH_FLOW_STATIC_JSON={OUT / 'summary.json'}")
    return 0 if ok else 1


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def render_md(data: dict) -> str:
    lines = [
        "# Board Stage-Hash Flow Static Check",
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
