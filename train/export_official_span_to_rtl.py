"""Export official SPAN checkpoint weights for the RTL integration flow."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import torch


DEPLOY_SUFFIXES = (
    "eval_conv.weight",
    "eval_conv.bias",
    "conv_cat.weight",
    "conv_cat.bias",
    "upsampler.0.weight",
    "upsampler.0.bias",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--scale", type=int, choices=(2, 4), required=True)
    parser.add_argument("--channels", type=int, default=48)
    parser.add_argument("--output-dir", default="rtl/generated")
    parser.add_argument("--tag", default=None)
    parser.add_argument("--best-psnr", type=float, default=None)
    parser.add_argument("--source-label", default="official SPAN")
    parser.add_argument("--dataset-name", default=None)
    parser.add_argument("--dataset-root", default=None)
    parser.add_argument("--span-root", default="external/SPAN")
    return parser.parse_args()


def quantize_tensor(tensor: torch.Tensor) -> tuple[torch.Tensor, float]:
    tensor = tensor.detach().cpu().float()
    max_abs = float(tensor.abs().max().item())
    scale = max(max_abs / 127.0, 1e-12)
    q = torch.clamp(torch.round(tensor / scale), -128, 127).to(torch.int8)
    return q, scale


def write_mem(path: Path, q: torch.Tensor) -> None:
    flat = q.reshape(-1).to(torch.int16)
    lines = [f"{v & 0xff:02x}" for v in flat.tolist()]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def import_span(span_root: Path):
    sys.path.insert(0, str(span_root.resolve()))
    from basicsr.archs.span_arch import SPAN

    return SPAN


def load_state(checkpoint: Path) -> tuple[dict[str, torch.Tensor], str]:
    ckpt = torch.load(checkpoint, map_location="cpu")
    if isinstance(ckpt, dict):
        if "params_ema" in ckpt:
            return ckpt["params_ema"], "params_ema"
        if "params" in ckpt:
            return ckpt["params"], "params"
    return ckpt, "state_dict"


def is_deploy_tensor(name: str) -> bool:
    return any(name.endswith(suffix) for suffix in DEPLOY_SUFFIXES)


def main() -> None:
    args = parse_args()
    checkpoint = Path(args.checkpoint)
    output_dir = Path(args.output_dir)
    tag = args.tag or f"official_span_x{args.scale}"
    export_dir = output_dir / tag
    weight_dir = export_dir / "weights"
    weight_dir.mkdir(parents=True, exist_ok=True)

    SPAN = import_span(Path(args.span_root))
    state, state_key = load_state(checkpoint)

    model = SPAN(3, 3, feature_channels=args.channels, upscale=args.scale)
    missing, unexpected = model.load_state_dict(state, strict=False)
    model.eval()
    with torch.no_grad():
        _ = model(torch.zeros(1, 3, 16, 16))

    deploy_state = model.state_dict()
    manifest = []
    for name, tensor in deploy_state.items():
        if not is_deploy_tensor(name):
            continue
        q, q_scale = quantize_tensor(tensor)
        safe_name = name.replace(".", "_")
        mem_path = weight_dir / f"{safe_name}.mem"
        write_mem(mem_path, q)
        manifest.append(
            {
                "name": name,
                "file": str(mem_path.relative_to(export_dir)).replace("\\", "/"),
                "shape": list(tensor.shape),
                "numel": int(tensor.numel()),
                "quant_scale": q_scale,
                "dtype": "int8_hex_mem",
            }
        )

    info = {
        "source": args.source_label,
        "source_checkpoint": str(checkpoint.resolve()),
        "checkpoint_state_key": state_key,
        "training_dataset": args.dataset_name,
        "training_dataset_root": str(Path(args.dataset_root).resolve()) if args.dataset_root else None,
        "scale": args.scale,
        "channels": args.channels,
        "num_blocks": 6,
        "best_psnr": args.best_psnr,
        "rgb_mean": [0.4488, 0.4371, 0.4040],
        "img_range": 255.0,
        "deploy_note": "Conv3XC branches were fused through SPAN eval forward before export.",
        "missing_keys": missing,
        "unexpected_keys": unexpected,
        "weights": manifest,
    }
    (export_dir / "official_span_manifest.json").write_text(
        json.dumps(info, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    layer_lines = [
        "`ifndef OFFICIAL_SPAN_LAYERS_VH",
        "`define OFFICIAL_SPAN_LAYERS_VH",
        "// Auto-generated layer table for the official SPAN RTL datapath.",
        f"`define OFFICIAL_SPAN_LAYER_COUNT {len(manifest)}",
    ]
    for idx, item in enumerate(manifest):
        macro_name = item["name"].replace(".", "_").replace("/", "_").upper()
        mem_abs = (export_dir / item["file"]).resolve().as_posix()
        layer_lines.append(f"`define OFFICIAL_SPAN_LAYER_{idx}_NAME \"{item['name']}\"")
        layer_lines.append(f"`define OFFICIAL_SPAN_LAYER_{idx}_FILE \"{mem_abs}\"")
        layer_lines.append(f"`define OFFICIAL_SPAN_LAYER_{idx}_NUMEL {item['numel']}")
        layer_lines.append(f"`define OFFICIAL_SPAN_LAYER_{idx}_{macro_name} {idx}")
    layer_lines.extend(["`endif", ""])
    (output_dir / "official_span_layers.vh").write_text("\n".join(layer_lines), encoding="utf-8")

    vh = "\n".join(
        [
            "`ifndef OFFICIAL_SPAN_MODEL_CONFIG_VH",
            "`define OFFICIAL_SPAN_MODEL_CONFIG_VH",
            "// Auto-generated by train/export_official_span_to_rtl.py.",
            "`define OFFICIAL_SPAN_TRAINED_WEIGHTS 1",
            f"`define OFFICIAL_SPAN_MODEL_SCALE {args.scale}",
            f"`define OFFICIAL_SPAN_FEATURE_CHANNELS {args.channels}",
            "`define OFFICIAL_SPAN_MODEL_BLOCKS 6",
            f"`define OFFICIAL_SPAN_WEIGHT_COUNT {len(manifest)}",
            "`endif",
            "",
        ]
    )
    (output_dir / "official_span_model_config.vh").write_text(vh, encoding="utf-8")

    tinyspan_compat_vh = "\n".join(
        [
            "`ifndef TINYSPAN_MODEL_CONFIG_VH",
            "`define TINYSPAN_MODEL_CONFIG_VH",
            "// Auto-generated compatibility header from official SPAN export.",
            "`define TINYSPAN_TRAINED_WEIGHTS 1",
            "`define TINYSPAN_SOURCE_OFFICIAL_SPAN 1",
            f"`define TINYSPAN_MODEL_SCALE {args.scale}",
            f"`define TINYSPAN_MODEL_CHANNELS {args.channels}",
            "`define TINYSPAN_MODEL_BLOCKS 6",
            f"`define TINYSPAN_WEIGHT_COUNT {len(manifest)}",
            "`endif",
            "",
        ]
    )
    (output_dir / "tinyspan_model_config.vh").write_text(tinyspan_compat_vh, encoding="utf-8")

    print(f"Exported {len(manifest)} official SPAN tensors to {export_dir}")


if __name__ == "__main__":
    main()
