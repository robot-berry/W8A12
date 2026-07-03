# JTAG W8A12 true2x2 dbg5/count-view 上板定位

Status: BOARD_FAIL_BLOCK1_C1_STALL

日期：2026-07-03

## 目标

在 dbg4/bank4 已确认 `sched_feat0_hash` 匹配但 `sched_b1_hash` 不匹配并伴随 no-output stall 后，新增更低侵入的 `bank5` 计数/状态视图，仅暴露 scheduler/block1 的 valid/count/done 类信息：

- `front_state`
- `C1/C2/C3/attention counts`
- `block_start/block_output counts`
- `replay_feature_count`

## 生成与验证结果

| 项目 | 结果 |
| --- | --- |
| RTL raw compare | PASS，`0 / 192` mismatch |
| RTL xsim bank5 期望 | `front_state=0x00017800`，`C1/C2/C3/ATT=0x00030003`，`block_counts=0x00060018`，`replay=0x00000018` |
| bitstream | PASS |
| timing | PASS，WNS `12.580 ns`，WHS `0.010 ns` |
| implementation resource | LUT `39799`，REG `116685`，BRAM tile `311`，DSP `128`，URAM `0` |
| board probe | PASS，USB/JTAG target 可见 |
| psu_init | PASS |
| board smoke | FAIL，输出 `0 / 192` bytes |
| register read after smoke | PASS |
| delayed register read | PASS，延迟 5 秒后状态未变化 |

## 关键路径

```text
RTL raw compare log:
G:\UESTC\feitengspan1\build\xsim_jtag_raw_compare_dbg5_countview_20260703\jtag_w8a12_tile_writer_raw_compare_sim.sim\sim_1\behav\xsim\simulate.log

bitstream:
G:\UESTC\feitengspan1\vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg5_countview_20260703.bit

timing report:
G:\UESTC\feitengspan1\vivado\reports\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg5_countview_20260703_timing_impl.rpt

utilization report:
G:\UESTC\feitengspan1\vivado\reports\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg5_countview_20260703_utilization_impl.rpt

board run:
G:\UESTC\feitengspan1\board_runs\jtag_w8a12_tile_writer\true2x2_dbg5_countview_20260703
```

## RTL 期望与板端读数

| 信号 | RTL/xsim 期望 | 板端读数 | 结论 |
| --- | --- | --- | --- |
| `bank5_front_state` | `0x00017800` | `0x00060427` | FAIL，状态机未到达 RTL 完成态 |
| `bank5_c1_counts` | `0x00030003` | `0x00000003` | PARTIAL，仅低 16-bit 侧看到 3 次 |
| `bank5_c2_counts` | `0x00030003` | `0x00000000` | FAIL |
| `bank5_c3_counts` | `0x00030003` | `0x00000000` | FAIL |
| `bank5_att_counts` | `0x00030003` | `0x00000000` | FAIL |
| `bank5_block_counts` | `0x00060018` | `0x00010000` | FAIL，仅启动/进入 block1，未形成预期 block 输出 |
| `bank5_replay_count` | `0x00000018` | `0x00000004` | FAIL，仅重放 4 次 |

板端 after-smoke 与 delayed read 均为：

```text
counter_in=4
counter_out=0
frame_done=0
error=0x00000000
bank5_front_state=0x00060427
bank5_c1_counts=0x00000003
bank5_c2_counts=0x00000000
bank5_c3_counts=0x00000000
bank5_att_counts=0x00000000
bank5_block_counts=0x00010000
bank5_replay_count=0x00000004
writer_live=valid_h=2 valid_w=2 tile_last=1 sched_done=0 sched_busy=0 writer_busy=1 front_busy=1 writer_done=0 front_done=0 writer_error=0 front_error=0 tile_is_full=1 sched_tile_ready=0 sched_tile_valid=0 sched_error=0 state=3
```

## 结论

dbg5/count-view 把当前上板异常从“block1 输出 hash 不匹配”进一步压缩为“SPAB block1 内部在 C1 后没有推进到 C2/C3/attention/输出完成”。JTAG、PSU init、AXI-Lite register read 和输入写入仍然可用；`counter_in=4` 表示 2x2 输入已经送入 PL，但 `counter_out=0`、`frame_done=0` 表明 writer 没收到有效输出。

该 run 仍是定位证据，不是 clean correctness baseline。clean baseline 继续以 dbg3/single-boundary 的完整输出、`error=0`、`src_feat0_hash` 匹配但 `src_b1_hash` 首错为准。

## 下一步排查

1. 在 RTL 仿真中对比板端 `bank5_front_state=0x00060427` 对应的 scheduler 状态位，确认卡在 C1 done、C2 wait、input replay 还是 output ready。
2. 新增单一 ready/valid 探针：优先只导出 `c1_done/c2_start/c2_valid_in/c2_ready_in` 或 `feature replay valid/ready`，避免再次暴露宽 hash。
3. 若 valid/ready 证明 C1 输出没有被 C2 接收，排查 C1->C2 buffer/replay 地址、tile edge/halo 小图边界和 reset/enable 门控。
4. 若 C2 接收正常但计数仍为 0，排查 count 探针触发条件与综合优化是否被状态机重排。
