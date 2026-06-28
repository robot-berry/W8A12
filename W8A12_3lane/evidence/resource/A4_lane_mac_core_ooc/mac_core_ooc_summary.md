# A4 Lane MAC Core OOC 资源基线

## 状态

RESOURCE GATE PASS / TIMING TODO

## 背景

直接综合 `span_w8a12_conv_layer` 和 `w8a12_3lane_conv_layer` 会让常量 bank 与完整 48x9 乘加网络大规模展开，OOC 综合超时。A4 因此先拆出 synthesis-friendly MAC 基线，用于后续 single-lane scheduler 的资源估算。

## RTL

- MAC core: `W8A12_3lane/rtl/span/w8a12_lane_mac_core.v`
- Testbench: `W8A12_3lane/sim/tb_w8a12_lane_mac_core.sv`
- TAP_PAR: `8`
- ACT_W: `12`
- WEIGHT_W: `8`
- ACC_W: `48`

## 功能仿真

```text
PASS w8a12_lane_mac_core cases=16 tap_par=8
```

仿真脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_lane_mac_core.ps1
```

## OOC 资源

资源报告：

```text
W8A12_3lane/evidence/resource/A4_lane_mac_core_ooc/utilization_ooc.rpt
```

XC7Z045 gate：

```text
W8A12_3lane/evidence/resource/A4_lane_mac_core_ooc/xc7z045_resource_gate.json
```

| 资源 | 数值 | XC7Z045 门限 | 状态 |
| --- | ---: | ---: | --- |
| LUT | 51 | 218600 | PASS |
| FF/REG | 49 | 437200 | PASS |
| BRAM Tile | 0 | 545 | PASS |
| DSP | 8 | 900 | PASS |
| URAM | 0 | 0 | PASS |

## MAC IP 结论

Vivado 可以直接调用或推断 MAC 相关硬核：

- `DSP48E2` primitive：最直接、资源最可控，适合本项目。
- RTL 乘加推断：当前 `w8a12_lane_mac_core` 已被 Vivado 推断为 8 个 `DSP48E2`。
- IP Catalog 中的 Multiplier/FIR/Math 类 IP：可以用，但对 W8A12 的自定义 window 调度、weight ROM、bias/requant 连接帮助有限。

本项目建议优先使用 RTL 推断或显式 `DSP48E2` primitive，不建议把核心卷积包装成通用 IP Catalog MAC。原因是 SPAN W8A12 需要自定义 48x9 tap 调度、per-output-channel weight ROM、bias/requant 和三路 output-channel 并行，通用 IP 接口会增加集成复杂度。

## 待完成

1. 增加 lane scheduler：循环 48x9 taps，复用 `w8a12_lane_mac_core`。
2. 增加同步 ROM/BRAM 常量读取。
3. 接入 `span_w8a12_requant`。
4. 生成 single-lane 和 three-lane OOC 资源/timing 报告。
