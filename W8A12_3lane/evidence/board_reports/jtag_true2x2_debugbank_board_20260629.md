# JTAG true2x2 debug-bank 实板排查记录

日期：2026-06-29

状态：BASELINE OUTPUT PASS / DEBUG-BANK BOARD STALL

## 本轮目标

上一轮 stage-hash 已经证明板端最早可见偏差出现在 `tail_b1_hash`。本轮新增 debug bank，试图把 `tail_b1_hash` 之前继续拆成 `feat0/input/halo/block1 C1/C2/C3/attention`。

## 已完成项

| 项目 | 结果 |
| --- | --- |
| debug-bank RTL raw compare | PASS，`0 / 192` mismatch |
| debug-bank bitstream | PASS |
| debug-bank timing | PASS，WNS `12.267ns`，WHS `0.009ns` |
| debug-bank resource | LUT `40363`，FF `116367`，BRAM tile `311`，DSP `126` |
| 板卡/JTAG preflight | READY，USB known JTAG candidate `3` |
| PSU init | PASS |
| debug-bank register read | PASS |

debug-bank bitstream：

```text
vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_debugbank_20260629.bit
```

## debug-bank 上板结果

debug-bank 版本可以烧录、可以读 AXI-Lite，但 true2x2 smoke 没有输出像素：

| 指标 | 数值 |
| --- | --- |
| output bytes | `0 / 192` |
| counter in | `4` |
| counter out | `0` |
| frame done | `0x00000000` |
| error | `0x00000000` |
| status | `0x00002000` |
| delayed read after >10s | 仍为 `counter_out=0/frame_done=0` |
| writer live | `valid_h=2 valid_w=2 tile_last=1 sched_done=0 sched_busy=0 writer_busy=1 front_busy=1 writer_done=0 front_done=0 writer_error=0 front_error=0 tile_is_full=1 sched_tile_ready=0 sched_tile_valid=0 sched_error=0 state=3` |

结论：debug-bank 版本不是单纯数值 mismatch，而是板端运行卡在 busy 状态。由于行为级 RTL 仍 PASS，这更像是 debug 探针过重、扇出/优化路径改变、或 debug bank 读数插入方式对板端控制路径产生了侵入。

证据：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_debugbank_acceptance_20260629
board_runs/jtag_w8a12_tile_writer/true2x2_debugbank_acceptance_20260629/reg_read_delayed_no_reprogram
```

## baseline 复跑结果

为排除板子/JTAG/脚本问题，复跑旧 `stagehash_20260628` bitstream：

```text
vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_stagehash_20260628.bit
```

结果：

| 指标 | 数值 |
| --- | --- |
| output bytes | `192 / 192` |
| frame done | `1` |
| error | `0x00000000` |
| counter in/out | `4 / 64` |
| frame cycles | `7202120` |
| compare | FAIL |
| mismatch bytes | `190 / 192` |
| max channel diff | `160` |
| PSNR | `14.3819 dB` |

baseline stage-hash 读回：

| 边界 | 实板读回 |
| --- | --- |
| `tail_b1_hash` | `0xF6ADBE60` |
| `tail_b6_act1_hash` | `0xE76F9C80` |
| `tail_rgb_q_hash` | `0x094093C6` |
| `writeback_hash` | `0x4718842B` |
| `writeback_range` | `0x00FF0040` |
| `writeback_first` | `0x00393444` |
| `writeback_last` | `0x0025140E` |

RTL true2x2 期望仍为：

| 边界 | RTL 期望 |
| --- | --- |
| `tail_b1_hash` | `0x16ede1c2` |
| `tail_b6_act1_hash` | `0xc7a092b8` |
| `tail_rgb_q_hash` | `0xb712a61b` |
| `writeback_hash` | `0x61d3ea1d` |

结论：板子/JTAG/PSU/输出通路仍然可用；baseline 仍然是数值 mismatch，且最早可见边界仍不匹配 `tail_b1_hash`。debug-bank 新版本导致 stall，不能作为下一步定位依据。

证据：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_baseline_recheck_after_debugbank_20260629
```

## 当前排查结论

1. mismatch 不是板子未连接、JTAG 不可见、PSU init 失败或输出读回脚本失效。
2. baseline bitstream 可完整输出，因此当前 primary blocker 仍是 PL 数值路径 mismatch。
3. debug-bank 一次性挂太多 hash 探针后会导致板端 busy stall，说明下一轮 debug 必须降侵入。
4. 下一步不应继续扩大 debug bank，而应回到旧 stagehash baseline，从最小单点探针开始，每次只加一组 hash 或一个寄存器 bank。

## 下一步排查清单

| 排查项 | 目的 | 状态 |
| --- | --- | --- |
| JTAG/PSU/preflight | 确认板端可访问 | PASS |
| baseline 2x2 output full length | 确认输出通路可用 | PASS，`192 / 192` |
| baseline compare | 确认 mismatch 仍存在 | FAIL，`190 / 192` |
| debug-bank all-in-one | 读取更细 hash | FAIL，板端 busy stall |
| 低侵入 single-bank bitstream | 一次只导出 `feat0/src_feat0/src_b1` 或只导出 `block1 C1` | TODO |
| 对比 Default vs RuntimeOptimized | 固定 correctness build 策略 | TODO，当前继续使用 `SynthDirective=Default` |
| writer-only pattern test | 排除 writer 输出缓存路径 | TODO，优先级低于低侵入 stage hash |

