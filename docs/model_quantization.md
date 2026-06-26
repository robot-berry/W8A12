# 模型结构、训练与量化说明

## 模型选择

调研文档建议以 SPAN 为主线，并结合 ESPCN 的低分辨率域计算和上采样思想。本轮更新后，训练侧采用 TinySPAN 作为主模型，硬件侧保留纯 RTL baseline 作为 Vivado/上板闭环，并为后续把 TinySPAN 的 INT8 卷积阵列映射到 FPGA 做接口准备。

根据 SPAN 论文和官方代码，主干由 6 个 Swift Parameter-free Attention Block（SPAB）串联组成。每个 SPAB 内部包含 3 个卷积特征提取层、残差连接和无额外可训练参数的 attention map。attention map 直接由卷积特征经过对称激活近似得到，避免 SwinIR/HAT 一类窗口 self-attention 的复杂矩阵计算。

训练代码中的 TinySPAN 结构为：

```text
LR RGB input
  -> 3x3 head convolution, 48 channels
  -> SPAB x 6
  -> concat(head, SPAB1, SPAB5, tail_conv(SPAB6))
  -> 3x3 reconstruction convolution
  -> PixelShuffle x2/x4
  -> HR RGB output
```

当前 RTL 已替换为 `sr_tinyspan_core`，其硬件数据通路按 TinySPAN 的阶段组织：

```text
RGB stream
  -> head_extract
  -> SPAB-like residual + parameter-free attention gate x6
  -> stream PixelShuffle timing
  -> HR RGB stream
```

训练导出的 `rtl/generated/tinyspan_model_config.vh` 已被 RTL include，用于同步 scale、channels、blocks 和权重数量。当前 SPAB 内部仍是定点近似表达；后续继续把 `rtl/generated/weights/*.mem` 逐层接入真实 INT8 3x3 卷积阵列。

## 训练建议

- 数据集：REDS，按赛题要求从 HR 帧在线生成 x2/x4 LR-HR 图像对。
- 退化：建议叠加视频会议常见退化，包括低码率压缩、轻微模糊、噪声、人脸区域和文档文字区域。
- Teacher：可使用较大 x4 SR 模型生成软标签，对轻量模型蒸馏。
- Loss：`L1 + edge loss + text/face ROI loss`，用于兼顾 PSNR 和会议主观清晰度。
- 本工程已提供 `train/train_reds_span.py`，默认使用 `L1 + Sobel edge loss`，并支持 JPEG 压缩退化增强。

## 量化策略

- 输入/输出：RGB888，每通道 8 bit。
- 激活：uint8。
- 权重：int8。
- 累加：int32，输出前做缩放、偏置和饱和截断。
- 训练阶段：先用 FP32/AMP 训练 TinySPAN，再做 PTQ/QAT。
- 硬件目标：将 `Conv3XC` 训练结构离线融合为单个 3x3 卷积核，再进行 INT8 权重量化。
- 当前 RTL baseline：无显式权重乘法，内部差分使用 16 bit signed 中间值，最终饱和回 uint8。

## 模型到硬件转换

`model/example_model.json` 描述模型层级、量化格式和尺度；`model/model_to_rtl.py` 可生成 RTL include 参数：

```bash
python model/model_to_rtl.py model/example_model.json -o build/model_params.vh --scale 4
```

当前 RTL 直接用参数配置尺度；训练权重接入时，可扩展 JSON 的 `layers[].weights` 字段，并由脚本生成 ROM 初始化文件或 Verilog package。训练入口示例：

```bash
python train/train_reds_span.py \
  --train-hr G:/REDS/train_sharp \
  --val-hr G:/REDS/val_sharp \
  --scale 4 --channels 48 --num-blocks 6 \
  --patch-size 192 --batch-size 16 --epochs 200 --amp \
  --output runs/tinyspan_reds_x4
```

训练后导出 RTL 参数和 INT8 权重：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_latest_tinyspan_to_rtl.ps1 `
  -Checkpoint runs/tinyspan_reds_x4_full/best.pt `
  -Scale 4 -Channels 48 -Blocks 6
```
