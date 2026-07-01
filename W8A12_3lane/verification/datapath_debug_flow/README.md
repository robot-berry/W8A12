# W8A12 数据通路调试验证工程

本目录用于存放 `W8A12_3lane` 当前 mismatch 的分模块仿真、综合、上板验证和证据归档。最终目标不是只定位 mismatch，而是把当前板端 mismatch 修到通过。

## 当前结论

截至 2026-06-30，本轮已经确认：

```text
JTAG stack = READY
D2XX device count = 2
Vivado hardware target count = 1

旧 current dbg2 上板运行 = FAIL，但没有卡住
frame_done = 1
error = 0
counter_in = 4
counter_out = 64
output bytes = 192 / 192
byte mismatch = 185 / 192
```

旧 dbg2 可靠边界解释如下：

```text
tail_b1_hash     board = 0x16EDE1C2, expected = 0x16EDE1C2
tail_b6_act1_hash board = 0x0810B515, expected = 0xC7A092B8
tail_rgb_q_hash  board = 0x765490DA, expected = 0xB712A61B
writeback_hash   board = 0xFF516EF7, expected = 0x61D3EA1D
```

因此当前最小可靠夹逼为：

```text
tail_b1 对，tail_b6_act1 错
=> 问题在 b6_act1 source/tap、feature buffer/replay 到 tail handoff，或 tail 输入对齐附近
```

同时已经修正一个工作流误判点：旧脚本把 `bank1_tail_feat0_hash` 当作边界 hash 使用，但当前 RTL 中该寄存器在普通 dbg2 模式下是 RGB q 范围/诊断字段，不再用于第一处 mismatch 判定。

## 本轮新增修正

为继续定位 `tail_b6_act1`，已经加入低侵入 source-b6 探针：

```text
rtl/board/sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v
  DEBUG_SRC_HASH=1 时保留真正 source hash，不再被 ST_STREAM 早期状态计数覆盖。

rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v
  新增 debug bank3，导出 src_feat0/src_block6/src_b1/src_b6_act1 和 tail 三个关键 hash。

scripts/read_jtag_w8a12_tile_writer_regs.tcl
scripts/run_read_jtag_w8a12_tile_writer_regs.ps1
  新增 bank3 读回和 summary 字段。

scripts/continue_w8a12_mismatch_flow.ps1
  边界顺序更新为 src_feat0 -> src_b1 -> src_b6_act1 -> tail_b1 -> tail_b6_act1 -> tail_rgb_q -> writeback。
```

## 快速验收入口

JTAG/PnP 前置门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\check_w8a12_jtag_stack.ps1 -OutputDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\jtag_stack_precheck
```

重新插拔板子后，可以使用等待版门禁自动轮询：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\W8A12_3lane\scripts\wait_w8a12_jtag_ready.ps1 -MaxSeconds 300 -IntervalSeconds 10
```

只有门禁满足以下结果，才进入 datapath hash 判定：

```text
W8A12_JTAG_STACK_STATUS = READY
D2XX device count >= 1
Vivado hardware target count >= 1
```

若结果为 `BLOCKED_PNP`、`D2XX device count = 0`、或 USB Serial Converter A/B 显示 `Disconnected`/`CM_PROB_PHANTOM`，本轮证据只能说明板端连接未恢复，不能作为 RTL mismatch 结论。先检查板子供电、JTAG USB 数据线、USB 口和驱动枚举，再重跑本门禁。

解析器自测：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\test_continue_w8a12_mismatch_flow_parser.ps1 -OutputRoot W8A12_3lane\verification\datapath_debug_flow\runs\continue_flow_parser_tests_src_b6_green2_20260630
```

2x2 行为仿真：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 -SkipPackWeights -ImageW 2 -TileW 2 -TileH 2 -Halo 21 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -DebugExportLevel 2 -BuildRoot build\xsim_srcb6
```

当前 source-b6 bitstream 构建：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\run_vivado_bitstream_jtag_w8a12_tile_writer.ps1 -ImgW 2 -TileW 2 -TileH 2 -Halo 21 -PlFreqMhz 25 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -DebugExportLevel 2 -VivadoMaxThreads 1 -SynthDirective RuntimeOptimized -AttemptLabel current_dbg2_source_b6_20260701
```

构建完成后，上板验收入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\continue_w8a12_mismatch_flow.ps1 -OutputDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\continue_w8a12_mismatch_source_b6_20260701
```

2026-07-01 状态：

```text
source-b6 bitstream 已生成
TIMING_CHECK = PASS
WNS_NS = 12.517
WHS_NS = 0.010

当前上板 flow 被 JTAG/PnP 门禁拦截：
W8A12_JTAG_STACK_STATUS = BLOCKED_PNP
D2XX device count = 0
USB Serial Converter A/B = Disconnected / CM_PROB_PHANTOM
```

## 判定表

| 第一处失败边界 | 判定 | 主要 RTL |
| --- | --- | --- |
| `src_feat0_hash` | 输入、halo、conv1/front-end 先错 | `sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v`, `span_w8a12_conv1_streamed_frontend.v` |
| `src_b1_hash` | block1 输出/source tap 或前级 replay 错 | `sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v`, `sr_feature_tile_buffer_streamer.v` |
| `src_b6_act1_hash` | 最后一个 block 的 C1 tap/b6_act1 source 错 | `sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v`, `sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v` |
| `tail_b1_hash` 或 `tail_b6_act1_hash` | source 对但 tail 输入错，优先看 replay/handoff/valid-ready | `sr_feature_tile_buffer_streamer.v`, `sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v`, `span_w8a12_tail_streamed_rgb.v` |
| `tail_rgb_q_hash` | tail 内部量化、concat、pixelshuffle/RGB 错 | `span_w8a12_tail_streamed_rgb.v`, `span_w8a12_upsampler0_pixelshuffle_streamed_rgb.v` |
| `writeback_hash` | writer、RGB888 packing、读回错 | `sr_tile_output_writer.v`, `sr_jtag_w8a12_tile_writer_endpoint.v` |

## 完成条件

当前 mismatch 只有在以下条件全部满足后才算修好：

```text
第一处 mismatch 已固定到单个 RTL owner 或明确小范围
修改后的低成本仿真/OOC 综合通过
true2x2 边界 hash 全部通过
最终 board/reference compare mismatch = 0
frame_done = 1
error = 0
```
