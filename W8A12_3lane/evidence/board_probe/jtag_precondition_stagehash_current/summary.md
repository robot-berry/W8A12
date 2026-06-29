# JTAG Precondition Summary

Status: READY

| Field | Value |
| --- | --- |
| Generated at | `2026-06-29 14:43:17` |
| USB match count | `6` |
| USB known JTAG candidate count | `3` |
| PnP history known candidate count | `4` |
| PnP history known VID/PID count | `3` |
| Vivado target count | `1` |
| USB evidence | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight\stagehash_current_20260629_144313\usb\usb_jtag_devices.json` |
| Vivado probe dir | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight\stagehash_current_20260629_144313\vivado_probe` |

## Interpretation

Vivado sees at least one hardware target. Stage-hash programming and register readback can proceed.

## Required Next Step

Restore board power/cable/JTAG mode/driver until the USB known candidate count is nonzero and `probe_vivado_hw_targets.ps1` reports `VIVADO_HW_TARGET_COUNT=1` or higher. Then run the stage-hash true2x2 acceptance wrapper.
