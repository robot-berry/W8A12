#!/usr/bin/env python3
"""Validate x2 W8A12 export outputs and create evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "evidence" / "x2" / "w8a12_export"


def resolve(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def add(checks: list[dict], name: str, passed: bool, detail: object) -> None:
    checks.append({"name": name, "pass": bool(passed), "detail": detail})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--rtl-manifest",
        type=Path,
        default=Path("rtl/generated/reds_span_x2_f48_w8a12/span_w8a12_rtl_manifest.json"),
    )
    parser.add_argument(
        "--postprocess-manifest",
        type=Path,
        default=Path("rtl/generated/reds_span_x2_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json"),
    )
    parser.add_argument(
        "--quant-plan",
        type=Path,
        default=Path("runs/reds_span_quant_plan/reds_span_x2_f48_w8a12/span_w8a12_quant_plan.json"),
    )
    args = parser.parse_args()

    rtl_manifest = resolve(args.rtl_manifest)
    post_manifest = resolve(args.postprocess_manifest)
    quant_plan = resolve(args.quant_plan)
    checks: list[dict] = []

    add(checks, "rtl_manifest_exists", rtl_manifest.exists(), str(rtl_manifest))
    add(checks, "postprocess_manifest_exists", post_manifest.exists(), str(post_manifest))
    add(checks, "quant_plan_exists", quant_plan.exists(), str(quant_plan))

    rtl: dict = {}
    post: dict = {}
    quant: dict = {}
    if rtl_manifest.exists():
        rtl = load_json(rtl_manifest)
        add(checks, "scale_is_x2", int(rtl.get("scale", -1)) == 2, rtl.get("scale"))
        add(checks, "channels_f48", int(rtl.get("channels", -1)) == 48, rtl.get("channels"))
        add(checks, "activation_bits_12", int(rtl.get("activation_bits", -1)) == 12, rtl.get("activation_bits"))
        add(checks, "quant_plan_link_exists", bool(rtl.get("quant_plan")), rtl.get("quant_plan"))
    if post_manifest.exists():
        post = load_json(post_manifest)
        add(checks, "postprocess_has_entries", len(post) > 0, list(post)[:8])
    if quant_plan.exists():
        quant = load_json(quant_plan)
        add(checks, "quant_activation_bits_12", int(quant.get("activation_bits", -1)) == 12, quant.get("activation_bits"))
        add(checks, "quant_weight_bits_8", int(quant.get("weight_bits", -1)) == 8, quant.get("weight_bits"))
        add(checks, "quant_has_activation_scale_table", "activation_scale_table" in quant, "activation_scale_table" in quant)

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {
        "status": "PASS" if ok else "FAIL",
        "rtl_manifest": str(rtl_manifest),
        "postprocess_manifest": str(post_manifest),
        "quant_plan": str(quant_plan),
        "checks": checks,
    }
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# x2 W8A12 Export Check",
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
