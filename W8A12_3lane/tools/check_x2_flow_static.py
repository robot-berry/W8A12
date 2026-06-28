#!/usr/bin/env python3
"""Static checks for the x2 W8A12 export and fixed-reference flow."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "x2" / "flow_static"


FILES = {
    "export_ps1": BASE / "scripts" / "export_x2_w8a12_to_rtl.ps1",
    "export_cmd": BASE / "scripts" / "export_x2_w8a12_to_rtl.cmd",
    "export_check": BASE / "tools" / "check_x2_w8a12_export.py",
    "fixed_check": BASE / "tools" / "check_x2_fixed_reference.py",
    "readiness_check": BASE / "tools" / "check_x2_reference_readiness.py",
    "asset_search": BASE / "tools" / "find_x2_assets.py",
    "reference": BASE / "tools" / "w8a12_3lane_reference.py",
    "export_doc": BASE / "docs" / "x2_w8a12_export_plan.md",
    "fixed_doc": BASE / "docs" / "x2_fixed_reference_contract.md",
    "root_calibrate_tool": ROOT / "tools" / "calibrate_span_activation_scales.py",
    "root_quant_tool": ROOT / "tools" / "export_span_w8a12_quant_plan.py",
    "root_rtl_export_tool": ROOT / "tools" / "export_span_quant_plan_to_rtl.py",
    "root_postprocess_export_tool": ROOT / "tools" / "export_span_w8a12_postprocess_to_rtl.py",
    "root_rtl_check_tool": ROOT / "tools" / "check_span_w8a12_rtl_export.py",
    "checkpoint": ROOT / "runs" / "official_span" / "official_SPAN_REDS_x2_f48" / "models" / "net_g_300000.pth",
    "official_manifest": ROOT / "rtl" / "generated" / "official_span_x2" / "official_span_manifest.json",
}


def main() -> int:
    checks: list[dict] = []

    def add(name: str, passed: bool, detail: object) -> None:
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    texts: dict[str, str] = {}
    for name, file_path in FILES.items():
        exists = file_path.exists()
        add(f"file:{name}", exists, file_path.relative_to(ROOT).as_posix())
        texts[name] = file_path.read_text(encoding="utf-8", errors="ignore") if exists and file_path.suffix.lower() in {".ps1", ".py", ".md", ".cmd", ".json"} else ""

    add("export_ps1_calibrates_a12", "calibrate_span_activation_scales.py" in texts["export_ps1"] and "--activation-bits 12" in texts["export_ps1"], "activation calibration")
    add("export_ps1_exports_quant_w8a12", "export_span_w8a12_quant_plan.py" in texts["export_ps1"] and "--weight-bits 8" in texts["export_ps1"], "W8A12 quant plan")
    add("export_ps1_exports_rtl", "export_span_quant_plan_to_rtl.py" in texts["export_ps1"] and "reds_span_x2_f48_w8a12" in texts["export_ps1"], "RTL manifest")
    add("export_ps1_exports_postprocess", "export_span_w8a12_postprocess_to_rtl.py" in texts["export_ps1"], "postprocess manifest")
    add("export_ps1_runs_root_check", "check_span_w8a12_rtl_export.py" in texts["export_ps1"], "root RTL export check")
    add("export_ps1_runs_x2_check", "check_x2_w8a12_export.py" in texts["export_ps1"], "x2 export evidence check")
    add("export_ps1_uses_x2_assets", "official_SPAN_REDS_x2_f48" in texts["export_ps1"] and "official_span_x2" in texts["export_ps1"], "x2 checkpoint/manifest")
    add("root_export_tools_present", all(texts[name] for name in [
        "root_calibrate_tool",
        "root_quant_tool",
        "root_rtl_export_tool",
        "root_postprocess_export_tool",
        "root_rtl_check_tool",
    ]), "root-level export/check tools")
    add("export_cmd_redirects_stdout", "export_x2_w8a12_to_rtl.stdout.txt" in texts["export_cmd"], "stdout evidence")
    add("export_cmd_runs_ps1", "export_x2_w8a12_to_rtl.ps1" in texts["export_cmd"], "ps1 fallback")
    add("export_cmd_runs_check", "check_x2_w8a12_export.py" in texts["export_cmd"], "post-export check")

    add("export_check_requires_scale2", "scale_is_x2" in texts["export_check"], "scale x2")
    add("export_check_requires_f48", "channels_f48" in texts["export_check"], "48 channels")
    add("export_check_requires_w8a12", "activation_bits_12" in texts["export_check"] and "quant_weight_bits_8" in texts["export_check"], "W8A12")
    add("export_check_requires_postprocess", "postprocess_manifest_exists" in texts["export_check"], "postprocess")

    add("fixed_check_requires_a3", "stage_a3_tail_rgb" in texts["fixed_check"], "A3 tail RGB")
    add("fixed_check_requires_x2_dims", "out_height_matches_x2" in texts["fixed_check"] and "out_width_matches_x2" in texts["fixed_check"], "x2 output size")
    add("fixed_check_requires_rgb_hash", "rgb_hash_present" in texts["fixed_check"], "RGB hash")

    add("reference_supports_a3_tail_rgb", "a3-tail-rgb" in texts["reference"] and "scale" in texts["reference"], "fixed reference subcommand")
    add("doc_mentions_28_30_targets", "28" in texts["export_doc"] and "30" in texts["fixed_doc"], "quality targets documented")
    add("doc_mentions_export_cmd", "export_x2_w8a12_to_rtl" in texts["export_doc"], "export command documented")

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# x2 W8A12 Flow Static Check",
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
