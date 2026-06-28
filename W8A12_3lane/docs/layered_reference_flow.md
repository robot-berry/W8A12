# 分层 Reference 流程

三路并行新线的核心验收标准是：硬件并行方式改变，但数学结果不变。因此每一级 RTL 都必须对齐 Python W8A12 fixed-point reference。

## 1. 总原则

每个阶段都生成三类文件：

```text
reference 输入
reference 输出
reference hash/summary
```

RTL 仿真只和当前阶段 reference 对比，不跨级猜问题。

## 2. 分层阶段

| 阶段 | 名称 | 目标 | 输出 |
| --- | --- | --- | --- |
| A0 | 单层 3-lane conv | 验证 output-channel lane 拆分正确 | 48ch conv output |
| A1 | 单个 SPAB block | 验证 C1/C2/C3/attention/residual 正确 | 48ch block output |
| A2 | 6 block feature | 验证 `block_i=0..5` 调度和 ping-pong 正确 | block6 feature |
| A3 | tail/pixelshuffle/RGB | 验证 tail、channel order、pixelshuffle 正确 | RGB888 tile |
| A4 | OOC synthesis | 验证资源和时序 | utilization/timing/resource gate |
| A5 | board 32x32 | 验证 DDR/AXI/板端配置 | board RGB output |

## 3. A0：单层 3-lane conv reference

### 输入

- 一个小 tile 的 48ch feature window。
- 一个目标卷积层的 W8A12 权重、bias、scale、shift。
- 输出通道范围：

```text
lane0: out_ch  0..15
lane1: out_ch 16..31
lane2: out_ch 32..47
```

### Python reference 要做什么

1. 使用完整 48 个 input channels。
2. 对每个 output channel 独立计算 3x3 convolution。
3. 使用原 W8A12 累加、scale、bias、activation、clip 规则。
4. 输出 48ch feature。
5. 额外输出三个 lane 的 hash：

```text
lane0_hash
lane1_hash
lane2_hash
full48_hash
```

### 通过标准

- RTL lane0/1/2 输出分别匹配 Python lane0/1/2。
- 拼回 48ch 后 `full48_hash` 匹配。
- 首选 bit-exact。

## 4. A1：单个 SPAB block reference

### 输入

- 48ch input feature。
- 指定 `block_i` 的 C1/C2/C3/attention 权重和量化参数。

### Python reference 要做什么

依次输出以下边界：

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

每个边界保存：

- raw tensor，
- hash，
- shape，
- min/max，
- checksum。

### 通过标准

- A0 已经通过。
- 单 block RTL 每个关键边界 hash 匹配。
- `block_output` bit-exact 匹配。

## 5. A2：6 block feature reference

### 输入

- conv1 后的 48ch feature。
- block0 到 block5 的全部权重和量化参数。

### Python reference 要做什么

保存每个 block 的输入和输出：

```text
block0_input
block0_output
block1_input
block1_output
...
block5_input
block5_output
```

### RTL 对比重点

如果 A2 失败，优先查：

- `block_i` 是否递增正确；
- ping/pong buffer 是否 swap 正确；
- bank0/1/2 写回顺序是否正确；
- 下一 block 读取的 bank 是否是上一 block 输出；
- ready/valid backpressure 是否造成重复写或漏写。

### 通过标准

- 每个 block 的 input/output hash 匹配。
- 最终 `block5_output` 或 `block6 feature` 匹配。

## 6. A3：tail/pixelshuffle/RGB reference

### 输入

- conv1 feature，
- block1/block5/block6 等 tail 所需 skip feature，
- tail/reconstruct/pixelshuffle 权重和量化参数。

### Python reference 要做什么

保存：

```text
tail_input_concat
tail_conv_output
pixelshuffle_input
rgb888_output
```

### RTL 对比重点

如果 A3 失败，优先查：

- 48ch bank 拼接顺序；
- tail concat 顺序；
- x4 pixelshuffle channel order；
- RGB channel order；
- 饱和截断位置。

### 通过标准

- RGB888 tile bit-exact 匹配。
- 输出像素数正确。

## 7. A4：OOC synthesis reference

此阶段不看画质，只看资源和时序。

必须保存：

- utilization report，
- timing report，
- resource gate JSON/MD，
- Vivado log，
- 构建参数。

通过标准：

- XC7Z045 resource gate PASS。
- WNS/WHS 非负。

## 8. A5：board 32x32 reference

### 输入

- 同 A3 的 32x32 LR tile 或整图输入。
- 固定 halo=21。
- x4 输出 128x128 RGB。

### 板端通过标准

- `FRAME_DONE=1`。
- `ERROR=0`。
- 输出像素数正确。
- board RGB 与 Python RGB reference bit-exact。

若不通过，优先查：

- DDR input 地址和 stride；
- tile/halo 坐标；
- AXI/ready/valid；
- output writer 地址；
- XSCT 配置寄存器。

## 9. Evidence 命名

建议按阶段保存 evidence：

```text
W8A12_3lane/evidence/
  A0_single_conv/
  A1_single_block/
  A2_six_block/
  A3_tail_rgb/
  A4_ooc/
  A5_board_32x32/
```

每个目录至少包含：

```text
summary.md
summary.json
input.bin 或 input.npy
reference_output.bin 或 reference_output.npy
rtl_output.bin 或 board_output.rgb
hashes.json
run.log
```

