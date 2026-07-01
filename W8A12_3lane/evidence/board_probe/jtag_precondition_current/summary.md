# JTAG Precondition Summary

Status: BLOCKED

| Field | Value |
| --- | --- |
| Generated at | `2026-06-30 11:38:24` |
| USB match count | `6` |
| USB known JTAG candidate count | `3` |
| PnP history known candidate count | `4` |
| PnP history known VID/PID count | `3` |
| Vivado target count | `0` |
| USB evidence | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight\dbg2_src_boundary_current\usb\usb_jtag_devices.json` |
| Vivado probe dir | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight\dbg2_src_boundary_current\vivado_probe` |

## Interpretation

Board programming is currently blocked before Vivado/JTAG use: no online known Xilinx/FTDI JTAG candidate is visible, or Vivado target count is zero.
Historical Xilinx/FTDI-style devices are present only in PnP history, so this is a current online enumeration/driver/cable/power issue rather than a W8A12 bitstream or algorithm result.

## Current Online USB Matches

| Name | Class | Status | Known JTAG | Device ID |
| --- | --- | --- | --- | --- |
| `USB Composite Device` | `USB` | `OK` | `True` | `USB\VID_0403&PID_6010\210203367162` |
| `USB Composite Device` | `USB` | `OK` | `False` | `USB\VID_0B05&PID_6208\6&64C86AE&0&1` |
| `USB Composite Device` | `USB` | `OK` | `False` | `USB\VID_13D3&PID_3563\000000000` |
| `USB Composite Device` | `USB` | `OK` | `False` | `USB\VID_322E&PID_202C\6&7E781F5&0&4` |
| `USB Serial Converter A` | `USB` | `OK` | `True` | `USB\VID_0403&PID_6010&MI_00\7&68AC5D3&0&0000` |
| `USB Serial Converter B` | `USB` | `OK` | `True` | `USB\VID_0403&PID_6010&MI_01\7&68AC5D3&0&0001` |

## Historical Known JTAG Candidates

| Name | Class | Status | Instance ID |
| --- | --- | --- | --- |
| `Silicon Labs CP210x USB to UART Bridge (COM3)` | `Ports` | `Unknown` | `USB\VID_10C4&PID_EA60\0001` |
| `USB Composite Device` | `USB` | `OK` | `USB\VID_0403&PID_6010\210203367162` |
| `USB Serial Converter A` | `USB` | `OK` | `USB\VID_0403&PID_6010&MI_00\7&68AC5D3&0&0000` |
| `USB Serial Converter B` | `USB` | `OK` | `USB\VID_0403&PID_6010&MI_01\7&68AC5D3&0&0001` |

## Required Next Step

Restore board power/cable/JTAG mode/driver until the USB known candidate count is nonzero and `probe_vivado_hw_targets.ps1` reports `VIVADO_HW_TARGET_COUNT=1` or higher. Then run the stage-hash true2x2 acceptance wrapper.
