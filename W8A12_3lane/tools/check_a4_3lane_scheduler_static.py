#!/usr/bin/env python3
"""Static acceptance checks for the W8A12 3-lane A4 scheduler path.

This check is intentionally conservative: it does not claim RTL simulation PASS.
It verifies that the scheduler/TB/OOC files are wired to the A0 bit-exact fixture
with the intended 3 x 16 output-channel lane mapping.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
A0 = ROOT / "W8A12_3lane" / "evidence" / "reference" / "A0_single_conv"
RTL = ROOT / "W8A12_3lane" / "rtl" / "span"
SIM = ROOT / "W8A12_3lane" / "sim"
SCRIPTS = ROOT / "W8A12_3lane" / "scripts"
OUT = ROOT / "W8A12_3lane" / "evidence" / "resource" / "A4_3lane_mac_scheduler"

REQUIRED = [
    A0 / "a0_3lane_files.vh",
    A0 / "input_feature.txt",
    A0 / "full48_output.txt",
    RTL / "w8a12_lane_mac_core.v",
    RTL / "w8a12_single_out_mac_scheduler.v",
    RTL / "w8a12_single_lane_mac_scheduler.v",
    RTL / "w8a12_3lane_mac_scheduler.v",
    RTL / "w8a12_single_lane_mac_scheduler_ooc_top.v",
    RTL / "w8a12_3lane_mac_scheduler_ooc_top.v",
    SIM / "tb_w8a12_single_lane_mac_scheduler.sv",
    SIM / "tb_w8a12_3lane_mac_scheduler.sv",
    SCRIPTS / "run_vivado_sim_w8a12_single_lane_mac_scheduler.tcl",
    SCRIPTS / "run_vivado_sim_w8a12_3lane_mac_scheduler.tcl",
    SCRIPTS / "run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.tcl",
    SCRIPTS / "run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.tcl",
]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(cond: bool, name: str, details: str, checks: list[dict]) -> None:
    checks.append({"name": name, "pass": bool(cond), "details": details})


def write(ok: bool, checks: list[dict]) -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "checks": checks}
    (OUT / "a4_3lane_static_check.json").write_text(
        json.dumps(data, indent=2), encoding="utf-8"
    )
    lines = [
        "# A4 3-Lane Static Check",
        "",
        f"状态：{'PASS' if ok else 'FAIL'}",
        "",
        "| 检查项 | 结果 | 说明 |",
        "| --- | --- | --- |",
    ]
    for item in checks:
        result = "PASS" if item["pass"] else "FAIL"
        lines.append(f"| `{item['name']}` | {result} | {item['details']} |")
    lines.append("")
    lines.append(
        "该检查不替代 Vivado/xsim 仿真；它只证明 A4 3-lane scheduler 的文件绑定、lane 拆分和 A0 fixture 对齐关系。"
    )
    (OUT / "a4_3lane_static_check.md").write_text("\n".join(lines), encoding="utf-8")
    return 0 if ok else 1


def main() -> int:
    checks: list[dict] = []
    for path in REQUIRED:
        rel = path.relative_to(ROOT).as_posix()
        require(path.exists(), f"exists:{rel}", str(path), checks)

    if not all(c["pass"] for c in checks):
        return write(False, checks)

    inc = read(A0 / "a0_3lane_files.vh")
    scheduler = read(RTL / "w8a12_3lane_mac_scheduler.v")
    tb3 = read(SIM / "tb_w8a12_3lane_mac_scheduler.sv")
    tbs = read(SIM / "tb_w8a12_single_lane_mac_scheduler.sv")
    tcl3 = read(SCRIPTS / "run_vivado_sim_w8a12_3lane_mac_scheduler.tcl")
    ooc3 = read(SCRIPTS / "run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.tcl")

    for lane in range(3):
        for suffix in ["WEIGHT_MEM", "BIAS_MEM", "REQUANT_MEM", "SHIFT_MEM"]:
            macro = f"W8A12_3LANE_A0_LANE{lane}_{suffix}"
            require(macro in inc, f"macro:{macro}", "A0 include binds lane memory", checks)
            require(macro in tb3, f"tb3_uses:{macro}", "3-lane TB binds lane memory", checks)

    lane_inst = len(re.findall(r"w8a12_single_lane_mac_scheduler\s*#\(", scheduler))
    require(lane_inst == 3, "scheduler_instantiates_3_lanes", f"found {lane_inst}", checks)
    for lane in range(3):
        require(f"u_lane{lane}" in scheduler, f"scheduler_has_u_lane{lane}", "explicit lane instance", checks)
        slice_expr = f"feat_o[{lane}*LANE_CH*ACT_W +: LANE_CH*ACT_W]"
        require(slice_expr in scheduler, f"lane{lane}_packed_slice", "lane output slice is contiguous", checks)

    require("localparam int CH = 48" in tb3, "tb3_checks_48ch", "3-lane TB channel count", checks)
    require(
        "for (ch = 0; ch < CH; ch = ch + 1)" in tb3,
        "tb3_compares_all_channels",
        "3-lane TB loops all channels",
        checks,
    )
    require(
        "expected_full[out_pix*CH + ch]" in tb3,
        "tb3_expected_full_index",
        "3-lane TB compares against full48 output",
        checks,
    )
    require("PASS w8a12_3lane_mac_scheduler" in tb3, "tb3_pass_banner", "3-lane PASS banner exists", checks)

    require("localparam int LANE_CH = 16" in tbs, "single_lane_16ch", "single-lane TB lane width", checks)
    require(
        "expected_full[out_pix*CH + ch]" in tbs,
        "single_lane_expected_full_index",
        "single-lane TB compares lane0 against full48",
        checks,
    )

    for src in [
        "w8a12_lane_mac_core.v",
        "w8a12_single_out_mac_scheduler.v",
        "w8a12_single_lane_mac_scheduler.v",
        "w8a12_3lane_mac_scheduler.v",
    ]:
        require(src in tcl3, f"sim_tcl_adds:{src}", "3-lane sim Tcl source list", checks)
        require(src in ooc3, f"ooc_tcl_adds:{src}", "3-lane OOC Tcl source list", checks)

    input_count = len((A0 / "input_feature.txt").read_text(encoding="utf-8").splitlines())
    expected_count = len((A0 / "full48_output.txt").read_text(encoding="utf-8").splitlines())
    require(input_count == 16 * 48, "a0_input_count", f"{input_count} values", checks)
    require(expected_count == 16 * 48, "a0_expected_count", f"{expected_count} values", checks)

    return write(all(c["pass"] for c in checks), checks)


if __name__ == "__main__":
    raise SystemExit(main())
