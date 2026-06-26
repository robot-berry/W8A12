"""REDS dataset loader for single-image super-resolution training."""

from __future__ import annotations

import random
from pathlib import Path

import torch
from PIL import Image
from torch.utils.data import Dataset
from torchvision.transforms.functional import to_tensor


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp"}


def list_images(root: Path) -> list[Path]:
    return sorted(p for p in root.rglob("*") if p.suffix.lower() in IMAGE_EXTS)


def bicubic_downsample(hr: Image.Image, scale: int) -> Image.Image:
    w, h = hr.size
    return hr.resize((w // scale, h // scale), Image.Resampling.BICUBIC)


def jpeg_degrade(img: Image.Image, quality_min: int, quality_max: int) -> Image.Image:
    """Apply a lightweight video-conference-like JPEG compression degradation."""
    import io

    quality = random.randint(quality_min, quality_max)
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=quality)
    buffer.seek(0)
    return Image.open(buffer).convert("RGB")


class REDSSISRDataset(Dataset):
    """Crop HR frames from REDS and generate LR crops on the fly.

    Expected REDS root examples:
      REDS/train/train_sharp/000/00000000.png
      REDS/train_sharp/000/00000000.png
      REDS/val/val_sharp/000/00000000.png

    If paired LR folders are available, this loader still uses on-the-fly
    bicubic LR generation to keep x2/x4 experiments consistent.
    """

    def __init__(
        self,
        hr_root: str | Path,
        scale: int = 4,
        patch_size: int = 192,
        augment: bool = True,
        jpeg_prob: float = 0.2,
        jpeg_quality: tuple[int, int] = (45, 90),
        max_images: int | None = None,
    ) -> None:
        self.hr_root = Path(hr_root)
        self.scale = scale
        self.patch_size = patch_size
        self.augment = augment
        self.jpeg_prob = jpeg_prob
        self.jpeg_quality = jpeg_quality
        self.paths = list_images(self.hr_root)
        if max_images is not None:
            self.paths = self.paths[:max_images]
        if not self.paths:
            raise FileNotFoundError(f"No images found under {self.hr_root}")
        if patch_size % scale != 0:
            raise ValueError("patch_size must be divisible by scale")

    def __len__(self) -> int:
        return len(self.paths)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        hr = Image.open(self.paths[index]).convert("RGB")

        w, h = hr.size
        crop = min(self.patch_size, w - (w % self.scale), h - (h % self.scale))
        if crop < self.scale:
            raise ValueError(f"Image too small for scale {self.scale}: {self.paths[index]}")

        if self.augment:
            x = random.randint(0, w - crop)
            y = random.randint(0, h - crop)
        else:
            x = max(0, (w - crop) // 2)
            y = max(0, (h - crop) // 2)
        hr = hr.crop((x, y, x + crop, y + crop))

        if self.augment and random.random() < 0.5:
            hr = hr.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if self.augment and random.random() < 0.5:
            hr = hr.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        if self.augment:
            rot = random.randint(0, 3)
            if rot:
                hr = hr.rotate(90 * rot, expand=True)

        lr = bicubic_downsample(hr, self.scale)
        if self.augment and random.random() < self.jpeg_prob:
            lr = jpeg_degrade(lr, *self.jpeg_quality)

        return to_tensor(lr), to_tensor(hr)


def sobel_edges(x: torch.Tensor) -> torch.Tensor:
    """Compute RGB edge magnitude for auxiliary edge loss."""
    kernel_x = torch.tensor(
        [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=x.dtype, device=x.device
    ).view(1, 1, 3, 3)
    kernel_y = torch.tensor(
        [[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=x.dtype, device=x.device
    ).view(1, 1, 3, 3)
    kernel_x = kernel_x.repeat(x.size(1), 1, 1, 1)
    kernel_y = kernel_y.repeat(x.size(1), 1, 1, 1)
    gx = torch.nn.functional.conv2d(x, kernel_x, padding=1, groups=x.size(1))
    gy = torch.nn.functional.conv2d(x, kernel_y, padding=1, groups=x.size(1))
    return torch.sqrt(gx * gx + gy * gy + 1e-12)


def psnr(sr: torch.Tensor, hr: torch.Tensor, border: int = 0) -> float:
    if border > 0:
        sr = sr[..., border:-border, border:-border]
        hr = hr[..., border:-border, border:-border]
    mse = torch.mean((sr.clamp(0, 1) - hr.clamp(0, 1)) ** 2).item()
    if mse <= 0:
        return 99.0
    return 10.0 * torch.log10(torch.tensor(1.0 / mse)).item()
