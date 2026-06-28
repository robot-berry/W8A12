# 传统插值 Baseline 对比流程

## 目标

赛题报告需要说明 AI 超分相对传统插值的画质提升。本文档规定 REDS_val 上的 nearest / bilinear / bicubic baseline 评测方法，并把结果与 SPAN FP32、W8A12 fixed-point、board 输出放在同一张表里。

## 当前已知训练指标

| 倍率 | 模型 | REDS_val PSNR |
| --- | --- | ---: |
| x4 | SPAN/F48 FP32 | 28.3118 dB @ 295000 iter |
| x2 | SPAN/F48 FP32 | 34.4297 dB @ 300000/300001 iter |

注意：上述训练 PSNR 不能替代 W8A12 fixed-point、RTL 或 board 验收，只能作为模型侧画质上限和插值法对比基线。

## 输入数据

| 倍率 | GT | LQ |
| --- | --- | --- |
| x4 | `G:/REDS/val/val_sharp` | `G:/REDS/val/val_sharp_bicubic/X4` |
| x2 | `G:/REDS/val/val_sharp` | `G:/REDS/val/val_sharp_bicubic/X2` |

若本机 REDS 目录不同，命令中替换 `--gt-dir` 和 `--lq-dir` 即可。最终报告建议使用 REDS_val 全量 3000 images；调试时可先用 `--limit 30`。

## 评测命令

x4 全量 baseline：

```powershell
python W8A12_3lane\tools\evaluate_interpolation_baseline.py --scale 4 --gt-dir G:\REDS\val\val_sharp --lq-dir G:\REDS\val\val_sharp_bicubic\X4 --span-fp32-psnr-db 28.3118 --out-dir W8A12_3lane\evidence\quality_baseline\x4_interpolation
```

x2 全量 baseline：

```powershell
python W8A12_3lane\tools\evaluate_interpolation_baseline.py --scale 2 --gt-dir G:\REDS\val\val_sharp --lq-dir G:\REDS\val\val_sharp_bicubic\X2 --span-fp32-psnr-db 34.4297 --out-dir W8A12_3lane\evidence\quality_baseline\x2_interpolation
```

调试命令：

```powershell
python W8A12_3lane\tools\evaluate_interpolation_baseline.py --scale 4 --gt-dir G:\REDS\val\val_sharp --lq-dir G:\REDS\val\val_sharp_bicubic\X4 --limit 30 --span-fp32-psnr-db 28.3118 --out-dir W8A12_3lane\evidence\quality_baseline\x4_interpolation_smoke
```

## 输出证据

每个倍率必须生成：

```text
evidence/quality_baseline/x4_interpolation/summary.md
evidence/quality_baseline/x4_interpolation/summary.json
evidence/quality_baseline/x2_interpolation/summary.md
evidence/quality_baseline/x2_interpolation/summary.json
```

随后生成统一质量对比报告：

```powershell
python W8A12_3lane\tools\generate_quality_comparison_report.py
```

输出：

```text
evidence/quality_comparison/summary.md
evidence/quality_comparison/summary.json
```

`summary.md` 至少包含：

- nearest / bilinear / bicubic 的 RGB PSNR；
- nearest / bilinear / bicubic 的 Y 通道 PSNR；
- Y 通道 SSIM；
- SPAN FP32 PSNR；
- 后续补入 W8A12 fixed 和 board PSNR。
- 相对 bicubic 的 PSNR 提升值。

## 报告表格模板

| 倍率 | 方法 | PSNR RGB | PSNR Y | SSIM Y | 备注 |
| --- | --- | ---: | ---: | ---: | --- |
| x4 | bicubic | 待跑 | 待跑 | 待跑 | 传统插值 |
| x4 | SPAN FP32 | 28.3118 | 待统一口径 | 待统一口径 | 训练日志 |
| x4 | W8A12 fixed | 待跑 | 待跑 | 待跑 | 定点 reference |
| x4 | board | 待跑 | 待跑 | 待跑 | A7 720p 上板 |
| x2 | bicubic | 待跑 | 待跑 | 待跑 | 传统插值 |
| x2 | SPAN FP32 | 34.4297 | 待统一口径 | 待统一口径 | 训练日志 |
| x2 | W8A12 fixed | 待跑 | 待跑 | 待跑 | 定点 reference |
| x2 | board | 待跑 | 待跑 | 待跑 | x2 720p 上板 |

## 验收标准

- x4 baseline 文件存在，且 `summary.md` 显示 `Status: PASS`；
- x2 baseline 文件存在，且 `summary.md` 显示 `Status: PASS`；
- 统一质量对比报告 `evidence/quality_comparison/summary.md` 显示 `Status: PASS`；
- 最终报告中必须写出 AI 超分相对 bicubic 的 PSNR 提升值；
- 若 W8A12 fixed 或 board PSNR 与 FP32 训练 PSNR 存在差距，需要解释量化误差、tile halo 裁剪和板端输出差异。
