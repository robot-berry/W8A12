# 数据通路调试 RTL 映射表

当工作流给出 `first_mismatching_boundary` 后，按本表选择下一轮检查的 RTL。优先修改最小 owner，不做无关重构。

## Debug Bank 约定

| Bank | 字段 | 用途 |
| --- | --- | --- |
| 0 | `tail_b1_hash`, `tail_b6_act1_hash`, `tail_rgb_q_hash`, `writeback_hash/range/first/last` | 保持旧 stage-hash 兼容，快速判断 tail/writeback |
| 1 | `tail_feat0` 诊断字段、`src_feat0_hash`, `src_b1_hash`, tail/writeback 镜像 | 旧 dbg2 兼容。注意 `tail_feat0` 不作为边界 |
| 2 | SPAB block1 deep hash | 只在 `DEBUG_EXPORT_LEVEL>=3` 时用于 block1 内部分解 |
| 3 | `src_feat0_hash`, `src_block6_hash`, `src_b1_hash`, `src_b6_act1_hash`, tail 三个 hash | 当前 source-b6 定位主 bank |

## 边界到 RTL owner

| 第一处失败边界 | 主要 RTL owner | 检查重点 |
| --- | --- | --- |
| `src_feat0_hash` | `rtl/board/sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v`; `rtl/board/sr_tile_halo_fetch_w8a12_conv1_shell.v`; `rtl/span/span_w8a12_conv1_streamed_frontend.v` | halo fetch、RGB normalize、conv1 valid-ready、feat0 source tap |
| `src_b1_hash` | `rtl/board/sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v`; `rtl/board/sr_feature_tile_buffer_streamer.v`; `rtl/board/sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v` | block1 output/tap、ping-pong replay、first block handoff |
| `src_b6_act1_hash` | `rtl/board/sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v`; `rtl/board/sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v` | `tap_c1_active`、`block_q == BLOCKS-1`、`tap_b6_act1_valid/ready`、last-block C1 输出 |
| `tail_b1_hash` | `rtl/board/sr_feature_tile_buffer_streamer.v`; `rtl/board/sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v` | b1 buffer load/stream、tail 四路输入同步 |
| `tail_b6_act1_hash` | `rtl/board/sr_feature_tile_buffer_streamer.v`; `rtl/board/sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v`; `rtl/span/span_w8a12_tail_streamed_rgb.v` | b6_act1 buffer replay、tail handoff、tail input ready 夹逼 |
| `tail_rgb_q_hash` | `rtl/span/span_w8a12_tail_streamed_rgb.v`; `rtl/span/span_w8a12_conv_cat_scale_concat.v`; `rtl/span/span_w8a12_upsampler0_pixelshuffle_streamed_rgb.v` | concat 顺序、conv2/upsampler、pixelshuffle/RGB 顺序 |
| `writeback_hash` | `rtl/board/sr_tile_output_writer.v`; `rtl/board/sr_tile_halo_fetch_w8a12_front_tail_writer_shell.v`; `rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v` | RGB888 packing、write address/index、readback mux |

## 当前重点

当前旧 dbg2 证据是：

```text
tail_b1_hash MATCH
tail_b6_act1_hash MISMATCH
```

所以新 bitstream 必须先读取 `src_b6_act1_hash`：

```text
src_b6_act1_hash MISMATCH
  -> 优先查 SPAB last-block C1 tap/source。

src_b6_act1_hash MATCH, tail_b6_act1_hash MISMATCH
  -> 优先查 b6_act1 feature buffer replay 或 tail handoff。
```

## 已降级字段

`bank1_tail_feat0_hash` 在当前普通 dbg2 模式下是 RGB q 范围/诊断字段，不是 feature hash。它可以保留在报告中辅助观察输出范围，但不得参与 `first_mismatching_boundary` 判定。
