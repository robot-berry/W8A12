"""Export a hardware-oriented W8A12 quantization plan for REDS-trained SPAN."""

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


def qparams_per_out_channel(weight: torch.Tensor, bits: int = 8) -> tuple[torch.Tensor, torch.Tensor]:
    qmax = 2 ** (bits - 1) - 1
    reduce_dims = tuple(dim for dim in range(weight.ndim) if dim != 0)
    scale = torch.clamp(weight.detach().float().abs().amax(dim=reduce_dims), min=1e-12) / float(qmax)
    q = torch.clamp(torch.round(weight.detach().float() / scale.view(-1, *([1] * (weight.ndim - 1)))), -128, 127).to(torch.int8)
    return scale.cpu(), q.cpu()


def eval_conv(module: torch.nn.Module) -> torch.nn.Conv2d:
    if hasattr(module, "update_params"):
        module.update_params()
    return module.eval_conv if hasattr(module, "eval_conv") else module


def conv_specs(model: torch.nn.Module) -> list[tuple[str, torch.nn.Conv2d, str, str]]:
    specs: list[tuple[str, torch.nn.Conv2d, str, str]] = []
    specs.append(("conv_1", eval_conv(model.conv_1), "conv_1.input", "conv_1.output"))
    for idx in range(1, 7):
        block = getattr(model, f"block_{idx}")
        specs.append((f"block_{idx}.c1_r", eval_conv(block.c1_r), f"block_{idx}.c1_r.input", f"block_{idx}.c1_r.output"))
        specs.append((f"block_{idx}.c2_r", eval_conv(block.c2_r), f"block_{idx}.c2_r.input", f"block_{idx}.c2_r.output"))
        specs.append((f"block_{idx}.c3_r", eval_conv(block.c3_r), f"block_{idx}.c3_r.input", f"block_{idx}.c3_r.output"))
    specs.append(("conv_2", eval_conv(model.conv_2), "conv_2.input", "conv_2.output"))
    specs.append(("conv_cat", model.conv_cat, "conv_cat.input", "conv_cat.output"))
    specs.append(("upsampler.0", model.upsampler[0], "upsampler.0.input", "upsampler.0.output"))
    return specs


def postprocess_specs() -> list[dict]:
    specs: list[dict] = []
    for idx in range(1, 7):
        specs.append(
            {
                "name": f"block_{idx}.act1",
                "kind": "silu",
                "input_scale_ref": f"block_{idx}.c1_r.output",
                "output_scale_ref": f"block_{idx}.act1",
            }
        )
        specs.append(
            {
                "name": f"block_{idx}.act2",
                "kind": "silu",
                "input_scale_ref": f"block_{idx}.c2_r.output",
                "output_scale_ref": f"block_{idx}.act2",
            }
        )
        specs.append(
            {
                "name": f"block_{idx}.attention",
                "kind": "span_attention",
                "out3_scale_ref": f"block_{idx}.c3_r.output",
                "residual_scale_ref": "conv_1.output" if idx == 1 else f"block_{idx - 1}.out",
                "sim_att_scale_ref": f"block_{idx}.sim_att",
                "output_scale_ref": f"block_{idx}.out",
            }
        )
    return specs


def ratio_to_q31(value: float) -> dict:
    shift = 31
    multiplier = int(round(value * (1 << shift)))
    return {
        "real_multiplier": value,
        "multiplier_q31": multiplier,
        "shift": shift,
    }


def tensor_stats(q: torch.Tensor) -> dict:
    qf = q.float()
    return {
        "q_min": int(qf.min().item()),
        "q_max": int(qf.max().item()),
        "zero_frac": float((qf == 0).float().mean().item()),
        "sat_neg_frac": float((qf <= -128).float().mean().item()),
        "sat_pos_frac": float((qf >= 127).float().mean().item()),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export W8A12 SPAN quantization constants.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--activation-scales", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--activation-bits", type=int, default=12)
    parser.add_argument("--weight-bits", type=int, default=8)
    parser.add_argument("--device", default="cpu", choices=("cpu", "cuda", "auto"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    manifest = ptq.load_manifest(args.manifest)
    calibration = json.loads(args.activation_scales.read_text(encoding="utf-8"))
    activation_scales = calibration["activation_scales"]
    checkpoint = args.checkpoint or Path(manifest["source_checkpoint"])
    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    model = ptq.load_model(manifest, checkpoint, device)
    qmax_act = 2 ** (args.activation_bits - 1) - 1
    layers = []
    for name, conv, in_scale_ref, out_scale_ref in conv_specs(model):
        weight = conv.weight.detach().cpu()
        bias = conv.bias.detach().cpu() if conv.bias is not None else torch.zeros(weight.shape[0])
        weight_scale, q_weight = qparams_per_out_channel(weight, args.weight_bits)
        input_scale = float(activation_scales[in_scale_ref])
        output_scale = float(activation_scales[out_scale_ref])
        bias_q = torch.round((bias / output_scale) * float(1 << 31)).to(torch.int64)
        multipliers = [ratio_to_q31(float(input_scale * float(ws) / output_scale)) for ws in weight_scale]
        layer_dir = args.out_dir / "weights"
        layer_dir.mkdir(exist_ok=True)
        safe = name.replace(".", "_")
        q_weight.reshape(-1).numpy().tofile(layer_dir / f"{safe}_w_i8.bin")
        bias_q.numpy().astype("<i8").tofile(layer_dir / f"{safe}_bias_i64.bin")
        layers.append(
            {
                "name": name,
                "input_scale_ref": in_scale_ref,
                "output_scale_ref": out_scale_ref,
                "input_scale": input_scale,
                "output_scale": output_scale,
                "weight_bits": args.weight_bits,
                "activation_bits": args.activation_bits,
                "activation_qmax": qmax_act,
                "weight_shape": list(weight.shape),
                "bias_shape": list(bias.shape),
                "weight_scale": [float(v) for v in weight_scale.tolist()],
                "bias_encoding": "output_scale_q31_offset",
                "bias_q_i64_min": int(bias_q.min().item()),
                "bias_q_i64_max": int(bias_q.max().item()),
                "requant": multipliers,
                "weight_file_i8_bin": f"weights/{safe}_w_i8.bin",
                "bias_file_i64_bin": f"weights/{safe}_bias_i64.bin",
                "quantized_weight_stats": tensor_stats(q_weight),
            }
        )

    quant_plan = {
        "source": "REDS-trained SPAN W8A12 hardware quantization plan",
        "manifest": str(args.manifest),
        "checkpoint": str(checkpoint),
        "activation_scales_file": str(args.activation_scales),
        "scale": int(manifest["scale"]),
        "channels": int(manifest["channels"]),
        "weight_bits": args.weight_bits,
        "activation_bits": args.activation_bits,
        "activation_qmin": -(2 ** (args.activation_bits - 1)),
        "activation_qmax": qmax_act,
        "layer_count": len(layers),
        "activation_scale_count": len(activation_scales),
        "activation_scale_table": activation_scales,
        "layers": layers,
        "postprocess": postprocess_specs(),
        "notes": [
            "Conv requantization target: q_out = round(acc_i32 * real_multiplier + bias_fp32 / output_scale), where real_multiplier = input_scale * weight_scale[channel] / output_scale.",
            "Bias is stored per output channel as a signed Q31 offset: round((bias_fp32 / output_scale) * 2^31).",
            "Activation functions must use calibrated input/output scales, not raw int code domains.",
            "SPAN SPAB returns activated c1 output to conv_cat because upstream SiLU is inplace.",
        ],
    }
    out_json = args.out_dir / "span_w8a12_quant_plan.json"
    out_json.write_text(json.dumps(quant_plan, indent=2), encoding="utf-8")

    lines = [
        "# SPAN W8A12 Quantization Plan",
        "",
        f"Checkpoint: `{checkpoint}`",
        f"Activation scales: `{args.activation_scales}`",
        f"Layers: `{len(layers)}`",
        f"Activation tensors: `{len(activation_scales)}`",
        "",
        "## Conv Layers",
        "",
        "| Layer | Input scale | Output scale | Weight scale min..max | Bias q min..max |",
        "| --- | --- | --- | --- | --- |",
    ]
    for layer in layers:
        ws = layer["weight_scale"]
        lines.append(
            f"| {layer['name']} | `{layer['input_scale']:.8g}` | `{layer['output_scale']:.8g}` | "
            f"`{min(ws):.8g}..{max(ws):.8g}` | `{layer['bias_q_i64_min']}..{layer['bias_q_i64_max']}` |"
        )
    lines.extend(
        [
            "",
            "## RTL Implications",
            "",
            "- Use signed 12-bit activation storage/datapath for intermediate feature maps.",
            "- Use int8 weights with per-output-channel weight scales.",
            "- Use per-output-channel bias integers and requant multipliers.",
            "- Replace the current global `SCALE_SHIFT=8` path with layer-specific requantization.",
            "- Implement SiLU/sigmoid/attention using calibrated input/output scales.",
            "",
        ]
    )
    (args.out_dir / "span_w8a12_quant_plan.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"out": str(out_json), "layers": len(layers), "activation_scales": len(activation_scales)}, indent=2))


if __name__ == "__main__":
    main()
