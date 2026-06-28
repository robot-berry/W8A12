# x2 W8A12 导出计划

本文档定义从现有 x2 FP32 checkpoint 生成 W8A12 fixed-reference 所需资产的步骤。

总体验收质量目标：

```text
x4 REDS_val PSNR >= 28 dB
x2 REDS_val PSNR >= 30 dB
```

x2 当前已有 FP32 训练证据 `34.4297 dB @ 300000/300001 iter`，但本导出流程必须把该模型落到 W8A12 quant plan、RTL manifest、postprocess manifest、fixed reference 和后续 board 报告，不能用 FP32 结果替代 W8A12 交付证据。

## 1. 输入

```text
runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth
rtl/generated/official_span_x2/official_span_manifest.json
G:/REDS/val_sharp
```

## 2. 输出

交付审计需要以下三个资产存在：

```text
rtl/generated/reds_span_x2_f48_w8a12/span_w8a12_rtl_manifest.json
rtl/generated/reds_span_x2_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json
runs/reds_span_quant_plan/reds_span_x2_f48_w8a12/span_w8a12_quant_plan.json
```

导出检查证据：

```text
W8A12_3lane/evidence/x2/w8a12_export/summary.md
W8A12_3lane/evidence/x2/w8a12_export/summary.json
```

## 3. 一键导出脚本

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_x2_w8a12_to_rtl.ps1
```

如果当前 PowerShell 通道异常，可以使用 `.cmd` 包装。该包装会把 stdout 落到 `evidence/x2/w8a12_export/`，并在导出成功后自动运行导出检查：

```cmd
W8A12_3lane\scripts\export_x2_w8a12_to_rtl.cmd
```

脚本顺序：

1. `tools/calibrate_span_activation_scales.py`
2. `tools/export_span_w8a12_quant_plan.py`
3. `tools/export_span_quant_plan_to_rtl.py`
4. `tools/export_span_w8a12_postprocess_to_rtl.py`
5. `tools/check_span_w8a12_rtl_export.py`
6. `W8A12_3lane/tools/check_x2_w8a12_export.py`

## 4. 默认校准设置

```text
input: G:/REDS/val_sharp
width: 640
height: 360
max_images: 8
activation_bits: 12
weight_bits: 8
```

注意：如果 x2 训练使用的 LQ/GT 数据路径不同，必须在导出记录中同步修改校准输入和尺寸。

## 5. 导出后检查

导出成功后运行：

```powershell
python W8A12_3lane\tools\check_x2_reference_readiness.py
python W8A12_3lane\tools\find_x2_assets.py
python W8A12_3lane\tools\check_x2_w8a12_export.py
```

期望：

```text
readiness: READY
asset_search: READY
x2_w8a12_export: PASS
```

然后生成 fixed reference：

```powershell
python W8A12_3lane\tools\w8a12_3lane_reference.py a3-tail-rgb --rtl-manifest rtl\generated\reds_span_x2_f48_w8a12\span_w8a12_rtl_manifest.json --postprocess-manifest rtl\generated\reds_span_x2_f48_w8a12\postprocess\span_w8a12_postprocess_manifest.json --out-dir W8A12_3lane\evidence\x2\reference
python W8A12_3lane\tools\check_x2_fixed_reference.py
```

fixed reference 检查证据：

```text
W8A12_3lane/evidence/x2/reference/summary.md
W8A12_3lane/evidence/x2/reference_validation/validation.md
```
