"""Diagnose the gap between PyTorch SPAN and the current fixed-point RTL reference."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageChops, ImageDraw, ImageStat

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def import_span():
    span_root = repo_root() / "external" / "SPAN"
    sys.path.insert(0, str(span_root))
    from basicsr.archs.span_arch import SPAN

    return SPAN


def import_fixed_ref():
    sys.path.insert(0, str(repo_root() / "tools"))
    from span_official_fixed_ref import SpanFixedRef, get_input, load_weights

    return SpanFixedRef, get_input, load_weights


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


def image_to_tensor(path: Path, width: int, height: int, device: torch.device) -> torch.Tensor:
    img = Image.open(path).convert("RGB").resize((width, height), Image.Resampling.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0).to(device)


def tensor_to_image(tensor: torch.Tensor) -> Image.Image:
    arr = tensor.detach().float().clamp(0, 1).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return Image.fromarray(np.rint(arr * 255.0).astype(np.uint8), "RGB")


def feature_to_numpy(feature) -> np.ndarray:
    if isinstance(feature, torch.Tensor):
        arr = feature.detach().float().cpu().numpy()
        if arr.ndim == 4:
            arr = np.transpose(arr[0], (1, 2, 0))
        return arr
    return np.asarray(feature, dtype=np.float32)


def stats(arr: np.ndarray) -> dict:
    arr = np.asarray(arr)
    flat = arr.reshape(-1)
    if flat.size == 0:
        return {"numel": 0}
    return {
        "numel": int(flat.size),
        "min": float(flat.min()),
        "max": float(flat.max()),
        "mean": float(flat.mean()),
        "std": float(flat.std()),
        "p01": float(np.percentile(flat, 1)),
        "p50": float(np.percentile(flat, 50)),
        "p99": float(np.percentile(flat, 99)),
    }


def fixed_stats(arr: np.ndarray) -> dict:
    out = stats(arr)
    flat = np.asarray(arr).reshape(-1)
    out["sat_neg128_frac"] = float(np.mean(flat <= -128)) if flat.size else 0.0
    out["sat_pos127_frac"] = float(np.mean(flat >= 127)) if flat.size else 0.0
    out["zero_frac"] = float(np.mean(flat == 0)) if flat.size else 0.0
    return out


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


def make_preview(path: Path, inp: Image.Image, torch_img: Image.Image, fixed_img: Image.Image, tile: int) -> dict:
    diff = ImageChops.difference(torch_img, fixed_img)
    amplified = diff.point(lambda value: min(255, value * 8))
    metrics = compare_images(torch_img, fixed_img)
    panels = [
        (f"Input {inp.width}x{inp.height}", fit_tile(inp, tile)),
        (f"PyTorch {torch_img.width}x{torch_img.height}", fit_tile(torch_img, tile)),
        (f"Fixed Ref {fixed_img.width}x{fixed_img.height}", fit_tile(fixed_img, tile)),
        ("Diff x8", fit_tile(amplified, tile)),
    ]
    label_h = 28
    title_h = 42
    summary_h = 30
    gap = 12
    canvas = Image.new("RGB", (len(panels) * tile + (len(panels) + 1) * gap, title_h + label_h + tile + summary_h + 2 * gap), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), "REDS-trained SPAN PyTorch vs current fixed reference", fill=(20, 24, 31))
    summary = f"mismatch {metrics['mismatch_bytes']}/{metrics['total_bytes']}, MAE {metrics['mae']:.3f}, PSNR {metrics['psnr_db']:.3f} dB"
    draw.text((gap, canvas.height - summary_h + 5), summary, fill=(64, 72, 84))
    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += tile + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)
    return metrics


def run_torch_stages(model: torch.nn.Module, x: torch.Tensor) -> dict[str, np.ndarray]:
    with torch.inference_mode():
        model.mean = model.mean.type_as(x)
        centered = (x - model.mean) * model.img_range
        feat0 = model.conv_1(centered)
        b1, _, _ = model.block_1(feat0)
        b2, _, _ = model.block_2(b1)
        b3, _, _ = model.block_3(b2)
        b4, _, _ = model.block_4(b3)
        b5, _, _ = model.block_5(b4)
        b6, b5_2, _ = model.block_6(b5)
        b6conv = model.conv_2(b6)
        fused = model.conv_cat(torch.cat([feat0, b6conv, b1, b5_2], 1))
        up_conv = model.upsampler[0](fused)
        output = model.upsampler[1](up_conv)
    return {
        "centered_input": feature_to_numpy(centered),
        "feat0": feature_to_numpy(feat0),
        "b1": feature_to_numpy(b1),
        "b5_2": feature_to_numpy(b5_2),
        "b6conv": feature_to_numpy(b6conv),
        "fused": feature_to_numpy(fused),
        "up_conv": feature_to_numpy(up_conv),
        "output": feature_to_numpy(output),
    }


def run_fixed_stages(args: argparse.Namespace, manifest: dict) -> tuple[dict[str, np.ndarray], Image.Image]:
    SpanFixedRef, get_input, load_weights = import_fixed_ref()
    fixed_args = argparse.Namespace(
        manifest=str(args.manifest),
        width=args.width,
        height=args.height,
        pixel="406080",
        input_png=str(args.input),
        out_rgb=str(args.out_dir / "fixed.rgb"),
        out_png=str(args.out_dir / "fixed.png"),
        debug_txt=None,
        scale_shift=args.scale_shift,
    )
    weights, _ = load_weights(args.manifest)
    img = get_input(fixed_args)
    ref = SpanFixedRef(weights, args.width, args.height, int(manifest["scale"]), int(manifest["channels"]), args.scale_shift)
    out = ref.forward(img)
    data = bytes(v for row in out for pix in row for v in pix)
    out_img = Image.frombytes("RGB", (args.width * int(manifest["scale"]), args.height * int(manifest["scale"])), data)
    return {
        "feat0": feature_to_numpy(ref.last_feat0),
        "b1": feature_to_numpy(ref.last_b1),
        "b5_2": feature_to_numpy(ref.last_b5_2),
        "b6conv": feature_to_numpy(ref.last_b6conv),
        "fused": feature_to_numpy(ref.last_fused),
        "up_conv": feature_to_numpy(ref.last_up),
        "output": np.asarray(out_img, dtype=np.float32),
    }, out_img


def write_markdown(path: Path, summary: dict) -> None:
    lines = [
        "# SPAN Quantization Gap Diagnostic",
        "",
        f"Input: `{summary['input']}`",
        f"Manifest: `{summary['manifest']}`",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Scale/input: `X{summary['scale']} {summary['width']}x{summary['height']}`",
        f"Preview: `{summary['preview']}`",
        "",
        "## Output Gap",
        "",
        f"- mismatch bytes: `{summary['output_gap']['mismatch_bytes']} / {summary['output_gap']['total_bytes']}`",
        f"- MAE: `{summary['output_gap']['mae']:.6f}`",
        f"- MSE: `{summary['output_gap']['mse']:.6f}`",
        f"- PSNR: `{summary['output_gap']['psnr_db']:.6f} dB`",
        f"- max channel diff: `{summary['output_gap']['max_channel_diff']}`",
        "",
        "## Layer Ranges",
        "",
        "| Stage | PyTorch min..max | PyTorch p01..p99 | Fixed min..max | Fixed sat -128 | Fixed sat 127 | Fixed zero |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in summary["layers"]:
        pt = row["pytorch"]
        fx = row["fixed"]
        lines.append(
            f"| {row['stage']} | `{pt['min']:.3f}..{pt['max']:.3f}` | `{pt['p01']:.3f}..{pt['p99']:.3f}` | "
            f"`{fx['min']:.3f}..{fx['max']:.3f}` | `{fx['sat_neg128_frac']:.4f}` | `{fx['sat_pos127_frac']:.4f}` | `{fx['zero_frac']:.4f}` |"
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "The current fixed/RTL path stores only int8 weights and repeatedly applies a fixed right shift. It does not yet preserve the PyTorch input normalization, per-layer weight scales, activation scales, or floating-point SiLU/sigmoid behavior. Hardware byte-match against this reference proves transfer/RTL consistency, but not software-model fidelity.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze PyTorch SPAN vs current fixed-point reference.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--scale-shift", type=int, default=8)
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
    tensor = image_to_tensor(args.input, args.width, args.height, device)
    torch_stages = run_torch_stages(model, tensor)
    torch_img = tensor_to_image(torch.from_numpy(np.transpose(torch_stages["output"], (2, 0, 1))).unsqueeze(0))
    torch_img.save(args.out_dir / "pytorch_span.png")

    fixed_stages, fixed_img = run_fixed_stages(args, manifest)
    fixed_img.save(args.out_dir / "fixed_ref.png")
    inp = Image.open(args.input).convert("RGB").resize((args.width, args.height), Image.Resampling.BICUBIC)
    preview_path = args.out_dir / "pytorch_vs_fixed_preview.png"
    output_gap = make_preview(preview_path, inp, torch_img, fixed_img, args.tile)

    layers = []
    layers.append(
        {
            "stage": "centered_input",
            "pytorch": stats(torch_stages["centered_input"]),
            "fixed": fixed_stats(np.asarray(inp, dtype=np.float32)),
        }
    )
    for stage in ("feat0", "b1", "b5_2", "b6conv", "fused", "up_conv", "output"):
        layers.append(
            {
                "stage": stage,
                "pytorch": stats(torch_stages[stage]),
                "fixed": fixed_stats(fixed_stages[stage]),
            }
        )
    summary = {
        "input": str(args.input),
        "manifest": str(args.manifest),
        "checkpoint": str(checkpoint),
        "scale": int(manifest["scale"]),
        "width": args.width,
        "height": args.height,
        "scale_shift": args.scale_shift,
        "preview": str(preview_path),
        "output_gap": output_gap,
        "layers": layers,
    }
    (args.out_dir / "quant_gap_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_markdown(args.out_dir / "quant_gap_summary.md", summary)
    print(json.dumps({"summary": str(args.out_dir / "quant_gap_summary.md"), "preview": str(preview_path), "output_gap": output_gap}, indent=2))


if __name__ == "__main__":
    main()
