# Interpolation Baseline Evaluation

Status: PASS

Scale: x4
Pair count: 3000
GT dir: `G:/REDS/val_sharp`
LQ dir: `G:/REDS/val/val_sharp_bicubic/X4`

| Method | PSNR RGB (dB) | PSNR Y (dB) | SSIM Y |
| --- | ---: | ---: | ---: |
| nearest | 25.0921 | 25.1077 | 0.969136 |
| bilinear | 25.7670 | 25.7734 | 0.972569 |
| bicubic | 26.2949 | 26.2980 | 0.975825 |

Comparison slots:

- SPAN FP32 PSNR: 28.3118
- W8A12 fixed PSNR: None
- Board PSNR: None
