#!/usr/bin/env python3
"""Generate a final quality comparison report against interpolation baselines."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"


def load_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def method_value(data: dict | None, method_name: str, key: str) -> float | None:
    if not data:
        return None
    for method in data.get("methods", []):
        if method.get("name") == method_name:
            value = method.get(key)
            return float(value) if value is not None else None
    return None


def board_psnr(board_summary: Path) -> float | None:
    data = load_json(board_summary)
    if not data:
        return None
    value = data.get("quality", {}).get("psnr_db")
    return float(value) if value is not None else None


def delta(value: float | None, baseline: float | None) -> float | None:
    if value is None or baseline is None:
        return None
    return value - baseline


def fmt(value: float | None, digits: int = 4) -> str:
    if value is None:
        return "待跑"
    return f"{value:.{digits}f}"


def build_row(scale: int, label: str, psnr_rgb: float | None, psnr_y: float | None, ssim_y: float | None, bicubic_rgb: float | None, note: str) -> dict:
    return {
        "scale": scale,
        "method": label,
        "psnr_rgb_db": psnr_rgb,
        "psnr_y_db": psnr_y,
        "ssim_y": ssim_y,
        "delta_vs_bicubic_rgb_db": delta(psnr_rgb, bicubic_rgb),
        "note": note,
    }


def render_md(data: dict) -> str:
    lines = [
        "# Quality Comparison Report",
        "",
        f"Status: {data['status']}",
        "",
        "该报告汇总传统插值法、SPAN FP32、W8A12 fixed-point 和 board 输出的画质指标，用于赛题文档中的“清晰度/超分效果”分析。",
        "",
        "| Scale | Method | PSNR RGB | PSNR Y | SSIM Y | Delta vs Bicubic RGB | Note |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in data["rows"]:
        lines.append(
            f"| x{row['scale']} | {row['method']} | {fmt(row['psnr_rgb_db'])} | "
            f"{fmt(row['psnr_y_db'])} | {fmt(row['ssim_y'], 6)} | "
            f"{fmt(row['delta_vs_bicubic_rgb_db'])} | {row['note']} |"
        )
    lines.extend(
        [
            "",
            "验收口径：",
            "",
            "- x4 SPAN/W8A12/board 最终目标：REDS_val PSNR >= 28 dB；",
            "- x2 SPAN/W8A12/board 最终目标：REDS_val PSNR >= 30 dB；",
            "- `Delta vs Bicubic RGB` 用于说明 AI 超分相对传统插值的 PSNR 提升；",
            "- 若 W8A12 fixed 或 board 指标低于 FP32，需要在最终报告解释量化、tile halo、DDR/拼接误差来源。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--x4-baseline", type=Path, default=BASE / "evidence" / "quality_baseline" / "x4_interpolation" / "summary.json")
    parser.add_argument("--x2-baseline", type=Path, default=BASE / "evidence" / "quality_baseline" / "x2_interpolation" / "summary.json")
    parser.add_argument("--x4-board-summary", type=Path, default=BASE / "evidence" / "board_reports" / "a7_720p_x4" / "summary.json")
    parser.add_argument("--x2-board-summary", type=Path, default=BASE / "evidence" / "board_reports" / "x2_720p" / "summary.json")
    parser.add_argument("--x4-span-fp32-psnr-db", type=float, default=28.3118)
    parser.add_argument("--x2-span-fp32-psnr-db", type=float, default=34.4297)
    parser.add_argument("--x4-fixed-psnr-db", type=float)
    parser.add_argument("--x2-fixed-psnr-db", type=float)
    parser.add_argument("--x4-board-psnr-db", type=float)
    parser.add_argument("--x2-board-psnr-db", type=float)
    parser.add_argument("--out-dir", type=Path, default=BASE / "evidence" / "quality_comparison")
    args = parser.parse_args()

    x4_base = load_json(args.x4_baseline)
    x2_base = load_json(args.x2_baseline)
    x4_bicubic_rgb = method_value(x4_base, "bicubic", "psnr_rgb_avg")
    x2_bicubic_rgb = method_value(x2_base, "bicubic", "psnr_rgb_avg")

    rows: list[dict] = []
    for scale, baseline, bicubic_rgb in ((4, x4_base, x4_bicubic_rgb), (2, x2_base, x2_bicubic_rgb)):
        for method in ("nearest", "bilinear", "bicubic"):
            rows.append(
                build_row(
                    scale,
                    method,
                    method_value(baseline, method, "psnr_rgb_avg"),
                    method_value(baseline, method, "psnr_y_avg"),
                    method_value(baseline, method, "ssim_y_avg"),
                    bicubic_rgb,
                    "traditional interpolation",
                )
            )

    x4_board = args.x4_board_psnr_db if args.x4_board_psnr_db is not None else board_psnr(args.x4_board_summary)
    x2_board = args.x2_board_psnr_db if args.x2_board_psnr_db is not None else board_psnr(args.x2_board_summary)
    rows.extend(
        [
            build_row(4, "SPAN FP32", args.x4_span_fp32_psnr_db, None, None, x4_bicubic_rgb, "training log"),
            build_row(4, "W8A12 fixed", args.x4_fixed_psnr_db, None, None, x4_bicubic_rgb, "fixed-point reference"),
            build_row(4, "board", x4_board, None, None, x4_bicubic_rgb, "A7 720p board report"),
            build_row(2, "SPAN FP32", args.x2_span_fp32_psnr_db, None, None, x2_bicubic_rgb, "training log"),
            build_row(2, "W8A12 fixed", args.x2_fixed_psnr_db, None, None, x2_bicubic_rgb, "fixed-point reference"),
            build_row(2, "board", x2_board, None, None, x2_bicubic_rgb, "x2 720p board report"),
        ]
    )

    missing_inputs = []
    if x4_base is None:
        missing_inputs.append(args.x4_baseline.as_posix())
    if x2_base is None:
        missing_inputs.append(args.x2_baseline.as_posix())
    status = "PASS" if not missing_inputs else "NOT_READY"
    data = {
        "status": status,
        "missing_inputs": missing_inputs,
        "rows": rows,
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (args.out_dir / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
