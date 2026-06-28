# Interpolation Baseline Evaluation

Status: PASS

Scale: x2
Pair count: 3000
GT dir: `G:/REDS/val_sharp`
LQ dir: `G:/REDS/val/val_sharp_bicubic/X2`

| Method | PSNR RGB (dB) | PSNR Y (dB) | SSIM Y |
| --- | ---: | ---: | ---: |
| nearest | 29.0969 | 29.1166 | 0.987690 |
| bilinear | 29.7218 | 29.7359 | 0.988867 |
| bicubic | 30.8645 | 30.8855 | 0.991444 |

Comparison slots:

- SPAN FP32 PSNR: 34.4297
- W8A12 fixed PSNR: None
- Board PSNR: None
