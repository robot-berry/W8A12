#!/usr/bin/env python3
"""Static checks for the hard-gate queue runner."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "delivery_audit" / "hard_gate_runner_static"


def add(checks: list[dict], name: str, passed: bool, detail: object) -> None:
    checks.append({"name": name, "pass": bool(passed), "detail": detail})


def powershell_parse(path: Path) -> tuple[bool, str]:
    if not path.exists():
        return False, "file missing"
    command = (
        "$tokens=$null;$errors=$null;"
        f"[System.Management.Automation.Language.Parser]::ParseFile('{path}',[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count -gt 0){$errors | ForEach-Object { $_.Message }; exit 1};"
        "Write-Output 'parse ok'"
    )
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", command],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except Exception as exc:  # pragma: no cover - diagnostic fallback
        return False, str(exc)
    detail = (result.stdout + result.stderr).strip()
    return result.returncode == 0, detail or f"exit={result.returncode}"


def main() -> int:
    runner = BASE / "scripts" / "run_hard_gate_queue.ps1"
    delivery_runner = BASE / "scripts" / "run_delivery_gates.ps1"
    queue_tool = BASE / "tools" / "generate_hard_gate_execution_queue.py"
    doc = BASE / "docs" / "delivery_gate_runner.md"
    text = runner.read_text(encoding="utf-8", errors="ignore") if runner.exists() else ""
    delivery_text = delivery_runner.read_text(encoding="utf-8", errors="ignore") if delivery_runner.exists() else ""
    queue_text = queue_tool.read_text(encoding="utf-8", errors="ignore") if queue_tool.exists() else ""
    doc_text = doc.read_text(encoding="utf-8", errors="ignore") if doc.exists() else ""
    checks: list[dict] = []

    add(checks, "file:runner", runner.exists(), runner.relative_to(ROOT).as_posix())
    add(checks, "file:delivery_runner", delivery_runner.exists(), delivery_runner.relative_to(ROOT).as_posix())
    add(checks, "file:queue_tool", queue_tool.exists(), queue_tool.relative_to(ROOT).as_posix())
    add(checks, "file:doc", doc.exists(), doc.relative_to(ROOT).as_posix())
    delivery_parse_ok, delivery_parse_detail = powershell_parse(delivery_runner)
    add(checks, "delivery_runner_powershell_parse", delivery_parse_ok, delivery_parse_detail)
    add(checks, "delivery_runner_param_first", delivery_text.lstrip().startswith("param("), "param block is first statement")
    add(checks, "delivery_runner_skip_flags", all(token in delivery_text for token in [
        "$SkipVivado",
        "$SkipX2",
        "$ContinueOnError",
    ]), "SkipVivado/SkipX2/ContinueOnError")
    add(checks, "delivery_runner_allowed_exit_codes", "AllowedExitCodes" in delivery_text and "-AllowedExitCodes @(0, 1)" in delivery_text, "missing evidence plan can be incomplete")
    add(checks, "delivery_runner_safe_file_interpolation", "${File}:" in delivery_text and "$File:" not in delivery_text, "no invalid $File: interpolation")
    add(checks, "delivery_runner_summary_interpolation", "``$($Result.name)``" in delivery_text and "$Msg" in delivery_text, "summary rows expand step names")
    add(checks, "delivery_runner_stagehash_static", "board_stagehash_flow_static" in delivery_text and "check_board_stagehash_flow_static.py" in delivery_text, "stage-hash static gate")
    add(checks, "delivery_runner_jtag_recovery_checklist", "jtag_recovery_checklist" in delivery_text and "generate_jtag_recovery_checklist.py" in delivery_text, "JTAG recovery checklist gate")
    add(checks, "delivery_runner_contest_report_pdf", "contest_report_pdf" in delivery_text and "export_contest_report_pdf.ps1" in delivery_text, "contest report PDF gate")
    add(checks, "delivery_runner_evidence_matrix", "delivery_evidence_matrix" in delivery_text and "generate_delivery_evidence_matrix.py" in delivery_text, "delivery evidence matrix gate")
    add(checks, "delivery_runner_final_gates", all(token in delivery_text for token in [
        "submission_manifest_final",
        "delivery_audit",
        "collect_submission_package.py",
        "audit_contest_delivery.py",
    ]), "final manifest/audit gates")
    gate_order = [match.split('"')[1] for match in delivery_text.split("-Name ")[1:]]

    def before(left: str, right: str) -> bool:
        return left in gate_order and right in gate_order and gate_order.index(left) < gate_order.index(right)

    add(checks, "delivery_runner_jtag_recovery_before_stagehash_static", before("jtag_recovery_checklist", "board_stagehash_flow_static"), "recovery evidence generated before stage-hash static check")
    add(checks, "delivery_runner_matrix_before_final_archive", before("delivery_audit", "delivery_evidence_matrix") and before("delivery_evidence_matrix", "submission_archive_final"), "evidence matrix is generated after audit and before final archive")
    add(checks, "supports_start_at", "$StartAt" in text and "StartAt did not match" in text, "resume from step")
    add(checks, "supports_only_category", "$OnlyCategory" in text and "category -eq" in text, "category filter")
    add(checks, "supports_continue_on_error", "$ContinueOnError" in text, "continue on error")
    add(checks, "supports_dry_run", "$DryRun" in text and "dry run" in text, "dry-run mode")
    add(checks, "writes_hard_gate_runs", "evidence\\hard_gate_runs" in text, "run output directory")
    add(checks, "captures_stdout_stderr", "stdout.txt" in text and "stderr.txt" in text, "stdout/stderr logs")
    add(checks, "records_commands", "commands.txt" in text, "per-step commands")
    add(checks, "checks_required_evidence", "required_path" in text and "required_text" in text, "evidence validation")
    add(checks, "queue_marks_external_process", "requires_external_process" in queue_text, "hard gates flagged external")
    add(checks, "queue_has_all_hard_names", all(token in queue_text for token in [
        "top.accel_shell_sim",
        "a4.single_lane_sim",
        "a4.3lane_ooc_summary",
        "board.vivado_hw_probe",
        "quality.x4_interpolation_baseline",
        "quality.x2_interpolation_baseline",
        "quality.comparison_report",
        "x2.w8a12_export",
        "a7.board_720p_x4",
        "x2.board",
    ]), "representative hard gates")
    add(checks, "queue_orders_probe_before_board", "\"board.vivado_hw_probe\"" in queue_text and queue_text.find("\"board.vivado_hw_probe\"") < queue_text.find("\"a5.board_32x32\""), "probe before A5")
    add(checks, "doc_lists_hard_queue_runner", "run_hard_gate_queue.ps1" in doc_text and "hard_gate_execution_queue.json" in doc_text, "hard queue runner documented")
    add(checks, "doc_lists_categories", all(token in doc_text for token in [
        "accelerator_top_vivado",
        "a4_scheduler_vivado",
        "x2_export_reference_board",
        "quality_baseline",
        "board_probe",
        "board_x4",
    ]), "category examples documented")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Hard Gate Runner Static Check",
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
