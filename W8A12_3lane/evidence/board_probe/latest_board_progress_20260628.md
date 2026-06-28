# W8A12 latest board progress

Generated at: `2026-06-28 19:36 Asia/Shanghai`

Status: `BLOCKED_BEFORE_BOARD_VALIDATION`

## What was rechecked

The board recovery preflight was rerun with forced Vivado hardware probing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -OutputDir W8A12_3lane\evidence\board_probe\recovery_preflight_force_vivado_current -PreconditionOutDir W8A12_3lane\evidence\board_probe\jtag_precondition_current -ForceVivadoProbe
```

The forced probe did not reach W8A12 programming or image readback. It stopped at the board/JTAG precondition.

| Check | Result |
| --- | --- |
| USB match count | `3` |
| USB known JTAG candidate count | `0` |
| Vivado hardware target count | `0` |
| Final precondition status | `BLOCKED` |
| Residual `vivado` / `hw_server` / `xsct` process | none after cleanup |

Evidence:

- `W8A12_3lane/evidence/board_probe/recovery_preflight_force_vivado_current/board_recovery_preflight_summary.md`
- `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md`
- `W8A12_3lane/evidence/board_probe/recovery_preflight_force_vivado_current/vivado_probe/probe_vivado_hw_targets.log`
- `W8A12_3lane/evidence/board_probe/recovery_preflight_force_vivado_current/vivado_probe/usb_jtag_devices.txt`

## Current interpretation

The current blocker is not a new RTL failure and not a missing workflow step. The PC/Vivado side currently cannot enumerate a valid hardware target:

```text
VIVADO_HW_TARGET_COUNT=0
USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=0
```

The historical FTDI JTAG device remains visible only in PnP history as `VID_0403&PID_6010`, with status `Unknown`; it is not present in the online USB device list. Continuing directly to W8A12 stage-hash acceptance at this point would only fail before programming the bitstream.

## Verified baseline before this blocker

The following W8A12 facts are still the current technical baseline:

| Item | Status |
| --- | --- |
| true 2x2 RTL raw compare | `PASS`, `0 / 192` byte mismatch |
| stage-hash bitstream | generated and timing PASS |
| stage-hash expected hashes | `tail_b1=0x16ede1c2`, `tail_b6_act1=0xc7a092b8`, `tail_rgb_q=0xb712a61b`, `writeback=0x61d3ea1d` |
| prior Default/inpixfix true2x2 board baseline | complete output, `153 / 192` byte mismatch, PSNR `44.0265 dB` |
| prior dbgprogress true2x2 board run | `frame_done=1`, `192 / 192` output bytes, but `189 / 192` byte mismatch and board writeback hash `0xAD24396D` |

## Next command after JTAG is visible

After the USB known JTAG candidate count is at least `1` and Vivado reports at least one target, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance
```

The next successful board-side milestone is true2x2 stage-hash readback. It must decide whether the mismatch first appears at `tail_b1_hash`, `tail_b6_act1_hash`, `tail_rgb_q_hash`, `writeback_hash`, or only after endpoint/JTAG readback.

## Contest delivery impact

The strict contest delivery audit remains incomplete because the following real board validation reports are still missing:

- `W8A12_3lane/evidence/board_reports/a5_32x32/validation.md`
- `W8A12_3lane/evidence/board_reports/a6_64x64/validation.md`
- `W8A12_3lane/evidence/board_reports/a7_720p_x4/validation.md`
- `W8A12_3lane/evidence/board_reports/x2_720p/validation.md`

