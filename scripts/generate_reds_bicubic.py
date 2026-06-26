"""Generate REDS bicubic LR folders for BasicSR paired training."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image
from tqdm import tqdm


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", required=True, help="HR root, e.g. G:/REDS/train_sharp")
    parser.add_argument("--dst", required=True, help="LR root, e.g. G:/REDS/train/train_sharp_bicubic/X2")
    parser.add_argument("--scale", type=int, choices=(2, 4), required=True)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def downsample_one(src_root: Path, dst_root: Path, scale: int, overwrite: bool, path: Path) -> None:
    rel = path.relative_to(src_root)
    out_path = dst_root / rel
    if out_path.exists() and not overwrite:
        return
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(path) as img:
        img = img.convert("RGB")
        width, height = img.size
        lr = img.resize((width // scale, height // scale), Image.Resampling.BICUBIC)
        lr.save(out_path)


def main() -> None:
    args = parse_args()
    src_root = Path(args.src)
    dst_root = Path(args.dst)
    paths = sorted(p for p in src_root.rglob("*") if p.suffix.lower() in IMAGE_EXTS)
    if not paths:
        raise FileNotFoundError(f"No images found under {src_root}")

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        jobs = [
            executor.submit(downsample_one, src_root, dst_root, args.scale, args.overwrite, path)
            for path in paths
        ]
        for job in tqdm(jobs, desc=f"x{args.scale} bicubic"):
            job.result()
    print(f"Generated {len(paths)} images under {dst_root}")


if __name__ == "__main__":
    main()
