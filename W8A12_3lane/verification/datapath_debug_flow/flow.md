# 数据通路 Mismatch 定位与修复流程

本流程的目标是闭环修复当前板端 mismatch。任何一次实验都要回答一个问题：

```text
第一处不匹配边界在哪里？
```

## 0. 先判定证据是否可用

只有满足以下条件，板端 hash 才能用于 datapath 定位：

```text
JTAG stack = READY
D2XX device count >= 1
Vivado hardware target count >= 1
frame_done = 1
error = 0
counter_in = 4
counter_out = 64
output bytes = 192 / 192
debug probe 没有造成 counter_out=0 或 front/core error
```

如果不满足，先修 JTAG/控制壳/探针侵入性，不要改 datapath RTL。

JTAG/PnP 门禁命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\check_w8a12_jtag_stack.ps1 -OutputDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\jtag_stack_precheck
```

如果刚重新插板，建议用等待版门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\W8A12_3lane\scripts\wait_w8a12_jtag_ready.ps1 -MaxSeconds 300 -IntervalSeconds 10
```

若门禁输出为：

```text
W8A12_JTAG_STACK_STATUS = BLOCKED_PNP
D2XX device count = 0
USB Serial Converter A/B = Disconnected 或 CM_PROB_PHANTOM
```

则本轮不允许进入 datapath mismatch 判定。此时需要先恢复板端 USB/JTAG 枚举：确认板子供电、JTAG USB 是数据线、换 USB 口或重新插拔，必要时用管理员权限重新扫描硬件。恢复后必须重新跑 `check_w8a12_jtag_stack.ps1`，直到状态为 READY。

## 1. 固定参考值

true2x2 软件/行为参考值如下：

```text
src_feat0_hash     = 0xF7F21881
src_b1_hash        = 0x16EDE581
src_b6_act1_hash   = 0xC7A096FB
tail_b1_hash       = 0x16EDE1C2
tail_b6_act1_hash  = 0xC7A092B8
tail_rgb_q_hash    = 0xB712A61B
writeback_hash     = 0x61D3EA1D
```

注意：`bank1_tail_feat0_hash` 当前是诊断/范围字段，不参与第一处 mismatch 判定。

## 2. 边界顺序

当前 source-b6 工作流使用以下顺序：

```text
src_feat0_hash
src_b1_hash
src_b6_act1_hash
tail_b1_hash
tail_b6_act1_hash
tail_rgb_q_hash
writeback_hash
```

判定规则：

```text
最后一个 MATCH 与第一个 MISMATCH 之间，就是下一轮应检查的 RTL 区间。
```

## 3. 当前已知板端证据

旧 current dbg2 上板后已经确认不是卡住：

```text
frame_done = 1
error = 0
counter_in = 4
counter_out = 64
byte mismatch = 185 / 192
```

可靠边界：

```text
tail_b1_hash       MATCH
tail_b6_act1_hash  MISMATCH
tail_rgb_q_hash    MISMATCH
writeback_hash     MISMATCH
```

因此下一步不是继续猜 tail，而是先导出 `src_b6_act1_hash`：

```text
src_b6_act1 mismatch
  -> 最后一个 block 的 C1 tap / b6_act1 source 已经错

src_b6_act1 match, tail_b6_act1 mismatch
  -> source 正确，错误发生在 feature buffer replay / tail handoff / tail 输入对齐
```

## 4. 当前实现动作

已经完成：

```text
1. 修正 continue_w8a12_mismatch_flow.ps1：
   - 不再把 bank1_tail_feat0_hash 当作边界。
   - 支持 src_b6_act1_hash。
   - 增加 src_b6_mismatch 与 tail_b6_after_debug_range_mismatch 自测。

2. 修正 RTL debug：
   - DEBUG_SRC_HASH=1 时保留真实 source hash。
   - JTAG endpoint 新增 bank3，导出 src_b6_act1_hash。

3. 修正读寄存器脚本：
   - read_jtag_w8a12_tile_writer_regs.tcl 读取 bank3。
   - run_read_jtag_w8a12_tile_writer_regs.ps1 写入 summary。

4. 行为仿真：
   - run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 PASS。
```

2026-07-01 已完成：

```text
构建 current_dbg2_source_b6_20260701 bitstream
TIMING_CHECK = PASS
WNS_NS = 12.517
WHS_NS = 0.010
```

当前阻塞：

```text
source-b6 上板 flow 被 JTAG/PnP 门禁拦截。
W8A12_JTAG_STACK_STATUS = BLOCKED_PNP
D2XX device count = 0
USB Serial Converter A/B = Disconnected / CM_PROB_PHANTOM
```

## 5. 修复闭环

拿到新板端 summary 后按以下方式推进：

```text
若 first_mismatch = src_b6_act1_hash：
  1. 在 sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v
     检查 last block 的 tap_c1_active、block_q、c1 输出 valid-ready。
  2. 在 sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v
     检查 block_index_r、last_block、tap_b6_act1_valid/ready。
  3. 修复后先跑 raw-compare 行为仿真，再跑 OOC/bitstream。

若 first_mismatch = tail_b6_act1_hash 且 src_b6_act1_hash MATCH：
  1. 检查 sr_feature_tile_buffer_streamer.v 的 b6_act1 实例读写时序。
  2. 检查 sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v 的四路 tail 输入 ready 夹逼。
  3. 检查 span_w8a12_tail_streamed_rgb.v 对 b6_act1_i 的采样顺序。

若 first_mismatch = tail_rgb_q_hash：
  检查 tail 内部 concat、conv2、upsampler、pixelshuffle/RGB。

若 first_mismatch = writeback_hash：
  检查 sr_tile_output_writer.v、RGB888 packing、输出 index/readback。
```

## 6. 验收命令

解析器回归：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\test_continue_w8a12_mismatch_flow_parser.ps1 -OutputRoot W8A12_3lane\verification\datapath_debug_flow\runs\continue_flow_parser_tests_src_b6_green2_20260630
```

新位流上板：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\continue_w8a12_mismatch_flow.ps1 -OutputDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\continue_w8a12_mismatch_source_b6_20260701
```

最终修复通过标准：

```text
W8A12_MISMATCH_FLOW_STATUS = BOUNDARY_HASH_PASS 或后续 final compare PASS
final byte mismatch = 0 / 192
frame_done = 1
error = 0
```
