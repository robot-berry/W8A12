# 失败回退流程

本文档定义 W8A12_3lane 新主线的失败处理和回退规则。核心原则是：哪一层失败，就回退到该层的最小复现，不跨层排查。

## 1. 总原则

1. 不在失败层继续叠加新功能。
2. 不跳过失败层进入下一阶段。
3. 不同时修改多个可疑模块。
4. 每次只改变一个变量，并记录到 summary。
5. 优先回退到最近一次 bit-exact 或 PASS 的 evidence。
6. 新主线失败时，不回旧线继续补丁；旧线只作为 reference 和工具来源。

## 2. 回退锚点

每个阶段通过后，必须保存一个可回退锚点：

```text
W8A12_3lane/evidence/
  A0_single_conv/pass_<tag>/
  A1_single_block/pass_<tag>/
  A2_six_block/pass_<tag>/
  A3_tail_rgb/pass_<tag>/
  A4_ooc/pass_<tag>/
  A5_board_32x32/pass_<tag>/
```

每个 `pass_<tag>` 至少包含：

- `summary.md`
- `summary.json`
- reference 输入
- reference 输出
- RTL 或 board 输出
- `hashes.json`
- `run.log`
- 当前 git commit 或 dirty 状态说明

## 3. A0 失败：单层 3-lane conv

### 现象

- lane0/1/2 任一路输出不匹配；
- `full48_hash` 不匹配；
- 输出数量正确但数值不同。

### 只允许排查

- lane 与 output channel 映射；
- weight bank 映射；
- bias/scale/shift bank 映射；
- 输入 window 顺序；
- 3x3 kernel 顺序；
- INT32 accumulation；
- rounding/shift/saturation 顺序。

### 禁止排查

- SPAB attention；
- ping-pong buffer；
- tail/pixelshuffle；
- DDR/AXI；
- 上板配置。

### 回退动作

1. 固定一个最小输入，例如 1 个或 2 个输出像素。
2. 只跑 lane0；lane0 bit-exact 后再打开 lane1、lane2。
3. 对每个 lane 输出 `first_mismatch_ch`、`first_mismatch_pixel`、`expected`、`actual`。
4. 若 lane 内所有通道都错，优先查 weight bank base。
5. 若只有部分通道错，优先查 `lane_ch -> out_ch` 映射。
6. 若误差呈固定比例，优先查 scale/shift。
7. 若误差只在边缘，优先查 padding/window 顺序。

## 4. A1 失败：单个 SPAB block

### 现象

- A0 已通过，但单 block 输出不匹配；
- C1 匹配，C2/C3 或 attention 不匹配；
- block output hash 不匹配。

### 只允许排查

- C1/C2/C3 串接顺序；
- 每层 activation 位置；
- attention/residual 公式；
- block_i 对应权重；
- block 内中间 feature bank 写回和读取；
- 单 block 内 ready/valid。

### 禁止排查

- 6 block scheduler；
- ping-pong A/B 轮换；
- tail/pixelshuffle；
- DDR/AXI；
- 上板配置。

### 回退动作

1. 回到最近通过的 A0。
2. 固定 `block_i=0`，只跑 block1。
3. 逐边界对比：

```text
block_input
c1_output
c1_activation
c2_output
c2_activation
c3_output
attention_output
block_output
```

4. 哪个边界第一个失败，只查该边界前一段逻辑。
5. block1 通过后，再独立测试 block2 和 block6，避免 block_i 权重选择错位。

## 5. A2 失败：6 block feature

### 现象

- 单 block 通过，但 6 block 不通过；
- block1 对齐，block2-block5 后开始 mismatch；
- block6 input 或 block6 output 不匹配。

### 只允许排查

- `block_i` 递增；
- block_i 与模型 block 编号映射；
- ping-pong buffer swap；
- A/B buffer input/output 选择；
- bank0/1/2 写回顺序；
- block done 和 next block start 的握手；
- backpressure 下是否重复读写。

### 禁止排查

- 单层卷积数学；
- tail/pixelshuffle；
- DDR/AXI；
- 上板配置。

### 回退动作

1. 回到最近通过的 A1。
2. 先跑 2 block：block0 -> block1。
3. 再跑 3 block、4 block、6 block。
4. 每个 block 保存：

```text
block_i
input_buffer
output_buffer
bank0_hash
bank1_hash
bank2_hash
full48_hash
```

5. 如果奇数 block 都错，优先查 A/B swap。
6. 如果某一个 bank 总错，优先查 bank_id 或 lane 写回。
7. 如果只有 block_i=1 以后错，优先查下一 block start 时读取的是不是上一 block output。

## 6. A3 失败：tail / pixelshuffle / RGB

### 现象

- block6 feature 匹配，但 RGB 输出 mismatch；
- 图像颜色错；
- 图像有周期性块状错位；
- 输出像素数量正确但视觉异常。

### 只允许排查

- tail input concat 顺序；
- 48ch bank 拼接顺序；
- tail/reconstruct 权重 bank；
- x4 pixelshuffle channel order；
- RGB channel order；
- 输出 clip/saturation；
- 行尾和帧首信号。

### 禁止排查

- SPAB block 数学；
- 6 block scheduler；
- DDR/AXI；
- 上板配置。

### 回退动作

1. 回到最近通过的 A2。
2. 先跳过 pixelshuffle，只验证 tail conv intermediate。
3. 再验证 pixelshuffle input。
4. 最后验证 RGB888 output。
5. 如果颜色通道互换，优先查 RGB order。
6. 如果 4x4 周期错位，优先查 pixelshuffle channel order。
7. 如果 tile 边缘异常，优先查 halo 和 padding。

## 7. A4 失败：OOC synthesis / resource / timing

### 现象

- xsim 通过，但综合失败；
- resource gate FAIL；
- WNS/WHS 为负；
- BRAM 或 DSP 超过 XC7Z045 门限。

### 只允许排查

- 综合脚本；
- 顶层参数；
- RAM 推断方式；
- weight/feature bank 复制；
- 过宽组合路径；
- DSP 推断；
- debug probe 是否导致资源膨胀。

### 禁止排查

- 改模型结构；
- 减少通道数；
- 减少 SPAB block；
- 移除 attention；
- 缩 halo 逃避资源问题。

### 回退动作

1. 回到最近通过的 A3。
2. 先关掉非必要 debug hash/probe。
3. 检查是否复制了完整 48ch feature buffer。
4. 检查 weight bank 是否被复制多份。
5. 若 BRAM 超限，优先查 buffer 深度和 bank 复制。
6. 若 DSP 超限，检查是否误实例化多套 block engine。
7. 若 timing 失败，先定位最大路径，再加 pipeline，不改数学。

## 8. A5 失败：board 32x32

### 现象

- xsim 和 OOC 通过，但上板失败；
- `FRAME_DONE=0`；
- `ERROR=1`；
- 输出像素数不对；
- board 输出和 reference mismatch。

### 只允许排查

- XSCT 配置寄存器；
- DDR input/output 地址；
- stride；
- tile/halo 坐标；
- AXI 读写握手；
- output writer；
- cache flush/invalidate；
- bitstream 和软件 reference 是否同源。

### 禁止排查

- A0-A3 已通过的数学逻辑；
- 临时改模型或量化规则；
- 临时缩小 halo 或通道数。

### 回退动作

1. 回到最近通过的 A4。
2. 先跑全零输入和固定 ramp 输入。
3. 确认 DDR 输入 SHA256 与 reference 输入一致。
4. 确认配置寄存器读回值正确。
5. 确认输出像素计数。
6. 若输入 hash 错，查 PS/DDR 写入。
7. 若输入 hash 对但输出错，查 PL reader/writer 和 AXI backpressure。
8. 若 board 和 xsim 差异只在边界，查 tile/halo 坐标。

## 9. 失败记录模板

每次失败必须写一个 `failure_summary.md`：

```text
# Failure Summary

阶段:
标签:
日期:
git 状态:

现象:

最近通过锚点:

第一处 mismatch:

本次只改了什么:

已排除:

下一步:
```

## 10. 何时允许进入下一阶段

只有满足以下条件才允许进入下一阶段：

```text
当前阶段 PASS
reference、RTL/board 输出和 hash 已保存
summary 已写
git diff 范围清楚
resource/timing 已记录，如适用
```

