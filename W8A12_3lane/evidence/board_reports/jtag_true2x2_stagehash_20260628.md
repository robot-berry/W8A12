# JTAG true2x2 stage-hash 排查记录

日期：2026-06-28

## 结论摘要

在 `dbgprogress` bitstream 已经证明 true 2x2 可以完整输出但数值错误后，当前排查路线改为更低扰动的 stage-hash 读数，而不是继续扩大 debug bus。

本次代码侧新增的只读寄存器映射为：

| 地址 | 字段 | 用途 |
| --- | --- | --- |
| `0x04` | `tail_b1_hash` | block1 之后的尾部输入/中间边界 hash |
| `0x08` | `tail_b6_act1_hash` | block6 后 act1 边界 hash |
| `0x10` | `tail_rgb_q_hash` | tail / pixelshuffle / RGB 量化边界 hash |
| `0x30` | `writeback_hash` | writer 实际写回 hash |
| `0x34` | `writeback_range` | writer 写回范围 / count |
| `0x38` | `writeback_first` | writer 首像素 |
| `0x3c` | `writeback_last` | writer 尾像素 |

行为级 RTL true 2x2 raw compare 已重新通过，仍为 `0/192 mismatch`。这说明新 stage-hash 读数没有破坏 RTL 数学结果，可作为下一轮板上定位点。

## 行为级 RTL 结果

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 -SkipPackWeights -SimRuntime 300ms -ImageW 2 -TileW 2 -TileH 2 -Halo 21 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -MaxCycles 22000000 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -BuildRoot build\xsim_jtag_w8a12_stagehash_20260628
```

关键输出：

```text
PASS sr_jtag_w8a12_tile_writer_endpoint_raw_compare inputs=4 outputs=64
JTAG_RTL_COMPARE_MISMATCH_BYTES=0
JTAG_RTL_COMPARE_MAX_DIFF=0
JTAG_RTL_COMPARE_TOTAL_BYTES=192
JTAG_RTL_COMPARE_PSNR_DB=Infinity
JTAG_DEBUG_TAIL_B1_HASH=0x16ede1c2
JTAG_DEBUG_TAIL_B6_ACT1_HASH=0xc7a092b8
JTAG_DEBUG_TAIL_RGB_Q_HASH=0xb712a61b
JTAG_DEBUG_WRITEBACK_HASH=0x61d3ea1d
JTAG_DEBUG_WRITEBACK_RANGE=0x4e9f0040
JTAG_DEBUG_WRITEBACK_FIRST=0x0061605d
JTAG_DEBUG_WRITEBACK_LAST=0x007a6366
```

日志：

```text
build/xsim_jtag_w8a12_stagehash_20260628/jtag_w8a12_tile_writer_raw_compare_sim.sim/sim_1/behav/xsim/simulate.log
board_runs/w8a12_partition_sim_attempts/jtag_raw_compare_2x2_tile2x2_h21_ol1_tl4_sl1.log
```

## post-synth 尝试

已尝试启动 post-synth raw compare：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 -SkipPackWeights -PostSynth -SimRuntime 300ms -ImageW 2 -TileW 2 -TileH 2 -Halo 21 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -MaxCycles 22000000 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -BuildRoot build\xsim_jtag_w8a12_stagehash_postsynth_20260628
```

结果：未形成 PASS/FAIL 结论。该进程完成到 compile/elaborate 产物生成后，`simulate.log` 仍为 0 字节，Vivado 进程长时间无有效输出，已停止该次长跑。该项记录为“待长跑验证”，不作为 RTL 正确性失败证据。

保留产物：

```text
build/xsim_jtag_w8a12_stagehash_postsynth_20260628/
board_runs/w8a12_partition_sim_attempts/jtag_post_synth_raw_compare_2x2_tile2x2_h21_ol1_tl4_sl1.log
```

## stage-hash bitstream

已生成可上板的 true 2x2 stage-hash bitstream，综合策略固定为 `SynthDirective=Default`，与当前 correctness baseline 保持一致。

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_w8a12_tile_writer.ps1 -ImgW 2 -TileW 2 -TileH 2 -Halo 21 -PlFreqMhz 25 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -SynthDirective Default -VivadoMaxThreads 1 -AttemptLabel true2x2_jtagaxi_stagehash_20260628
```

结果：PASS，bitstream 已生成。

| 项目 | 数值 |
| --- | ---: |
| WNS | `11.772 ns` |
| WHS | `0.009 ns` |
| CLB LUTs | `39951` |
| CLB Registers | `116172` |
| BRAM Tile | `311` |
| DSP | `126` |
| URAM | `0` |

关键产物：

```text
vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_stagehash_20260628.bit
vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_stagehash_20260628_utilization_impl.rpt
vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_stagehash_20260628_timing_impl.rpt
board_runs/w8a12_tile_writer_bitstream_attempts/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_stagehash_20260628.log
```

## 板上读取工具

新增包装脚本：

```text
scripts/run_read_jtag_w8a12_tile_writer_regs.ps1
scripts/read_jtag_w8a12_tile_writer_regs.tcl
```

用途：在已经烧录 stage-hash bitstream 后，通过 Vivado JTAG-to-AXI 读取上述 hash/status/counter 寄存器，并生成 Markdown/JSON summary。

已在当前 `dbgprogress` bitstream 加载状态下验证包装脚本本身可运行并返回 `JTAG_W8A12_REG_READ_STATUS=PASS`。由于该 bitstream 仍使用旧 progress 映射，因此这次包装脚本运行只证明读取通路可用，不作为 stage-hash 数值证据。

## 最新板卡连接状态

在 post-synth 长跑停止后，执行了一次 stage-hash bitstream 生成前的 JTAG 存活检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_read_jtag_w8a12_tile_writer_regs.ps1 -PollCount 2 -PollDelayMs 200 -OutputDir board_runs\jtag_w8a12_tile_writer\stagehash_prebuild_jtag_alive_20260628
```

结果：FAIL，Vivado 报告 `No hardware target found`。

随后执行硬件 target probe：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe_vivado_hw_targets.ps1 -OutputDir board_runs\vivado_hw_target_probe_stagehash_prebuild_20260628
```

结果同样为 FAIL：

```text
VIVADO_HW_TARGET_COUNT=0
USB_JTAG_DIAG_MATCH_COUNT=3
USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=0
```

解释：当前不是 W8A12 算法或 RTL mismatch 的新证据，而是板卡/JTAG 连接态退回到 Vivado 无 target 的状态。此前 `jtag_after_psuinit_20260628` 已证明在 target count=1 且执行对应 `psu_init.tcl` 后，最小 JTAG-to-AXI register probe 可 PASS；因此继续板上 stage-hash 读数前，需要先恢复 Vivado target count=1。

stage-hash bitstream 生成后再次执行 target probe：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe_vivado_hw_targets.ps1 -OutputDir board_runs\vivado_hw_target_probe_after_stagehash_bit_20260628
```

结果仍为 FAIL：

```text
VIVADO_HW_TARGET_COUNT=0
USB_JTAG_DIAG_MATCH_COUNT=3
USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=0
```

因此当前板上 stage-hash 读数尚未执行；原因是 Vivado 无法枚举到硬件 target，而不是 stage-hash bitstream 缺失。

## 一键上板验收入口

已新增 stage-hash true2x2 上板验收包装脚本：

```text
scripts/run_w8a12_stagehash_true2x2_acceptance.ps1
W8A12_3lane/scripts/run_w8a12_stagehash_true2x2_acceptance.ps1
```

该脚本串联以下步骤：

1. `probe_vivado_hw_targets.ps1`
2. `run_xsct_psu_init_only.ps1`
3. `run_jtag_w8a12_tile_writer_smoke.ps1`
4. `run_read_jtag_w8a12_tile_writer_regs.ps1`

当前环境实际运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_w8a12_stagehash_true2x2_acceptance.ps1 -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_stagehash_acceptance_wrapper_20260628
```

结果：FAIL，第一步 target probe 即失败。

```text
W8A12_STAGEHASH_STEP_EXIT_probe=1
W8A12_STAGEHASH_ACCEPTANCE_STATUS=FAIL
Error: Initial Vivado target probe failed
VIVADO_HW_TARGET_COUNT=0
```

该结果说明：stage-hash 上板验收流程入口已就绪，但当前板卡/JTAG 连接态仍不满足烧录与读 hash 的前置条件。

证据：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_acceptance_wrapper_20260628/stagehash_true2x2_acceptance_summary.md
board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_acceptance_wrapper_20260628/probe/probe_vivado_hw_targets.stdout.log
```

## 续跑 target probe

继续目标推进时重新执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe_vivado_hw_targets.ps1 -OutputDir board_runs\vivado_hw_target_probe_goal_continue_20260628_b
```

结果仍为 FAIL：

```text
VIVADO_HW_TARGET_COUNT=0
USB_JTAG_DIAG_MATCH_COUNT=3
USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=0
```

当前在线 USB 设备列表没有 Xilinx/FTDI known candidate；历史设备里可见 FTDI `VID_0403&PID_6010`。这说明 stage-hash bitstream 和读取流程已准备好，但当前 PC/板卡连接态尚未满足烧录与读 hash 的前置条件。

## 下一步板上定位

1. 先恢复板卡/JTAG 连接，要求 `probe_vivado_hw_targets.ps1` 返回 `VIVADO_HW_TARGET_COUNT=1` 且可见 `xczu19_0`。
2. 直接运行 `scripts/run_w8a12_stagehash_true2x2_acceptance.ps1`。
3. 若 wrapper 通过 smoke 阶段，读取 `tail_b1_hash`、`tail_b6_act1_hash`、`tail_rgb_q_hash` 和 writeback 组。
4. 对照行为级 RTL 期望值：
   - 若 `tail_b1_hash` 已不同，优先查 front / block1 输入输出；
   - 若 `tail_b1_hash` 相同但 `tail_b6_act1_hash` 不同，查 SPAB block2-block6；
   - 若 `tail_b6_act1_hash` 相同但 `tail_rgb_q_hash` 不同，查 tail / pixelshuffle / RGB 量化；
   - 若三段 stage hash 相同但 `writeback_hash` 不同，查 writer 数据生成和写回；
   - 若 writeback 组也相同但 board output mismatch，查 endpoint 输出缓存或 JTAG 读回。

该路线可以在不阻塞赛题报告/PPA 主线的情况下继续缩小 board mismatch 范围。
