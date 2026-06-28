# A2/A3 Tile Scheduler 接口契约

本文档定义 `W8A12_3lane` 从 A2 语义仿真走向 A5 上板所需的可综合 tile pipeline 外壳。目标不是改变 A0-A3 已验证的数学路径，而是把它们接成可控、可观测、可综合的 tile 级流程。

## 1. 覆盖范围

第一版 tile pipeline 覆盖：

```text
load tile + halo
  -> conv1
  -> SPAB block0..block5
  -> tail / pixelshuffle
  -> RGB writer
```

其中：

- SPAB block 内部仍使用 3-lane output-channel 并行。
- 6 个 block 串行推进。
- feature buffer 使用 A/B ping-pong。
- feature bank 使用 3 banks x 16 channels。
- 第一验收目标仍是 `32x32 LR tile + halo=21 -> 128x128 RGB`。

## 2. 控制相位

| phase | 名称 | 说明 |
| ---: | --- | --- |
| 0 | IDLE | 等待 `start_i` |
| 1 | LOAD | tile + halo 输入装载 |
| 2 | CONV1 | RGB/YUV 输入到 48ch feature |
| 3 | SPAB | block0..block5 串行执行 |
| 4 | TAIL | conv2、concat、conv_cat、upsampler、pixelshuffle |
| 5 | WRITE | RGB888 写出 |
| 6 | DONE | 拉高 `done_o`，等待 `start_i` 拉低 |
| 7 | ERROR | 协议错误或下游错误 |

## 3. Ping-Pong 规则

`block_idx_o` 表示正在执行的 block，范围 0..5。

| block_idx | input buffer | output buffer |
| ---: | --- | --- |
| 0 | A | B |
| 1 | B | A |
| 2 | A | B |
| 3 | B | A |
| 4 | A | B |
| 5 | B | A |

因此 `block5` 完成后最终 feature 在 buffer A。

## 4. 接口分层

外壳只负责调度，不直接实现数学算子。每个 stage 使用 ready/valid 风格的启动/完成握手：

```text
stage_start_o
stage_done_i
stage_error_i
```

后续接入时：

- `load_done_i` 来自 tile/halo reader。
- `conv1_done_i` 来自 conv1 3-lane engine。
- `spab_done_i` 来自 single SPAB block engine。
- `tail_done_i` 来自 tail/pixelshuffle engine。
- `write_done_i` 来自 RGB/DDR writer。

## 5. 验收信号

外壳必须导出：

```text
phase_o
block_idx_o
read_buf_o
write_buf_o
lane_valid_o = 3'b111
done_o
error_o
```

这些信号用于：

- xsim 分层检查；
- ILA/调试寄存器观测；
- 上板 summary 记录；
- 失败回退定位。

## 6. 当前 RTL 骨架

```text
W8A12_3lane/rtl/span/w8a12_3lane_tile_pipeline_shell.v
```

该骨架是可综合控制 FSM，不声明 A2/A3 功能通过。它的作用是固定 A5 上板前必须接入的阶段边界和观测信号。

## 7. 后续接入顺序

1. 将 A4 3-lane scheduler 接入 `conv1` 或单层 conv stage。
2. 将 A1/A2 已验证的 SPAB block engine 接入 `spab` stage。
3. 将 A3 tail/pixelshuffle/RGB path 接入 `tail` 和 `write` stage。
4. 建立 32x32 tile testbench，对齐 Python fixed reference。
5. 生成 bitstream 并形成 A5 board report。
