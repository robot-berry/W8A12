"""Backfill metrics.csv from an already-running tqdm training log."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


PROGRESS_RE = re.compile(
    r"epoch\s+(\d+)/(\d+):\s+(\d+)%\|.*?\|\s+(\d+)/(\d+)\s+\[(.*?)<([^,\]]+).*?loss=([0-9.]+),\s+lr=([0-9.eE+-]+)"
)
VAL_RE = re.compile(r"epoch=(\d+)\s+val_psnr=([0-9.]+)dB")


def elapsed_to_seconds(text: str) -> float | None:
    parts = text.split(":")
    try:
        nums = [float(p) for p in parts]
    except ValueError:
        return None
    if len(nums) == 2:
        return nums[0] * 60 + nums[1]
    if len(nums) == 3:
        return nums[0] * 3600 + nums[1] * 60 + nums[2]
    return None


def parse(log_path: Path) -> list[dict]:
    raw = log_path.read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff") or raw[:200].count(b"\x00") > 20:
        text = raw.decode("utf-16", errors="ignore")
    else:
        text = raw.decode("utf-8", errors="ignore")
    text = text.replace("\r", "\n")
    by_epoch: dict[int, dict] = {}
    for m in PROGRESS_RE.finditer(text):
        epoch = int(m.group(1))
        step = int(m.group(4))
        total = int(m.group(5))
        elapsed = elapsed_to_seconds(m.group(6))
        row = {
            "epoch": epoch,
            "train_loss": float(m.group(8)),
            "val_psnr": "",
            "epoch_seconds": elapsed if step >= total else "",
            "steps_per_second": (total / elapsed) if (elapsed and step >= total) else "",
            "lr": m.group(9),
            "gpu_max_mem_mb": "",
            "best_psnr": "",
        }
        old = by_epoch.get(epoch)
        if old is None or step >= old.get("_step", -1):
            row["_step"] = step
            by_epoch[epoch] = row

    vals: dict[int, float] = {}
    for m in VAL_RE.finditer(text):
        vals[int(m.group(1))] = float(m.group(2))

    best = None
    rows = []
    for epoch in sorted(by_epoch):
        row = by_epoch[epoch]
        row.pop("_step", None)
        if epoch in vals:
            row["val_psnr"] = vals[epoch]
            best = vals[epoch] if best is None else max(best, vals[epoch])
        row["best_psnr"] = "" if best is None else best
        rows.append(row)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", default="runs/tinyspan_reds_x4_full/train_stdout.log")
    parser.add_argument("--output", default="runs/tinyspan_reds_x4_full/metrics.csv")
    args = parser.parse_args()

    rows = parse(Path(args.log))
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "epoch",
        "train_loss",
        "val_psnr",
        "epoch_seconds",
        "steps_per_second",
        "lr",
        "gpu_max_mem_mb",
        "best_psnr",
    ]
    with out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fields})
    print(f"Wrote {len(rows)} rows to {out}")


if __name__ == "__main__":
    main()
