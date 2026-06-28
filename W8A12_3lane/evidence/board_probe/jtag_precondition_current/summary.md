# JTAG Precondition Summary

Status: BLOCKED

| Field | Value |
| --- | --- |
| Generated at | `2026-06-28 19:15:01` |
| USB match count | `3` |
| USB known JTAG candidate count | `0` |
| PnP history known candidate count | `4` |
| PnP history known VID/PID count | `3` |
| Vivado target count | `0` |
| USB evidence | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\board_probe\recovery_preflight_force_vivado_current\usb\usb_jtag_devices.json` |
| Vivado probe dir | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\board_probe\recovery_preflight_force_vivado_current\vivado_probe` |

## Interpretation

Board programming is currently blocked before Vivado/JTAG use: no online known Xilinx/FTDI JTAG candidate is visible, or Vivado target count is zero.

## Required Next Step

Restore board power/cable/JTAG mode/driver until the USB known candidate count is nonzero and `probe_vivado_hw_targets.ps1` reports `VIVADO_HW_TARGET_COUNT=1` or higher. Then run the stage-hash true2x2 acceptance wrapper.
