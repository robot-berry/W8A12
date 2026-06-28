# 三路并行 Bank 映射规则

本文档定义 W8A12_3lane 中 lane、权重 bank、feature bank 和 tail 拼接的固定映射。所有 Python reference、RTL、testbench 和 debug hash 必须使用同一套规则。

## 1. Lane 与输出通道映射

固定使用 3 个 lane，每个 lane 负责 16 个输出通道：

| lane_id | output channel 范围 | 说明 |
| ---: | --- | --- |
| 0 | 0..15 | 低 16 通道 |
| 1 | 16..31 | 中 16 通道 |
| 2 | 32..47 | 高 16 通道 |

公式：

```text
lane_id = out_ch / 16
lane_ch = out_ch % 16
out_ch  = lane_id * 16 + lane_ch
```

## 2. 输入通道规则

每个 lane 都必须读取完整 48 个输入通道：

```text
for out_ch in lane range:
  acc = sum(in_ch=0..47, ky=0..2, kx=0..2)
```

禁止第一版只让 lane0 读 input channels 0..15、lane1 读 16..31、lane2 读 32..47。那是 input-channel split，会产生 partial sum，不是当前新主线。

## 3. Feature Bank 映射

48ch feature 固定拆成 3 个 bank：

| bank_id | feature channel 范围 | 对应 lane |
| ---: | --- | ---: |
| 0 | 0..15 | lane0 |
| 1 | 16..31 | lane1 |
| 2 | 32..47 | lane2 |

公式：

```text
bank_id = ch / 16
bank_ch = ch % 16
ch      = bank_id * 16 + bank_ch
```

## 4. Feature 地址格式

第一版建议使用像素优先地址，bank 内保存 16 个通道：

```text
addr = y * TILE_W + x
data = feature[y][x][bank_id][0..15]
```

逻辑 tensor 视图：

```text
feature[y][x][ch]
```

物理 bank 视图：

```text
feature_bank[bank_id][addr][bank_ch]
```

转换关系：

```text
feature[y][x][ch]
  = feature_bank[ch / 16][y * TILE_W + x][ch % 16]
```

## 5. Ping-Pong Buffer 映射

使用两套 3-bank feature buffer：

```text
buffer A:
  A.bank0
  A.bank1
  A.bank2

buffer B:
  B.bank0
  B.bank1
  B.bank2
```

block 调度：

| block_i | input buffer | output buffer |
| ---: | --- | --- |
| 0 | A | B |
| 1 | B | A |
| 2 | A | B |
| 3 | B | A |
| 4 | A | B |
| 5 | B | A |

因此 block5 完成后，最终 feature 在 buffer A。

如果实现中 block 编号使用 1..6 命名，必须在文档中明确：

```text
block_i=0 对应模型 block1
block_i=5 对应模型 block6
```

## 6. 权重 Bank 映射

权重按 output-channel lane 分 bank：

```text
weight_bank[lane_id][lane_ch][in_ch][ky][kx]
```

对应模型权重：

```text
weight[out_ch][in_ch][ky][kx]
```

转换关系：

```text
weight_bank[lane_id][lane_ch][in_ch][ky][kx]
  = weight[lane_id * 16 + lane_ch][in_ch][ky][kx]
```

每个 lane 只读自己的 `weight_bank[lane_id]`，但每个 lane 都遍历全部 `in_ch=0..47`。

## 7. Bias / Scale / Shift 映射

bias、scale、shift 与 output channel 绑定，映射方式和权重一致：

```text
bias_bank[lane_id][lane_ch]  = bias[out_ch]
scale_bank[lane_id][lane_ch] = scale[out_ch]
shift_bank[lane_id][lane_ch] = shift[out_ch]
```

其中：

```text
out_ch = lane_id * 16 + lane_ch
```

## 8. Lane 输出拼接顺序

三路 lane 输出组成 48ch 逻辑 feature 时，顺序固定为：

```text
lane0[0..15], lane1[0..15], lane2[0..15]
```

等价通道顺序：

```text
ch 0..15, ch 16..31, ch 32..47
```

禁止使用交错顺序：

```text
lane0_ch0, lane1_ch0, lane2_ch0, lane0_ch1, ...
```

除非重新定义所有 reference、tail 和 pixelshuffle 映射。

## 9. Tail 读取规则

tail 阶段读取 48ch feature 时，必须按逻辑通道顺序读取：

```text
for ch = 0..47:
  bank_id = ch / 16
  bank_ch = ch % 16
  value = feature_bank[bank_id][addr][bank_ch]
```

如果 tail 需要 concat 多路 skip feature，concat 顺序必须在 reference 和 RTL 中一致。

建议第一版显式记录 concat 顺序，例如：

```text
tail_input = concat(feat0, block1, block5, block6)
```

实际以模型导出和旧 reference 为准，不能凭直觉改。

## 10. Hash 规则

每个阶段至少统计：

```text
bank0_hash
bank1_hash
bank2_hash
full48_hash
```

full48 hash 必须按逻辑通道顺序计算：

```text
for y
  for x
    for ch = 0..47
      update_hash(feature[y][x][ch])
```

不要按物理 bank 顺序直接 hash 后声称是 full48 hash，除非 hash 规则明确写为 bank-major。

## 11. 常见错误

| 错误 | 现象 |
| --- | --- |
| 按 input channel 拆 lane | 数值和 reference 不一致，需要 partial sum |
| lane 拼接成交错顺序 | tail/RGB 严重错色或纹理异常 |
| ping-pong swap 错 | block1 对齐，block2-block5 后开始 mismatch |
| block_i 与模型 block 编号错位 | 单 block 可过，6 block 不过 |
| bank hash 和 full48 hash 规则混用 | debug 结论互相矛盾 |
| tail concat 顺序错 | block feature 对齐，但最终 RGB mismatch |

