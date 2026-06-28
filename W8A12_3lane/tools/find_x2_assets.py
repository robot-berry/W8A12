#!/usr/bin/env python3
"""Find existing x2 assets relevant to W8A12 fixed-reference bring-up."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "evidence" / "x2" / "asset_search"


def find(root: Path, pred, limit: int = 200) -> list[str]:
    if not root.exists():
        return []
    hits: list[str] = []
    for path in root.rglob("*"):
        if len(hits) >= limit:
            break
        if path.is_file() and pred(path):
            hits.append(path.relative_to(ROOT).as_posix())
    return hits


def main() -> int:
    manifests = find(ROOT / "rtl" / "generated", lambda p: "x2" in p.as_posix().lower() and p.name.endswith("manifest.json"))
    postprocess = find(
        ROOT / "rtl" / "generated",
        lambda p: "x2" in p.as_posix().lower() and "postprocess" in p.as_posix().lower() and p.name.endswith("manifest.json"),
    )
    quant = find(
        ROOT / "runs",
        lambda p: "x2" in p.as_posix().lower() and ("quant" in p.as_posix().lower() or "w8a12" in p.as_posix().lower()) and p.suffix == ".json",
    )
    logs = find(ROOT / "runs", lambda p: "x2" in p.as_posix().lower() and p.suffix == ".log", limit=50)

    required = {
        "w8a12_rtl_manifest": "rtl/generated/reds_span_x2_f48_w8a12/span_w8a12_rtl_manifest.json",
        "w8a12_postprocess_manifest": "rtl/generated/reds_span_x2_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json",
        "w8a12_quant_plan": "runs/reds_span_quant_plan/reds_span_x2_f48_w8a12/span_w8a12_quant_plan.json",
    }
    required_status = {name: (ROOT / rel).exists() for name, rel in required.items()}
    ready = all(required_status.values())
    data = {
        "status": "READY" if ready else "NOT_READY",
        "required": required,
        "required_status": required_status,
        "found": {
            "manifests": manifests,
            "postprocess": postprocess,
            "quant_or_w8a12_json": quant,
            "logs": logs,
        },
        "conclusion": "x2 W8A12 export is missing" if not ready else "x2 W8A12 export exists",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "x2_asset_search.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "x2_asset_search.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ready else 1


def render_md(data: dict) -> str:
    lines = [
        "# x2 Asset Search",
        "",
        f"状态：{data['status']}",
        "",
        "## Required W8A12 x2 Assets",
        "",
        "| Item | Status | Path |",
        "| --- | --- | --- |",
    ]
    for name, rel in data["required"].items():
        lines.append(f"| `{name}` | {'OK' if data['required_status'][name] else 'MISSING'} | `{rel}` |")
    lines.extend(["", "## Found x2 Assets", ""])
    for key, values in data["found"].items():
        lines.append(f"### {key}")
        if not values:
            lines.append("")
            lines.append("None")
        else:
            lines.extend(f"- `{value}`" for value in values[:80])
            if len(values) > 80:
                lines.append(f"- ... {len(values) - 80} more")
        lines.append("")
    lines.extend(["## Conclusion", "", data["conclusion"], ""])
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
