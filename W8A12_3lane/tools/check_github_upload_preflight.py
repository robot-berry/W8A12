#!/usr/bin/env python3
"""Preflight checks before uploading W8A12_3lane to robot-berry/W8A12."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "github_upload_preflight"

TARGET_REPO = "https://github.com/robot-berry/W8A12.git"
TARGET_FULL_NAME = "robot-berry/W8A12"
ALLOWED_PREFIX = "W8A12_3lane/"
FORBIDDEN_UPLOAD_RE = re.compile(
    r"(\.(npy|npz|pth|pt|pid|zip|dcp|bit|xsa|jou|log|wdb)$|"
    r"(^|/)(stdout|stderr)\.txt$|"
    r"_(stdout|stderr)\.txt$)",
    re.IGNORECASE,
)


def run_git(args: list[str]) -> tuple[int, str]:
    proc = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return proc.returncode, proc.stdout.strip()


def add(checks: list[dict], name: str, passed: bool, detail: object) -> None:
    checks.append({"name": name, "pass": bool(passed), "detail": detail})


def read_json(rel: str) -> dict:
    path = BASE / rel
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def normalized_remote_urls(remote_output: str) -> list[str]:
    urls: list[str] = []
    for line in remote_output.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            urls.append(parts[1])
    return sorted(set(urls))


def main() -> int:
    checks: list[dict] = []

    code, branch = run_git(["branch", "--show-current"])
    add(checks, "git.branch_detected", code == 0 and bool(branch), branch or "not detected")

    code, remote_output = run_git(["remote", "-v"])
    urls = normalized_remote_urls(remote_output) if code == 0 else []
    has_target_remote = any(TARGET_FULL_NAME in url or url == TARGET_REPO for url in urls)
    add(checks, "git.target_remote_configured", has_target_remote, {"target": TARGET_REPO, "configured": urls})

    code, status_output = run_git(["status", "--short"])
    status_lines = status_output.splitlines() if code == 0 and status_output else []
    w8a12_lines = [line for line in status_lines if line[3:].startswith("W8A12_3lane")]
    outside_lines = [line for line in status_lines if not line[3:].startswith("W8A12_3lane")]
    add(checks, "git.w8a12_changes_present", bool(w8a12_lines), f"{len(w8a12_lines)} W8A12_3lane status lines")
    add(checks, "git.outside_changes_detected", bool(outside_lines), f"{len(outside_lines)} outside status lines; do not stage them for W8A12 upload")

    code, staged_output = run_git(["diff", "--cached", "--name-only"])
    staged = staged_output.splitlines() if code == 0 and staged_output else []
    staged_outside = [path for path in staged if not path.startswith(ALLOWED_PREFIX)]
    add(checks, "git.no_staged_outside_w8a12", not staged_outside, staged_outside)

    code, upload_candidates_output = run_git(["ls-files", "--others", "--cached", "--exclude-standard", "W8A12_3lane"])
    upload_candidates = upload_candidates_output.splitlines() if code == 0 and upload_candidates_output else []
    forbidden_candidates = [path for path in upload_candidates if FORBIDDEN_UPLOAD_RE.search(path.replace("\\", "/"))]
    add(checks, "git.upload_candidate_count", bool(upload_candidates), len(upload_candidates))
    add(checks, "git.no_forbidden_upload_candidates", not forbidden_candidates, forbidden_candidates[:50])

    audit = read_json("evidence/delivery_audit/contest_delivery_audit.json")
    add(checks, "delivery_audit.exists", bool(audit), "evidence/delivery_audit/contest_delivery_audit.json")
    add(checks, "delivery_audit.not_claiming_final_pass", audit.get("status") == "INCOMPLETE", audit.get("status"))
    if audit.get("items"):
        missing = [item["name"] for item in audit["items"] if not item.get("pass")]
        add(checks, "delivery_audit.missing_only_board_validation", missing == ["a5.board_32x32", "a6.board_64x64", "a7.board_720p_x4", "x2.board"], missing)

    manifest = read_json("evidence/submission_package/submission_manifest.json")
    add(checks, "submission_manifest.exists", bool(manifest), "evidence/submission_package/submission_manifest.json")
    add(checks, "submission_manifest.not_final", manifest.get("status") == "INCOMPLETE", manifest.get("status"))
    add(checks, "submission_manifest.has_files", manifest.get("file_count", 0) > 0, manifest.get("file_count"))

    pdf = BASE / "output" / "pdf" / "W8A12_3lane_contest_submission_report.pdf"
    add(checks, "contest_report_pdf.exists", pdf.is_file(), pdf.as_posix())

    archive_summary = BASE / "evidence" / "submission_package" / "archive" / "summary.md"
    add(checks, "draft_archive_summary.exists", archive_summary.is_file(), archive_summary.as_posix())

    hard_fail_names = {
        "git.target_remote_configured",
        "git.no_staged_outside_w8a12",
        "git.upload_candidate_count",
        "git.no_forbidden_upload_candidates",
        "delivery_audit.exists",
        "submission_manifest.exists",
        "contest_report_pdf.exists",
        "draft_archive_summary.exists",
    }
    hard_ok = all(check["pass"] for check in checks if check["name"] in hard_fail_names)
    status = "PASS" if hard_ok else "FAIL"
    data = {
        "status": status,
        "target_repo": TARGET_REPO,
        "current_branch": branch,
        "checks": checks,
        "note": (
            "This preflight permits an INCOMPLETE draft package, but blocks upload if the target remote "
            "is not configured or if staged files include paths outside W8A12_3lane/."
        ),
    }

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"GITHUB_UPLOAD_PREFLIGHT_STATUS={status}")
    print(f"GITHUB_UPLOAD_PREFLIGHT_MD={OUT / 'summary.md'}")
    print(f"GITHUB_UPLOAD_PREFLIGHT_JSON={OUT / 'summary.json'}")
    return 0 if status == "PASS" else 1


def render_md(data: dict) -> str:
    lines = [
        "# GitHub Upload Preflight",
        "",
        f"Status: {data['status']}",
        "",
        f"Target repository: `{data['target_repo']}`",
        "",
        f"Current branch: `{data.get('current_branch') or 'unknown'}`",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in data["checks"]:
        detail = json.dumps(check["detail"], ensure_ascii=False) if isinstance(check["detail"], (dict, list)) else str(check["detail"])
        detail = detail.replace("|", "/")
        lines.append(f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | `{detail}` |")
    lines.extend(["", data["note"], ""])
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
