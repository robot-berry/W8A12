# JTAG true 2x2 debugregs 复核

日期：2026-06-27

## 目的

在不改动 W8A12 计算 datapath 的前提下，把 `sr_tile_halo_fetch_w8a12_front_tail_writer_shell` 已有的 writeback 调试信号接到 JTAG endpoint 的 AXI-Lite 只读寄存器：

| register | address | meaning |
| --- | ---: | --- |
| `REG_DEBUG_WRITEBACK_HASH` | `0x30` | writer 写回 RGB 序列 hash |
| `REG_DEBUG_WRITEBACK_RANGE` | `0x34` | writer 写回 min/max/count |
| `REG_DEBUG_WRITEBACK_FIRST` | `0x38` | writer 首个写回 RGB |
| `REG_DEBUG_WRITEBACK_LAST` | `0x3c` | writer 最后写回 RGB |

这一步用于判断板端 `153 / 192` 小幅 mismatch 是出现在 writer 前的计算路径，还是 endpoint/output buffer/AXI 读回之后。

## RTL 行为仿真

命令入口：

```text
scripts/run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1
```

关键参数：

```text
ImageW=2
TileW=2
TileH=2
Halo=21
OutLanes=1
TapLanes=4
ScaleLanes=1
InputRaw=runs/reds_span_quant_plan/endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1/reference/input.rgb
ReferenceRaw=runs/reds_span_quant_plan/endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1/reference.rgb
BuildRoot=build/xsim_jtag_w8a12_tile_writer_raw_compare_dbgregs
```

结果：

| item | value |
| --- | --- |
| status | PASS |
| mismatch | `0 / 192` |
| max diff | `0` |
| frame cycles | `7202120` |
| debug writeback hash | `0x61d3ea1d` |
| debug writeback range | `0x4e9f0040` |
| debug writeback first | `0x0061605d` |
| debug writeback last | `0x007a6366` |
| sim log | `build/xsim_jtag_w8a12_tile_writer_raw_compare_dbgregs/jtag_w8a12_tile_writer_raw_compare_sim.sim/sim_1/behav/xsim/simulate.log` |

结论：debug 寄存器接线没有破坏 RTL 行为级 bit-exact，且 RTL 侧已有可用于板端对照的 writeback hash/first/last。

## bitstream 构建

构建命令使用 `SynthDirective=Default`，保持 correctness bring-up 主线一致。

构建产物：

- bitstream：`vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627.bit`
- utilization：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627_utilization_impl.rpt`
- timing：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627_timing_impl.rpt`
- Vivado log：`board_runs/w8a12_tile_writer_bitstream_attempts/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627.log`

资源和时序：

| metric | value |
| --- | ---: |
| CLB LUTs | 39261 |
| CLB registers | 116070 |
| BRAM Tile | 311 |
| URAM | 0 |
| DSP | 126 |
| setup worst slack | 10.026 ns |
| hold worst slack | 0.010 ns |
| timing | PASS |

## 上板尝试

上板命令入口：

```text
scripts/run_jtag_w8a12_tile_writer_smoke.ps1
```

本轮输出目录：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgregs_20260627
```

结果：

| item | value |
| --- | --- |
| status | FAIL |
| Vivado exit | `1` |
| output bytes | `0 / 192` |
| compare | SKIPPED |
| failure reason | `No hardware target found. Check USB-JTAG cable and board power.` |

随后执行硬件探测：

| probe | result |
| --- | --- |
| `board_runs/vivado_hw_target_probe_dbgregs_20260627` | `VIVADO_HW_TARGET_COUNT=0` |
| `board_runs/vivado_hw_target_probe_dbgregs_cs_20260627` | `VIVADO_HW_TARGET_COUNT=0` |
| USB/JTAG known candidate count | `0` |
| PnP history known candidate count | `4` |

结论：debugregs bitstream 已经具备上板条件，但当前主机没有枚举到可用 Vivado hardware target。这不是本次 RTL 或 bitstream 的失败，也不是 `153 / 192` mismatch 的新结果；它是板端 USB-JTAG/电源/模式/驱动状态阻塞。

## 下一步

1. 重新确认板卡电源、JTAG USB 线、启动模式和 Windows 设备管理器中 Xilinx/Digilent/FTDI 设备是否在线。
2. 重新运行 `scripts/probe_vivado_hw_targets.ps1 -OutputDir board_runs/vivado_hw_target_probe_dbgregs_retry_<tag>`，要求 `VIVADO_HW_TARGET_COUNT > 0`。
3. 重新运行 debugregs 上板：

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627.bit -ImgW 2 -ImgH 2 -Scale 4 -InputRaw runs/reds_span_quant_plan/endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1/reference/input.rgb -ReferenceRaw runs/reds_span_quant_plan/endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1/reference.rgb -OutputDir board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgregs_retry_<tag>
```

4. 对比板端 debug 寄存器与 RTL 期望：

```text
expected_hash  = 0x61d3ea1d
expected_range = 0x4e9f0040
expected_first = 0x0061605d
expected_last  = 0x007a6366
```

若板端 debug hash 与 RTL 一致但 `board_output.rgb` 仍 mismatch，则问题在 endpoint 输出缓存或 JTAG 读回序列；若 debug hash 已经不一致，则问题在 writer 前的综合后 PL 计算路径。
