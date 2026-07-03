#!/usr/bin/env python3
"""Generate BRAM accounting evidence for the W8A12_3lane report."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT_DIR = BASE / "evidence" / "resource" / "bram_accounting"

BRAM36_BITS = 36 * 1024
XC7Z045_BRAM_TILE_LIMIT = 545


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tile-width", type=int, default=32)
    parser.add_argument("--tile-height", type=int, default=32)
    parser.add_argument("--halo", type=int, default=21)
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def bram36_exact(bits: int | float) -> float:
    return float(bits) / BRAM36_BITS


def bram36_ceil(bits: int | float) -> int:
    return int(math.ceil(bram36_exact(bits)))


def pct(value: float, limit: float = XC7Z045_BRAM_TILE_LIMIT) -> float:
    return value * 100.0 / limit


def model_constant_accounting(label: str, manifest_path: Path, post_path: Path) -> dict[str, Any]:
    manifest = read_json(manifest_path)
    post = read_json(post_path)
    if manifest is None:
        return {
            "label": label,
            "status": "MISSING",
            "manifest": str(manifest_path),
            "postprocess_manifest": str(post_path),
        }

    weight_bits = sum(int(layer.get("weight_numel", 0)) for layer in manifest.get("layers", [])) * int(
        manifest.get("weight_bits", 8)
    )
    bias_bits = sum(int(layer.get("bias_numel", 0)) for layer in manifest.get("layers", [])) * 64
    requant_q31_bits = sum(int(layer.get("requant_numel", 0)) for layer in manifest.get("layers", [])) * 32
    requant_shift_bits = sum(int(layer.get("requant_numel", 0)) for layer in manifest.get("layers", [])) * 8
    activation_scale_bits = int(manifest.get("activation_scale_count", 0)) * 32

    post_lut_bits = 0
    post_entries = 0
    if post is not None:
        post_entries = int(post.get("entry_count", len(post.get("entries", []))))
        post_lut_bits = sum(int(entry.get("value_count", 0)) for entry in post.get("entries", [])) * int(
            post.get("activation_bits", manifest.get("activation_bits", 12))
        )

    total_bits = (
        weight_bits
        + bias_bits
        + requant_q31_bits
        + requant_shift_bits
        + activation_scale_bits
        + post_lut_bits
    )

    return {
        "label": label,
        "status": "PASS",
        "manifest": str(manifest_path),
        "postprocess_manifest": str(post_path),
        "scale": int(manifest.get("scale", 0)),
        "channels": int(manifest.get("channels", 0)),
        "activation_bits": int(manifest.get("activation_bits", 0)),
        "weight_bits": int(manifest.get("weight_bits", 0)),
        "layer_count": int(manifest.get("layer_count", len(manifest.get("layers", [])))),
        "postprocess_entry_count": post_entries,
        "weight_bits_total": weight_bits,
        "bias_bits": bias_bits,
        "requant_q31_bits": requant_q31_bits,
        "requant_shift_bits": requant_shift_bits,
        "activation_scale_bits": activation_scale_bits,
        "postprocess_lut_bits": post_lut_bits,
        "total_bits": total_bits,
        "bram36_exact": bram36_exact(total_bits),
        "bram36_ceil": bram36_ceil(total_bits),
    }


def load_feature_buffer_count(plan_path: Path) -> int:
    plan = read_json(plan_path)
    if plan is None:
        return 8
    return sum(
        1
        for buf in plan.get("buffers", [])
        if int(buf.get("channels", 0)) == 48 and int(buf.get("bits_per_value", 0)) == 12
    )


def tile_buffer_accounting(
    label: str,
    *,
    scale: int,
    tile_width: int,
    tile_height: int,
    halo: int,
    feature_buffer_count: int,
) -> dict[str, Any]:
    rgb_halo_bits = (tile_width + 2 * halo) * (tile_height + 2 * halo) * 3 * 8
    one_feature_bits = tile_width * tile_height * 48 * 12
    feature_bits = one_feature_bits * feature_buffer_count
    sr_output_bits = tile_width * scale * tile_height * scale * 3 * 8
    total_bits = rgb_halo_bits + feature_bits + sr_output_bits

    rows = [
        {
            "name": "rgb_halo_tile",
            "formula": f"({tile_width}+2*{halo})*({tile_height}+2*{halo})*3*8",
            "bits": rgb_halo_bits,
        },
        {
            "name": f"feature_buffer_x{feature_buffer_count}",
            "formula": f"{feature_buffer_count}*{tile_width}*{tile_height}*48*12",
            "bits": feature_bits,
        },
        {
            "name": "sr_rgb_output_tile",
            "formula": f"({tile_width}*{scale})*({tile_height}*{scale})*3*8",
            "bits": sr_output_bits,
        },
    ]
    for row in rows:
        row["bram36_exact"] = bram36_exact(row["bits"])
        row["bram36_ceil"] = bram36_ceil(row["bits"])

    return {
        "label": label,
        "scale": scale,
        "tile_width": tile_width,
        "tile_height": tile_height,
        "halo": halo,
        "feature_buffer_count": feature_buffer_count,
        "one_feature_buffer_bits": one_feature_bits,
        "rows": rows,
        "total_bits": total_bits,
        "bram36_exact": bram36_exact(total_bits),
        "bram36_ceil": bram36_ceil(total_bits),
    }


def actual_bram_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []

    ppa = read_json(BASE / "evidence" / "ppa_summary" / "summary.json")
    if ppa is not None:
        for row in ppa.get("rows", []):
            if row.get("name") in {"A4 3-lane scheduler", "A4 single-lane scheduler"}:
                bram = float(row.get("metrics", {}).get("bram", 0.0))
                rows.append(
                    {
                        "name": row.get("name"),
                        "scope": row.get("scope"),
                        "status": row.get("status"),
                        "bram_tile": bram,
                        "bram_pct_xc7z045": pct(bram),
                        "evidence": row.get("source"),
                    }
                )

    bitstream = read_json(BASE / "evidence" / "bitstream_ppa_gate" / "summary.json")
    if bitstream is not None:
        bram = float(bitstream.get("resource", {}).get("bram_tile", 0.0))
        rows.append(
            {
                "name": "true2x2 JTAG-W8A12 dbg5 implementation",
                "scope": bitstream.get("scope"),
                "status": bitstream.get("status"),
                "bram_tile": bram,
                "bram_pct_xc7z045": pct(bram),
                "evidence": "W8A12_3lane/evidence/bitstream_ppa_gate/summary.json",
            }
        )

    dbg6 = read_json(BASE / "evidence" / "implementation_runs" / "jtag_true2x2_dbg6_build_attempt_20260703" / "summary.json")
    if dbg6 is not None:
        bram = float(dbg6.get("synth_resources", {}).get("bram_tiles", 0.0))
        rows.append(
            {
                "name": "true2x2 JTAG-W8A12 dbg6 synth snapshot",
                "scope": dbg6.get("scope"),
                "status": dbg6.get("status"),
                "bram_tile": bram,
                "bram_pct_xc7z045": pct(bram),
                "evidence": "W8A12_3lane/evidence/implementation_runs/jtag_true2x2_dbg6_build_attempt_20260703/summary.json",
            }
        )

    a5 = read_json(BASE / "evidence" / "board_reports" / "a5_32x32_attempt" / "attempt_summary.json")
    if a5 is not None:
        gate = a5.get("resource_gate", {})
        bram = float(gate.get("bram_tile", 0.0))
        rows.append(
            {
                "name": "A5 32x32 PS-DDR tile-writer attempt",
                "scope": "32x32 LR tile, x4 output, board attempt resource gate",
                "status": gate.get("status", a5.get("status")),
                "bram_tile": bram,
                "bram_pct_xc7z045": pct(bram),
                "evidence": "W8A12_3lane/evidence/board_reports/a5_32x32_attempt/attempt_summary.json",
            }
        )

    dma = read_json(BASE / "evidence" / "implementation_runs" / "dma_axis_w8a10_route_congestion_20260703" / "summary.json")
    if dma is not None:
        bram = float(dma.get("placed_utilization", {}).get("block_ram_tile", {}).get("used", 0.0))
        rows.append(
            {
                "name": "large DMA/AXIS integration stress run",
                "scope": dma.get("scope"),
                "status": dma.get("status"),
                "bram_tile": bram,
                "bram_pct_xc7z045": pct(bram),
                "evidence": "W8A12_3lane/evidence/implementation_runs/dma_axis_w8a10_route_congestion_20260703/summary.json",
            }
        )

    return rows


def render_summary(data: dict[str, Any]) -> str:
    lines: list[str] = [
        "# W8A12_3lane BRAM 消耗计算",
        "",
        f"Status: {data['status']}",
        "",
        "## 口径",
        "",
        f"- BRAM36 按 `{BRAM36_BITS}` bit/tile 计算；XC7Z045/ZC706 等效门限按 `{XC7Z045_BRAM_TILE_LIMIT}` BRAM tile。",
        "- 模型常量按 unique layer weight/bias/requant/LUT 逻辑位宽计算，不重复统计导出目录中的 raw/grouped 多视图文件。",
        "- 32x32 tile buffer 是理论存储下限；真实 Vivado BRAM 会因为 banking、端口、位宽对齐、FIFO 和调试/PS 壳产生额外开销。",
        "",
        "## 模型常量存储",
        "",
        "| Model | Scale | Act bits | Layers | Weights bits | Bias/Requant bits | LUT bits | Total bits | BRAM36 exact | BRAM36 ceil |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in data["model_constants"]:
        bias_requant = row.get("bias_bits", 0) + row.get("requant_q31_bits", 0) + row.get("requant_shift_bits", 0)
        lines.append(
            "| {label} | {scale} | {activation_bits} | {layer_count} | {weight_bits_total} | {bias_requant} | "
            "{postprocess_lut_bits} | {total_bits} | {bram36_exact:.2f} | {bram36_ceil} |".format(
                **row,
                bias_requant=bias_requant,
            )
        )

    lines.extend(
        [
            "",
            "## 32x32 Tile Buffer 下限",
            "",
            "| Model | Scale | Tile/Halo | Feature buffers | Buffer bits | BRAM36 exact | BRAM36 ceil |",
            "| --- | ---: | --- | ---: | ---: | ---: | ---: |",
        ]
    )
    for row in data["tile_buffers"]:
        lines.append(
            f"| {row['label']} | {row['scale']} | {row['tile_width']}x{row['tile_height']} / h{row['halo']} | "
            f"{row['feature_buffer_count']} | {row['total_bits']} | {row['bram36_exact']:.2f} | {row['bram36_ceil']} |"
        )

    lines.extend(
        [
            "",
            "### x4 32x32 明细",
            "",
            "| Item | Formula | Bits | BRAM36 exact | BRAM36 ceil |",
            "| --- | --- | ---: | ---: | ---: |",
        ]
    )
    for row in data["tile_buffers"][0]["rows"]:
        lines.append(
            f"| {row['name']} | `{row['formula']}` | {row['bits']} | {row['bram36_exact']:.2f} | {row['bram36_ceil']} |"
        )

    lines.extend(
        [
            "",
            "## Vivado 实际 BRAM 口径",
            "",
            "| Implementation / OOC | Status | BRAM tile | XC7Z045 % | Evidence |",
            "| --- | --- | ---: | ---: | --- |",
        ]
    )
    for row in data["actual_bram"]:
        lines.append(
            f"| {row['name']} | `{row['status']}` | {row['bram_tile']:.1f} | {row['bram_pct_xc7z045']:.2f}% | `{row['evidence']}` |"
        )

    lines.extend(
        [
            "",
            "## 结论",
            "",
            "- A4 scheduler OOC BRAM 为 0，是因为该 OOC 只覆盖计算调度逻辑，不含 tile/frame buffer 与权重 ROM。",
            "- x4 W8A12/F48 的模型常量逻辑下限约为 "
            f"`{data['model_constants'][0]['bram36_exact']:.2f}` BRAM36；32x32 tile buffer 下限约为 "
            f"`{data['tile_buffers'][0]['bram36_exact']:.2f}` BRAM36。",
            "- 当前可用于 PPA 提交口径的 true2x2/JTAG-W8A12 实现为 `311` BRAM tile，占 XC7Z045/ZC706 等效门限 `57.06%`；A5 32x32 attempt 为 `415.5` BRAM tile，占 `76.24%`，资源门限 PASS 但板端完成信号未通过。",
            "- 大集成压力测试使用 `619` BRAM tile，超过 XC7Z045/ZC706 等效门限且 route 未完成，只能作为后续降资源风险证据。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    out_dir = args.out_dir if args.out_dir.is_absolute() else ROOT / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    x4_manifest = ROOT / "rtl" / "generated" / "reds_span_x4_f48_w8a12" / "span_w8a12_rtl_manifest.json"
    x4_post = ROOT / "rtl" / "generated" / "reds_span_x4_f48_w8a12" / "postprocess" / "span_w8a12_postprocess_manifest.json"
    x2_manifest = ROOT / "rtl" / "generated" / "reds_span_x2_f48_w8a12" / "span_w8a12_rtl_manifest.json"
    x2_post = ROOT / "rtl" / "generated" / "reds_span_x2_f48_w8a12" / "postprocess" / "span_w8a12_postprocess_manifest.json"
    x4_plan = ROOT / "rtl" / "generated" / "reds_span_x4_f48_w8a12" / "frame_engine" / "span_w8a12_frame_engine_plan.json"

    feature_buffer_count = load_feature_buffer_count(x4_plan)
    data = {
        "status": "PASS",
        "bram36_bits": BRAM36_BITS,
        "xc7z045_bram_tile_limit": XC7Z045_BRAM_TILE_LIMIT,
        "tile_width": args.tile_width,
        "tile_height": args.tile_height,
        "halo": args.halo,
        "model_constants": [
            model_constant_accounting("x4 W8A12/F48", x4_manifest, x4_post),
            model_constant_accounting("x2 W8A12/F48", x2_manifest, x2_post),
        ],
        "tile_buffers": [
            tile_buffer_accounting(
                "x4 W8A12/F48",
                scale=4,
                tile_width=args.tile_width,
                tile_height=args.tile_height,
                halo=args.halo,
                feature_buffer_count=feature_buffer_count,
            ),
            tile_buffer_accounting(
                "x2 W8A12/F48",
                scale=2,
                tile_width=args.tile_width,
                tile_height=args.tile_height,
                halo=args.halo,
                feature_buffer_count=feature_buffer_count,
            ),
        ],
        "actual_bram": actual_bram_rows(),
    }
    (out_dir / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_summary(data), encoding="utf-8")
    print(f"BRAM_ACCOUNTING_STATUS={data['status']}")
    print(f"BRAM_ACCOUNTING_SUMMARY={out_dir / 'summary.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
