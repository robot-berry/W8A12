# W8A12 SPAN Training Package

This branch contains the software-side training and export flow for the W8A12 SPAN route.

## What Is Included

- REDS SPAN x4/x2 training launch scripts.
- SPAN F48 configuration templates.
- REDS meta-info generation.
- W8A12 quantization/reference/export helpers.
- Training dashboard helpers.

Large files are intentionally not included: REDS data, checkpoints, `runs/`, Vivado outputs, and bitstreams.

## Expected Data Layout

Put REDS on the training machine, for example:

```text
G:/REDS/
  train_sharp/
  val_sharp/
  train/train_sharp_bicubic/X4/
  train/train_sharp_bicubic/X2/
  val/val_sharp_bicubic/X4/
  val/val_sharp_bicubic/X2/
```

The scripts accept another REDS root through `scripts/configure_span_training.ps1`.

## First-Time Setup

```powershell
git clone -b training-software https://github.com/robot-berry/W8A12.git
cd W8A12
powershell -ExecutionPolicy Bypass -File scripts/setup_external_span.ps1
powershell -ExecutionPolicy Bypass -File scripts/configure_span_training.ps1 -RedsRoot G:\REDS
```

## Start Training

x4:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/train_official_span_reds_x4.ps1 -RedsRoot G:\REDS
```

x2:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/train_official_span_reds_x2.ps1 -RedsRoot G:\REDS
```

Background launch:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_official_span_training.ps1 -RedsRoot G:\REDS
powershell -ExecutionPolicy Bypass -File scripts/start_official_span_x2_training.ps1 -RedsRoot G:\REDS
```

## Recorded Targets From This Project

- x4 SPAN F48 REDS validation target: at least 28 dB; recorded training evidence reached about 28.31 dB near 295k iterations.
- x2 SPAN F48 REDS validation target: at least 30 dB; recorded training evidence reached about 34.43 dB near 300k iterations.

Use the generated checkpoints in `runs/official_span/.../models/` for the later W8A12 quantization/export flow.
