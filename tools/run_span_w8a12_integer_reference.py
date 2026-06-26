"""Run a full REDS-trained SPAN W8A12 integer reference.

This tool keeps three reference points side by side:

1. PyTorch FP32 trained SPAN output.
2. PyTorch fake W8A12 output from the quantization-plan runner.
3. Plan-driven integer W8A12 output using the same helpers as the RTL
   full-image testbench generator.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import numpy as np
import torch
from PIL import Image, ImageChops, ImageDraw, ImageStat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_span_ptq_reference as ptq
from compare_span_w8a12_conv1_frame import make_reference
from generate_span_w8a12_full_image_frame_tb import read_input_pixels
from generate_span_w8a12_spab_frame_tb import apply_lut_frame, attention_frame, read_lut
from generate_span_w8a12_tail_frame_tb import concat_for_conv_cat, conv_frame_any, pixelshuffle_q


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def resolve_repo_path(value: str | Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return (repo_root() / path).resolve()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def flatten_feature_rows(rows: list[list[int]]) -> list[int]:
    return [int(value) for row in rows for value in row]


def integer_w8a12_q(
    *,
    quant_plan: dict,
    rtl_manifest: dict,
    rgb_norm: dict,
    postprocess_manifest: dict,
    input_png: Path,
    width: int,
    height: int,
) -> tuple[list[int], list[int], dict]:
    bits = int(rtl_manifest["activation_bits"])
    channels = int(rtl_manifest["channels"])
    scale = int(rtl_manifest["scale"])
    layers = {layer["name"]: layer for layer in rtl_manifest["layers"]}
    entries = {entry["name"]: entry for entry in postprocess_manifest["entries"]}
    scales = quant_plan["activation_scale_table"]

    input_pixels = read_input_pixels(None, input_png, width, height)
    assert input_pixels is not None

    feat0 = flatten_feature_rows(make_reference(rtl_manifest, rgb_norm, width, height, pixels=input_pixels))
    q = feat0
    saved_b1: list[int] | None = None
    saved_b6_act1: list[int] | None = None
    stage_metrics: dict[str, dict] = {"conv_1.output": q_stats(feat0)}

    for block in range(1, 7):
        c1 = conv_frame_any(q, layers[f"block_{block}.c1_r"], width, height, channels, bits)
        act1 = apply_lut_frame(c1, read_lut(Path(entries[f"block_{block}.act1"]["mem"]), bits), bits)
        c2 = conv_frame_any(act1, layers[f"block_{block}.c2_r"], width, height, channels, bits)
        act2 = apply_lut_frame(c2, read_lut(Path(entries[f"block_{block}.act2"]["mem"]), bits), bits)
        c3 = conv_frame_any(act2, layers[f"block_{block}.c3_r"], width, height, channels, bits)
        sim = apply_lut_frame(c3, read_lut(Path(entries[f"block_{block}.attention"]["mem"]), bits), bits)
        out = attention_frame(c3, q, sim, entries[f"block_{block}.attention"], bits)

        stage_metrics[f"block_{block}.out"] = q_stats(out)
        if block == 1:
            saved_b1 = out
        if block == 6:
            saved_b6_act1 = act1
        q = out

    if saved_b1 is None or saved_b6_act1 is None:
        raise AssertionError("Internal block-save failure")

    conv2 = conv_frame_any(q, layers["conv_2"], width, height, channels, bits)
    cat_mults = {
        "feat0": q31_ratio(scales["conv_1.output"], scales["conv_cat.input"]),
        "b6conv": q31_ratio(scales["conv_2.output"], scales["conv_cat.input"]),
        "b1": q31_ratio(scales["block_1.out"], scales["conv_cat.input"]),
        "b6_act1": q31_ratio(scales["block_6.act1"], scales["conv_cat.input"]),
    }
    cat = concat_for_conv_cat(
        feat0=feat0,
        b6conv=conv2,
        b1=saved_b1,
        b6_act1=saved_b6_act1,
        multipliers=cat_mults,
        bits=bits,
    )
    conv_cat = conv_frame_any(cat, layers["conv_cat"], width, height, channels * 4, bits)
    up = conv_frame_any(conv_cat, layers["upsampler.0"], width, height, channels, bits)
    sr_q = pixelshuffle_q(up, width, height=height, scale=scale, out_ch=3)

    stage_metrics.update(
        {
            "conv_2.output": q_stats(conv2),
            "conv_cat.input": q_stats(cat),
            "conv_cat.output": q_stats(conv_cat),
            "upsampler.0.output": q_stats(up),
            "pixelshuffle.output": q_stats(sr_q),
        }
    )
    return sr_q, [channel for pixel in input_pixels for channel in pixel], stage_metrics


def q31_ratio(src_scale: float, dst_scale: float) -> int:
    return int(round((float(src_scale) / float(dst_scale)) * (1 << 31)))


def q_stats(values: list[int]) -> dict:
    arr = np.asarray(values, dtype=np.int64)
    return {
        "q_min": int(arr.min()) if arr.size else 0,
        "q_max": int(arr.max()) if arr.size else 0,
        "zero_frac": float(np.mean(arr == 0)) if arr.size else 0.0,
    }


def q_to_image(values: list[int], width: int, height: int, scale: float) -> Image.Image:
    arr = np.asarray(values, dtype=np.float32).reshape(height, width, 3)
    arr = np.clip(arr * float(scale), 0.0, 1.0)
    return Image.fromarray(np.rint(arr * 255.0).astype(np.uint8), "RGB")


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


def diff_tile(ref: Image.Image, actual: Image.Image, gain: int) -> Image.Image:
    if ref.size != actual.size:
        actual = actual.resize(ref.size, Image.Resampling.BICUBIC)
    return ImageChops.difference(ref, actual).point(lambda value: min(255, value * gain))


def make_preview(
    *,
    out: Path,
    title: str,
    precision_label: str,
    input_img: Image.Image,
    pytorch_img: Image.Image,
    fake_img: Image.Image,
    integer_img: Image.Image,
    rtl_img: Image.Image | None,
    metrics: dict,
    tile: int,
    diff_gain: int,
) -> None:
    panels = [
        (f"Input {input_img.width}x{input_img.height}", input_img),
        (f"PyTorch {pytorch_img.width}x{pytorch_img.height}", pytorch_img),
        (f"Fake {precision_label} {fake_img.width}x{fake_img.height}", fake_img),
        (f"Integer {precision_label} {integer_img.width}x{integer_img.height}", integer_img),
    ]
    diff_target = integer_img
    diff_label = f"Integer-PyTorch Diff x{diff_gain}"
    if rtl_img is not None:
        panels.append((f"RTL/Board {rtl_img.width}x{rtl_img.height}", rtl_img))
        diff_target = rtl_img
        diff_label = f"RTL-PyTorch Diff x{diff_gain}"
    panels.append((diff_label, diff_tile(pytorch_img, diff_target, diff_gain)))

    label_h = 28
    title_h = 42
    summary_h = 34
    gap = 12
    width = len(panels) * tile + (len(panels) + 1) * gap
    height = title_h + label_h + tile + summary_h + 2 * gap
    canvas = Image.new("RGB", (width, height), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), title, fill=(20, 24, 31))
    key = "pytorch_vs_rtl" if rtl_img is not None else "pytorch_vs_integer"
    summary_metrics = metrics[key]
    summary = (
        f"{key}: mismatch {summary_metrics['mismatch_bytes']}/{summary_metrics['total_bytes']}, "
        f"PSNR {summary_metrics['psnr_db']:.3f} dB, max diff {summary_metrics['max_channel_diff']}"
    )
    draw.text((gap, height - summary_h + 7), summary, fill=(64, 72, 84))

    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(fit_tile(img, tile), (x, title_h + label_h))
        x += tile + gap

    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run REDS-trained SPAN W8A12 integer reference.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--rtl-manifest", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rtl_manifest.json"))
    parser.add_argument("--rgb-norm", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rgb_norm.json"))
    parser.add_argument("--postprocess-manifest", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json"))
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--rtl-png", type=Path)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--tile", type=int, default=180)
    parser.add_argument("--diff-gain", type=int, default=16)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    quant_plan = load_json(args.quant_plan)
    rtl_manifest = load_json(args.rtl_manifest)
    rgb_norm = load_json(args.rgb_norm)
    postprocess_manifest = load_json(args.postprocess_manifest)
    manifest_path = resolve_repo_path(quant_plan["manifest"])
    checkpoint_path = resolve_repo_path(quant_plan["checkpoint"])

    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    model = ptq.load_model(ptq.load_manifest(manifest_path), checkpoint_path, device)
    tensor, input_img = ptq.image_to_tensor(args.input, args.width, args.height, device)
    fp32 = ptq.run_fp32(model, tensor)
    fake, _ = ptq.run_ptq(
        model,
        tensor,
        quant_weights=True,
        quant_activations=True,
        per_channel_weights=True,
        activation_bits=int(quant_plan["activation_bits"]),
        activation_scales=quant_plan["activation_scale_table"],
    )
    pytorch_img = ptq.tensor_to_image(fp32)
    fake_img = ptq.tensor_to_image(fake)
    precision_label = f"W{int(quant_plan['weight_bits'])}A{int(quant_plan['activation_bits'])}"
    precision_slug = precision_label.lower()

    sr_q, input_raw_values, stage_metrics = integer_w8a12_q(
        quant_plan=quant_plan,
        rtl_manifest=rtl_manifest,
        rgb_norm=rgb_norm,
        postprocess_manifest=postprocess_manifest,
        input_png=args.input,
        width=args.width,
        height=args.height,
    )
    out_w = args.width * int(quant_plan["scale"])
    out_h = args.height * int(quant_plan["scale"])
    integer_img = q_to_image(sr_q, out_w, out_h, quant_plan["activation_scale_table"]["pixelshuffle.output"])
    rtl_img = Image.open(args.rtl_png).convert("RGB") if args.rtl_png else None

    input_raw = args.out_dir / "input.rgb"
    pytorch_png = args.out_dir / "pytorch_span.png"
    fake_png = args.out_dir / f"fake_{precision_slug}_span.png"
    integer_png = args.out_dir / f"integer_{precision_slug}_span.png"
    integer_qdump = args.out_dir / f"integer_{precision_slug}_qdump.txt"
    preview = args.out_dir / f"span_{precision_slug}_integer_reference_preview.png"
    input_raw.write_bytes(bytes(input_raw_values))
    pytorch_img.save(pytorch_png)
    fake_img.save(fake_png)
    integer_img.save(integer_png)
    write_qdump(integer_qdump, out_w, out_h, sr_q)

    metrics = {
        "pytorch_vs_fake": compare_images(pytorch_img, fake_img),
        "pytorch_vs_integer": compare_images(pytorch_img, integer_img),
        "fake_vs_integer": compare_images(fake_img, integer_img),
    }
    if rtl_img is not None:
        metrics["integer_vs_rtl"] = compare_images(integer_img, rtl_img)
        metrics["pytorch_vs_rtl"] = compare_images(pytorch_img, rtl_img)

    make_preview(
        out=preview,
        title=f"REDS-trained SPAN X4: PyTorch / fake {precision_label} / integer {precision_label}",
        precision_label=precision_label,
        input_img=input_img,
        pytorch_img=pytorch_img,
        fake_img=fake_img,
        integer_img=integer_img,
        rtl_img=rtl_img,
        metrics=metrics,
        tile=args.tile,
        diff_gain=args.diff_gain,
    )

    summary = {
        "input": str(args.input),
        "quant_plan": str(args.quant_plan),
        "rtl_manifest": str(args.rtl_manifest),
        "rgb_norm": str(args.rgb_norm),
        "postprocess_manifest": str(args.postprocess_manifest),
        "checkpoint": str(checkpoint_path),
        "device": str(device),
        "width": args.width,
        "height": args.height,
        "scale": int(quant_plan["scale"]),
        "precision_label": precision_label,
        "pytorch_png": str(pytorch_png),
        "fake_w8a12_png": str(fake_png),
        "fake_quant_png": str(fake_png),
        "integer_w8a12_png": str(integer_png),
        "integer_quant_png": str(integer_png),
        "integer_w8a12_qdump": str(integer_qdump),
        "integer_quant_qdump": str(integer_qdump),
        "rtl_png": str(args.rtl_png) if args.rtl_png else None,
        "preview": str(preview),
        "metrics": metrics,
        "stage_metrics": stage_metrics,
    }
    summary_json = args.out_dir / "span_w8a12_integer_reference_summary.json"
    summary_md = args.out_dir / "span_w8a12_integer_reference_summary.md"
    summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_markdown(summary_md, summary)
    print(json.dumps({"summary": str(summary_md), "preview": str(preview), "metrics": metrics}, indent=2))


def write_qdump(path: Path, width: int, height: int, values: list[int]) -> None:
    lines = []
    for pix in range(width * height):
        for ch in range(3):
            lines.append(f"{pix} {ch} {int(values[pix * 3 + ch])}")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def write_markdown(path: Path, summary: dict) -> None:
    precision_label = summary.get("precision_label", "W8A12")
    lines = [
        f"# SPAN {precision_label} Integer Reference",
        "",
        f"Input: `{summary['input']}`",
        f"Quant plan: `{summary['quant_plan']}`",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Preview: `{summary['preview']}`",
        "",
        "## Metrics",
        "",
        "| Compare | PSNR | MAE | Max diff | Mismatch bytes |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for name, metrics in summary["metrics"].items():
        lines.append(
            f"| `{name}` | `{metrics['psnr_db']:.6f}` | `{metrics['mae']:.6f}` | "
            f"`{metrics['max_channel_diff']}` | `{metrics['mismatch_bytes']} / {metrics['total_bytes']}` |"
        )
    lines.extend(
        [
            "",
            "## Artifacts",
            "",
            f"- PyTorch PNG: `{summary['pytorch_png']}`",
            f"- fake {precision_label} PNG: `{summary['fake_quant_png']}`",
            f"- integer {precision_label} PNG: `{summary['integer_quant_png']}`",
            f"- integer {precision_label} q dump: `{summary['integer_quant_qdump']}`",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
