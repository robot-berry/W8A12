#!/usr/bin/env python3
"""Check whether x2 W8A12 fixed-reference inputs are ready."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "evidence" / "x2" / "reference_readiness"

REQUIRED = [
    ("checkpoint_300000", "runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth"),
    ("checkpoint_latest", "runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_latest.pth"),
    ("train_log", "runs/official_span/official_SPAN_REDS_x2_f48/train_official_SPAN_REDS_x2_f48_20260524_161741.log"),
    ("fp32_manifest", "rtl/generated/official_span_x2/official_span_manifest.json"),
]

MISSING_W8A12 = [
    ("w8a12_rtl_manifest", "rtl/generated/reds_span_x2_f48_w8a12/span_w8a12_rtl_manifest.json"),
    ("w8a12_postprocess_manifest", "rtl/generated/reds_span_x2_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json"),
    ("w8a12_quant_plan", "runs/reds_span_quant_plan/reds_span_x2_f48_w8a12/span_w8a12_quant_plan.json"),
]


def main() -> int:
    rows = []
    for name, rel in REQUIRED + MISSING_W8A12:
        rows.append({"name": name, "path": rel, "exists": (ROOT / rel).exists()})

    ready = all(row["exists"] for row in rows)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {
        "status": "READY" if ready else "NOT_READY",
        "scale": 2,
        "target_psnr_db": 30,
        "known_fp32_psnr_db": 34.4297,
        "items": rows,
        "note": "READY only means inputs exist; it is not fixed-reference PASS.",
    }
    (OUT / "readiness.json").write_text(json.dumps(data, indent=2), encoding="utf-8")

    lines = [
        "# x2 W8A12 Fixed Reference Readiness",
        "",
        f"状态：{'READY' if ready else 'NOT_READY'}",
        "",
        "| 项目 | 状态 | 路径 |",
        "| --- | --- | --- |",
    ]
    for row in rows:
        lines.append(f"| `{row['name']}` | {'OK' if row['exists'] else 'MISSING'} | `{row['path']}` |")
    lines.extend(
        [
            "",
            "该检查只确认 x2 fixed reference 的输入材料是否齐全；不能替代 `W8A12_3lane/evidence/x2/reference/summary.md`。",
        ]
    )
    (OUT / "readiness.md").write_text("\n".join(lines), encoding="utf-8")
    return 0 if ready else 1


if __name__ == "__main__":
    raise SystemExit(main())
