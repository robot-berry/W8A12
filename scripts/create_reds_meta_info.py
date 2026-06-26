"""Create BasicSR meta-info files for nested REDS frame folders."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, help="HR image root, e.g. G:/REDS/train_sharp")
    parser.add_argument("--output", required=True, help="Output meta-info txt path")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = Path(args.root)
    paths = sorted(p for p in root.rglob("*") if p.suffix.lower() in IMAGE_EXTS)
    if not paths:
        raise FileNotFoundError(f"No images found under {root}")

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for path in paths:
            rel = path.relative_to(root).as_posix()
            with Image.open(path) as img:
                width, height = img.size
            f.write(f"{rel} ({height},{width},3)\n")
    print(f"Wrote {len(paths)} entries to {out_path}")


if __name__ == "__main__":
    main()
