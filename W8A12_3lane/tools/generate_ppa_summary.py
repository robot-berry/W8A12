#!/usr/bin/env python3
"""Generate a contest-report PPA summary from existing OOC evidence."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "evidence" / "ppa_summary"

OOC_ITEMS = [
    {
        "name": "A4 MAC core TAP_PAR=8",
        "kind": "mac_core",
        "path": ROOT / "W8A12_3lane" / "evidence" / "resource" / "A4_lane_mac_core_ooc" / "xc7z045_resource_gate.json",
        "scope": "single reusable lane MAC primitive; timing report not available in this legacy gate",
    },
    {
        "name": "A4 single-lane scheduler",
        "kind": "ooc_summary",
        "path": ROOT / "W8A12_3lane" / "evidence" / "resource" / "A4_single_lane_mac_scheduler_ooc" / "ooc_summary.json",
        "scope": "one 16-channel output lane scheduler",
    },
    {
        "name": "A4 3-lane scheduler",
        "kind": "ooc_summary",
        "path": ROOT / "W8A12_3lane" / "evidence" / "resource" / "A4_3lane_mac_scheduler_ooc" / "ooc_summary.json",
        "scope": "three 16-channel output lanes, 48 output channels total",
    },
    {
        "name": "accelerator top shell",
        "kind": "ooc_summary",
        "path": ROOT / "W8A12_3lane" / "evidence" / "top" / "accel_top_ooc" / "ooc_summary.json",
        "scope": "control/status shell only, not full datapath resource",
    },
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def pct(value: float | int | None, limit: float | int | None) -> str:
    if value is None or limit in (None, 0):
        return "NA"
    return f"{100.0 * float(value) / float(limit):.2f}%"


def normalize_resource_gate(data: dict[str, Any], kind: str) -> tuple[dict[str, float], dict[str, float], bool]:
    if kind == "mac_core":
        metrics = data.get("metrics", {})
        limits = data.get("limits", {})
        normalized_metrics = {
            "lut": float(metrics.get("lut", 0)),
            "ff": float(metrics.get("register", 0)),
            "bram": float(metrics.get("bram_tile", 0)),
            "dsp": float(metrics.get("dsp", 0)),
            "uram": float(metrics.get("uram", 0)),
        }
        normalized_limits = {
            "lut": float(limits.get("lut", 0)),
            "ff": float(limits.get("register", 0)),
            "bram": float(limits.get("bram_tile", 0)),
            "dsp": float(limits.get("dsp", 0)),
            "uram": float(limits.get("uram", 0)),
        }
        return normalized_metrics, normalized_limits, bool(data.get("pass"))

    gate = data.get("resource_gate", {})
    metrics = gate.get("metrics", {})
    limits = gate.get("limits", {})
    normalized_metrics = {key: float(metrics.get(key, 0)) for key in ["lut", "ff", "bram", "dsp", "uram"]}
    normalized_limits = {key: float(limits.get(key, 0)) for key in ["lut", "ff", "bram", "dsp", "uram"]}
    return normalized_metrics, normalized_limits, bool(gate.get("pass"))


def row_from_item(item: dict[str, Any]) -> dict[str, Any]:
    path = item["path"]
    data = load_json(path)
    metrics, limits, resource_pass = normalize_resource_gate(data, item["kind"])
    timing = data.get("timing", {}) if item["kind"] == "ooc_summary" else {}
    timing_pass = timing.get("pass")
    if resource_pass and timing_pass is True:
        status = "PASS"
    elif resource_pass and timing_pass is None:
        status = "RESOURCE_PASS"
    elif resource_pass:
        status = "PARTIAL_PASS"
    else:
        status = "FAIL"
    return {
        "name": item["name"],
        "scope": item["scope"],
        "source": str(path.relative_to(ROOT)).replace("\\", "/"),
        "status": status,
        "resource_pass": resource_pass,
        "timing_pass": timing_pass,
        "metrics": metrics,
        "limits": limits,
        "usage_pct": {key: pct(metrics.get(key), limits.get(key)) for key in ["lut", "ff", "bram", "dsp", "uram"]},
        "wns_ns": timing.get("wns_ns"),
        "whs_ns": timing.get("whs_ns"),
    }


def render_md(rows: list[dict[str, Any]]) -> str:
    all_ok = all(row["status"] in {"PASS", "PARTIAL_PASS", "RESOURCE_PASS"} for row in rows)
    lines = [
        "# W8A12_3lane PPA Summary",
        "",
        f"Status: {'PASS' if all_ok else 'FAIL'}",
        "",
        "This report is generated from existing Vivado OOC/resource-gate evidence.",
        "It is intended for the contest technical report. It does not claim board-measured FPS or power.",
        "",
        "## Resource And Timing Summary",
        "",
        "| Module | Status | LUT | LUT % | FF | FF % | BRAM | BRAM % | DSP | DSP % | WNS(ns) | WHS(ns) |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        m = row["metrics"]
        p = row["usage_pct"]
        wns = "NA" if row["wns_ns"] is None else f"{float(row['wns_ns']):.3f}"
        whs = "NA" if row["whs_ns"] is None else f"{float(row['whs_ns']):.3f}"
        lines.append(
            f"| {row['name']} | {row['status']} | "
            f"{m['lut']:.0f} | {p['lut']} | "
            f"{m['ff']:.0f} | {p['ff']} | "
            f"{m['bram']:.0f} | {p['bram']} | "
            f"{m['dsp']:.0f} | {p['dsp']} | "
            f"{wns} | {whs} |"
        )

    lines.extend(
        [
            "",
            "## Scope Notes",
            "",
            "| Module | Evidence | Scope |",
            "| --- | --- | --- |",
        ]
    )
    for row in rows:
        lines.append(f"| {row['name']} | `{row['source']}` | {row['scope']} |")

    lines.extend(
        [
            "",
            "## Reporting Rules",
            "",
            "- Resource limits use the XC7Z045/ZC706-equivalent gate: LUT 218600, FF 437200, BRAM tile 545, DSP 900.",
            "- OOC results are valid module-level synthesis evidence, not full board implementation results.",
            "- The accelerator top shell row is only the control/status shell; it must not be reported as the full W8A12 datapath resource.",
            "- Board FPS, latency, and measured power remain pending until real board validation produces runtime logs.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    rows = [row_from_item(item) for item in OOC_ITEMS]
    OUT.mkdir(parents=True, exist_ok=True)
    data = {
        "status": "PASS" if all(row["status"] in {"PASS", "PARTIAL_PASS", "RESOURCE_PASS"} for row in rows) else "FAIL",
        "limits": {"lut": 218600, "ff": 437200, "bram": 545, "dsp": 900, "uram": 0},
        "rows": rows,
    }
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(rows), encoding="utf-8")
    print(f"PPA_SUMMARY_STATUS={data['status']}")
    print(f"PPA_SUMMARY_MD={OUT / 'summary.md'}")
    print(f"PPA_SUMMARY_JSON={OUT / 'summary.json'}")
    return 0 if data["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
