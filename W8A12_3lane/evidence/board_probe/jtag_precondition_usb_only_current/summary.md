# JTAG Precondition Summary

Status: USB_READY

| Field | Value |
| --- | --- |
| Generated at | `2026-07-03 00:40:03` |
| USB match count | `6` |
| USB known JTAG candidate count | `3` |
| PnP history known candidate count | `4` |
| PnP history known VID/PID count | `3` |
| Vivado target count | `not_checked` |
| USB evidence | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight\usb_only_current_20260703\usb\usb_jtag_devices.json` |
| Vivado probe dir | `not_checked` |

## Interpretation

Windows sees a known JTAG-class USB device. Run the Vivado target probe before programming.

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

Run `probe_vivado_hw_targets.ps1`; continue only when it reports `VIVADO_HW_TARGET_COUNT=1` or higher.
