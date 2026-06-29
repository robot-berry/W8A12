"""Export a SPAN W8A12 quantization plan into RTL-friendly headers and .mem files."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def resolve_repo_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return (repo_root() / path).resolve()


def safe_layer_name(name: str) -> str:
    return name.replace(".", "_").replace("/", "_")


def macro_name(name: str) -> str:
    return safe_layer_name(name).upper()


def read_i8_binary(path: Path) -> list[int]:
    data = path.read_bytes()
    return [byte - 256 if byte >= 128 else byte for byte in data]


def read_i64_binary(path: Path) -> list[int]:
    data = path.read_bytes()
    if len(data) % 8 != 0:
        raise ValueError(f"int64 binary size is not aligned: {path}")
    return [int.from_bytes(data[idx : idx + 8], "little", signed=True) for idx in range(0, len(data), 8)]


def write_hex_mem(path: Path, values: list[int], bits: int) -> None:
    mask = (1 << bits) - 1
    width = (bits + 3) // 4
    lines = [f"{value & mask:0{width}x}" for value in values]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export SPAN W8A12 plan constants for RTL.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12"))
    parser.add_argument("--tag", default="REDS_SPAN_W8A12")
    parser.add_argument("--copy-plan", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    plan_path = args.quant_plan.resolve()
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    out_dir = args.out_dir
    mem_dir = out_dir / "mem"
    mem_dir.mkdir(parents=True, exist_ok=True)

    layers_out = []
    for layer_id, layer in enumerate(plan["layers"]):
        name = layer["name"]
        safe = safe_layer_name(name)
        weight_src = (plan_path.parent / layer["weight_file_i8_bin"]).resolve()
        bias_src = (plan_path.parent / layer["bias_file_i64_bin"]).resolve()
        weights = read_i8_binary(weight_src)
        bias = read_i64_binary(bias_src)
        requant = [int(item["multiplier_q31"]) for item in layer["requant"]]
        shifts = [int(item["shift"]) for item in layer["requant"]]

        weight_mem = mem_dir / f"{safe}_w_i8.mem"
        bias_mem = mem_dir / f"{safe}_bias_i64.mem"
        requant_mem = mem_dir / f"{safe}_requant_q31.mem"
        shift_mem = mem_dir / f"{safe}_requant_shift_u8.mem"
        write_hex_mem(weight_mem, weights, 8)
        write_hex_mem(bias_mem, bias, 64)
        write_hex_mem(requant_mem, requant, 32)
        write_hex_mem(shift_mem, shifts, 8)

        expected_weights = 1
        for dim in layer["weight_shape"]:
            expected_weights *= int(dim)
        expected_channels = int(layer["weight_shape"][0])
        if len(weights) != expected_weights:
            raise ValueError(f"{name}: weight count {len(weights)} != expected {expected_weights}")
        if len(bias) != expected_channels:
            raise ValueError(f"{name}: bias count {len(bias)} != expected {expected_channels}")
        if len(requant) != expected_channels:
            raise ValueError(f"{name}: requant count {len(requant)} != expected {expected_channels}")

        layers_out.append(
            {
                "id": layer_id,
                "name": name,
                "macro": macro_name(name),
                "input_scale_ref": layer["input_scale_ref"],
                "output_scale_ref": layer["output_scale_ref"],
                "weight_shape": layer["weight_shape"],
                "out_channels": expected_channels,
                "weight_numel": len(weights),
                "bias_numel": len(bias),
                "requant_numel": len(requant),
                "weight_mem": str(weight_mem.resolve()).replace("\\", "/"),
                "bias_mem": str(bias_mem.resolve()).replace("\\", "/"),
                "requant_q31_mem": str(requant_mem.resolve()).replace("\\", "/"),
                "requant_shift_mem": str(shift_mem.resolve()).replace("\\", "/"),
                "bias_i64_min": min(bias),
                "bias_i64_max": max(bias),
                "requant_q31_min": min(requant),
                "requant_q31_max": max(requant),
            }
        )

    activation_scale_items = list(plan["activation_scale_table"].items())
    act_scale_mem = mem_dir / "activation_scales_f32_hex.mem"
    # Store IEEE-754 bit patterns through Python's struct-free float.hex text; this is for traceability,
    # while the actual conv requant path consumes the per-layer Q31 multipliers above.
    act_scale_mem.write_text(
        "\n".join(f"{name} {float(value).hex()}" for name, value in activation_scale_items) + "\n",
        encoding="ascii",
    )

    manifest = {
        "source": "RTL-friendly export from SPAN W8A12 quantization plan",
        "quant_plan": str(plan_path),
        "source_checkpoint": plan["checkpoint"],
        "scale": int(plan["scale"]),
        "channels": int(plan["channels"]),
        "weight_bits": int(plan["weight_bits"]),
        "activation_bits": int(plan["activation_bits"]),
        "activation_qmin": int(plan["activation_qmin"]),
        "activation_qmax": int(plan["activation_qmax"]),
        "layer_count": len(layers_out),
        "activation_scale_count": len(activation_scale_items),
        "layers": layers_out,
        "activation_scales_trace_file": str(act_scale_mem.resolve()).replace("\\", "/"),
        "notes": [
            "Weights are signed int8 hex .mem files.",
            "Bias constants are signed int64 hex .mem files; downstream RTL may narrow only after range analysis.",
            "Requant multipliers are signed Q31 constants paired with an 8-bit shift field.",
            "Activation scale trace file is for auditability; convolution RTL should use requant Q31 constants.",
        ],
    }
    write_json(out_dir / "span_w8a12_rtl_manifest.json", manifest)
    if args.copy_plan:
        shutil.copy2(plan_path, out_dir / plan_path.name)

    guard = f"{args.tag}_LAYERS_VH"
    lines = [
        f"`ifndef {guard}",
        f"`define {guard}",
        "// Auto-generated by tools/export_span_quant_plan_to_rtl.py.",
        f"`define {args.tag}_SCALE {int(plan['scale'])}",
        f"`define {args.tag}_FEATURE_CHANNELS {int(plan['channels'])}",
        f"`define {args.tag}_WEIGHT_BITS {int(plan['weight_bits'])}",
        f"`define {args.tag}_ACTIVATION_BITS {int(plan['activation_bits'])}",
        f"`define {args.tag}_ACTIVATION_QMIN {int(plan['activation_qmin'])}",
        f"`define {args.tag}_ACTIVATION_QMAX {int(plan['activation_qmax'])}",
        f"`define {args.tag}_LAYER_COUNT {len(layers_out)}",
        f"`define {args.tag}_ACTIVATION_SCALE_COUNT {len(activation_scale_items)}",
        "",
    ]
    for layer in layers_out:
        prefix = f"{args.tag}_LAYER_{layer['id']}"
        lines.extend(
            [
                f"`define {prefix}_NAME \"{layer['name']}\"",
                f"`define {prefix}_ID {layer['id']}",
                f"`define {prefix}_{layer['macro']} {layer['id']}",
                f"`define {prefix}_OUT_CHANNELS {layer['out_channels']}",
                f"`define {prefix}_WEIGHT_NUMEL {layer['weight_numel']}",
                f"`define {prefix}_BIAS_NUMEL {layer['bias_numel']}",
                f"`define {prefix}_REQUANT_NUMEL {layer['requant_numel']}",
                f"`define {prefix}_WEIGHT_FILE \"{layer['weight_mem']}\"",
                f"`define {prefix}_BIAS_I64_FILE \"{layer['bias_mem']}\"",
                f"`define {prefix}_REQUANT_Q31_FILE \"{layer['requant_q31_mem']}\"",
                f"`define {prefix}_REQUANT_SHIFT_FILE \"{layer['requant_shift_mem']}\"",
            ]
        )
    lines.extend(["`endif", ""])
    (out_dir / "span_w8a12_layers.vh").write_text("\n".join(lines), encoding="ascii")

    summary_lines = [
        "# SPAN W8A12 RTL Export",
        "",
        f"Quant plan: `{plan_path}`",
        f"Output directory: `{out_dir}`",
        f"Layers: `{len(layers_out)}`",
        f"Activation scales: `{len(activation_scale_items)}`",
        f"Header: `{out_dir / 'span_w8a12_layers.vh'}`",
        f"Manifest: `{out_dir / 'span_w8a12_rtl_manifest.json'}`",
        "",
        "| ID | Layer | Out ch | Weight numel | Bias range | Requant Q31 range |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for layer in layers_out:
        summary_lines.append(
            f"| {layer['id']} | `{layer['name']}` | `{layer['out_channels']}` | `{layer['weight_numel']}` | "
            f"`{layer['bias_i64_min']}..{layer['bias_i64_max']}` | "
            f"`{layer['requant_q31_min']}..{layer['requant_q31_max']}` |"
        )
    (out_dir / "span_w8a12_rtl_export.md").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

    print(
        json.dumps(
            {
                "manifest": str(out_dir / "span_w8a12_rtl_manifest.json"),
                "header": str(out_dir / "span_w8a12_layers.vh"),
                "layers": len(layers_out),
                "activation_scales": len(activation_scale_items),
                "mem_files": len(list(mem_dir.glob("*.mem"))),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
