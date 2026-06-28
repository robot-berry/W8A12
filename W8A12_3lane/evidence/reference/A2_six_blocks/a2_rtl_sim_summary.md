# A2 六个 SPAB Block RTL 语义仿真记录

## 状态

PASS

## 命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_six_blocks.ps1
```

## 仿真环境

- Vivado: `v2025.2`
- Part: `xczu19eg-ffvc1760-2-i`
- Testbench: `W8A12_3lane/sim/tb_w8a12_3lane_six_blocks.sv`
- Testbench generator: `W8A12_3lane/tools/generate_a2_six_blocks_tb.py`
- 3-lane conv wrapper: `W8A12_3lane/rtl/span/w8a12_3lane_conv_layer.v`
- LUT RTL: `rtl/span/span_w8a12_unary_lut.v`
- Attention RTL: `rtl/span/span_w8a12_attention.v`

## 通过信息

```text
PASS w8a12_3lane_six_blocks blocks=6 pixels=16 channels=48
```

## 覆盖范围

本次仿真覆盖 `block_1` 到 `block_6` 的三路 output-channel 并行语义：

- 每个 block 的 `c1_r`、`c2_r`、`c3_r` 都使用 `w8a12_3lane_conv_layer`。
- 每个 block 的 `act1`、`act2`、`sim_att` 使用导出的 W8A12 LUT。
- 每个 block 的 attention 使用导出的 Q31 multiplier 和 shift。
- 每个 block 的 C1/C2/C3/LUT/attention 中间输出逐元素对齐 Python fixed-point reference。
- `block_6_output` 对齐 Python reference，hash 为 `0xD2AC6553`。

注意：这是 4x4 feature frame 的 RTL 语义仿真，用于证明 6 个 SPAB block 在三路 output-channel 并行下数学结果不变；可综合的 tile scheduler、feature bank ping-pong 和上板通路仍需后续 A3/A4/A5 完成。

## Block 边界 Hash

| 项目 | Hash |
| --- | --- |
| `block_0_input` | `0x47766845` |
| `block_1_output` | `0xD12E1B43` |
| `block_2_output` | `0x8C609E9C` |
| `block_3_output` | `0xF686415B` |
| `block_4_output` | `0x110F1273` |
| `block_5_output` | `0x0FB25029` |
| `block_6_output` | `0xD2AC6553` |

## 日志

```text
build/vivado_w8a12_3lane_six_blocks_sim/w8a12_3lane_six_blocks_sim.sim/sim_1/behav/xsim/simulate.log
```
