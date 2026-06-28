# A3 Tail / PixelShuffle / RGB RTL 语义仿真记录

## 状态

PASS

## 生成命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\generate_a3_tail_frame_tb.ps1
```

## 仿真命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_a3_tail_frame.ps1
```

## 通过信息

```text
PASS span_w8a12_tail_frame values=768
```

## 覆盖范围

本次仿真使用 A3 deterministic `4x4x48` feature 输入，输出 `16x16x3` RGB q 值，共 768 个输出值。

覆盖路径：

```text
feat0
  -> block_1..block_6
  -> conv_2
  -> conv_cat
  -> upsampler.0
  -> pixelshuffle x4
  -> RGB q output
```

说明：

- 该 testbench 由旧线 `tools/generate_span_w8a12_tail_frame_tb.py` 生成，使用已验证的 W8A12 serial RTL primitive 验证 tail/RGB 语义。
- A2 已单独证明 6 个 SPAB block 在 3-lane output-channel 并行下与 Python fixed-point reference bit-exact。
- 本次 A3 证明 tail、conv_cat、upsampler 和 pixelshuffle 的 RGB 输出与 Python fixed-point reference bit-exact。

## 关键 Hash

| 项目 | Hash |
| --- | --- |
| `block_6_output` | `0xD2AC6553` |
| `conv2` | `0x7C22A0C6` |
| `cat_input` | `0x731D1CD9` |
| `conv_cat` | `0xE6DF97F6` |
| `upsampler_0` | `0x9630BB9C` |
| `rgb_q` | `0x280F9356` |

## 产物

- Generated testbench: `W8A12_3lane/evidence/reference/A3_tail_rgb/rtl_tail_frame_tb/tb_span_w8a12_tail_frame.sv`
- Reference RGB dump: `W8A12_3lane/evidence/reference/A3_tail_rgb/rtl_tail_frame_tb/span_w8a12_tail_frame_rgb_ref.txt`
- Simulation log: `build/vivado_w8a12_3lane_a3_tail_frame_sim/vivado_w8a12_3lane_a3_tail_frame_sim.sim/sim_1/behav/xsim/simulate.log`
