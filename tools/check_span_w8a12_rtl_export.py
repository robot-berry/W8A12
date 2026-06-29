"""Check that a SPAN W8A12 RTL export matches its source quantization plan."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_i8_binary(path: Path) -> list[int]:
    data = path.read_bytes()
    return [byte - 256 if byte >= 128 else byte for byte in data]


def read_i64_binary(path: Path) -> list[int]:
    data = path.read_bytes()
    if len(data) % 8 != 0:
        raise ValueError(f"int64 binary size is not aligned: {path}")
    return [int.from_bytes(data[idx : idx + 8], "little", signed=True) for idx in range(0, len(data), 8)]


def read_hex_mem(path: Path, bits: int) -> list[int]:
    sign_bit = 1 << (bits - 1)
    mask = (1 << bits) - 1
    values = []
    for line in path.read_text(encoding="ascii").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        value = int(line, 16) & mask
        if value & sign_bit:
            value -= 1 << bits
        values.append(value)
    return values


def compare(name: str, expected: list[int], actual: list[int]) -> None:
    if len(expected) != len(actual):
        raise AssertionError(f"{name}: length mismatch {len(actual)} != {len(expected)}")
    for idx, (exp, got) in enumerate(zip(expected, actual)):
        if exp != got:
            raise AssertionError(f"{name}: mismatch at {idx}: got {got}, expected {exp}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check SPAN W8A12 RTL export consistency.")
    parser.add_argument("--rtl-manifest", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rtl_manifest = json.loads(args.rtl_manifest.read_text(encoding="utf-8"))
    quant_plan_path = Path(rtl_manifest["quant_plan"])
    quant_plan = json.loads(quant_plan_path.read_text(encoding="utf-8"))
    if int(rtl_manifest["layer_count"]) != len(quant_plan["layers"]):
        raise AssertionError("layer count mismatch")
    if int(rtl_manifest["activation_scale_count"]) != len(quant_plan["activation_scale_table"]):
        raise AssertionError("activation scale count mismatch")

    for plan_layer, rtl_layer in zip(quant_plan["layers"], rtl_manifest["layers"]):
        name = plan_layer["name"]
        if name != rtl_layer["name"]:
            raise AssertionError(f"layer name mismatch: {rtl_layer['name']} != {name}")
        plan_weight = read_i8_binary(quant_plan_path.parent / plan_layer["weight_file_i8_bin"])
        plan_bias = read_i64_binary(quant_plan_path.parent / plan_layer["bias_file_i64_bin"])
        plan_requant = [int(item["multiplier_q31"]) for item in plan_layer["requant"]]
        plan_shift = [int(item["shift"]) for item in plan_layer["requant"]]

        compare(f"{name}.weight", plan_weight, read_hex_mem(Path(rtl_layer["weight_mem"]), 8))
        compare(f"{name}.bias", plan_bias, read_hex_mem(Path(rtl_layer["bias_mem"]), 64))
        compare(f"{name}.requant", plan_requant, read_hex_mem(Path(rtl_layer["requant_q31_mem"]), 32))
        compare(f"{name}.shift", plan_shift, read_hex_mem(Path(rtl_layer["requant_shift_mem"]), 8))

    print(
        json.dumps(
            {
                "status": "PASS",
                "rtl_manifest": str(args.rtl_manifest),
                "quant_plan": str(quant_plan_path),
                "layers": int(rtl_manifest["layer_count"]),
                "activation_scales": int(rtl_manifest["activation_scale_count"]),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
