# Quality Comparison Report

Status: PASS

该报告汇总传统插值法、SPAN FP32、W8A12 fixed-point 和 board 输出的画质指标，用于赛题文档中的“清晰度/超分效果”分析。

| Scale | Method | PSNR RGB | PSNR Y | SSIM Y | Delta vs Bicubic RGB | Note |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| x4 | nearest | 25.0921 | 25.1077 | 0.969136 | -1.2029 | traditional interpolation |
| x4 | bilinear | 25.7670 | 25.7734 | 0.972569 | -0.5279 | traditional interpolation |
| x4 | bicubic | 26.2949 | 26.2980 | 0.975825 | 0.0000 | traditional interpolation |
| x2 | nearest | 29.0969 | 29.1166 | 0.987690 | -1.7676 | traditional interpolation |
| x2 | bilinear | 29.7218 | 29.7359 | 0.988867 | -1.1427 | traditional interpolation |
| x2 | bicubic | 30.8645 | 30.8855 | 0.991444 | 0.0000 | traditional interpolation |
| x4 | SPAN FP32 | 28.3118 | 待跑 | 待跑 | 2.0169 | training log |
| x4 | W8A12 fixed | 待跑 | 待跑 | 待跑 | 待跑 | fixed-point reference |
| x4 | board | 待跑 | 待跑 | 待跑 | 待跑 | A7 720p board report |
| x2 | SPAN FP32 | 34.4297 | 待跑 | 待跑 | 3.5652 | training log |
| x2 | W8A12 fixed | 待跑 | 待跑 | 待跑 | 待跑 | fixed-point reference |
| x2 | board | 待跑 | 待跑 | 待跑 | 待跑 | x2 720p board report |

验收口径：

- x4 SPAN/W8A12/board 最终目标：REDS_val PSNR >= 28 dB；
- x2 SPAN/W8A12/board 最终目标：REDS_val PSNR >= 30 dB；
- `Delta vs Bicubic RGB` 用于说明 AI 超分相对传统插值的 PSNR 提升；
- 若 W8A12 fixed 或 board 指标低于 FP32，需要在最终报告解释量化、tile halo、DDR/拼接误差来源。
