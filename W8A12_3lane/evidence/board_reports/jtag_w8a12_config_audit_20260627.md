# JTAG W8A12 上板参数配置对照

日期：2026-06-27

## 结论

当前没有发现 JTAG-W8A12 上板路径存在器件、时钟、复位、JTAG-to-AXI 或 AXI-Lite 地址映射漏配问题。

本轮对照的关键结论是：

- `jtag_axi_register_probe` 已经在板上 PASS，证明 `USB-JTAG -> JTAG-to-AXI -> 0xA0000000` 的读写通路有效。
- `jtag_w8a12_tile_writer` 使用与已通过 JTAG 例程同类的 Block Design：PS 只提供 PL 时钟和复位，数据/control 均走 JTAG-to-AXI Master。
- 仍在运行的 true 2x2 JTAG-W8A12 bitstream flow 卡在 Vivado `route_design` 的 `Phase 5 Rip-up And Reroute`，当前现象更像完整 W8A12 endpoint 的布线收敛压力，而不是板卡参数配置错误。

## 对照项

| 配置项 | 已通过 JTAG register probe | 当前 JTAG-W8A12 true2x2 | 结论 |
| --- | --- | --- | --- |
| 器件 | `xczu19eg-ffvc1760-2-i` | `xczu19eg-ffvc1760-2-i` | 一致 |
| 控制访问主机 | Vivado Hardware Manager JTAG-to-AXI | Vivado Hardware Manager JTAG-to-AXI | 一致 |
| PS 角色 | 仅提供 PL clock/reset | 仅提供 PL clock/reset | 一致 |
| PL 时钟源 | `ps/pl_clk0` / IOPLL | `ps/pl_clk0` / IOPLL | 一致 |
| PL 频率 | probe 为 25 MHz | true2x2 为 25 MHz | 一致 |
| AXI-Lite 基址 | `0xA0000000` | `0xA0000000` | 一致 |
| AXI-Lite 范围 | `0x00010000` | `0x00010000` | 一致 |
| AXI-Lite 数据宽度 | 32-bit | 32-bit | 一致 |
| PS HPM/HP/DDR 数据口 | 不使用 | 不使用 | 一致 |
| 上板证明 | magic/scratch read-write PASS | 等待完整 W8A12 bitstream route 完成后验证 | probe 已证明通路 |

## 已通过的 JTAG 通路证据

最小 JTAG-to-AXI register probe 上板结果：

| 项目 | 数值 |
| --- | --- |
| 状态 | PASS |
| `ctrl base` | `0xA0000000` |
| `magic` | `0x57384158` |
| `version` | `0x00010000` |
| `status word` | `0x00000001` |
| `scratch` | `0xA5A55A5A` |
| `write count` | `2` |
| `read count` | `13` |

证据路径：

- `board_runs/jtag_axi_register_probe/f25m_20260627_0052_noprogram_clean/jtag_axi_register_probe_summary.md`

## 当前 true2x2 JTAG-W8A12 实现状态

当前正在运行的 bitstream flow：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_w8a12_tile_writer.ps1 `
  -ImgW 2 -TileW 2 -TileH 2 -Halo 21 -PlFreqMhz 25 `
  -OutLanes 1 -TapLanes 4 -ScaleLanes 1 `
  -SynthDirective Default -AttemptLabel true2x2_jtagaxi_20260627 `
  -VivadoMaxThreads 1 -RequireVivadoIdle
```

已完成：

- `synth_design` PASS；
- `opt_design` PASS；
- `place_design` PASS；
- `phys_opt_design` PASS；
- place 后 WNS 约 `11.946 ns`；
- 正在 `route_design`，当前日志阶段为 `Phase 5 Rip-up And Reroute`。

当前需等待：

- `jwtw_wrapper_routed.dcp`；
- `jwtw_wrapper.bit`；
- implementation utilization/timing report。

## 与 PS/DDR 版失败的区别

此前 PS/DDR 版 true2x2 的失败点主要包括：

- 正常 `psu_init` 后，首次写 `0xA0000000` 出现 AP transaction timeout；
- 跳过 `psu_init` 后，A53 访问仍出现 `EDITR not ready`；
- 最小 PS AXI-Lite register-only probe 也复现了 PS/A53 访问层问题。

因此，JTAG 路线是为了绕开 PS/A53/XSCT 调试访问不稳定因素。JTAG probe 已 PASS，说明 JTAG 访问参数和基础通路有效。

## 下一步验收

true2x2 JTAG-W8A12 bitstream 生成后，立即执行：

1. 烧录 JTAG-W8A12 bitstream；
2. 通过 `scripts/jtag_rgb_transfer.tcl` 写入 2x2 RGB；
3. 从 JTAG endpoint 读回 8x8 RGB；
4. 使用 `scripts/compare_jtag_w8a12_span_output.ps1` 与整数参考逐字节对比；
5. 生成 board output PNG、reference PNG、validation preview 和 summary；
6. 若 mismatch 为 0，进入 4x4/8x8/32x32 分级上板；若 route 或输出失败，切到更轻的分层 JTAG endpoint 继续定位。
