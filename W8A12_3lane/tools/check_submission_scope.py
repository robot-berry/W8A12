#!/usr/bin/env python3
"""Check source/tool scope required for contest repository upload."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "submission_scope"

REQUIRED_ROOT_TOOLS = [
    "tools/calibrate_span_activation_scales.py",
    "tools/export_span_w8a12_quant_plan.py",
    "tools/export_span_quant_plan_to_rtl.py",
    "tools/export_span_w8a12_postprocess_to_rtl.py",
    "tools/check_span_w8a12_rtl_export.py",
    "tools/run_span_ptq_reference.py",
]

REQUIRED_MODEL_SOURCES = [
    "external/SPAN/basicsr/archs/span_arch.py",
]

REQUIRED_MAINLINE_DOCS = [
    "W8A12_3lane/docs/submission_scope_policy.md",
    "W8A12_3lane/docs/github_upload_plan.md",
    "W8A12_3lane/docs/x2_w8a12_export_plan.md",
]


def add(checks: list[dict], name: str, passed: bool, detail: object) -> None:
    checks.append({"name": name, "pass": bool(passed), "detail": detail})


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def main() -> int:
    checks: list[dict] = []

    for rel in REQUIRED_ROOT_TOOLS:
        add(checks, f"root_tool:{rel}", (ROOT / rel).is_file(), rel)
    for rel in REQUIRED_MODEL_SOURCES:
        add(checks, f"model_source:{rel}", (ROOT / rel).is_file(), rel)
    for rel in REQUIRED_MAINLINE_DOCS:
        add(checks, f"mainline_doc:{rel}", (ROOT / rel).is_file(), rel)

    ptq = text(ROOT / "tools/run_span_ptq_reference.py")
    add(checks, "ptq_imports_span", "basicsr.archs.span_arch" in ptq and "SPAN" in ptq, "run_span_ptq_reference.py imports SPAN")

    calibrate = text(ROOT / "tools/calibrate_span_activation_scales.py")
    quant = text(ROOT / "tools/export_span_w8a12_quant_plan.py")
    add(checks, "calibrate_uses_ptq_reference", "run_span_ptq_reference" in calibrate, "calibration uses PTQ reference")
    add(checks, "quant_export_uses_ptq_reference", "run_span_ptq_reference" in quant, "quant export uses PTQ reference")

    upload_plan = text(BASE / "docs/github_upload_plan.md")
    scope_doc = text(BASE / "docs/submission_scope_policy.md")
    add(checks, "upload_plan_mentions_scope", "submission_scope_policy.md" in upload_plan, "GitHub upload plan points to scope policy")
    add(checks, "scope_doc_mentions_basicsr_span", "basicsr.archs.span_arch.SPAN" in scope_doc, "scope doc names SPAN dependency")
    add(checks, "scope_doc_lists_root_tools", all(rel in scope_doc for rel in REQUIRED_ROOT_TOOLS), "scope doc lists required root tools")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Submission Scope Check",
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
