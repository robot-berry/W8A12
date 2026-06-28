"""Write an HWC .npy feature tensor as `pix ch value` dump."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_npy", type=Path)
    parser.add_argument("output_dump", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    arr = np.load(args.input_npy)
    if arr.ndim != 3:
        raise SystemExit(f"expected HWC tensor, got shape {arr.shape}")
    height, width, channels = arr.shape
    lines: list[str] = []
    for y in range(height):
        for x in range(width):
            pix = y * width + x
            for ch in range(channels):
                lines.append(f"{pix} {ch} {int(arr[y, x, ch])}")
    args.output_dump.parent.mkdir(parents=True, exist_ok=True)
    args.output_dump.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"wrote {args.output_dump} shape={height}x{width}x{channels}")


if __name__ == "__main__":
    main()
