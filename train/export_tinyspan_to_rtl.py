"""Export TinySPAN checkpoint metadata and quantized weights for RTL flow."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import torch
from torch import nn

from span_model import Conv3XC, build_model


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--scale", type=int, choices=(2, 4), required=True)
    parser.add_argument("--channels", type=int, default=48)
    parser.add_argument("--num-blocks", type=int, default=6)
    parser.add_argument("--output-dir", default="rtl/generated")
    parser.add_argument("--fuse-conv3xc", action="store_true", help="Fuse each Conv3XC block into one 3x3 C->C conv before export.")
    return parser.parse_args()


class FusedConv3XC(nn.Module):
    def __init__(self, weight: torch.Tensor, bias: torch.Tensor) -> None:
        super().__init__()
        channels = int(weight.shape[0])
        self.conv = nn.Conv2d(channels, channels, 3, 1, 1)
        with torch.no_grad():
            self.conv.weight.copy_(weight)
            self.conv.bias.copy_(bias)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.conv(x)


def fuse_conv3xc(module: Conv3XC) -> tuple[torch.Tensor, torch.Tensor]:
    conv1 = module.conv1
    conv2 = module.conv2
    conv3 = module.conv3
    skip = module.skip
    w1 = conv1.weight.detach().float()[:, :, 0, 0]
    b1 = conv1.bias.detach().float()
    w2 = conv2.weight.detach().float()
    b2 = conv2.bias.detach().float()
    w3 = conv3.weight.detach().float()[:, :, 0, 0]
    b3 = conv3.bias.detach().float()
    wsk = skip.weight.detach().float()[:, :, 0, 0]
    bsk = skip.bias.detach().float()

    fused_w = torch.einsum("oh,hmxy,mi->oixy", w3, w2, w1)
    center = fused_w.shape[-1] // 2
    fused_w[:, :, center, center] += wsk
    conv2_bias_interior = b2 + torch.einsum("hmxy,m->h", w2, b1)
    fused_b = b3 + torch.einsum("oh,h->o", w3, conv2_bias_interior) + bsk
    return fused_w, fused_b


def fuse_model_conv3xc(model: nn.Module) -> int:
    fused_count = 0
    for block in model.blocks:
        for attr in ("c1", "c2", "c3"):
            original = getattr(block, attr)
            if not isinstance(original, Conv3XC):
                raise TypeError(f"expected Conv3XC at {attr}, got {type(original).__name__}")
            weight, bias = fuse_conv3xc(original)
            setattr(block, attr, FusedConv3XC(weight, bias))
            fused_count += 1
    return fused_count


def quantize_tensor(tensor: torch.Tensor) -> tuple[torch.Tensor, float]:
    tensor = tensor.detach().cpu().float()
    max_abs = float(tensor.abs().max().item())
    scale = max(max_abs / 127.0, 1e-12)
    q = torch.clamp(torch.round(tensor / scale), -128, 127).to(torch.int8)
    return q, scale


def write_mem(path: Path, q: torch.Tensor) -> None:
    flat = q.reshape(-1).to(torch.int16)
    lines = []
    for v in flat.tolist():
        lines.append(f"{v & 0xff:02x}")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    weight_dir = output_dir / "weights"
    weight_dir.mkdir(parents=True, exist_ok=True)

    ckpt = torch.load(args.checkpoint, map_location="cpu")
    model = build_model(scale=args.scale, channels=args.channels, num_blocks=args.num_blocks)
    model.load_state_dict(ckpt["model"], strict=True)
    model.eval()
    fused_count = 0
    if args.fuse_conv3xc:
        fused_count = fuse_model_conv3xc(model)

    manifest = []
    for name, tensor in model.state_dict().items():
        q, q_scale = quantize_tensor(tensor)
        safe_name = name.replace(".", "_")
        mem_path = weight_dir / f"{safe_name}.mem"
        write_mem(mem_path, q)
        manifest.append(
            {
                "name": name,
                "file": str(mem_path.relative_to(output_dir)).replace("\\", "/"),
                "shape": list(tensor.shape),
                "quant_scale": q_scale,
                "dtype": "int8_hex_mem",
            }
        )

    info = {
        "source_checkpoint": str(Path(args.checkpoint).resolve()),
        "scale": args.scale,
        "channels": args.channels,
        "num_blocks": args.num_blocks,
        "epoch": ckpt.get("epoch"),
        "best_psnr": ckpt.get("best_psnr"),
        "conv3xc_fused": bool(args.fuse_conv3xc),
        "conv3xc_fused_count": fused_count,
        "fusion_note": "Conv3XC fused with interior-bias formula; validate border behavior against PyTorch before RTL signoff." if args.fuse_conv3xc else "",
        "weights": manifest,
    }
    (output_dir / "tinyspan_manifest.json").write_text(json.dumps(info, indent=2), encoding="utf-8")

    vh = "\n".join(
        [
            "`ifndef TINYSPAN_MODEL_CONFIG_VH",
            "`define TINYSPAN_MODEL_CONFIG_VH",
            "// Auto-generated by train/export_tinyspan_to_rtl.py.",
            f"`define TINYSPAN_TRAINED_WEIGHTS 1",
            f"`define TINYSPAN_MODEL_SCALE {args.scale}",
            f"`define TINYSPAN_MODEL_CHANNELS {args.channels}",
            f"`define TINYSPAN_MODEL_BLOCKS {args.num_blocks}",
            f"`define TINYSPAN_CONV3XC_FUSED {1 if args.fuse_conv3xc else 0}",
            f"`define TINYSPAN_WEIGHT_COUNT {len(manifest)}",
            "`endif",
            "",
        ]
    )
    (output_dir / "tinyspan_model_config.vh").write_text(vh, encoding="utf-8")
    print(f"Exported TinySPAN RTL artifacts to {output_dir}")


if __name__ == "__main__":
    main()
