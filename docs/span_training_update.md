# SPAN 方案更新与 REDS 训练说明

## 论文依据

SPAN 论文提出 Swift Parameter-free Attention Network，用 6 个 SPAB 作为主干。SPAB 的关键点是：用卷积提取的特征直接经过近似对称激活得到 attention map，不额外引入可训练 attention 参数；再通过残差连接缓解参数免费 attention 的信息损失。

NTIRE 2026 Efficient SR 报告继续把 SPAN 作为 baseline，并强调高效 SR 的评价不只看 PSNR，还看 runtime、参数量和 FLOPs。其中 runtime 是最重要指标。这一点和赛题中“清晰度、实时性、功耗”的综合目标一致。

## 当前工程更新

- `train/span_model.py`：实现 TinySPAN，包括 `Conv3XC`、`SPAB`、`TinySPAN`。
- `train/reds_dataset.py`：实现 REDS HR 帧读取、在线 bicubic x2/x4 降采样、随机裁剪、翻转旋转、JPEG 压缩退化。
- `train/train_reds_span.py`：实现训练循环、AMP、Cosine LR、L1 loss、Sobel edge loss、PSNR 验证和 checkpoint。
- `configs/train_reds_span_x4.json`：给出 x4 训练命令模板。
- `model/example_model.json`：从旧的残差 baseline 描述更新为 TinySPAN FPGA target 描述。

## 数据集组织

推荐 REDS 路径：

```text
REDS/
  train/
    train_sharp/
      000/
        00000000.png
  val/
    val_sharp/
      000/
        00000000.png
```

训练脚本只要求传入 HR 根目录，会自动递归寻找图像，并在线生成 LR。

## x4 训练命令

```bash
python train/train_reds_span.py \
  --train-hr G:/REDS/train_sharp \
  --val-hr G:/REDS/val_sharp \
  --scale 4 \
  --channels 48 \
  --num-blocks 6 \
  --patch-size 192 \
  --batch-size 16 \
  --epochs 200 \
  --amp \
  --output runs/tinyspan_reds_x4
```

## x2 训练命令

```bash
python train/train_reds_span.py \
  --train-hr G:/REDS/train_sharp \
  --val-hr G:/REDS/val_sharp \
  --scale 2 \
  --channels 48 \
  --num-blocks 6 \
  --patch-size 192 \
  --batch-size 16 \
  --epochs 200 \
  --amp \
  --output runs/tinyspan_reds_x2
```

## 到 FPGA 的后续转换

1. 训练 TinySPAN FP32/AMP 权重。
2. 将 `Conv3XC` 的 1x1-3x3-1x1 与 skip 分支离线融合为单个 3x3 kernel。
3. 对权重、激活做 INT8 PTQ/QAT，累加保持 INT32。
4. 导出每层 weight/bias/scale 到 ROM 初始化文件或 Verilog package。
5. 当前 RTL 顶层已替换为 `sr_tinyspan_core`，并按 `head -> SPAB x6 -> PixelShuffle` 组织。后续继续把 `.mem` 权重接入真实 INT8 3x3 卷积阵列。

## 本机连通性训练结果

已在 `G:/REDS/train_sharp` 和 `G:/REDS/val_sharp` 上完成一次快速 smoke 训练：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/train_reds_x4_smoke.ps1
powershell -ExecutionPolicy Bypass -File scripts/export_latest_tinyspan_to_rtl.ps1
```

本次 smoke 配置为 x4、12 通道、6 个 SPAB、训练 32 张图、验证 8 张图、1 epoch。该运行只用于验证训练链路和 RTL 导出链路，画质指标不能代表最终模型。导出的 RTL 产物位于 `rtl/generated/`。
