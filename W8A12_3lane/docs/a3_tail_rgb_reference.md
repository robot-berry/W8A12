# A3 Tail / PixelShuffle / RGB Reference

A3 用于证明三路 block 主线可以继续接到 SPAN 的 tail 结构，形成 x4 RGB 定点输出。

## 1. 输入

当前 A3 reference 使用 deterministic `4x4x48` feature 作为 `conv_1.output`，与 A0/A1/A2 的输入保持一致：

```text
feat0_hash = 0x47766845
```

## 2. 计算路径

```text
feat0
  -> block_1..block_6
  -> conv_2
  -> concat(feat0, conv_2, block_1.out, block_6.act1)
  -> conv_cat
  -> upsampler.0
  -> pixelshuffle x4
  -> rgb_q
```

其中 `conv_cat` 前四路输入需要统一到 `conv_cat.input` scale，Q31 multiplier 来自 quant plan。

## 3. 证据

生成命令：

```powershell
python W8A12_3lane\tools\w8a12_3lane_reference.py a3-tail-rgb
```

输出目录：

```text
W8A12_3lane/evidence/reference/A3_tail_rgb/
```

关键文件：

- `summary.md`
- `summary.json`
- `hashes.json`
- `rgb_q.npy`
- `rgb_q.txt`

## 4. 当前 Hash

| 项目 | Hash |
| --- | --- |
| `block_6_output` | `0xD2AC6553` |
| `conv2` | `0x7C22A0C6` |
| `cat_input` | `0x731D1CD9` |
| `conv_cat` | `0xE6DF97F6` |
| `upsampler_0` | `0x9630BB9C` |
| `rgb_q` | `0x280F9356` |

## 5. 待完成

当前已完成 Python fixed-point reference 和 RTL 语义仿真。A3 还需要：

1. pixelshuffle RGB writer 的板端输出通路接入；
2. 32x32 tile + halo 的真实输入 reference；
3. board 输出与 `rgb_q` 或 RGB888 reference 的一致性检查。

RTL 语义仿真证据见：

```text
W8A12_3lane/evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md
```
