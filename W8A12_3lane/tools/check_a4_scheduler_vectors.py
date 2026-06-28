#!/usr/bin/env python3
"""Offline vector check for the A4 W8A12 3-lane MAC schedulers.

This checker mirrors the RTL testbenches:
  * input layout: pixel-major, 48 channels per pixel
  * window layout: channel-major, 3x3 taps per channel
  * lane layout: 3 lanes x 16 output channels
  * requant: span_w8a12_requant.v default path

It is intentionally stricter than a file-existence check, but it is not a
replacement for Vivado xsim/OOC gates.
"""

from __future__ import annotations

import argparse
import json
import re
import zlib
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
A0_DIR = REPO / "W8A12_3lane" / "evidence" / "reference" / "A0_single_conv"
OUT_DIR = REPO / "W8A12_3lane" / "evidence" / "resource" / "A4_scheduler_vector_check"

IMG_W = 4
IMG_H = 4
PIXELS = IMG_W * IMG_H
IN_CH = 48
LANE_CH = 16
KERNEL_TAPS = 9
ACT_W = 12
TAP_COUNT = IN_CH * KERNEL_TAPS


def signed_from_width(value: int, width: int) -> int:
    mask = (1 << width) - 1
    value &= mask
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def read_dec_vector(path: Path) -> list[int]:
    return [int(line.strip()) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def read_memh(path: Path, width: int) -> list[int]:
    out: list[int] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("//", 1)[0].strip()
        if not line:
            continue
        out.append(signed_from_width(int(line, 16), width))
    return out


def crc32_i12(values: list[int]) -> str:
    data = bytearray()
    for v in values:
        u = v & ((1 << ACT_W) - 1)
        data.extend(u.to_bytes(2, "little", signed=False))
    return f"0x{zlib.crc32(data) & 0xFFFFFFFF:08X}"


def parse_expected_hashes(summary: Path) -> dict[str, str]:
    text = summary.read_text(encoding="utf-8")
    hashes: dict[str, str] = {}
    for key, value in re.findall(r"- `([^`]+)`: `(0x[0-9A-Fa-f]+)`", text):
        hashes[key] = value.upper()
    return hashes


def requant(acc: int, bias_i64: int, q31: int, shift: int) -> int:
    product = acc * q31 + bias_i64
    if shift:
        offset = 1 << (shift - 1)
        if product >= 0:
            shifted = (product + offset) >> shift
        else:
            shifted = -(((-product) + offset) >> shift)
    else:
        shifted = product

    sat_max = (1 << (ACT_W - 1)) - 1
    sat_min = -(1 << (ACT_W - 1))
    return max(sat_min, min(sat_max, shifted))


def build_window(input_feature: list[int], pix: int) -> list[int]:
    px = pix % IMG_W
    py = pix // IMG_W
    window: list[int] = []
    for ch in range(IN_CH):
        for ky in range(3):
            for kx in range(3):
                sx = px + kx - 1
                sy = py + ky - 1
                if 0 <= sx < IMG_W and 0 <= sy < IMG_H:
                    window.append(input_feature[(sy * IMG_W + sx) * IN_CH + ch])
                else:
                    window.append(0)
    return window


def compute_lane(input_feature: list[int], lane: int) -> list[int]:
    mem_dir = A0_DIR / "lane_mems"
    prefix = f"lane{lane}_block_1_c1_r"
    weights = read_memh(mem_dir / f"{prefix}_w_i8.mem", 8)
    biases = read_memh(mem_dir / f"{prefix}_bias_i64.mem", 64)
    requants = read_memh(mem_dir / f"{prefix}_requant_q31.mem", 32)
    shifts = read_memh(mem_dir / f"{prefix}_requant_shift_u8.mem", 8)

    assert len(weights) == LANE_CH * TAP_COUNT
    assert len(biases) == LANE_CH
    assert len(requants) == LANE_CH
    assert len(shifts) == LANE_CH

    outputs: list[int] = []
    for pix in range(PIXELS):
        window = build_window(input_feature, pix)
        for out_idx in range(LANE_CH):
            base = out_idx * TAP_COUNT
            acc = 0
            for tap in range(TAP_COUNT):
                acc += window[tap] * weights[base + tap]
            outputs.append(requant(acc, biases[out_idx], requants[out_idx], shifts[out_idx]))
    return outputs


def stitch_lanes(lanes: list[list[int]]) -> list[int]:
    stitched: list[int] = []
    for pix in range(PIXELS):
        for lane in range(3):
            start = pix * LANE_CH
            stitched.extend(lanes[lane][start : start + LANE_CH])
    return stitched


def write_outputs(summary: dict[str, object], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    lines = [
        "# A4 Scheduler Vector Check",
        "",
        f"Status: {summary['status']}",
        "",
        "| Item | Value |",
        "| --- | --- |",
    ]
    for key in ["single_lane0_hash", "lane1_hash", "lane2_hash", "stitched_hash", "expected_full48_hash", "mismatches"]:
        lines.append(f"| `{key}` | `{summary[key]}` |")
    lines.extend(
        [
            "",
            "说明：该检查复现 RTL testbench 的 A0 输入窗口、3-lane 通道拼接和 `span_w8a12_requant` 公式，用于提前验证 A4 scheduler 的映射规则。",
            "它不能替代 Vivado xsim 和 OOC 综合，最终交付仍要求对应仿真/资源报告 PASS。",
            "",
        ]
    )
    (out_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()

    input_feature = read_dec_vector(A0_DIR / "input_feature.txt")
    expected = read_dec_vector(A0_DIR / "full48_output.txt")
    if len(input_feature) != PIXELS * IN_CH:
        raise RuntimeError(f"unexpected input length: {len(input_feature)}")
    if len(expected) != PIXELS * IN_CH:
        raise RuntimeError(f"unexpected expected length: {len(expected)}")

    lanes = [compute_lane(input_feature, lane) for lane in range(3)]
    stitched = stitch_lanes(lanes)
    mismatches = sum(1 for a, b in zip(stitched, expected) if a != b)
    expected_hashes = parse_expected_hashes(A0_DIR / "a0_rtl_sim_summary.md")

    summary: dict[str, object] = {
        "status": "PASS" if mismatches == 0 else "FAIL",
        "single_lane0_hash": crc32_i12(lanes[0]),
        "lane1_hash": crc32_i12(lanes[1]),
        "lane2_hash": crc32_i12(lanes[2]),
        "stitched_hash": crc32_i12(stitched),
        "expected_full48_hash": crc32_i12(expected),
        "mismatches": mismatches,
        "expected_hashes_from_a0": expected_hashes,
        "note": "Offline vector check only; Vivado xsim/OOC remain mandatory gates.",
    }
    write_outputs(summary, args.out_dir)
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
