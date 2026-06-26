"""Train TinySPAN on REDS for x2/x4 super-resolution.

Example:
  python train/train_reds_span.py --train-hr D:/data/REDS/train/train_sharp \
      --val-hr D:/data/REDS/val/val_sharp --scale 4 --epochs 200
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import time
from pathlib import Path

import torch
from torch import nn
from torch.amp import GradScaler, autocast
from torch.utils.data import DataLoader
from tqdm import tqdm

from reds_dataset import REDSSISRDataset, psnr, sobel_edges
from span_model import build_model


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train-hr", required=True, help="Path to REDS train HR frames")
    parser.add_argument("--val-hr", default=None, help="Optional REDS val HR frames")
    parser.add_argument("--scale", type=int, choices=(2, 4), default=4)
    parser.add_argument("--channels", type=int, default=48)
    parser.add_argument("--num-blocks", type=int, default=6)
    parser.add_argument("--patch-size", type=int, default=192)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--epochs", type=int, default=200)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument("--num-workers", type=int, default=4)
    parser.add_argument("--train-max-images", type=int, default=None)
    parser.add_argument("--val-max-images", type=int, default=None)
    parser.add_argument("--edge-weight", type=float, default=0.05)
    parser.add_argument("--jpeg-prob", type=float, default=0.2)
    parser.add_argument("--output", default="runs/tinyspan_reds")
    parser.add_argument("--resume", default=None)
    parser.add_argument("--amp", action="store_true")
    parser.add_argument("--save-every", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def save_checkpoint(
    path: Path,
    model: nn.Module,
    optimizer: torch.optim.Optimizer,
    epoch: int,
    best_psnr: float,
    val_psnr: float | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "epoch": epoch,
            "model": model.state_dict(),
            "optimizer": optimizer.state_dict(),
            "best_psnr": best_psnr,
            "val_psnr": val_psnr,
        },
        path,
    )


def append_metrics(path: Path, row: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    exists = path.exists()
    fieldnames = [
        "epoch",
        "train_loss",
        "val_psnr",
        "epoch_seconds",
        "steps_per_second",
        "lr",
        "gpu_max_mem_mb",
        "best_psnr",
    ]
    with path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if not exists:
            writer.writeheader()
        writer.writerow({k: row.get(k, "") for k in fieldnames})


def append_jsonl(path: Path, row: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


@torch.no_grad()
def validate(model: nn.Module, loader: DataLoader, device: torch.device, border: int) -> float:
    model.eval()
    scores: list[float] = []
    for lr, hr in tqdm(loader, desc="validate", leave=False):
        lr = lr.to(device, non_blocking=True)
        hr = hr.to(device, non_blocking=True)
        sr = model(lr)
        scores.append(psnr(sr, hr, border=border))
    model.train()
    return sum(scores) / max(1, len(scores))


def main() -> None:
    args = parse_args()
    torch.manual_seed(args.seed)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    (output / "args.json").write_text(json.dumps(vars(args), indent=2), encoding="utf-8")
    metrics_csv = output / "metrics.csv"
    metrics_jsonl = output / "metrics.jsonl"

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = build_model(scale=args.scale, channels=args.channels, num_blocks=args.num_blocks).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, betas=(0.9, 0.99), weight_decay=0.0)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs, eta_min=args.lr * 0.05)
    scaler = GradScaler("cuda", enabled=args.amp and device.type == "cuda")
    l1 = nn.L1Loss()

    train_set = REDSSISRDataset(
        args.train_hr,
        scale=args.scale,
        patch_size=args.patch_size,
        augment=True,
        jpeg_prob=args.jpeg_prob,
        max_images=args.train_max_images,
    )
    train_loader = DataLoader(
        train_set,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        pin_memory=True,
        drop_last=True,
    )

    val_loader = None
    if args.val_hr:
        val_set = REDSSISRDataset(
            args.val_hr,
            scale=args.scale,
            patch_size=args.patch_size,
            augment=False,
            jpeg_prob=0.0,
            max_images=args.val_max_images,
        )
        val_loader = DataLoader(val_set, batch_size=1, shuffle=False, num_workers=args.num_workers)

    start_epoch = 0
    best = -math.inf
    if args.resume:
        ckpt = torch.load(args.resume, map_location=device)
        model.load_state_dict(ckpt["model"])
        optimizer.load_state_dict(ckpt["optimizer"])
        start_epoch = int(ckpt["epoch"]) + 1
        best = float(ckpt.get("best_psnr", best))

    for epoch in range(start_epoch, args.epochs):
        model.train()
        running = 0.0
        epoch_start = time.perf_counter()
        if device.type == "cuda":
            torch.cuda.reset_peak_memory_stats(device)
        progress = tqdm(train_loader, desc=f"epoch {epoch + 1}/{args.epochs}")
        for lr, hr in progress:
            lr = lr.to(device, non_blocking=True)
            hr = hr.to(device, non_blocking=True)

            optimizer.zero_grad(set_to_none=True)
            with autocast("cuda", enabled=args.amp and device.type == "cuda"):
                sr = model(lr)
                image_loss = l1(sr, hr)
                edge_loss = l1(sobel_edges(sr), sobel_edges(hr))
                loss = image_loss + args.edge_weight * edge_loss

            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            running += loss.item()
            progress.set_postfix(loss=f"{running / (progress.n + 1):.5f}", lr=f"{scheduler.get_last_lr()[0]:.2e}")

        scheduler.step()
        epoch_seconds = time.perf_counter() - epoch_start
        train_loss = running / max(1, len(train_loader))
        steps_per_second = len(train_loader) / max(epoch_seconds, 1e-9)
        gpu_max_mem_mb = ""
        if device.type == "cuda":
            gpu_max_mem_mb = torch.cuda.max_memory_allocated(device) / (1024 * 1024)

        val_psnr = None
        if val_loader is not None:
            val_psnr = validate(model, val_loader, device, border=args.scale)
            print(f"epoch={epoch + 1} val_psnr={val_psnr:.3f}dB")
            if val_psnr > best:
                best = val_psnr
                save_checkpoint(output / "best.pt", model, optimizer, epoch, best, val_psnr)

        metric_row = {
            "epoch": epoch + 1,
            "train_loss": f"{train_loss:.8f}",
            "val_psnr": "" if val_psnr is None else f"{val_psnr:.6f}",
            "epoch_seconds": f"{epoch_seconds:.3f}",
            "steps_per_second": f"{steps_per_second:.4f}",
            "lr": f"{scheduler.get_last_lr()[0]:.8e}",
            "gpu_max_mem_mb": "" if gpu_max_mem_mb == "" else f"{gpu_max_mem_mb:.2f}",
            "best_psnr": "" if best == -math.inf else f"{best:.6f}",
        }
        append_metrics(metrics_csv, metric_row)
        append_jsonl(metrics_jsonl, metric_row)
        print(
            "metrics "
            f"epoch={epoch + 1} train_loss={train_loss:.6f} "
            f"val_psnr={val_psnr if val_psnr is not None else 'NA'} "
            f"epoch_seconds={epoch_seconds:.2f} steps_per_second={steps_per_second:.3f} "
            f"gpu_max_mem_mb={gpu_max_mem_mb if gpu_max_mem_mb != '' else 'NA'}"
        )

        save_checkpoint(output / "last.pt", model, optimizer, epoch, best, val_psnr)
        if ((epoch + 1) % args.save_every == 0) or (epoch + 1 == args.epochs):
            save_checkpoint(output / f"epoch_{epoch + 1:04d}.pt", model, optimizer, epoch, best, val_psnr)


if __name__ == "__main__":
    main()
