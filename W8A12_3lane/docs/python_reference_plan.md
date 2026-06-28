# W8A12_3lane Python Reference 落地计划

本文档固定 W8A12_3lane 新主线使用的 Python reference 来源、数据集口径、checkpoint 和分层输出要求。

## 1. 当前训练集和验证集

当前 x4/F48 和 x2/F48 SPAN 模型均使用 REDS 数据集。

| 项目 | 当前口径 |
| --- | --- |
| 训练 GT | `G:/REDS/train_sharp` |
| 训练 LQ | `G:/REDS/train/train_sharp_bicubic/X4` |
| 训练 meta | `configs/meta_info_REDS_train_GT.txt` |
| 训练图像数 | 24000 |
| 验证 GT | `G:/REDS/val_sharp` |
| 验证 LQ | `G:/REDS/val/val_sharp_bicubic/X4` |
| 验证 meta | `configs/meta_info_REDS_val_GT.txt` |
| 验证图像数 | 3000 |
| 图像尺寸 | meta 记录为 `(720,1280,3)` |

证据来源：

- `configs/train_reds_span_x4.json`
- `configs/meta_info_REDS_train_GT.txt`
- `configs/meta_info_REDS_val_GT.txt`
- `runs/official_span/official_SPAN_REDS_x4_f48/train_official_SPAN_REDS_x4_f48_20260523_211359.log`

训练日志中记录：

```text
Number of train images: 24000
Number of val images/folders in REDS_val: 3000
```

## 2. 画质目标和当前 checkpoint

新主线采用双倍率目标：

| 倍率 | 目标 | 当前证据 | 状态 |
| --- | --- | --- | --- |
| x4 | REDS_val PSNR `>= 28 dB` | x4/F48 checkpoint 达到 `28.3118 dB` | 已有训练证据，W8A12 定点/RTL 需闭环 |
| x2 | REDS_val PSNR `>= 30 dB` | x2/F48 checkpoint 达到 `34.4297 dB` | 已有 FP32/official SPAN 训练证据，W8A12 定点/RTL 需闭环 |

注意：上述 PSNR 是训练日志中的 REDS_val 验证结果。赛题最终报告需要同时给出 FP32、W8A12 fixed-point、RTL/board 三个层级的指标或一致性说明。

## 3. 当前选定 checkpoint

当前硬件 handoff 使用的成熟 x4/F48 checkpoint：

```text
runs/official_span/official_SPAN_REDS_x4_f48/models/net_g_295000.pth
```

对应记录：

```text
best validation PSNR: 28.3118 dB
Best: 28.3118 @ 295000 iter
```

证据来源：

- `runs/reds_span_hardware_handoff/handoff_reds_span_x4_f48_best295k.md`
- `runs/official_span/official_SPAN_REDS_x4_f48/train_official_SPAN_REDS_x4_f48_20260523_211359.log`

当前 x2/F48 checkpoint：

```text
runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth
runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_latest.pth
```

对应记录：

```text
Best: 34.4297 @ 300000 iter
Best: 34.4297 @ 300001 iter
```

证据来源：

- `runs/official_span/official_SPAN_REDS_x2_f48/train_official_SPAN_REDS_x2_f48_20260524_161741.log`
- `rtl/generated/official_span_x2/official_span_manifest.json`

## 4. 旧线可复用 Python reference

新主线不从零重写全部 reference，先复用旧线已经验证过的 W8A12 定点函数。

| 旧工具 | 作用 | 新线用途 |
| --- | --- | --- |
| `tools/run_span_w8a12_integer_reference.py` | 完整 REDS-trained SPAN W8A12 integer reference | A2/A3/A5 的全链路 reference 基础 |
| `tools/compute_w8a12_tail_debug_hashes.py` | 生成 tail 和 SPAB 边界 hash | A1/A2/A3 的 debug hash 基础 |
| `tools/compare_span_w8a12_conv1_frame.py` | conv1 frame reference | A0/A2 conv1 reference |
| `tools/generate_span_w8a12_spab_frame_tb.py` | SPAB 中 LUT、attention、activation helper | A1 单 block reference |
| `tools/generate_span_w8a12_tail_frame_tb.py` | tail、conv、pixelshuffle helper | A3 tail/RGB reference |

新线应复制或包装这些工具，而不是直接在旧工具上继续改主线逻辑。

建议新文件：

```text
W8A12_3lane/tools/w8a12_3lane_reference.py
```

该文件作为统一入口，内部可以 import 旧工具中的成熟函数。

## 5. Reference 输入文件

第一版固定使用已导出的 W8A12 generated constants：

```text
rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rtl_manifest.json
rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_rgb_norm.json
rtl/generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json
runs/reds_span_quant_plan/reds_span_x4_f48_w8a12_reds_val4/span_w8a12_quant_plan.json
```

如果后续重新量化或重新导出，必须在 evidence 中记录新的 manifest 和 quant plan。

对于 x2 路线，当前已有 official SPAN x2 导出：

```text
rtl/generated/official_span_x2/official_span_manifest.json
```

x2 若进入 W8A12_3lane 主线，必须补齐与 x4 类似的 W8A12 quant plan、RTL manifest 和 fixed-point reference evidence；不能只用 FP32 训练 PSNR 替代硬件定点验收。

## 6. Reference 输出目录

新线 reference 输出统一放在：

```text
W8A12_3lane/evidence/reference/
```

按阶段分目录：

```text
W8A12_3lane/evidence/reference/
  A0_single_conv/
  A1_single_block/
  A2_six_block/
  A3_tail_rgb/
  A5_board_32x32/
```

## 7. Tensor 数据格式

第一版采用两种格式同时保存：

| 格式 | 用途 |
| --- | --- |
| `.npy` | Python 调试和快速加载 |
| `.txt` 或 `.mem` | RTL testbench 读取 |

逻辑顺序固定：

```text
for y
  for x
    for ch
      value
```

即 HWC / pixel-major / channel-last。

feature tensor：

```text
shape = [height, width, 48]
dtype = int16 或 int32，按阶段说明
```

RGB tensor：

```text
shape = [height * scale, width * scale, 3]
dtype = uint8 或 signed q value，按阶段说明
```

## 8. Hash 规则

必须同时输出：

```text
bank0_hash
bank1_hash
bank2_hash
full48_hash
```

full48 hash 使用逻辑通道顺序：

```text
for y
  for x
    for ch = 0..47
      update_hash(feature[y][x][ch])
```

hash 算法第一版沿用旧线：

```text
rtl_debug_rotl5_xor_v1
```

对应旧实现位于：

```text
tools/compute_w8a12_tail_debug_hashes.py
```

## 9. A0 单层 3-lane reference

A0 是新线第一件要落地的 Python reference。

目标：

```text
验证 48 输出通道按 3 x 16ch lane 拆分后，结果仍等价于原 W8A12 单层卷积。
```

输入：

- 一个小 feature tile，例如 `2x2` 或 `4x4`。
- 选定层权重，例如 `block_1.c1_r`。
- generated quantization 参数。

输出：

```text
input_feature.npy
lane0_output.npy
lane1_output.npy
lane2_output.npy
full48_output.npy
hashes.json
summary.md
```

通过标准：

- `concat(lane0,lane1,lane2) == full48_output`
- `full48_output` 与原串行 W8A12 layer reference bit-exact

## 10. A1-A5 Reference 扩展

A0 通过后再扩展：

| 阶段 | Python 输出 |
| --- | --- |
| A1 | `block_input`、`c1`、`act1`、`c2`、`act2`、`c3`、`attention`、`block_output` |
| A2 | `block0_input/output` 到 `block5_input/output` |
| A3 | `tail_input_concat`、`tail_conv`、`pixelshuffle_input`、`rgb888_output` |
| A5 | 与 board smoke 同输入的 `rgb888_reference` 和 hash |

## 11. 当前要做的第一步

先建立：

```text
W8A12_3lane/tools/w8a12_3lane_reference.py
```

第一版只实现：

```text
python W8A12_3lane/tools/w8a12_3lane_reference.py a0-single-conv
```

它应生成 A0 所需 reference，并把数据保存到：

```text
W8A12_3lane/evidence/reference/A0_single_conv/
```
