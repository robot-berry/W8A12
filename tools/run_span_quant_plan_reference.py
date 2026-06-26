"""Run a SPAN quantization-plan reference against the PyTorch checkpoint."""

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a SPAN hardware quantization-plan reference.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--tile", type=int, default=180)
    return parser.parse_args()


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def resolve_repo_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return (repo_root() / path).resolve()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    plan = json.loads(args.quant_plan.read_text(encoding="utf-8"))
    manifest_path = resolve_repo_path(plan["manifest"])
    checkpoint_path = resolve_repo_path(plan["checkpoint"])
    manifest = ptq.load_manifest(manifest_path)
    activation_scales = plan["activation_scale_table"]
    activation_bits = int(plan["activation_bits"])

    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    model = ptq.load_model(manifest, checkpoint_path, device)
    tensor, input_img = ptq.image_to_tensor(args.input, args.width, args.height, device)
    fp32 = ptq.run_fp32(model, tensor)
    quant, scales = ptq.run_ptq(
        model,
        tensor,
        quant_weights=True,
        quant_activations=True,
        per_channel_weights=True,
        activation_bits=activation_bits,
        activation_scales=activation_scales,
    )

    fp32_img = ptq.tensor_to_image(fp32)
    quant_img = ptq.tensor_to_image(quant)
    fp32_png = args.out_dir / "pytorch_span.png"
    quant_png = args.out_dir / "quant_plan_span.png"
    fp32_img.save(fp32_png)
    quant_img.save(quant_png)
    metrics = ptq.compare_images(fp32_img, quant_img)
    preview = args.out_dir / "quant_plan_preview.png"
    ptq.make_preview(preview, input_img, fp32_img, quant_img, metrics, args.tile)

    scale_order = [key for key in scales.keys() if key != "__overrides__"]
    layer_files = []
    for layer in plan["layers"]:
        layer_files.append(
            {
                "name": layer["name"],
                "weight_file_i8_bin": str((args.quant_plan.parent / layer["weight_file_i8_bin"]).resolve()),
                "bias_file_i64_bin": str((args.quant_plan.parent / layer["bias_file_i64_bin"]).resolve()),
            }
        )

    summary = {
        "input": str(args.input),
        "quant_plan": str(args.quant_plan),
        "manifest": str(manifest_path),
        "checkpoint": str(checkpoint_path),
        "device": str(device),
        "scale": int(plan["scale"]),
        "width": args.width,
        "height": args.height,
        "weight_bits": int(plan["weight_bits"]),
        "activation_bits": activation_bits,
        "layer_count": int(plan["layer_count"]),
        "activation_scale_count": int(plan["activation_scale_count"]),
        "pytorch_png": str(fp32_png),
        "quant_plan_png": str(quant_png),
        "preview": str(preview),
        "metrics": metrics,
        "scale_order": scale_order,
        "layer_files": layer_files,
    }
    summary_json = args.out_dir / "quant_plan_summary.json"
    summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        "# SPAN Quantization-Plan Reference",
        "",
        f"Input: `{summary['input']}`",
        f"Quant plan: `{summary['quant_plan']}`",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Weight bits: `{summary['weight_bits']}`",
        f"Activation bits: `{summary['activation_bits']}`",
        f"Conv layers: `{summary['layer_count']}`",
        f"Activation scales: `{summary['activation_scale_count']}`",
        f"Preview: `{summary['preview']}`",
        "",
        "## PyTorch vs Quant Plan",
        "",
        f"- mismatch bytes: `{metrics['mismatch_bytes']} / {metrics['total_bytes']}`",
        f"- MAE: `{metrics['mae']:.6f}`",
        f"- MSE: `{metrics['mse']:.6f}`",
        f"- PSNR: `{metrics['psnr_db']:.6f} dB`",
        f"- max channel diff: `{metrics['max_channel_diff']}`",
        "",
        "## RTL Handoff",
        "",
        "The preview output is the software target for the next fixed-reference/RTL rewrite. The layer files listed in the JSON summary are the int8 weight and int64 bias constants exported from the same quantization plan.",
        "",
    ]
    summary_md = args.out_dir / "quant_plan_summary.md"
    summary_md.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"summary": str(summary_md), "preview": str(preview), "metrics": metrics}, indent=2))


if __name__ == "__main__":
    main()
