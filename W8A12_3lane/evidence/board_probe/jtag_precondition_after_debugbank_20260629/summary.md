# JTAG Precondition Summary

Status: READY

| Field | Value |
| --- | --- |
| Generated at | `2026-06-29 17:38:05` |
| USB match count | `6` |
| USB known JTAG candidate count | `3` |
| PnP history known candidate count | `4` |
| PnP history known VID/PID count | `3` |
| Vivado target count | `1` |
| USB evidence | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight_after_debugbank_20260629\usb\usb_jtag_devices.json` |
| Vivado probe dir | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight_after_debugbank_20260629\vivado_probe` |

## Interpretation

Vivado sees at least one hardware target. Stage-hash programming and register readback can proceed.

## Required Next Step

Run the stage-hash true2x2 acceptance wrapper or the recovery preflight with `-RunStageHashAcceptance`.
