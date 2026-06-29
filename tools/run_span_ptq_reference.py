"""Run a fake-int8 PTQ reference for the REDS-trained SPAN checkpoint.

This tool is not a board reference. It answers a narrower question:
if we preserve the PyTorch SPAN graph and input normalization, then add int8
weight/activation quant-dequant with explicit scales, how close can the result
stay to the floating-point software output?
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, ImageChops, ImageDraw, ImageStat

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def import_span():
    span_root = repo_root() / "external" / "SPAN"
    sys.path.insert(0, str(span_root))
    from basicsr.archs.span_arch import SPAN

    return SPAN


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_model(manifest: dict, checkpoint: Path, device: torch.device) -> torch.nn.Module:
    SPAN = import_span()
    model = SPAN(
        3,
        3,
        feature_channels=int(manifest.get("channels", 48)),
        upscale=int(manifest["scale"]),
        img_range=float(manifest.get("img_range", 255.0)),
        rgb_mean=tuple(manifest.get("rgb_mean", (0.4488, 0.4371, 0.4040))),
    )
    state = torch.load(checkpoint, map_location="cpu")
    key = manifest.get("checkpoint_state_key", "params_ema")
    if isinstance(state, dict) and key in state:
        state = state[key]
    elif isinstance(state, dict) and "params" in state:
        state = state["params"]
    model.load_state_dict(state, strict=True)
    model.eval().to(device)
    return model


def image_to_tensor(path: Path, width: int, height: int, device: torch.device) -> tuple[torch.Tensor, Image.Image]:
    img = Image.open(path).convert("RGB").resize((width, height), Image.Resampling.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    tensor = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0).to(device)
    return tensor, img


def tensor_to_image(tensor: torch.Tensor) -> Image.Image:
    arr = tensor.detach().float().clamp(0, 1).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return Image.fromarray(np.rint(arr * 255.0).astype(np.uint8), "RGB")


def qparams_symmetric(tensor: torch.Tensor, bits: int = 8, per_channel: bool = False) -> tuple[torch.Tensor, int, int]:
    qmin = -(2 ** (bits - 1))
    qmax = 2 ** (bits - 1) - 1
    t = tensor.detach().float()
    if per_channel:
        reduce_dims = tuple(dim for dim in range(t.ndim) if dim != 0)
        max_abs = t.abs().amax(dim=reduce_dims, keepdim=True)
    else:
        max_abs = t.abs().max()
    scale = torch.clamp(max_abs / float(qmax), min=1e-12)
    return scale, qmin, qmax


def fake_quant_symmetric(
    tensor: torch.Tensor,
    name: str,
    scales: dict,
    *,
    bits: int = 8,
    per_channel: bool = False,
    enabled: bool = True,
) -> torch.Tensor:
    if not enabled:
        scales[name] = {"enabled": False}
        return tensor
    overrides = scales.get("__overrides__", {})
    override = overrides.get(name)
    qmin = -(2 ** (bits - 1))
    qmax = 2 ** (bits - 1) - 1
    if override is not None:
        scale = torch.as_tensor(override, dtype=tensor.dtype, device=tensor.device)
        while scale.ndim < tensor.ndim:
            scale = scale.view(*scale.shape, *([1] * (tensor.ndim - scale.ndim)))
    else:
        scale, qmin, qmax = qparams_symmetric(tensor, bits=bits, per_channel=per_channel)
    q = torch.clamp(torch.round(tensor / scale), qmin, qmax)
    dq = q * scale
    q_float = q.detach().float()
    scales[name] = {
        "enabled": True,
        "override": override is not None,
        "bits": bits,
        "per_channel": per_channel,
        "scale_min": float(scale.min().detach().cpu()),
        "scale_max": float(scale.max().detach().cpu()),
        "q_min": float(q_float.min().cpu()),
        "q_max": float(q_float.max().cpu()),
        "zero_frac": float((q_float == 0).float().mean().cpu()),
        "sat_neg_frac": float((q_float <= qmin).float().mean().cpu()),
        "sat_pos_frac": float((q_float >= qmax).float().mean().cpu()),
    }
    return dq


def qconv2d(
    x: torch.Tensor,
    weight: torch.Tensor,
    bias: torch.Tensor | None,
    name: str,
    scales: dict,
    *,
    quant_weights: bool,
    quant_activations: bool,
    per_channel_weights: bool,
    activation_bits: int,
    padding: int,
) -> torch.Tensor:
    xq = fake_quant_symmetric(x, f"{name}.input", scales, bits=activation_bits, enabled=quant_activations)
    wq = fake_quant_symmetric(weight, f"{name}.weight", scales, per_channel=per_channel_weights, enabled=quant_weights)
    y = F.conv2d(xq, wq, bias, padding=padding)
    return fake_quant_symmetric(y, f"{name}.output", scales, bits=activation_bits, enabled=quant_activations)


def eval_conv(module: torch.nn.Module) -> tuple[torch.Tensor, torch.Tensor | None]:
    if hasattr(module, "update_params"):
        module.update_params()
    conv = module.eval_conv if hasattr(module, "eval_conv") else module
    return conv.weight, conv.bias


def spab_ptq(
    x: torch.Tensor,
    block: torch.nn.Module,
    prefix: str,
    scales: dict,
    *,
    quant_weights: bool,
    quant_activations: bool,
    per_channel_weights: bool,
    activation_bits: int,
) -> tuple[torch.Tensor, torch.Tensor]:
    w, b = eval_conv(block.c1_r)
    out1 = qconv2d(x, w, b, f"{prefix}.c1_r", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=1)
    out1_act = F.silu(out1)
    out1_act = fake_quant_symmetric(out1_act, f"{prefix}.act1", scales, bits=activation_bits, enabled=quant_activations)

    w, b = eval_conv(block.c2_r)
    out2 = qconv2d(out1_act, w, b, f"{prefix}.c2_r", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=1)
    out2_act = F.silu(out2)
    out2_act = fake_quant_symmetric(out2_act, f"{prefix}.act2", scales, bits=activation_bits, enabled=quant_activations)

    w, b = eval_conv(block.c3_r)
    out3 = qconv2d(out2_act, w, b, f"{prefix}.c3_r", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=1)
    sim_att = torch.sigmoid(out3) - 0.5
    sim_att = fake_quant_symmetric(sim_att, f"{prefix}.sim_att", scales, bits=activation_bits, enabled=quant_activations)
    out = (out3 + x) * sim_att
    out = fake_quant_symmetric(out, f"{prefix}.out", scales, bits=activation_bits, enabled=quant_activations)
    # SPAN uses SiLU(inplace=True), so the returned out1 in the upstream
    # module is the activated tensor. Mirror that behavior explicitly here.
    return out, out1_act


def run_fp32(model: torch.nn.Module, x: torch.Tensor) -> torch.Tensor:
    with torch.inference_mode():
        return model(x)


def run_ptq(
    model: torch.nn.Module,
    x: torch.Tensor,
    *,
    quant_weights: bool,
    quant_activations: bool,
    per_channel_weights: bool,
    activation_bits: int = 8,
    activation_scales: dict | None = None,
) -> tuple[torch.Tensor, dict]:
    scales: dict = {"__overrides__": activation_scales or {}}
    with torch.inference_mode():
        model.mean = model.mean.type_as(x)
        centered = (x - model.mean) * model.img_range
        centered = fake_quant_symmetric(centered, "centered_input", scales, bits=activation_bits, enabled=quant_activations)

        w, b = eval_conv(model.conv_1)
        feat0 = qconv2d(centered, w, b, "conv_1", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=1)

        b1, _ = spab_ptq(feat0, model.block_1, "block_1", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits)
        b2, _ = spab_ptq(b1, model.block_2, "block_2", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits)
        b3, _ = spab_ptq(b2, model.block_3, "block_3", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits)
        b4, _ = spab_ptq(b3, model.block_4, "block_4", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits)
        b5, _ = spab_ptq(b4, model.block_5, "block_5", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits)
        b6, b5_2 = spab_ptq(b5, model.block_6, "block_6", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits)

        w, b = eval_conv(model.conv_2)
        b6conv = qconv2d(b6, w, b, "conv_2", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=1)

        cat = torch.cat([feat0, b6conv, b1, b5_2], 1)
        cat = fake_quant_symmetric(cat, "conv_cat.input", scales, bits=activation_bits, enabled=quant_activations)
        out = qconv2d(cat, model.conv_cat.weight, model.conv_cat.bias, "conv_cat", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=0)

        up_conv = model.upsampler[0]
        up = qconv2d(out, up_conv.weight, up_conv.bias, "upsampler.0", scales, quant_weights=quant_weights, quant_activations=quant_activations, per_channel_weights=per_channel_weights, activation_bits=activation_bits, padding=1)
        sr = model.upsampler[1](up)
        sr = fake_quant_symmetric(sr, "pixelshuffle.output", scales, bits=activation_bits, enabled=quant_activations)
    return sr, scales


def compare_images(ref: Image.Image, actual: Image.Image) -> dict:
    if ref.size != actual.size:
        actual = actual.resize(ref.size, Image.Resampling.BICUBIC)
    diff = ImageChops.difference(ref, actual)
    stat = ImageStat.Stat(diff)
    extrema = [value for channel in stat.extrema for value in channel]
    data = np.frombuffer(diff.tobytes(), dtype=np.uint8)
    mse = float(np.mean(data.astype(np.float32) ** 2))
    return {
        "mismatch_bytes": int(np.count_nonzero(data)),
        "total_bytes": int(data.size),
        "max_channel_diff": int(max(extrema)),
        "mae": float(np.mean(data)),
        "mse": mse,
        "psnr_db": float("inf") if mse == 0 else float(20.0 * np.log10(255.0 / np.sqrt(mse))),
    }


def fit_tile(img: Image.Image, tile: int) -> Image.Image:
    fitted = img.copy()
    fitted.thumbnail((tile, tile), Image.Resampling.BICUBIC)
    canvas = Image.new("RGB", (tile, tile), (18, 22, 28))
    canvas.paste(fitted, ((tile - fitted.width) // 2, (tile - fitted.height) // 2))
    return canvas


def make_preview(path: Path, inp: Image.Image, fp32: Image.Image, ptq: Image.Image, metrics: dict, tile: int) -> None:
    diff = ImageChops.difference(fp32, ptq).point(lambda value: min(255, value * 8))
    panels = [
        (f"Input {inp.width}x{inp.height}", fit_tile(inp, tile)),
        (f"PyTorch {fp32.width}x{fp32.height}", fit_tile(fp32, tile)),
        (f"PTQ Ref {ptq.width}x{ptq.height}", fit_tile(ptq, tile)),
        ("Diff x8", fit_tile(diff, tile)),
    ]
    label_h = 28
    title_h = 42
    summary_h = 30
    gap = 12
    canvas = Image.new("RGB", (len(panels) * tile + (len(panels) + 1) * gap, title_h + label_h + tile + summary_h + 2 * gap), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), "REDS-trained SPAN PyTorch vs PTQ fake-int8 reference", fill=(20, 24, 31))
    summary = f"mismatch {metrics['mismatch_bytes']}/{metrics['total_bytes']}, MAE {metrics['mae']:.3f}, PSNR {metrics['psnr_db']:.3f} dB"
    draw.text((gap, canvas.height - summary_h + 5), summary, fill=(64, 72, 84))
    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += tile + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def write_markdown(path: Path, summary: dict) -> None:
    lines = [
        "# SPAN PTQ Reference",
        "",
        f"Input: `{summary['input']}`",
        f"Manifest: `{summary['manifest']}`",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Mode: `{summary['mode']}`",
        f"Per-channel weights: `{summary['per_channel_weights']}`",
        f"Activation bits: `{summary['activation_bits']}`",
        f"Preview: `{summary['preview']}`",
        "",
        "## Output Gap",
        "",
        f"- mismatch bytes: `{summary['metrics']['mismatch_bytes']} / {summary['metrics']['total_bytes']}`",
        f"- MAE: `{summary['metrics']['mae']:.6f}`",
        f"- MSE: `{summary['metrics']['mse']:.6f}`",
        f"- PSNR: `{summary['metrics']['psnr_db']:.6f} dB`",
        f"- max channel diff: `{summary['metrics']['max_channel_diff']}`",
        "",
        "## Scale Snapshot",
        "",
        "| Tensor | override | scale min | scale max | q min..max | zero frac | sat - | sat + |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for name in summary["scale_order"]:
        item = summary["scales"][name]
        if not item.get("enabled", False):
            continue
        lines.append(
            f"| {name} | `{item.get('override', False)}` | `{item['scale_min']:.8g}` | `{item['scale_max']:.8g}` | "
            f"`{item['q_min']:.0f}..{item['q_max']:.0f}` | `{item['zero_frac']:.4f}` | "
            f"`{item['sat_neg_frac']:.4f}` | `{item['sat_pos_frac']:.4f}` |"
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "This PTQ reference keeps the PyTorch input normalization and graph, then applies explicit quant-dequant. If this result is close to PyTorch, the remaining work is to export/calibrate these scales and implement matching RTL requantization. If it is not close, the model needs QAT or a smaller hardware-oriented student.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a SPAN fake-int8 PTQ reference.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--mode", choices=("float", "weight-only", "weight-activation"), default="weight-activation")
    parser.add_argument("--per-channel-weights", action="store_true")
    parser.add_argument("--activation-scales", type=Path, help="JSON produced by calibrate_span_activation_scales.py")
    parser.add_argument("--activation-bits", type=int, default=8)
    parser.add_argument("--tile", type=int, default=180)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    manifest = load_manifest(args.manifest)
    checkpoint = args.checkpoint or Path(manifest["source_checkpoint"])
    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    model = load_model(manifest, checkpoint, device)
    tensor, input_img = image_to_tensor(args.input, args.width, args.height, device)
    activation_scales = None
    if args.activation_scales:
        calibration = json.loads(args.activation_scales.read_text(encoding="utf-8"))
        activation_scales = calibration.get("activation_scales", calibration)
    fp32 = run_fp32(model, tensor)
    ptq, scales = run_ptq(
        model,
        tensor,
        quant_weights=args.mode != "float",
        quant_activations=args.mode == "weight-activation",
        per_channel_weights=args.per_channel_weights,
        activation_bits=args.activation_bits,
        activation_scales=activation_scales,
    )

    fp32_img = tensor_to_image(fp32)
    ptq_img = tensor_to_image(ptq)
    fp32_img.save(args.out_dir / "pytorch_span.png")
    ptq_img.save(args.out_dir / "ptq_span.png")
    metrics = compare_images(fp32_img, ptq_img)
    preview = args.out_dir / "ptq_preview.png"
    make_preview(preview, input_img, fp32_img, ptq_img, metrics, args.tile)

    summary = {
        "input": str(args.input),
        "manifest": str(args.manifest),
        "checkpoint": str(checkpoint),
        "scale": int(manifest["scale"]),
        "width": args.width,
        "height": args.height,
        "mode": args.mode,
        "per_channel_weights": bool(args.per_channel_weights),
        "activation_bits": args.activation_bits,
        "activation_scales": str(args.activation_scales) if args.activation_scales else None,
        "preview": str(preview),
        "metrics": metrics,
        "scale_order": [key for key in scales.keys() if key != "__overrides__"],
        "scales": {key: value for key, value in scales.items() if key != "__overrides__"},
    }
    (args.out_dir / "ptq_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_markdown(args.out_dir / "ptq_summary.md", summary)
    print(json.dumps({"summary": str(args.out_dir / "ptq_summary.md"), "preview": str(preview), "metrics": metrics}, indent=2))


if __name__ == "__main__":
    main()
