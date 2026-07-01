# 第一处失败边界后的下一步 Playbook

本文回答两个问题：

```text
1. 边界 hash 已经细分到某一行失败后，下一轮具体做什么？
2. suspect region 固定后，如何修改 RTL 并证明 mismatch 已修好？
```

每次确定第一处失败边界后，都要查 `rtl_target_map.md`，选择对应的 RTL owner，并进入修复闭环。

基本原则：

```text
Full path run 用来判断第一处 mismatch 在哪里。
Replay run 用来判断被选模块本身是否有问题。
Raw dump 只在 suspect region 已经很小时使用。
```

## 通用下一轮模式

每次发现第一处 mismatch 后，后续工作固定为四步：

```text
1. Freeze
   固定输入、bitstream 构建策略、mode、expected hash，不再同时变更多个条件。

2. Add One More Boundary
   只在失败边界前后新增 1 到 3 个更细的 hash/count/first/last。

3. Replay Or Bypass
   对可疑模块使用 golden vector replay，或 bypass 该模块确认下游是否正常。

4. Decide
   写出 matched-through、first-mismatch、suspect-region、next-action。
```

有效结论示例：

```text
Matched through: spab_b1_input_hash
First mismatch: spab_b1_c1_hash
Suspect region: block1 C1 MAC/requant path
Next action: run MODE_REPLAY_BLOCK1_C1 with golden spab_b1_input vector
```

进入修复阶段后，再追加：

```text
5. Patch RTL Owner
   根据 rtl_target_map.md 修改最小责任 RTL。

6. Replay Regression
   先跑该模块 replay，证明局部已经修好。

7. Full Closure
   再跑 true2x2 full hash 和最终 board/reference compare。
```

## 情况 A: `src_feat0` 不匹配

含义：

```text
board src_feat0 != reference src_feat0
```

优先怀疑：

```text
input DDR address/stride
halo crop/fill
front-end line buffer/window
RGB/channel unpack
signed/unsigned conversion before feature path
reset leaves stale front-end state
```

下一轮 probe：

```text
input_ddr_hash
input_pixel_unpack_hash
halo_pixel_hash
window3x3_hash
conv1_input_window_hash
src_feat0_hash
```

推荐实验：

```text
MODE_LOOPBACK_INPUT
  DDR input -> readback/hash

MODE_FRONTEND_ONLY
  DDR input -> halo/window/front-end hash，不启用 SPAB/tail
```

判定：

```text
input_ddr mismatch
  -> 先修 PS/DDR/input writer

input_ddr match，halo/window mismatch
  -> 修 tile coordinate、halo fill、stride、line-window order

halo/window match，src_feat0 mismatch
  -> 修 front-end conv 或 source feature generation
```

主要 RTL：

```text
../rtl/board/sr_tile_halo_fetch_stream_shell.v
../rtl/board/sr_tile_halo_fetch_w8a12_conv1_shell.v
../rtl/board/sr_tile_fetch_w8a12_conv1_shell.v
../rtl/span/span_rgb_line_window3x3.v
../rtl/span/span_w8a12_feature_line_window3x3.v
../rtl/span/span_w8a12_conv1_streamed_frontend.v
../rtl/span/span_w8a12_rgb_normalize.v
```

## 情况 B: `src_feat0` 匹配，`b1_input` 不匹配

含义：

```text
front/source feature 正确
block1 看到的输入不正确
```

优先怀疑：

```text
source tap select
feature bank read address
ping-pong bank selection
replay mux
stream packing into block1
valid-ready duplicate or drop at block1 input
```

下一轮 probe：

```text
src_feat0_hash
src_b1_hash
bank_read_addr_hash
bank_read_data_hash
replay_mux_out_hash
spab_b1_input_hash
```

推荐实验：

```text
MODE_REPLAY_B1_INPUT
  golden src_b1 vector -> block1 input path -> spab_b1_input_hash

MODE_BANK_BYPASS
  如果可行，绕过 feature bank/replay mux，直接把 source 喂给 block1
```

判定：

```text
bank_read_data mismatch
  -> feature bank write/read address 或 bank swap 问题

bank_read_data match，replay_mux_out mismatch
  -> replay mux/select timing 问题

replay_mux_out match，spab_b1_input mismatch
  -> block input packing 或 handshake 问题
```

主要 RTL：

```text
../rtl/board/sr_feature_tile_buffer_streamer.v
../rtl/board/sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v
../rtl/span/span_w8a12_feature_bank4.v
../rtl/span/span_w8a12_conv1_spab6_taps_streamed_frontend.v
../rtl/span/span_w8a12_conv1_spab6_streamed_frontend.v
../rtl/span/span_w8a12_spab6_streamed_frontend.v
```

## 情况 C: `b1_input` 匹配，`c1` 不匹配

含义：

```text
block1 input 正确
C1 output 错误
```

优先怀疑：

```text
C1 window/tap order
C1 weight file or bank
MAC accumulation signedness
requant q31/shift/bias
activation/clip
valid-ready around C1 output
```

下一轮 probe：

```text
spab_b1_input_hash
c1_window_hash
c1_weight_addr_hash
c1_acc_raw_hash
c1_bias_add_hash
c1_requant_hash
c1_clip_hash
spab_b1_c1_hash
```

推荐实验：

```text
MODE_REPLAY_BLOCK1_C1
  golden spab_b1_input vector -> C1 only -> c1 hashes
```

判定：

```text
c1_window mismatch
  -> window/tap/channel order 问题

c1_acc_raw mismatch
  -> MAC、weight、signedness 或 tap order 问题

c1_acc_raw match，requant mismatch
  -> bias/q31/shift/rounding 问题

requant match，c1 mismatch
  -> activation/clip/packing/handshake 问题
```

主要 RTL：

```text
../rtl/board/sr_w8a12_block1_c1_single_out_tile_engine.v
../rtl/board/sr_w8a12_block1_c1_single_out_buffered_tile_engine.v
../rtl/board/sr_w8a12_block_group_single_out_tile_engine.v
../rtl/board/sr_w8a12_block_group_single_out_buffered_tile_engine.v
../rtl/span/span_w8a12_block1_c1_single_out_kernel.v
../rtl/span/span_w8a12_block_group_single_out_conv_act_kernel.v
../rtl/span/span_w8a12_block_group_single_out_conv_layer.v
../rtl/span/span_w8a12_requant.v
../rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c1_r_*.mem
```

## 情况 D: `c1` 匹配，`c2` 不匹配

含义：

```text
C1 output 正确
C2 output 错误
```

优先怀疑：

```text
C2 replay source
C2 window generation
C2 weight/requant
C2 scheduler latency
backpressure between C1 and C2
```

下一轮 probe：

```text
spab_b1_c1_hash
c2_replay_in_hash
c2_window_hash
c2_acc_raw_hash
c2_requant_hash
spab_b1_c2_hash
```

推荐实验：

```text
MODE_REPLAY_BLOCK1_C2
  golden C1 output vector -> C2 only -> c2 hashes
```

判定：

```text
c2_replay_in mismatch
  -> replay buffer 或 C1 output storage 问题

c2_window mismatch
  -> C2 line-window/read-order 问题

c2_acc_raw mismatch
  -> C2 MAC/weight/signedness 问题

c2_acc_raw match，c2 mismatch
  -> C2 requant/activation/packing 问题
```

主要 RTL：

```text
../rtl/board/sr_w8a12_block1_c2_single_out_tile_engine.v
../rtl/board/sr_w8a12_block1_c2_single_out_buffered_tile_engine.v
../rtl/board/sr_w8a12_block1_c1c2c3_attention_buffered_tile_engine.v
../rtl/board/sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v
../rtl/span/span_w8a12_block1_c2_single_out_kernel.v
../rtl/span/span_w8a12_block_group_single_out_conv_act_kernel.v
../rtl/span/span_w8a12_feature_line_window3x3.v
../rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c2_r_*.mem
```

## 情况 E: `c1/c2/c3` 匹配，`att` 不匹配

含义：

```text
三个 conv 分支正确
attention 或 residual 输出错误
```

优先怀疑：

```text
attention LUT
attention multiply scale
residual add order
clip/saturation order
channel alignment between residual and attention path
```

下一轮 probe：

```text
spab_b1_c3_hash
attention_lut_in_hash
attention_lut_out_hash
attention_mul_raw_hash
residual_add_hash
spab_b1_att_hash
```

推荐实验：

```text
MODE_REPLAY_BLOCK1_ATT
  golden C3/residual vectors -> attention/residual only -> att hash
```

判定：

```text
lut_out mismatch
  -> LUT init/address 问题

mul_raw mismatch
  -> multiply scale/signedness/channel pairing 问题

residual_add mismatch
  -> residual source 或 add order 问题

residual_add match，att mismatch
  -> final clip/packing/handshake 问题
```

主要 RTL：

```text
../rtl/board/sr_w8a12_attention_residual_tile_engine.v
../rtl/board/sr_w8a12_block1_attention_residual_tile_engine.v
../rtl/board/sr_w8a12_block_group_attention_residual_tile_engine.v
../rtl/board/sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v
../rtl/span/span_w8a12_attention.v
../rtl/span/span_w8a12_block_group_attention.v
../rtl/span/span_w8a12_block_group_unary_lut.v
../rtl/span/span_w8a12_unary_lut.v
../rtl/generated/reds_span_x4_f48_w8a12/block_group/block_all_attention_*.mem
```

## 情况 F: 前面都匹配，`tail_b1` 不匹配

含义：

```text
front/block 数据正确
tail input boundary 错误
```

优先怀疑：

```text
tail input concat order
skip feature selection
block output to tail handoff
channel order
tail valid-ready boundary
stale buffer after reset
```

下一轮 probe：

```text
block1_out_hash
block6_out_hash
tail_skip_select_hash
tail_concat_hash
tail_b1_hash
tail_rgb_q_hash
```

推荐实验：

```text
MODE_REPLAY_TAIL_INPUT
  golden block/skip vectors -> tail input concat -> tail_b1_hash

MODE_TAIL_ONLY
  golden tail concat vector -> tail/RGB -> rgb hash
```

判定：

```text
tail_skip_select mismatch
  -> wrong skip source 或 bank selection

tail_concat mismatch
  -> concat/channel order 问题

tail_concat match，tail_b1 mismatch
  -> tail first conv/MAC/requant 或 input handshake 问题
```

主要 RTL：

```text
../rtl/board/sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v
../rtl/board/sr_tile_halo_fetch_w8a12_front_tail_writer_shell.v
../rtl/board/sr_tile_halo_w8a12_writer_shell.v
../rtl/board/sr_tile_rgb_buffer_streamer.v
../rtl/span/span_w8a12_tail_streamed_rgb.v
../rtl/span/span_w8a12_upsampler0_pixelshuffle_streamed_rgb.v
../rtl/span/span_w8a12_pixelshuffle_x4_streamed_rgb.v
../rtl/generated/reds_span_x4_f48_w8a12/mem/conv_2_*.mem
../rtl/generated/reds_span_x4_f48_w8a12/mem/conv_cat_*.mem
../rtl/generated/reds_span_x4_f48_w8a12/mem/upsampler_0_*.mem
```

## 什么时候可以改 RTL

不要在只有最终 mismatch 时改 RTL。满足下面任一条件再改：

```text
same boundary fails in two repeated full-path runs
REPLAY mode reproduces the failure
or a bypass test proves the failure disappears when one interface is skipped
```

每次 RTL 修改后只重新跑相关最小测试：

```text
module replay test
same true2x2 boundary hash full-path test
then final output compare
```

每次 patch 必须记录：

```text
rtl_owner
patched_files
why_this_owner
pre_fix_first_mismatch
post_fix_replay_result
post_fix_full_hash_result
post_fix_final_compare_result
```

## 什么时候停止当前分支

出现下面情况时，不继续沿当前方向改 RTL，先回退检查基础设施或 probe 本身：

```text
hash count is zero unexpectedly
counts vary between repeated runs
first/last vary while input and bitstream are unchanged
same bitstream gives non-deterministic boundary hash
frame_done/error behavior changes after adding a probe
```

这些现象通常说明 probe 本身扰动了时序、reset/clear 不干净，或 valid-ready 统计条件不一致。
