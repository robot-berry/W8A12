"""Collect fixed activation scales for the SPAN fake-int8 reference."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_span_ptq_reference as ptq


IMAGE_EXTS = {".bmp", ".jpg", ".jpeg", ".png", ".tif", ".tiff", ".webp"}


def collect_images(path: Path, limit: int) -> list[Path]:
    if path.is_file():
        return [path]
    images = sorted(p for p in path.rglob("*") if p.suffix.lower() in IMAGE_EXTS)
    return images[:limit] if limit > 0 else images


def merge_scale(dst: dict, name: str, item: dict) -> None:
    if not item.get("enabled", False):
        return
    if name.endswith(".weight"):
        return
    current = dst.get(name)
    scale = float(item["scale_max"])
    if current is None or scale > current:
        dst[name] = scale


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Calibrate activation scales for SPAN W8A8 fake quantization.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--max-images", type=int, default=8)
    parser.add_argument("--per-channel-weights", action="store_true")
    parser.add_argument("--activation-bits", type=int, default=8)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = ptq.load_manifest(args.manifest)
    checkpoint = args.checkpoint or Path(manifest["source_checkpoint"])
    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    images = collect_images(args.input, args.max_images)
    if not images:
        raise SystemExit(f"no calibration images found: {args.input}")

    model = ptq.load_model(manifest, checkpoint, device)
    activation_scales: dict[str, float] = {}
    per_image: list[dict] = []
    for image in images:
        tensor, _ = ptq.image_to_tensor(image, args.width, args.height, device)
        _, scales = ptq.run_ptq(
            model,
            tensor,
            quant_weights=True,
            quant_activations=True,
            per_channel_weights=args.per_channel_weights,
            activation_bits=args.activation_bits,
        )
        record = {"image": str(image), "scales": {}}
        for name, item in scales.items():
            if name == "__overrides__":
                continue
            if item.get("enabled", False) and not name.endswith(".weight"):
                record["scales"][name] = float(item["scale_max"])
                merge_scale(activation_scales, name, item)
        per_image.append(record)

    output = {
        "source": "SPAN activation calibration",
        "manifest": str(args.manifest),
        "checkpoint": str(checkpoint),
        "input": str(args.input),
        "width": args.width,
        "height": args.height,
        "scale": int(manifest["scale"]),
        "images": [str(p) for p in images],
        "per_channel_weights": bool(args.per_channel_weights),
        "activation_bits": args.activation_bits,
        "activation_scales": activation_scales,
        "per_image": per_image,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps({"out": str(args.out), "images": len(images), "activation_scale_count": len(activation_scales)}, indent=2))


if __name__ == "__main__":
    main()
