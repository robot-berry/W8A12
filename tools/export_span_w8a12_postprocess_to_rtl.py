"""Export W8A12 SPAN postprocess LUTs for RTL simulation/synthesis."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


def safe_name(name: str) -> str:
    return name.replace(".", "_").replace("-", "_")


def clamp_q(value: int, bits: int) -> int:
    qmin = -(1 << (bits - 1))
    qmax = (1 << (bits - 1)) - 1
    return max(qmin, min(qmax, value))


def quantize(value: float, scale: float, bits: int) -> int:
    return clamp_q(round(value / scale), bits)


def silu(value: float) -> float:
    return value / (1.0 + math.exp(-value))


def signed_to_hex(value: int, bits: int) -> str:
    mask = (1 << bits) - 1
    width = (bits + 3) // 4
    return f"{value & mask:0{width}x}"


def write_mem(path: Path, values: list[int], bits: int) -> None:
    path.write_text("\n".join(signed_to_hex(value, bits) for value in values) + "\n", encoding="ascii")


def make_silu_lut(input_scale: float, output_scale: float, bits: int) -> list[int]:
    qmin = -(1 << (bits - 1))
    qmax = (1 << (bits - 1)) - 1
    return [quantize(silu(q * input_scale), output_scale, bits) for q in range(qmin, qmax + 1)]


def make_sim_att_lut(out3_scale: float, sim_att_scale: float, bits: int) -> list[int]:
    qmin = -(1 << (bits - 1))
    qmax = (1 << (bits - 1)) - 1
    return [quantize((1.0 / (1.0 + math.exp(-(q * out3_scale)))) - 0.5, sim_att_scale, bits) for q in range(qmin, qmax + 1)]


def ratio_to_q31(value: float) -> dict:
    shift = 31
    multiplier = round(value * (1 << shift))
    return {"real_multiplier": value, "multiplier_q31": multiplier, "shift": shift}


def attention_output_q31(out3_q: int, residual_q: int, sim_q: int, out3_mult: int, residual_mult: int, shift: int, bits: int) -> int:
    product = (out3_q * sim_q * out3_mult) + (residual_q * sim_q * residual_mult)
    if shift > 0:
        offset = 1 << (shift - 1)
        product = ((product + offset) >> shift) if product >= 0 else -(((-product) + offset) >> shift)
    return clamp_q(product, bits)


def make_preview(path: Path, curves: list[tuple[str, str, list[int]]], bits: int) -> None:
    selected = []
    for wanted in ("block_1.act1", "block_1.act2", "block_1.attention", "block_6.attention"):
        for item in curves:
            if item[0] == wanted:
                selected.append(item)
                break
    if len(selected) < 4:
        selected = curves[:4]

    panel_w = 220
    panel_h = 150
    pad = 16
    title_h = 28
    canvas = Image.new("RGB", (pad + len(selected) * (panel_w + pad), title_h + panel_h + 2 * pad), "white")
    draw = ImageDraw.Draw(canvas)
    draw.text((pad, 8), "W8A12 postprocess LUT preview", fill=(20, 28, 40))
    qmin = -(1 << (bits - 1))
    qmax = (1 << (bits - 1)) - 1
    for idx, (name, kind, values) in enumerate(selected):
        x0 = pad + idx * (panel_w + pad)
        y0 = title_h + pad
        draw.rectangle((x0, y0, x0 + panel_w - 1, y0 + panel_h - 1), outline=(210, 216, 224))
        draw.text((x0, title_h - 2), f"{name} {kind}", fill=(32, 37, 45))
        lo = min(values)
        hi = max(values)
        if lo == hi:
            hi = lo + 1
        prev = None
        step = max(1, len(values) // panel_w)
        for sample_idx in range(0, len(values), step):
            x = x0 + round(sample_idx * (panel_w - 1) / (len(values) - 1))
            y = y0 + panel_h - 1 - round((values[sample_idx] - lo) * (panel_h - 1) / (hi - lo))
            if prev is not None:
                draw.line((prev[0], prev[1], x, y), fill=(32, 105, 180), width=2)
            prev = (x, y)
        draw.text((x0 + 4, y0 + 4), f"x {qmin}..{qmax}", fill=(82, 91, 105))
        draw.text((x0 + 4, y0 + panel_h - 18), f"y {lo}..{hi}", fill=(82, 91, 105))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def make_attention_preview(path: Path, entries: list[dict]) -> None:
    attention_entries = [entry for entry in entries if entry["kind"] == "span_attention"]
    if not attention_entries:
        return
    panel_w = 170
    panel_h = 150
    pad = 16
    title_h = 30
    canvas = Image.new("RGB", (pad + len(attention_entries) * (panel_w + pad), title_h + panel_h + 2 * pad), "white")
    draw = ImageDraw.Draw(canvas)
    draw.text((pad, 8), "W8A12 attention Q31 vs float reference", fill=(20, 28, 40))
    for idx, entry in enumerate(attention_entries):
        x0 = pad + idx * (panel_w + pad)
        y0 = title_h + pad
        vectors = entry["attention_vectors"]
        values = [item["float_reference_q"] for item in vectors] + [item["q31_output_q"] for item in vectors]
        lo = min(values)
        hi = max(values)
        if lo == hi:
            hi = lo + 1
        draw.rectangle((x0, y0, x0 + panel_w - 1, y0 + panel_h - 1), outline=(210, 216, 224))
        draw.text((x0, title_h - 2), entry["name"], fill=(32, 37, 45))
        for sample_idx, item in enumerate(vectors):
            x = x0 + 14 + round(sample_idx * (panel_w - 32) / max(1, len(vectors) - 1))
            y_float = y0 + panel_h - 16 - round((item["float_reference_q"] - lo) * (panel_h - 32) / (hi - lo))
            y_q31 = y0 + panel_h - 16 - round((item["q31_output_q"] - lo) * (panel_h - 32) / (hi - lo))
            draw.ellipse((x - 3, y_float - 3, x + 3, y_float + 3), fill=(80, 80, 80))
            draw.rectangle((x - 3, y_q31 - 3, x + 3, y_q31 + 3), fill=(32, 105, 180))
            if y_float != y_q31:
                draw.line((x, y_float, x, y_q31), fill=(220, 80, 70))
        err = entry["attention_q31_max_abs_error_vs_float"]
        draw.text((x0 + 4, y0 + 4), f"max err {err}", fill=(82, 91, 105))
        draw.text((x0 + 4, y0 + panel_h - 18), f"y {lo}..{hi}", fill=(82, 91, 105))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export W8A12 postprocess LUTs to RTL mem/header files.")
    parser.add_argument("--quant-plan", type=Path, default=Path("runs/reds_span_quant_plan/reds_span_x4_f48_w8a12_reds_val4/span_w8a12_quant_plan.json"))
    parser.add_argument("--out-dir", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/postprocess"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    plan = json.loads(args.quant_plan.read_text(encoding="utf-8"))
    scales = plan["activation_scale_table"]
    bits = int(plan["activation_bits"])
    qmin = int(plan["activation_qmin"])
    qmax = int(plan["activation_qmax"])
    args.out_dir.mkdir(parents=True, exist_ok=True)
    mem_dir = args.out_dir / "mem"
    mem_dir.mkdir(exist_ok=True)

    entries = []
    curves = []
    for idx, spec in enumerate(plan["postprocess"]):
        kind = spec["kind"]
        name = spec["name"]
        safe = safe_name(name)
        if kind == "silu":
            input_scale = float(scales[spec["input_scale_ref"]])
            output_scale = float(scales[spec["output_scale_ref"]])
            values = make_silu_lut(input_scale, output_scale, bits)
            mem_path = mem_dir / f"{safe}_silu_s{bits}.mem"
            macro_kind = "SILU"
            scale_info = {
                "input_scale_ref": spec["input_scale_ref"],
                "input_scale": input_scale,
                "output_scale_ref": spec["output_scale_ref"],
                "output_scale": output_scale,
            }
        elif kind == "span_attention":
            input_scale = float(scales[spec["out3_scale_ref"]])
            output_scale = float(scales[spec["sim_att_scale_ref"]])
            residual_scale = float(scales[spec["residual_scale_ref"]])
            attention_output_scale = float(scales[spec["output_scale_ref"]])
            out3_requant = ratio_to_q31(input_scale * output_scale / attention_output_scale)
            residual_requant = ratio_to_q31(residual_scale * output_scale / attention_output_scale)
            values = make_sim_att_lut(input_scale, output_scale, bits)
            mem_path = mem_dir / f"{safe}_sim_att_s{bits}.mem"
            macro_kind = "SIM_ATT"
            attention_vectors = []
            for out3_q, residual_q, sim_q in [(-2048, -1024, -2047), (-1024, 512, -512), (-17, 23, -3), (0, 0, 0), (17, -23, 3), (512, -1024, 512), (1536, 1024, 2047), (2047, 2047, 2047)]:
                q31_out = attention_output_q31(
                    out3_q,
                    residual_q,
                    sim_q,
                    int(out3_requant["multiplier_q31"]),
                    int(residual_requant["multiplier_q31"]),
                    int(out3_requant["shift"]),
                    bits,
                )
                float_out = quantize(
                    ((out3_q * input_scale) + (residual_q * residual_scale)) * (sim_q * output_scale),
                    attention_output_scale,
                    bits,
                )
                attention_vectors.append(
                    {
                        "out3_q": out3_q,
                        "residual_q": residual_q,
                        "sim_att_q": sim_q,
                        "q31_output_q": q31_out,
                        "float_reference_q": float_out,
                        "q31_minus_float": q31_out - float_out,
                    }
                )
            scale_info = {
                "input_scale_ref": spec["out3_scale_ref"],
                "input_scale": input_scale,
                "output_scale_ref": spec["sim_att_scale_ref"],
                "output_scale": output_scale,
                "residual_scale_ref": spec["residual_scale_ref"],
                "residual_scale": residual_scale,
                "attention_output_scale_ref": spec["output_scale_ref"],
                "attention_output_scale": attention_output_scale,
                "out3_requant": out3_requant,
                "residual_requant": residual_requant,
                "attention_vectors": attention_vectors,
                "attention_q31_max_abs_error_vs_float": max(abs(item["q31_minus_float"]) for item in attention_vectors),
            }
        else:
            raise ValueError(f"Unsupported postprocess kind: {kind}")

        write_mem(mem_path, values, bits)
        curves.append((name, kind, values))
        entries.append(
            {
                "id": idx,
                "name": name,
                "kind": kind,
                "macro_kind": macro_kind,
                "mem": str(mem_path.resolve()).replace("\\", "/"),
                "value_count": len(values),
                "q_min": min(values),
                "q_max": max(values),
                "zero_count": sum(1 for value in values if value == 0),
                **scale_info,
            }
        )

    header_lines = [
        "`ifndef REDS_SPAN_W8A12_POSTPROCESS_VH",
        "`define REDS_SPAN_W8A12_POSTPROCESS_VH",
        "// Auto-generated by tools/export_span_w8a12_postprocess_to_rtl.py.",
        f"`define REDS_SPAN_W8A12_POSTPROCESS_COUNT {len(entries)}",
        f"`define REDS_SPAN_W8A12_POSTPROCESS_BITS {bits}",
        f"`define REDS_SPAN_W8A12_POSTPROCESS_QMIN {qmin}",
        f"`define REDS_SPAN_W8A12_POSTPROCESS_QMAX {qmax}",
        "",
    ]
    for entry in entries:
        macro = safe_name(entry["name"]).upper()
        header_lines.extend(
            [
                f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_NAME \"{entry['name']}\"",
                f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_{macro} {entry['id']}",
                f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_KIND_{entry['macro_kind']} 1",
                f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_FILE \"{entry['mem']}\"",
            ]
        )
        if entry["kind"] == "span_attention":
            header_lines.extend(
                [
                    f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_OUT3_REQUANT_Q31 {entry['out3_requant']['multiplier_q31']}",
                    f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_RESIDUAL_REQUANT_Q31 {entry['residual_requant']['multiplier_q31']}",
                    f"`define REDS_SPAN_W8A12_POSTPROCESS_{entry['id']}_REQUANT_SHIFT {entry['out3_requant']['shift']}",
                ]
            )
        header_lines.append("")
    header_lines.append("`endif")

    manifest = {
        "source": "REDS-trained SPAN W8A12 postprocess LUT export",
        "quant_plan": str(args.quant_plan),
        "activation_bits": bits,
        "activation_qmin": qmin,
        "activation_qmax": qmax,
        "entry_count": len(entries),
        "entries": entries,
    }
    manifest_path = args.out_dir / "span_w8a12_postprocess_manifest.json"
    header_path = args.out_dir / "span_w8a12_postprocess.vh"
    summary_path = args.out_dir / "span_w8a12_postprocess.md"
    preview_path = args.out_dir / "span_w8a12_postprocess_preview.png"
    attention_preview_path = args.out_dir / "span_w8a12_attention_preview.png"
    make_preview(preview_path, curves, bits)
    make_attention_preview(attention_preview_path, entries)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    header_path.write_text("\n".join(header_lines) + "\n", encoding="ascii")

    lines = [
        "# SPAN W8A12 Postprocess LUT Export",
        "",
        f"Quant plan: `{args.quant_plan}`",
        f"Activation bits: `{bits}`",
        f"Entries: `{len(entries)}`",
        f"Header: `{header_path}`",
        f"Manifest: `{manifest_path}`",
        f"Preview: `{preview_path}`",
        f"Attention preview: `{attention_preview_path}`",
        "",
        "| ID | Name | Kind | Input scale | Output scale | q range |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for entry in entries:
        lines.append(
            f"| {entry['id']} | `{entry['name']}` | `{entry['kind']}` | "
            f"`{entry['input_scale']:.8g}` | `{entry['output_scale']:.8g}` | "
            f"`{entry['q_min']}..{entry['q_max']}` |"
        )
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "manifest": str(manifest_path),
                "header": str(header_path),
                "preview": str(preview_path),
                "attention_preview": str(attention_preview_path),
                "entries": len(entries),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
