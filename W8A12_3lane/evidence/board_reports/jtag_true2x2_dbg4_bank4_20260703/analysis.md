# JTAG W8A12 true2x2 dbg4/bank4 上板定位

Status: BOARD_FAIL_LOCALIZED_STALL

日期：2026-07-03

## 目标

在 dbg3/single-boundary 已确认 `src_feat0_hash` 匹配、`src_b1_hash` 首错之后，新增低侵入 `bank4` 调试寄存器，直接对比 scheduler/block1 边界：

- `sched_feat0_hash`
- `sched_b1_hash`
- `src_b1_hash`
- `tail_b1_hash`
- `SPAB B1 attention / C3 / residual hash`

## 生成与验证结果

| 项目 | 结果 |
| --- | --- |
| RTL raw compare | PASS，`0 / 192` mismatch |
| bitstream | PASS |
| timing | PASS，WNS `12.079 ns`，WHS `0.009 ns` |
| implementation resource | LUT `39698`，REG `116621`，BRAM tile `311`，DSP `128`，URAM `0` |
| board probe | PASS，USB/JTAG target 可见 |
| psu_init | PASS |
| board smoke | FAIL，输出 `0 / 192` bytes，`counter_out=0`，`frame_done=0` |
| register read after smoke | PASS |
| delayed register read | PASS，延迟后状态未变化 |

## 关键路径

```text
bitstream:
G:\UESTC\feitengspan1\vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg4_bank4_20260703.bit

timing report:
G:\UESTC\feitengspan1\vivado\reports\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg4_bank4_20260703_timing_impl.rpt

utilization report:
G:\UESTC\feitengspan1\vivado\reports\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg4_bank4_20260703_utilization_impl.rpt

board run:
G:\UESTC\feitengspan1\board_runs\jtag_w8a12_tile_writer\true2x2_dbg4_bank4_20260703
```

## RTL 期望与板端读数

| 信号 | RTL/xsim 期望 | 板端读数 | 结论 |
| --- | --- | --- | --- |
| `bank4_sched_feat0_hash` | `0xF7F21CC2` | `0xF7F21CC2` | PASS |
| `bank4_sched_b1_hash` | `0x16EDE1C2` | `0x811C9DC5` | FAIL |
| `bank4_src_b1_hash` | `0x16EDE581` | `0x811C9DC5` | FAIL |
| `bank4_tail_b1_hash` | `0x16EDE1C2` | `0x811C9DC5` | FAIL |
| `bank4_spab_b1_att_hash` | `0x16EDE1C2` | `0x811C9DC5` | FAIL |
| `bank4_spab_b1_c3_hash` | `0x811C9DC5` | `0x811C9DC5` | PASS/空流或默认 hash，需结合 valid 判断 |
| `bank4_spab_b1_residual_hash` | `0x811C9DC5` | `0x811C9DC5` | PASS/空流或默认 hash，需结合 valid 判断 |

板端 delayed read 仍为：

```text
counter_in=4
counter_out=0
frame_done=0
error=0x00000000
writer_live=valid_h=2 valid_w=2 tile_last=1 sched_done=0 sched_busy=0 writer_busy=1 front_busy=1 writer_done=0 front_done=0 writer_error=0 front_error=0 tile_is_full=1 sched_tile_ready=0 sched_tile_valid=0 sched_error=0 state=3
```

## 结论

本轮不是板端图像输出 mismatch，而是 dbg4/bank4 探针版本在板上进入 `ST_RUN_TILE` 后不完成，输出为 0 字节。它仍然提供了新的定位信息：

1. JTAG、PSU init、AXI-Lite 寄存器读写和输入发送链路正常。
2. `sched_feat0_hash` 与 RTL 完全一致，说明 conv1/feat0 scheduler 边界可到达。
3. `sched_b1_hash` 已经与 RTL 不一致，同时 `writer_busy/front_busy=1`、`sched_done=0`，说明首个可见异常点位于 SPAB block1 输出/attention 到 scheduler block1 完成握手附近。
4. 因 dbg4 版本引入了更深的 bank4 调试读数并导致 no-output/stall，本轮不能作为 clean correctness baseline；clean baseline 仍以 dbg3/single-boundary 的 `error=0`、完整输出、`src_feat0` 匹配但 `src_b1` 首错为准。

## 下一步排查

1. 保留 dbg4/bank4 作为“block1 内部边界已触发 stall”的定位证据。
2. 回到 dbg3 的低侵入方式，新增只读单一边界版本：仅导出 `sched_b1_valid_count`、`sched_b1_last_seen`、`block1_done` 或 `att_valid_count` 之一，避免一次暴露多组组合 hash。
3. 若单一 valid/count 探针仍 stall，则优先排查 block1 scheduler valid/ready、front/tail stream ready 常量、以及 `RuntimeOptimized` 对调试路径的扰动；correctness baseline 继续优先使用更少调试信号的 bitstream。
