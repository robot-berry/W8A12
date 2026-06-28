"""W8A12_3lane Python reference entrypoints."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


ROOT = repo_root()
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from check_span_w8a12_rtl_primitives import conv_output, read_hex_mem  # noqa: E402


MASK32 = 0xFFFFFFFF
HASH_SEED = 0x811C9DC5


def rotl5(value: int) -> int:
    value &= MASK32
    return ((value << 5) | (value >> 27)) & MASK32


def signed_to_u32(value: int) -> int:
    return int(value) & MASK32


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_path(value: str | Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return (ROOT / path).resolve()


def find_layer(manifest: dict, name: str) -> dict:
    for layer in manifest["layers"]:
        if layer["name"] == name:
            return layer
    raise KeyError(f"Layer not found: {name}")


def find_postprocess_entry(manifest: dict, name: str) -> dict:
    for entry in manifest["entries"]:
        if entry["name"] == name:
            return entry
    raise KeyError(f"Postprocess entry not found: {name}")


def make_input_feature(height: int, width: int, channels: int, bits: int) -> np.ndarray:
    qmin = -(1 << (bits - 1))
    qrange = 1 << bits
    arr = np.zeros((height, width, channels), dtype=np.int16)
    for y in range(height):
        for x in range(width):
            for ch in range(channels):
                value = ((y * 257 + x * 131 + ch * 37 + 19) % qrange) + qmin
                arr[y, x, ch] = np.int16(value)
    return arr


def feature_window(feature: np.ndarray, y: int, x: int, kernel_taps: int) -> list[int]:
    height, width, channels = feature.shape
    if kernel_taps == 1:
        return [int(feature[y, x, ch]) for ch in range(channels)]
    window: list[int] = []
    for ch in range(channels):
        for ky in range(3):
            for kx in range(3):
                sy = y + ky - 1
                sx = x + kx - 1
                if 0 <= sy < height and 0 <= sx < width:
                    window.append(int(feature[sy, sx, ch]))
                else:
                    window.append(0)
    return window


def conv_layer_reference(feature: np.ndarray, layer: dict, bits: int) -> np.ndarray:
    height, width, channels = feature.shape
    out_channels = int(layer["out_channels"])
    weights = read_hex_mem(resolve_path(layer["weight_mem"]), 8)
    bias = read_hex_mem(resolve_path(layer["bias_mem"]), 64)
    requant = read_hex_mem(resolve_path(layer["requant_q31_mem"]), 32)
    shifts = read_hex_mem(resolve_path(layer["requant_shift_mem"]), 8)
    kernel_taps = int(layer["weight_numel"]) // out_channels // channels
    out = np.zeros((height, width, out_channels), dtype=np.int16)
    for y in range(height):
        for x in range(width):
            window = feature_window(feature, y, x, kernel_taps)
            values = conv_output(window, weights, bias, requant, shifts, layer, bits)
            out[y, x, :] = np.asarray(values, dtype=np.int16)
    return out


def apply_lut_reference(feature: np.ndarray, entry: dict, bits: int) -> np.ndarray:
    lut = read_hex_mem(resolve_path(entry["mem"]), bits)
    offset = 1 << (bits - 1)
    flat = [lut[int(value) + offset] for value in feature.reshape(-1)]
    return np.asarray(flat, dtype=np.int16).reshape(feature.shape)


def clamp_q(value: int, bits: int) -> int:
    return max(-(1 << (bits - 1)), min((1 << (bits - 1)) - 1, int(value)))


def attention_reference(out3: np.ndarray, residual: np.ndarray, sim: np.ndarray, entry: dict, bits: int) -> np.ndarray:
    out3_mult = int(entry["out3_requant"]["multiplier_q31"])
    residual_mult = int(entry["residual_requant"]["multiplier_q31"])
    shift = int(entry["out3_requant"]["shift"])
    out = np.zeros_like(out3, dtype=np.int16)
    for index in np.ndindex(out3.shape):
        product = (int(out3[index]) * int(sim[index]) * out3_mult) + (
            int(residual[index]) * int(sim[index]) * residual_mult
        )
        if shift > 0:
            offset = 1 << (shift - 1)
            product = ((product + offset) >> shift) if product >= 0 else -(((-product) + offset) >> shift)
        out[index] = np.int16(clamp_q(product, bits))
    return out


def requant_q31(value: int, multiplier: int, shift: int, bits: int) -> int:
    product = int(value) * int(multiplier)
    if shift > 0:
        offset = 1 << (shift - 1)
        product = ((product + offset) >> shift) if product >= 0 else -(((-product) + offset) >> shift)
    return clamp_q(product, bits)


def requant_feature_reference(feature: np.ndarray, multiplier: int, bits: int) -> np.ndarray:
    out = np.zeros_like(feature, dtype=np.int16)
    for index in np.ndindex(feature.shape):
        out[index] = np.int16(requant_q31(int(feature[index]), multiplier, 31, bits))
    return out


def q31_ratio(src_scale: float, dst_scale: float) -> int:
    return int(round((float(src_scale) / float(dst_scale)) * (1 << 31)))


def concat_for_conv_cat_reference(
    *,
    feat0: np.ndarray,
    b6conv: np.ndarray,
    b1: np.ndarray,
    b6_act1: np.ndarray,
    multipliers: dict[str, int],
    bits: int,
) -> np.ndarray:
    feat0_q = requant_feature_reference(feat0, multipliers["feat0"], bits)
    b6conv_q = requant_feature_reference(b6conv, multipliers["b6conv"], bits)
    b1_q = requant_feature_reference(b1, multipliers["b1"], bits)
    b6_act1_q = requant_feature_reference(b6_act1, multipliers["b6_act1"], bits)
    return np.concatenate([feat0_q, b6conv_q, b1_q, b6_act1_q], axis=2).astype(np.int16)


def pixelshuffle_reference(up: np.ndarray, scale: int = 4, out_ch: int = 3) -> np.ndarray:
    height, width, channels = up.shape
    if channels != out_ch * scale * scale:
        raise AssertionError(f"pixelshuffle channels={channels} does not match {out_ch} x {scale} x {scale}")
    out = np.zeros((height * scale, width * scale, out_ch), dtype=np.int16)
    for y in range(height):
        for x in range(width):
            for c in range(out_ch):
                for sy in range(scale):
                    for sx in range(scale):
                        in_ch = c * scale * scale + sy * scale + sx
                        out[y * scale + sy, x * scale + sx, c] = up[y, x, in_ch]
    return out


def lane_slices(full: np.ndarray, lanes: int, out_ch_per_lane: int) -> list[np.ndarray]:
    return [full[:, :, lane * out_ch_per_lane : (lane + 1) * out_ch_per_lane].copy() for lane in range(lanes)]


def hash_values(values: np.ndarray) -> str:
    h = HASH_SEED
    flat = values.reshape(-1)
    for idx, value in enumerate(flat):
        h = (rotl5(h) ^ signed_to_u32(int(value)) ^ idx) & MASK32
    return f"0x{h:08X}"


def hash_full48(feature: np.ndarray) -> str:
    h = HASH_SEED
    height, width, channels = feature.shape
    for y in range(height):
        for x in range(width):
            for ch in range(channels):
                h = (rotl5(h) ^ signed_to_u32(int(feature[y, x, ch])) ^ ch) & MASK32
    return f"0x{h:08X}"


def write_txt(path: Path, arr: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    flat = arr.reshape(-1)
    path.write_text("\n".join(str(int(v)) for v in flat) + "\n", encoding="ascii")


def to_hex(value: int, bits: int) -> str:
    mask = (1 << bits) - 1
    width = (bits + 3) // 4
    return f"{int(value) & mask:0{width}X}"


def write_mem(path: Path, values: list[int], bits: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(to_hex(value, bits) for value in values) + "\n", encoding="ascii")


def emit_lane_mems(layer: dict, out_dir: Path, lanes: int, out_ch_per_lane: int) -> dict:
    weights = read_hex_mem(resolve_path(layer["weight_mem"]), 8)
    bias = read_hex_mem(resolve_path(layer["bias_mem"]), 64)
    requant = read_hex_mem(resolve_path(layer["requant_q31_mem"]), 32)
    shifts = read_hex_mem(resolve_path(layer["requant_shift_mem"]), 8)
    tap_count = int(layer["weight_numel"]) // int(layer["out_channels"])
    lane_files: dict[str, dict] = {}
    mem_dir = out_dir / "lane_mems"
    for lane in range(lanes):
        ch0 = lane * out_ch_per_lane
        ch1 = ch0 + out_ch_per_lane
        lane_weights: list[int] = []
        for ch in range(ch0, ch1):
            lane_weights.extend(weights[ch * tap_count : (ch + 1) * tap_count])
        lane_bias = bias[ch0:ch1]
        lane_requant = requant[ch0:ch1]
        lane_shifts = shifts[ch0:ch1]
        files = {
            "weight_mem": mem_dir / f"lane{lane}_{layer['name'].replace('.', '_')}_w_i8.mem",
            "bias_mem": mem_dir / f"lane{lane}_{layer['name'].replace('.', '_')}_bias_i64.mem",
            "requant_q31_mem": mem_dir / f"lane{lane}_{layer['name'].replace('.', '_')}_requant_q31.mem",
            "requant_shift_mem": mem_dir / f"lane{lane}_{layer['name'].replace('.', '_')}_requant_shift_u8.mem",
        }
        write_mem(files["weight_mem"], lane_weights, 8)
        write_mem(files["bias_mem"], lane_bias, 64)
        write_mem(files["requant_q31_mem"], lane_requant, 32)
        write_mem(files["requant_shift_mem"], lane_shifts, 8)
        lane_files[f"lane{lane}"] = {key: str(path) for key, path in files.items()}
    return lane_files


def sv_path(path: str | Path) -> str:
    return str(path).replace("\\", "/")


def emit_sv_file_defines(out_dir: Path, lane_mem_files: dict[str, dict]) -> Path:
    vh = out_dir / "a0_3lane_files.vh"
    lines = [
        "`ifndef W8A12_3LANE_A0_FILES_VH",
        "`define W8A12_3LANE_A0_FILES_VH",
        f'`define W8A12_3LANE_A0_INPUT_TXT "{sv_path(out_dir / "input_feature.txt")}"',
        f'`define W8A12_3LANE_A0_EXPECTED_TXT "{sv_path(out_dir / "full48_output.txt")}"',
    ]
    for lane in range(3):
        files = lane_mem_files[f"lane{lane}"]
        lines.extend(
            [
                f'`define W8A12_3LANE_A0_LANE{lane}_WEIGHT_MEM "{sv_path(files["weight_mem"])}"',
                f'`define W8A12_3LANE_A0_LANE{lane}_BIAS_MEM "{sv_path(files["bias_mem"])}"',
                f'`define W8A12_3LANE_A0_LANE{lane}_REQUANT_MEM "{sv_path(files["requant_q31_mem"])}"',
                f'`define W8A12_3LANE_A0_LANE{lane}_SHIFT_MEM "{sv_path(files["requant_shift_mem"])}"',
            ]
        )
    lines.extend(["`endif", ""])
    vh.write_text("\n".join(lines), encoding="ascii")
    return vh


def emit_a1_sv_file_defines(out_dir: Path, lane_mem_files: dict[str, dict], postprocess_entries: dict[str, dict]) -> Path:
    vh = out_dir / "a1_3lane_files.vh"
    lines = [
        "`ifndef W8A12_3LANE_A1_FILES_VH",
        "`define W8A12_3LANE_A1_FILES_VH",
        f'`define W8A12_3LANE_A1_INPUT_TXT "{sv_path(out_dir / "block_input.txt")}"',
        f'`define W8A12_3LANE_A1_EXPECTED_TXT "{sv_path(out_dir / "block_output.txt")}"',
        f'`define W8A12_3LANE_A1_C1_RAW_TXT "{sv_path(out_dir / "c1_raw.txt")}"',
        f'`define W8A12_3LANE_A1_ACT1_TXT "{sv_path(out_dir / "act1.txt")}"',
        f'`define W8A12_3LANE_A1_C2_RAW_TXT "{sv_path(out_dir / "c2_raw.txt")}"',
        f'`define W8A12_3LANE_A1_ACT2_TXT "{sv_path(out_dir / "act2.txt")}"',
        f'`define W8A12_3LANE_A1_C3_RAW_TXT "{sv_path(out_dir / "c3_raw.txt")}"',
        f'`define W8A12_3LANE_A1_SIM_ATT_TXT "{sv_path(out_dir / "sim_att.txt")}"',
        f'`define W8A12_3LANE_A1_ACT1_LUT "{sv_path(resolve_path(postprocess_entries["act1"]["mem"]))}"',
        f'`define W8A12_3LANE_A1_ACT2_LUT "{sv_path(resolve_path(postprocess_entries["act2"]["mem"]))}"',
        f'`define W8A12_3LANE_A1_ATTENTION_LUT "{sv_path(resolve_path(postprocess_entries["attention"]["mem"]))}"',
    ]
    for layer_key in ("c1", "c2", "c3"):
        for lane in range(3):
            files = lane_mem_files[layer_key][f"lane{lane}"]
            prefix = f"W8A12_3LANE_A1_{layer_key.upper()}_LANE{lane}"
            lines.extend(
                [
                    f'`define {prefix}_WEIGHT_MEM "{sv_path(files["weight_mem"])}"',
                    f'`define {prefix}_BIAS_MEM "{sv_path(files["bias_mem"])}"',
                    f'`define {prefix}_REQUANT_MEM "{sv_path(files["requant_q31_mem"])}"',
                    f'`define {prefix}_SHIFT_MEM "{sv_path(files["requant_shift_mem"])}"',
                ]
            )
    lines.extend(["`endif", ""])
    vh.write_text("\n".join(lines), encoding="ascii")
    return vh


def emit_a2_sv_file_defines(
    out_dir: Path,
    lane_mem_files: dict[str, dict[str, dict[str, dict]]],
    postprocess_entries: dict[str, dict[str, dict]],
) -> Path:
    vh = out_dir / "a2_3lane_files.vh"
    lines = [
        "`ifndef W8A12_3LANE_A2_FILES_VH",
        "`define W8A12_3LANE_A2_FILES_VH",
        f'`define W8A12_3LANE_A2_BLOCK0_INPUT_TXT "{sv_path(out_dir / "block_0_input.txt")}"',
    ]
    for block in range(1, 7):
        block_dir = out_dir / f"block_{block}"
        lines.extend(
            [
                f'`define W8A12_3LANE_A2_BLOCK{block}_OUTPUT_TXT "{sv_path(out_dir / f"block_{block}_output.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_C1_RAW_TXT "{sv_path(block_dir / "c1_raw.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_ACT1_TXT "{sv_path(block_dir / "act1.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_C2_RAW_TXT "{sv_path(block_dir / "c2_raw.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_ACT2_TXT "{sv_path(block_dir / "act2.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_C3_RAW_TXT "{sv_path(block_dir / "c3_raw.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_SIM_ATT_TXT "{sv_path(block_dir / "sim_att.txt")}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_ACT1_LUT "{sv_path(resolve_path(postprocess_entries[f"block_{block}"]["act1"]["mem"]))}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_ACT2_LUT "{sv_path(resolve_path(postprocess_entries[f"block_{block}"]["act2"]["mem"]))}"',
                f'`define W8A12_3LANE_A2_BLOCK{block}_ATTENTION_LUT "{sv_path(resolve_path(postprocess_entries[f"block_{block}"]["attention"]["mem"]))}"',
            ]
        )
        att = postprocess_entries[f"block_{block}"]["attention"]
        lines.extend(
            [
                f"`define W8A12_3LANE_A2_BLOCK{block}_ATT_SHIFT {int(att['out3_requant']['shift'])}",
                f"`define W8A12_3LANE_A2_BLOCK{block}_ATT_OUT3_Q31 32'sd{int(att['out3_requant']['multiplier_q31'])}",
                f"`define W8A12_3LANE_A2_BLOCK{block}_ATT_RESIDUAL_Q31 32'sd{int(att['residual_requant']['multiplier_q31'])}",
            ]
        )
        for layer_key in ("c1", "c2", "c3"):
            for lane in range(3):
                files = lane_mem_files[f"block_{block}"][layer_key][f"lane{lane}"]
                prefix = f"W8A12_3LANE_A2_BLOCK{block}_{layer_key.upper()}_LANE{lane}"
                lines.extend(
                    [
                        f'`define {prefix}_WEIGHT_MEM "{sv_path(files["weight_mem"])}"',
                        f'`define {prefix}_BIAS_MEM "{sv_path(files["bias_mem"])}"',
                        f'`define {prefix}_REQUANT_MEM "{sv_path(files["requant_q31_mem"])}"',
                        f'`define {prefix}_SHIFT_MEM "{sv_path(files["requant_shift_mem"])}"',
                    ]
                )
    lines.extend(["`endif", ""])
    vh.write_text("\n".join(lines), encoding="ascii")
    return vh


def spab_block_reference(feature: np.ndarray, manifest: dict, post: dict, block: int, bits: int) -> dict[str, np.ndarray]:
    c1 = find_layer(manifest, f"block_{block}.c1_r")
    c2 = find_layer(manifest, f"block_{block}.c2_r")
    c3 = find_layer(manifest, f"block_{block}.c3_r")
    act1_entry = find_postprocess_entry(post, f"block_{block}.act1")
    act2_entry = find_postprocess_entry(post, f"block_{block}.act2")
    attention_entry = find_postprocess_entry(post, f"block_{block}.attention")

    c1_raw = conv_layer_reference(feature, c1, bits)
    act1 = apply_lut_reference(c1_raw, act1_entry, bits)
    c2_raw = conv_layer_reference(act1, c2, bits)
    act2 = apply_lut_reference(c2_raw, act2_entry, bits)
    c3_raw = conv_layer_reference(act2, c3, bits)
    sim_att = apply_lut_reference(c3_raw, attention_entry, bits)
    block_output = attention_reference(c3_raw, feature, sim_att, attention_entry, bits)
    return {
        "block_input": feature,
        "c1_raw": c1_raw,
        "act1": act1,
        "c2_raw": c2_raw,
        "act2": act2,
        "c3_raw": c3_raw,
        "sim_att": sim_att,
        "block_output": block_output,
    }


def run_a0_single_conv(args: argparse.Namespace) -> dict:
    manifest = load_json(resolve_path(args.rtl_manifest))
    bits = int(manifest["activation_bits"])
    channels = int(manifest["channels"])
    layer = find_layer(manifest, args.layer)
    if int(layer["out_channels"]) != args.lanes * args.out_ch_per_lane:
        raise AssertionError(
            f"{args.layer}: out_channels={layer['out_channels']} does not match "
            f"{args.lanes} lanes x {args.out_ch_per_lane}"
        )

    input_feature = make_input_feature(args.height, args.width, channels, bits)
    full48 = conv_layer_reference(input_feature, layer, bits)
    lanes = lane_slices(full48, args.lanes, args.out_ch_per_lane)
    stitched = np.concatenate(lanes, axis=2)
    bit_exact = bool(np.array_equal(stitched, full48))
    if not bit_exact:
        mismatch = np.argwhere(stitched != full48)[0].tolist()
        raise AssertionError(f"A0 lane stitching mismatch at {mismatch}")

    out_dir = resolve_path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    np.save(out_dir / "input_feature.npy", input_feature)
    np.save(out_dir / "full48_output.npy", full48)
    write_txt(out_dir / "input_feature.txt", input_feature)
    write_txt(out_dir / "full48_output.txt", full48)
    for lane, values in enumerate(lanes):
        np.save(out_dir / f"lane{lane}_output.npy", values)
        write_txt(out_dir / f"lane{lane}_output.txt", values)
    lane_mem_files = emit_lane_mems(layer, out_dir, args.lanes, args.out_ch_per_lane)
    sv_defines = emit_sv_file_defines(out_dir, lane_mem_files)

    hashes = {
        "input_hash": hash_full48(input_feature),
        "lane0_hash": hash_values(lanes[0]),
        "lane1_hash": hash_values(lanes[1]),
        "lane2_hash": hash_values(lanes[2]),
        "full48_hash": hash_full48(full48),
        "stitched_hash": hash_full48(stitched),
    }
    summary = {
        "status": "PASS",
        "stage": "A0_single_conv",
        "layer": args.layer,
        "rtl_manifest": str(resolve_path(args.rtl_manifest)),
        "activation_bits": bits,
        "height": args.height,
        "width": args.width,
        "channels": channels,
        "lanes": args.lanes,
        "out_ch_per_lane": args.out_ch_per_lane,
        "bit_exact_lane_stitch": bit_exact,
        "hash_algorithm": "rotl5_xor_indexed_v1",
        "hashes": hashes,
        "outputs": {
            "input_feature_npy": str(out_dir / "input_feature.npy"),
            "full48_output_npy": str(out_dir / "full48_output.npy"),
            "lane0_output_npy": str(out_dir / "lane0_output.npy"),
            "lane1_output_npy": str(out_dir / "lane1_output.npy"),
            "lane2_output_npy": str(out_dir / "lane2_output.npy"),
            "sv_defines": str(sv_defines),
        },
        "lane_mem_files": lane_mem_files,
    }
    (out_dir / "hashes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_a0_summary(summary), encoding="utf-8")
    return summary


def run_a1_single_block(args: argparse.Namespace) -> dict:
    manifest = load_json(resolve_path(args.rtl_manifest))
    post = load_json(resolve_path(args.postprocess_manifest))
    bits = int(manifest["activation_bits"])
    channels = int(manifest["channels"])
    block = int(args.block)
    if channels != args.lanes * args.out_ch_per_lane:
        raise AssertionError(f"channels={channels} does not match {args.lanes} lanes x {args.out_ch_per_lane}")

    c1 = find_layer(manifest, f"block_{block}.c1_r")
    c2 = find_layer(manifest, f"block_{block}.c2_r")
    c3 = find_layer(manifest, f"block_{block}.c3_r")
    act1_entry = find_postprocess_entry(post, f"block_{block}.act1")
    act2_entry = find_postprocess_entry(post, f"block_{block}.act2")
    attention_entry = find_postprocess_entry(post, f"block_{block}.attention")

    block_input = make_input_feature(args.height, args.width, channels, bits)
    stages = spab_block_reference(block_input, manifest, post, block, bits)

    out_dir = resolve_path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, values in stages.items():
        np.save(out_dir / f"{name}.npy", values)
        write_txt(out_dir / f"{name}.txt", values)

    lane_mem_files = {
        "c1": emit_lane_mems(c1, out_dir / "c1", args.lanes, args.out_ch_per_lane),
        "c2": emit_lane_mems(c2, out_dir / "c2", args.lanes, args.out_ch_per_lane),
        "c3": emit_lane_mems(c3, out_dir / "c3", args.lanes, args.out_ch_per_lane),
    }
    sv_defines = emit_a1_sv_file_defines(
        out_dir,
        lane_mem_files,
        {"act1": act1_entry, "act2": act2_entry, "attention": attention_entry},
    )

    lane_hashes: dict[str, dict[str, str]] = {}
    lane_stitch_ok = True
    for stage_name in ("c1_raw", "c2_raw", "c3_raw", "block_output"):
        lanes = lane_slices(stages[stage_name], args.lanes, args.out_ch_per_lane)
        stitched = np.concatenate(lanes, axis=2)
        lane_stitch_ok = lane_stitch_ok and bool(np.array_equal(stitched, stages[stage_name]))
        lane_hashes[stage_name] = {f"lane{lane}_hash": hash_values(values) for lane, values in enumerate(lanes)}

    if not lane_stitch_ok:
        raise AssertionError("A1 lane stitching mismatch")

    hashes = {f"{name}_hash": hash_full48(values) for name, values in stages.items()}
    summary = {
        "status": "PASS",
        "stage": "A1_single_block",
        "block": block,
        "rtl_manifest": str(resolve_path(args.rtl_manifest)),
        "postprocess_manifest": str(resolve_path(args.postprocess_manifest)),
        "activation_bits": bits,
        "height": args.height,
        "width": args.width,
        "channels": channels,
        "lanes": args.lanes,
        "out_ch_per_lane": args.out_ch_per_lane,
        "bit_exact_lane_stitch": lane_stitch_ok,
        "hash_algorithm": "rotl5_xor_indexed_v1",
        "hashes": hashes,
        "lane_hashes": lane_hashes,
        "outputs": {
            **{f"{name}_npy": str(out_dir / f"{name}.npy") for name in stages},
            "sv_defines": str(sv_defines),
        },
        "postprocess_mems": {
            "act1_lut": str(resolve_path(act1_entry["mem"])),
            "act2_lut": str(resolve_path(act2_entry["mem"])),
            "attention_lut": str(resolve_path(attention_entry["mem"])),
        },
        "attention_requant": {
            "out3_multiplier_q31": int(attention_entry["out3_requant"]["multiplier_q31"]),
            "residual_multiplier_q31": int(attention_entry["residual_requant"]["multiplier_q31"]),
            "shift": int(attention_entry["out3_requant"]["shift"]),
        },
        "lane_mem_files": lane_mem_files,
    }
    (out_dir / "hashes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_a1_summary(summary), encoding="utf-8")
    return summary


def run_a2_six_blocks(args: argparse.Namespace) -> dict:
    manifest = load_json(resolve_path(args.rtl_manifest))
    post = load_json(resolve_path(args.postprocess_manifest))
    bits = int(manifest["activation_bits"])
    channels = int(manifest["channels"])
    if channels != args.lanes * args.out_ch_per_lane:
        raise AssertionError(f"channels={channels} does not match {args.lanes} lanes x {args.out_ch_per_lane}")

    feature = make_input_feature(args.height, args.width, channels, bits)
    out_dir = resolve_path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    np.save(out_dir / "block_0_input.npy", feature)
    write_txt(out_dir / "block_0_input.txt", feature)

    block_hashes = {"block_0_input_hash": hash_full48(feature)}
    block_outputs = {"block_0_input": str(out_dir / "block_0_input.npy")}
    per_block_stage_hashes: dict[str, dict[str, str]] = {}
    lane_hashes: dict[str, dict[str, str]] = {}
    lane_mem_files: dict[str, dict[str, dict[str, dict]]] = {}
    postprocess_entries: dict[str, dict[str, dict]] = {}

    for block in range(1, args.blocks + 1):
        stages = spab_block_reference(feature, manifest, post, block, bits)
        c1 = find_layer(manifest, f"block_{block}.c1_r")
        c2 = find_layer(manifest, f"block_{block}.c2_r")
        c3 = find_layer(manifest, f"block_{block}.c3_r")
        postprocess_entries[f"block_{block}"] = {
            "act1": find_postprocess_entry(post, f"block_{block}.act1"),
            "act2": find_postprocess_entry(post, f"block_{block}.act2"),
            "attention": find_postprocess_entry(post, f"block_{block}.attention"),
        }
        lane_mem_files[f"block_{block}"] = {
            "c1": emit_lane_mems(c1, out_dir / f"block_{block}" / "c1", args.lanes, args.out_ch_per_lane),
            "c2": emit_lane_mems(c2, out_dir / f"block_{block}" / "c2", args.lanes, args.out_ch_per_lane),
            "c3": emit_lane_mems(c3, out_dir / f"block_{block}" / "c3", args.lanes, args.out_ch_per_lane),
        }
        block_dir = out_dir / f"block_{block}"
        block_dir.mkdir(parents=True, exist_ok=True)
        per_block_stage_hashes[f"block_{block}"] = {}
        for stage_name, values in stages.items():
            np.save(block_dir / f"{stage_name}.npy", values)
            write_txt(block_dir / f"{stage_name}.txt", values)
            per_block_stage_hashes[f"block_{block}"][f"{stage_name}_hash"] = hash_full48(values)
        feature = stages["block_output"]
        np.save(out_dir / f"block_{block}_output.npy", feature)
        write_txt(out_dir / f"block_{block}_output.txt", feature)
        block_hashes[f"block_{block}_output_hash"] = hash_full48(feature)
        block_outputs[f"block_{block}_output"] = str(out_dir / f"block_{block}_output.npy")

        lanes = lane_slices(feature, args.lanes, args.out_ch_per_lane)
        stitched = np.concatenate(lanes, axis=2)
        if not np.array_equal(stitched, feature):
            raise AssertionError(f"A2 lane stitching mismatch at block {block}")
        lane_hashes[f"block_{block}_output"] = {
            f"lane{lane}_hash": hash_values(values) for lane, values in enumerate(lanes)
        }

    sv_defines = emit_a2_sv_file_defines(out_dir, lane_mem_files, postprocess_entries)
    summary = {
        "status": "PASS",
        "stage": "A2_six_blocks",
        "rtl_manifest": str(resolve_path(args.rtl_manifest)),
        "postprocess_manifest": str(resolve_path(args.postprocess_manifest)),
        "activation_bits": bits,
        "height": args.height,
        "width": args.width,
        "channels": channels,
        "blocks": args.blocks,
        "lanes": args.lanes,
        "out_ch_per_lane": args.out_ch_per_lane,
        "hash_algorithm": "rotl5_xor_indexed_v1",
        "block_hashes": block_hashes,
        "per_block_stage_hashes": per_block_stage_hashes,
        "lane_hashes": lane_hashes,
        "outputs": block_outputs,
        "sv_defines": str(sv_defines),
        "lane_mem_files": lane_mem_files,
    }
    (out_dir / "hashes.json").write_text(json.dumps(block_hashes, indent=2), encoding="utf-8")
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_a2_summary(summary), encoding="utf-8")
    return summary


def run_a3_tail_rgb(args: argparse.Namespace) -> dict:
    manifest = load_json(resolve_path(args.rtl_manifest))
    post = load_json(resolve_path(args.postprocess_manifest))
    quant_plan = load_json(resolve_path(manifest["quant_plan"]))
    scales = quant_plan["activation_scale_table"]
    bits = int(manifest["activation_bits"])
    channels = int(manifest["channels"])

    feat0 = make_input_feature(args.height, args.width, channels, bits)
    feature = feat0
    b1 = None
    b6_act1 = None
    block_outputs: dict[str, np.ndarray] = {"feat0": feat0}
    for block in range(1, 7):
        stages = spab_block_reference(feature, manifest, post, block, bits)
        if block == 1:
            b1 = stages["block_output"]
        if block == 6:
            b6_act1 = stages["act1"]
        feature = stages["block_output"]
        block_outputs[f"block_{block}_output"] = feature
    if b1 is None or b6_act1 is None:
        raise AssertionError("Missing b1 or b6_act1 for conv_cat")

    conv2 = conv_layer_reference(feature, find_layer(manifest, "conv_2"), bits)
    cat_mults = {
        "feat0": q31_ratio(scales["conv_1.output"], scales["conv_cat.input"]),
        "b6conv": q31_ratio(scales["conv_2.output"], scales["conv_cat.input"]),
        "b1": q31_ratio(scales["block_1.out"], scales["conv_cat.input"]),
        "b6_act1": q31_ratio(scales["block_6.act1"], scales["conv_cat.input"]),
    }
    cat_input = concat_for_conv_cat_reference(
        feat0=feat0,
        b6conv=conv2,
        b1=b1,
        b6_act1=b6_act1,
        multipliers=cat_mults,
        bits=bits,
    )
    cat = conv_layer_reference(cat_input, find_layer(manifest, "conv_cat"), bits)
    up = conv_layer_reference(cat, find_layer(manifest, "upsampler.0"), bits)
    rgb_q = pixelshuffle_reference(up, scale=int(manifest["scale"]), out_ch=3)

    out_dir = resolve_path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    arrays = {
        **block_outputs,
        "conv2": conv2,
        "cat_input": cat_input,
        "conv_cat": cat,
        "upsampler_0": up,
        "rgb_q": rgb_q,
    }
    for name, values in arrays.items():
        np.save(out_dir / f"{name}.npy", values)
        write_txt(out_dir / f"{name}.txt", values)

    hashes = {f"{name}_hash": hash_values(values) for name, values in arrays.items()}
    summary = {
        "status": "PASS",
        "stage": "A3_tail_rgb",
        "rtl_manifest": str(resolve_path(args.rtl_manifest)),
        "postprocess_manifest": str(resolve_path(args.postprocess_manifest)),
        "activation_bits": bits,
        "height": args.height,
        "width": args.width,
        "channels": channels,
        "scale": int(manifest["scale"]),
        "out_height": int(rgb_q.shape[0]),
        "out_width": int(rgb_q.shape[1]),
        "out_channels": int(rgb_q.shape[2]),
        "hash_algorithm": "rotl5_xor_indexed_v1",
        "cat_requant_q31": cat_mults,
        "hashes": hashes,
        "outputs": {f"{name}_npy": str(out_dir / f"{name}.npy") for name in arrays},
    }
    (out_dir / "hashes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_a3_summary(summary), encoding="utf-8")
    return summary


def render_a0_summary(summary: dict) -> str:
    hashes = summary["hashes"]
    return "\n".join(
        [
            "# A0 Single Conv 3-Lane Reference",
            "",
            f"Status: {summary['status']}",
            "",
            "## Config",
            "",
            f"- layer: `{summary['layer']}`",
            f"- shape: `{summary['height']}x{summary['width']}x{summary['channels']}`",
            f"- lanes: `{summary['lanes']} x {summary['out_ch_per_lane']}ch`",
            f"- activation_bits: `{summary['activation_bits']}`",
            f"- bit_exact_lane_stitch: `{summary['bit_exact_lane_stitch']}`",
            "",
            "## Hashes",
            "",
            "| Name | Value |",
            "| --- | --- |",
            *[f"| `{key}` | `{value}` |" for key, value in hashes.items()],
            "",
            "## Outputs",
            "",
            *[f"- `{key}`: `{value}`" for key, value in summary["outputs"].items()],
            "",
            "## Lane Mems",
            "",
            *[
                f"- `{lane}.{kind}`: `{path}`"
                for lane, files in summary["lane_mem_files"].items()
                for kind, path in files.items()
            ],
            "",
        ]
    )


def render_a1_summary(summary: dict) -> str:
    hashes = summary["hashes"]
    lines = [
        "# A1 Single SPAB Block 3-Lane Reference",
        "",
        f"Status: {summary['status']}",
        "",
        "## Config",
        "",
        f"- block: `{summary['block']}`",
        f"- shape: `{summary['height']}x{summary['width']}x{summary['channels']}`",
        f"- lanes: `{summary['lanes']} x {summary['out_ch_per_lane']}ch`",
        f"- activation_bits: `{summary['activation_bits']}`",
        f"- bit_exact_lane_stitch: `{summary['bit_exact_lane_stitch']}`",
        "",
        "## Hashes",
        "",
        "| Name | Value |",
        "| --- | --- |",
        *[f"| `{key}` | `{value}` |" for key, value in hashes.items()],
        "",
        "## Lane Hashes",
        "",
        "| Stage | Lane | Value |",
        "| --- | --- | --- |",
    ]
    for stage_name, stage_hashes in summary["lane_hashes"].items():
        for lane_name, value in stage_hashes.items():
            lines.append(f"| `{stage_name}` | `{lane_name}` | `{value}` |")
    lines.extend(
        [
            "",
            "## Attention Requant",
            "",
            *[f"- `{key}`: `{value}`" for key, value in summary["attention_requant"].items()],
            "",
            "## Outputs",
            "",
            *[f"- `{key}`: `{value}`" for key, value in summary["outputs"].items()],
            "",
        ]
    )
    return "\n".join(lines)


def render_a2_summary(summary: dict) -> str:
    lines = [
        "# A2 Six SPAB Blocks Python Reference",
        "",
        f"Status: {summary['status']}",
        "",
        "## Config",
        "",
        f"- shape: `{summary['height']}x{summary['width']}x{summary['channels']}`",
        f"- blocks: `{summary['blocks']}`",
        f"- lanes: `{summary['lanes']} x {summary['out_ch_per_lane']}ch`",
        f"- activation_bits: `{summary['activation_bits']}`",
        "",
        "## Block Boundary Hashes",
        "",
        "| Name | Value |",
        "| --- | --- |",
        *[f"| `{key}` | `{value}` |" for key, value in summary["block_hashes"].items()],
        "",
        "## Final Output Lane Hashes",
        "",
        "| Block Output | Lane | Value |",
        "| --- | --- | --- |",
    ]
    for block_name, block_lane_hashes in summary["lane_hashes"].items():
        for lane_name, value in block_lane_hashes.items():
            lines.append(f"| `{block_name}` | `{lane_name}` | `{value}` |")
    lines.extend(
        [
            "",
            "## Outputs",
            "",
            *[f"- `{key}`: `{value}`" for key, value in summary["outputs"].items()],
            "",
        ]
    )
    return "\n".join(lines)


def render_a3_summary(summary: dict) -> str:
    lines = [
        "# A3 Tail / PixelShuffle / RGB Python Reference",
        "",
        f"Status: {summary['status']}",
        "",
        "## Config",
        "",
        f"- input shape: `{summary['height']}x{summary['width']}x{summary['channels']}`",
        f"- scale: `x{summary['scale']}`",
        f"- output shape: `{summary['out_height']}x{summary['out_width']}x{summary['out_channels']}`",
        f"- activation_bits: `{summary['activation_bits']}`",
        "",
        "## Cat Requant Q31",
        "",
        "| Source | Multiplier |",
        "| --- | --- |",
        *[f"| `{key}` | `{value}` |" for key, value in summary["cat_requant_q31"].items()],
        "",
        "## Hashes",
        "",
        "| Name | Value |",
        "| --- | --- |",
        *[f"| `{key}` | `{value}` |" for key, value in summary["hashes"].items()],
        "",
        "## Outputs",
        "",
        *[f"- `{key}`: `{value}`" for key, value in summary["outputs"].items()],
        "",
    ]
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="W8A12_3lane Python reference tools.")
    sub = parser.add_subparsers(dest="command", required=True)

    a0 = sub.add_parser("a0-single-conv", help="Generate A0 3-lane single-conv reference.")
    a0.add_argument("--rtl-manifest", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rtl_manifest.json"))
    a0.add_argument("--layer", default="block_1.c1_r")
    a0.add_argument("--height", type=int, default=4)
    a0.add_argument("--width", type=int, default=4)
    a0.add_argument("--lanes", type=int, default=3)
    a0.add_argument("--out-ch-per-lane", type=int, default=16)
    a0.add_argument("--out-dir", type=Path, default=Path("W8A12_3lane/evidence/reference/A0_single_conv"))

    a1 = sub.add_parser("a1-single-block", help="Generate A1 3-lane single-SPAB-block reference.")
    a1.add_argument("--rtl-manifest", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rtl_manifest.json"))
    a1.add_argument(
        "--postprocess-manifest",
        type=Path,
        default=Path("rtl/generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json"),
    )
    a1.add_argument("--block", type=int, default=1)
    a1.add_argument("--height", type=int, default=4)
    a1.add_argument("--width", type=int, default=4)
    a1.add_argument("--lanes", type=int, default=3)
    a1.add_argument("--out-ch-per-lane", type=int, default=16)
    a1.add_argument("--out-dir", type=Path, default=Path("W8A12_3lane/evidence/reference/A1_single_block"))

    a2 = sub.add_parser("a2-six-blocks", help="Generate A2 six-SPAB-block Python fixed-point reference.")
    a2.add_argument("--rtl-manifest", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rtl_manifest.json"))
    a2.add_argument(
        "--postprocess-manifest",
        type=Path,
        default=Path("rtl/generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json"),
    )
    a2.add_argument("--blocks", type=int, default=6)
    a2.add_argument("--height", type=int, default=4)
    a2.add_argument("--width", type=int, default=4)
    a2.add_argument("--lanes", type=int, default=3)
    a2.add_argument("--out-ch-per-lane", type=int, default=16)
    a2.add_argument("--out-dir", type=Path, default=Path("W8A12_3lane/evidence/reference/A2_six_blocks"))

    a3 = sub.add_parser("a3-tail-rgb", help="Generate A3 tail/pixelshuffle/RGB Python fixed-point reference.")
    a3.add_argument("--rtl-manifest", type=Path, default=Path("rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rtl_manifest.json"))
    a3.add_argument(
        "--postprocess-manifest",
        type=Path,
        default=Path("rtl/generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json"),
    )
    a3.add_argument("--height", type=int, default=4)
    a3.add_argument("--width", type=int, default=4)
    a3.add_argument("--out-dir", type=Path, default=Path("W8A12_3lane/evidence/reference/A3_tail_rgb"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "a0-single-conv":
        summary = run_a0_single_conv(args)
        print(json.dumps({"status": summary["status"], "summary": summary["outputs"], "hashes": summary["hashes"]}, indent=2))
    elif args.command == "a1-single-block":
        summary = run_a1_single_block(args)
        print(json.dumps({"status": summary["status"], "summary": summary["outputs"], "hashes": summary["hashes"]}, indent=2))
    elif args.command == "a2-six-blocks":
        summary = run_a2_six_blocks(args)
        print(json.dumps({"status": summary["status"], "summary": summary["outputs"], "hashes": summary["block_hashes"]}, indent=2))
    elif args.command == "a3-tail-rgb":
        summary = run_a3_tail_rgb(args)
        print(json.dumps({"status": summary["status"], "summary": summary["outputs"], "hashes": summary["hashes"]}, indent=2))
    else:
        raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    main()
