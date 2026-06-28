# A1 单个 SPAB Block RTL 仿真记录

## 状态

PASS

## 命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_single_block.ps1
```

## 仿真环境

- Vivado: `v2025.2`
- Part: `xczu19eg-ffvc1760-2-i`
- Testbench: `W8A12_3lane/sim/tb_w8a12_3lane_single_block.sv`
- RTL wrapper: `W8A12_3lane/rtl/span/w8a12_3lane_conv_layer.v`
- LUT RTL: `rtl/span/span_w8a12_unary_lut.v`
- Attention RTL: `rtl/span/span_w8a12_attention.v`

## 通过信息

```text
PASS w8a12_3lane_single_block pixels=16 channels=48
```

## 覆盖范围

本次仿真覆盖单个 `block_1` SPAB 的最小闭环：

- `c1_r`: 3 路 output-channel 并行卷积，与 Python `c1_raw` bit-exact。
- `act1`: SiLU LUT，与 Python `act1` bit-exact。
- `c2_r`: 3 路 output-channel 并行卷积，与 Python `c2_raw` bit-exact。
- `act2`: SiLU LUT，与 Python `act2` bit-exact。
- `c3_r`: 3 路 output-channel 并行卷积，与 Python `c3_raw` bit-exact。
- `sim_att`: attention LUT，与 Python `sim_att` bit-exact。
- `attention + residual`: 与 Python `block_output` bit-exact。

## 关键 Hash

| 项目 | Hash |
| --- | --- |
| `block_input` | `0x47766845` |
| `c1_raw` | `0x080D3C47` |
| `act1` | `0x608EB896` |
| `c2_raw` | `0x0A7D238A` |
| `act2` | `0x17B3C9F8` |
| `c3_raw` | `0x19F8FA9A` |
| `sim_att` | `0x9EBD7351` |
| `block_output` | `0xD12E1B43` |

## 日志

```text
build/vivado_w8a12_3lane_single_block_sim/w8a12_3lane_single_block_sim.sim/sim_1/behav/xsim/simulate.log
```
