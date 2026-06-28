# 画质指标闭环补齐计划

本文档定义赛题报告中 PSNR/SSIM 指标的分层口径、当前可引用证据、待补工具和验收标准。它的目的不是替代真实上板输出，而是防止把模型训练指标、W8A12 fixed-point 指标和板端实测指标混写。

## 1. 指标分层

| 层级 | 可证明内容 | 当前状态 | 可用于报告的结论 |
| --- | --- | --- | --- |
| 传统插值 baseline | nearest / bilinear / bicubic 在 REDS_val 全量上的 PSNR RGB、PSNR Y、SSIM Y | PASS | 可说明传统插值上限和 AI 超分增益 |
| SPAN FP32 | x4/x2 checkpoint 在 REDS_val 全量验证日志中的 PSNR | PASS | 可作为模型侧画质目标达成证据 |
| W8A12 fixed-point | 量化后 Python integer reference 对 REDS_val 全量的 PSNR/SSIM | 待补 | 不能用 FP32 训练值替代 |
| RTL | RTL 输出与 W8A12 fixed reference bit-exact | A0-A4 分层 PASS，720p 级待补 | 可证明硬件数学等价，但不单独产生对 HR 的画质指标 |
| Board | 板端输出对 HR 的 PSNR/SSIM，以及 board-vs-fixed bit-exact | 待补 | 没有真实板图输出前不能声称板端 PSNR/SSIM/FPS/功耗 |

## 2. 当前已经完成的质量证据

REDS_val 全量传统插值 baseline 已完成：

| 倍率 | nearest RGB | bilinear RGB | bicubic RGB | bicubic Y | bicubic SSIM Y |
| --- | ---: | ---: | ---: | ---: | ---: |
| x4 | 25.0921 | 25.7670 | 26.2949 | 26.2980 | 0.975825 |
| x2 | 29.0969 | 29.7218 | 30.8645 | 30.8855 | 0.991444 |

SPAN FP32 模型侧训练/验证证据：

| 倍率 | FP32 PSNR | 目标 | 相对 bicubic RGB |
| --- | ---: | ---: | ---: |
| x4 | 28.3118 dB @ 295000 iter | >= 28 dB | +2.0169 dB |
| x2 | 34.4297 dB @ 300000/300001 iter | >= 30 dB | +3.5652 dB |

对应证据：

```text
evidence/quality_baseline/x4_interpolation/summary.md
evidence/quality_baseline/x2_interpolation/summary.md
evidence/quality_comparison/summary.md
docs/contest_submission_report.md
```

## 3. 没有板图输出的影响

没有板端输出图像时，以下结论仍然有效：

- REDS_val 全量传统插值 baseline；
- SPAN FP32 训练/验证 PSNR；
- W8A12 fixed reference 与 RTL 分层 bit-exact 的局部正确性；
- OOC resource/timing/PPA 估计。

没有板端输出图像时，以下结论不能声称已经完成：

- 板端输出对 HR 的 PSNR/SSIM；
- board-vs-fixed bit-exact；
- 720p tile 拼接后的真实画质；
- 板端实测 FPS、latency、power；
- 最终 `a7.board_720p_x4` 和 `x2.board` validation PASS。

因此，当前赛题报告可以写作“模型侧 x4 已达到 28 dB、x2 已超过 30 dB；传统插值对比已完成；W8A12 fixed 全量和 board 实测仍待补”，但不能写作“板端 x4/x2 已达到目标 PSNR”。

## 4. W8A12 fixed 全量指标补齐流程

后续需要实现或补齐一个全量评测工具，建议命名：

```text
tools/evaluate_w8a12_fixed_quality.py
```

建议输入：

```text
--scale 4
--gt-dir G:\REDS\val_sharp
--lq-dir G:\REDS\val\val_sharp_bicubic\X4
--rtl-manifest rtl\generated\reds_span_x4_f48_w8a12\span_w8a12_rtl_manifest.json
--postprocess-manifest rtl\generated\reds_span_x4_f48_w8a12\postprocess\span_w8a12_postprocess_manifest.json
--out-dir W8A12_3lane\evidence\quality_fixed\x4_w8a12
```

x2 对应输入：

```text
--scale 2
--gt-dir G:\REDS\val_sharp
--lq-dir G:\REDS\val\val_sharp_bicubic\X2
--rtl-manifest rtl\generated\reds_span_x2_f48_w8a12\span_w8a12_rtl_manifest.json
--postprocess-manifest rtl\generated\reds_span_x2_f48_w8a12\postprocess\span_w8a12_postprocess_manifest.json
--out-dir W8A12_3lane\evidence\quality_fixed\x2_w8a12
```

必须输出：

```text
evidence/quality_fixed/x4_w8a12/summary.md
evidence/quality_fixed/x4_w8a12/summary.json
evidence/quality_fixed/x2_w8a12/summary.md
evidence/quality_fixed/x2_w8a12/summary.json
```

`summary.json` 至少包含：

```json
{
  "status": "PASS",
  "scale": 4,
  "dataset": "REDS_val_full",
  "image_count": 3000,
  "psnr_rgb_avg": 0.0,
  "psnr_y_avg": 0.0,
  "ssim_y_avg": 0.0,
  "target_psnr_rgb_db": 28.0,
  "target_pass": true
}
```

验收条件：

- x4 使用 REDS_val 全量 3000 images，`psnr_rgb_avg >= 28.0`；
- x2 使用 REDS_val 全量 3000 images，`psnr_rgb_avg >= 30.0`；
- 同时记录 RGB PSNR、Y PSNR、Y SSIM；
- 重新运行 `generate_quality_comparison_report.py`，将 W8A12 fixed 行由“待跑”更新为真实数值。

## 5. Board 全量指标补齐流程

板端指标必须从真实 board output 计算，建议顺序：

1. A5：32x32 x4 tile，先验证 `FRAME_DONE=1`、`ERROR=0`、board-vs-fixed bit-exact。
2. A6：64x64 x4 多 tile，验证 tile+halo crop/stitch 和资源/时序。
3. A7：720p x4，输入 `320x180 LR`，输出 `1280x720 SR`，记录 PSNR/SSIM/FPS/latency/power。
4. x2：720p x2，输入 `640x360 LR`，输出 `1280x720 SR`，记录 PSNR/SSIM/FPS/latency/power。

每个完整上板报告必须使用：

```powershell
python W8A12_3lane\tools\create_board_report.py ...
python W8A12_3lane\tools\update_board_report.py ...
python W8A12_3lane\tools\validate_board_report.py ...
```

必须输出：

```text
evidence/board_reports/a5_32x32/validation.md
evidence/board_reports/a6_64x64/validation.md
evidence/board_reports/a7_720p_x4/validation.md
evidence/board_reports/x2_720p/validation.md
```

验收条件：

- validation 文件显示 `Status: PASS`；
- board output 与 W8A12 fixed reference bit-exact，或若允许非 bit-exact，必须明确误差阈值并经评审口径确认；
- x4 board PSNR >= 28 dB；
- x2 board PSNR >= 30 dB；
- 初版 FPS >= 15，优化目标 >= 20，冲刺目标 >= 30；
- 报告中同时给出 resource、timing、latency、FPS、power、PSNR/SSIM。

## 6. 报告填报规则

赛题报告中的画质表按照以下规则维护：

- 已有真实数值的传统插值和 FP32 行可以直接填数值；
- W8A12 fixed 未跑全量前必须写“待跑”，不能用 FP32 代替；
- board 未产生真实输出图像前必须写“待测”，不能用 RTL 或 fixed reference 代替；
- 若 W8A12 fixed 低于 FP32，需要解释量化误差；
- 若 board 低于 fixed，需要解释 tile halo、DDR、cache、拼接或 writer 误差；
- 每次补齐 fixed 或 board 指标后，必须重新生成 `evidence/quality_comparison/summary.md` 并同步 `docs/contest_submission_report.md`。

## 7. 当前结论

当前画质证据足以支撑“模型侧和传统插值对比”的赛题报告章节；它还不足以支撑“板端实测超分效果”章节。最终交付必须补齐 W8A12 fixed 全量指标和 board 输出指标，尤其是 `a7.board_720p_x4` 与 `x2.board`。
