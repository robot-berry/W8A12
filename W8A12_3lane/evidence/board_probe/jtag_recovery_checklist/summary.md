# JTAG Recovery Checklist Evidence

Status: BLOCKED

| Field | Value |
| --- | --- |
| generated_at | `2026-06-30 00:31:49` |
| USB match count | `3` |
| USB known JTAG candidate count | `0` |
| PnP history known JTAG candidate count | `4` |
| PnP history known VID/PID count | `3` |
| Vivado target count | `0` |
| known VID/PID pattern | `VID_03FD|VID_0403|VID_1443|VID_04B4` |

## Current Online USB Matches

| Name | Class | Status | Known JTAG | Device ID |
| --- | --- | --- | --- | --- |
| `USB Composite Device` | `USB` | `OK` | `False` | `USB\VID_0B05&PID_6208\6&64C86AE&0&1` |
| `USB Composite Device` | `USB` | `OK` | `False` | `USB\VID_13D3&PID_3563\000000000` |
| `USB Composite Device` | `USB` | `OK` | `False` | `USB\VID_322E&PID_202C\6&7E781F5&0&4` |

## Historical Known JTAG Candidates

| Name | Class | Status | Instance ID |
| --- | --- | --- | --- |
| `Silicon Labs CP210x USB to UART Bridge (COM3)` | `Ports` | `Unknown` | `USB\VID_10C4&PID_EA60\0001` |
| `USB Composite Device` | `USB` | `Unknown` | `USB\VID_0403&PID_6010\210203367162` |
| `USB Serial Converter A` | `USB` | `Unknown` | `USB\VID_0403&PID_6010&MI_00\7&68AC5D3&0&0000` |
| `USB Serial Converter B` | `USB` | `Unknown` | `USB\VID_0403&PID_6010&MI_01\7&68AC5D3&0&0001` |

## Required Pass Criteria

- `USB known JTAG candidate count >= 1`
- `VIVADO_HW_TARGET_COUNT >= 1`

## Recovery Actions

1. 确认板卡电源打开且电源指示稳定。
2. 确认 USB 线接到板卡 JTAG/USB-UART 对应接口，而不是普通 USB 外设接口。
3. 重新插拔 JTAG USB 线，优先主机直连 USB 口，暂时避免 USB hub。
4. 在 Windows 设备管理器确认在线设备出现 Xilinx/Digilent/FTDI/USB Serial 相关项。
5. 若历史中有 VID_0403&PID_6010 但当前在线列表没有，继续检查线缆、接口、板卡模式和 FTDI/JTAG 驱动。
6. 恢复后重新运行 recovery preflight；只有 USB known candidate 非零且 Vivado target 非零时继续 stage-hash。

## Continue Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance
```

This checklist records physical/JTAG recovery state only; it is not a board validation PASS.
