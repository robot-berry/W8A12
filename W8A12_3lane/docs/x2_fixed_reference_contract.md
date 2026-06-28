# x2 W8A12 Fixed Reference 契约

x2 目标是 REDS_val PSNR `>= 30 dB`，当前已有 FP32 训练证据 `34.4297 dB @ 300000/300001 iter`。但赛题交付不能只提交 FP32 训练结果，必须补齐 W8A12 fixed reference、RTL 和 board 证据。

## 1. 当前已知证据

```text
runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth
runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_latest.pth
runs/official_span/official_SPAN_REDS_x2_f48/train_official_SPAN_REDS_x2_f48_20260524_161741.log
rtl/generated/official_span_x2/official_span_manifest.json
```

训练日志记录：

```text
Best: 34.4297 @ 300000 iter
Best: 34.4297 @ 300001 iter
```

## 2. 缺失项

要进入交付审计的 `x2.fixed_reference`，必须生成：

```text
W8A12_3lane/evidence/x2/reference/summary.md
W8A12_3lane/evidence/x2/reference/summary.json
```

且 `summary.json` 必须由 `check_x2_fixed_reference.py` 校验通过。校验项包括：

```text
status=PASS
stage=A3_tail_rgb
scale=2
channels=48
activation_bits=12
out_channels=3
out_height=input_height*2
out_width=input_width*2
rgb_q_hash 存在
```

## 3. 必需输入

| 项目 | 要求 |
| --- | --- |
| x2 checkpoint | `net_g_300000.pth` 或经过确认的 `net_g_latest.pth` |
| x2 W8A12 quant plan | 包含 weight int8、activation int12、requant/shift |
| x2 RTL manifest | 与 x4 manifest 等价字段：layers、activation_bits、channels |
| x2 postprocess manifest | act1/act2/attention/tail/pixelshuffle 所需 LUT 和参数 |
| x2 fixed reference output | 至少 A0/A1/A2/A3 分层 hash 和 RGB tile |

## 4. 输出约束

x2 的 pixelshuffle scale 为 2：

```text
LR 640x360 -> HR 1280x720
tile 32x32 -> output 64x64
```

`pixelshuffle_reference` 必须使用：

```text
scale = 2
out_ch = 3
input_channels = 3 * 2 * 2 = 12
```

## 5. Readiness 工具

```text
W8A12_3lane/tools/check_x2_reference_readiness.py
```

该工具只检查 x2 fixed reference 的输入材料是否齐全，并生成：

```text
W8A12_3lane/evidence/x2/reference_readiness/readiness.md
W8A12_3lane/evidence/x2/reference_readiness/readiness.json
```

注意：readiness 不是 fixed reference PASS，不能替代 `evidence/x2/reference/summary.md`。

## 6. 资产搜索

如果 readiness 为 `NOT_READY`，先运行：

```powershell
python W8A12_3lane\tools\find_x2_assets.py
```

输出：

```text
W8A12_3lane/evidence/x2/asset_search/x2_asset_search.md
W8A12_3lane/evidence/x2/asset_search/x2_asset_search.json
```

当前搜索结论：只有 `rtl/generated/official_span_x2/official_span_manifest.json` 等 FP32/official 资产存在；x2 W8A12 RTL manifest、postprocess manifest 和 quant plan 仍缺。

## 7. 导出计划

导出步骤见：

```text
W8A12_3lane/docs/x2_w8a12_export_plan.md
W8A12_3lane/scripts/export_x2_w8a12_to_rtl.ps1
```

## 8. Fixed Reference 校验

生成 x2 fixed reference 后运行：

```powershell
python W8A12_3lane\tools\check_x2_fixed_reference.py
```

输出：

```text
W8A12_3lane/evidence/x2/reference_validation/validation.md
W8A12_3lane/evidence/x2/reference_validation/validation.json
```
