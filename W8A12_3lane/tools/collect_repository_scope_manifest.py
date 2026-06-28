#!/usr/bin/env python3
"""Collect a repository-scope manifest for files outside W8A12_3lane."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "submission_scope"

REQUIRED_FILES = [
    "tools/calibrate_span_activation_scales.py",
    "tools/export_span_w8a12_quant_plan.py",
    "tools/export_span_quant_plan_to_rtl.py",
    "tools/export_span_w8a12_postprocess_to_rtl.py",
    "tools/check_span_w8a12_rtl_export.py",
    "tools/run_span_ptq_reference.py",
    "external/SPAN/basicsr/archs/span_arch.py",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    entries: list[dict] = []
    missing: list[str] = []
    for rel in REQUIRED_FILES:
        path = ROOT / rel
        if not path.is_file():
            missing.append(rel)
            continue
        entries.append(
            {
                "path": rel,
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )

    status = "PASS" if not missing else "FAIL"
    data = {
        "status": status,
        "root": str(ROOT),
        "entries": entries,
        "missing": missing,
        "note": "Repository-level scope manifest for model-to-hardware export dependencies outside W8A12_3lane.",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "repository_scope_manifest.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "repository_scope_manifest.md").write_text(render_md(data), encoding="utf-8")
    return 0 if status == "PASS" else 1


def render_md(data: dict) -> str:
    lines = [
        "# Repository Scope Manifest",
        "",
        f"Status: {data['status']}",
        "",
        "该清单覆盖 `W8A12_3lane/` 之外、但赛题交付仍需要的模型到硬件导出依赖。",
        "",
    ]
    if data["missing"]:
        lines.extend(["## Missing", ""])
        for rel in data["missing"]:
            lines.append(f"- `{rel}`")
        lines.append("")
    lines.extend(
        [
            "## Files",
            "",
            "| Path | Bytes | SHA256 |",
            "| --- | ---: | --- |",
        ]
    )
    for entry in data["entries"]:
        lines.append(f"| `{entry['path']}` | {entry['bytes']} | `{entry['sha256']}` |")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
