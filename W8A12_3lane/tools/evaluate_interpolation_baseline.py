#!/usr/bin/env python3
"""Evaluate traditional interpolation baselines for REDS SR validation."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np


try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment guard
    raise SystemExit("Pillow is required: pip install pillow") from exc


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"


RESAMPLE = {
    "nearest": Image.Resampling.NEAREST,
    "bilinear": Image.Resampling.BILINEAR,
    "bicubic": Image.Resampling.BICUBIC,
}


def psnr_uint8(pred: np.ndarray, target: np.ndarray) -> float:
    diff = pred.astype(np.float64) - target.astype(np.float64)
    mse = float(np.mean(diff * diff))
    if mse == 0:
        return float("inf")
    return 20.0 * math.log10(255.0 / math.sqrt(mse))


def ssim_luma_uint8(pred: np.ndarray, target: np.ndarray) -> float:
    """Small global SSIM estimate on luma, enough for baseline ranking."""
    pred_y = rgb_to_y(pred).astype(np.float64)
    target_y = rgb_to_y(target).astype(np.float64)
    c1 = (0.01 * 255.0) ** 2
    c2 = (0.03 * 255.0) ** 2
    mu_x = float(pred_y.mean())
    mu_y = float(target_y.mean())
    sigma_x = float(((pred_y - mu_x) ** 2).mean())
    sigma_y = float(((target_y - mu_y) ** 2).mean())
    sigma_xy = float(((pred_y - mu_x) * (target_y - mu_y)).mean())
    return ((2 * mu_x * mu_y + c1) * (2 * sigma_xy + c2)) / (
        (mu_x * mu_x + mu_y * mu_y + c1) * (sigma_x + sigma_y + c2)
    )


def rgb_to_y(image: np.ndarray) -> np.ndarray:
    return 0.299 * image[..., 0] + 0.587 * image[..., 1] + 0.114 * image[..., 2]


def load_rgb(path: Path) -> Image.Image:
    return Image.open(path).convert("RGB")


def collect_pairs(gt_dir: Path, lq_dir: Path, limit: int | None) -> list[tuple[Path, Path]]:
    gt_files = sorted([p for p in gt_dir.rglob("*") if p.suffix.lower() in {".png", ".jpg", ".jpeg"}])
    pairs: list[tuple[Path, Path]] = []
    for gt in gt_files:
        rel = gt.relative_to(gt_dir)
        lq = lq_dir / rel
        if lq.exists():
            pairs.append((gt, lq))
            if limit is not None and len(pairs) >= limit:
                break
    return pairs


def render_md(data: dict) -> str:
    lines = [
        "# Interpolation Baseline Evaluation",
        "",
        f"Status: {data['status']}",
        "",
        f"Scale: x{data['scale']}",
        f"Pair count: {data['pair_count']}",
        f"GT dir: `{data['gt_dir']}`",
        f"LQ dir: `{data['lq_dir']}`",
        "",
        "| Method | PSNR RGB (dB) | PSNR Y (dB) | SSIM Y |",
        "| --- | ---: | ---: | ---: |",
    ]
    for method in data["methods"]:
        lines.append(
            f"| {method['name']} | {method['psnr_rgb_avg']:.4f} | "
            f"{method['psnr_y_avg']:.4f} | {method['ssim_y_avg']:.6f} |"
        )
    lines.extend(
        [
            "",
            "Comparison slots:",
            "",
            f"- SPAN FP32 PSNR: {data.get('span_fp32_psnr_db')}",
            f"- W8A12 fixed PSNR: {data.get('w8a12_fixed_psnr_db')}",
            f"- Board PSNR: {data.get('board_psnr_db')}",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", type=int, choices=[2, 4], required=True)
    parser.add_argument("--gt-dir", type=Path, required=True)
    parser.add_argument("--lq-dir", type=Path, required=True)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--span-fp32-psnr-db", type=float)
    parser.add_argument("--w8a12-fixed-psnr-db", type=float)
    parser.add_argument("--board-psnr-db", type=float)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    pairs = collect_pairs(args.gt_dir, args.lq_dir, args.limit)
    if not pairs:
        raise SystemExit(f"no GT/LQ image pairs found under {args.gt_dir} and {args.lq_dir}")

    method_rows = []
    for name, resample in RESAMPLE.items():
        psnr_rgb_values: list[float] = []
        psnr_y_values: list[float] = []
        ssim_y_values: list[float] = []
        for gt_path, lq_path in pairs:
            gt_img = load_rgb(gt_path)
            lq_img = load_rgb(lq_path)
            up_img = lq_img.resize(gt_img.size, resample=resample)
            gt_np = np.asarray(gt_img, dtype=np.uint8)
            up_np = np.asarray(up_img, dtype=np.uint8)
            psnr_rgb_values.append(psnr_uint8(up_np, gt_np))
            psnr_y_values.append(psnr_uint8(rgb_to_y(up_np), rgb_to_y(gt_np)))
            ssim_y_values.append(ssim_luma_uint8(up_np, gt_np))
        method_rows.append(
            {
                "name": name,
                "psnr_rgb_avg": float(np.mean(psnr_rgb_values)),
                "psnr_y_avg": float(np.mean(psnr_y_values)),
                "ssim_y_avg": float(np.mean(ssim_y_values)),
            }
        )

    data = {
        "status": "PASS",
        "scale": args.scale,
        "gt_dir": args.gt_dir.as_posix(),
        "lq_dir": args.lq_dir.as_posix(),
        "pair_count": len(pairs),
        "methods": method_rows,
        "span_fp32_psnr_db": args.span_fp32_psnr_db,
        "w8a12_fixed_psnr_db": args.w8a12_fixed_psnr_db,
        "board_psnr_db": args.board_psnr_db,
    }

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (args.out_dir / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
