# JTAG 物理恢复清单

本文档用于 `USB known JTAG candidate count = 0` 或 `VIVADO_HW_TARGET_COUNT = 0` 时的板卡恢复。它不替代上板验证，只定义恢复到可继续 stage-hash 验收前必须满足的条件。

## 1. 当前阻塞含义

如果 `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md` 显示：

```text
Status: BLOCKED
USB known JTAG candidate count: 0
Vivado target count: not_checked 或 0
```

说明阻塞发生在 PC/USB/JTAG 枚举阶段，尚未进入 W8A12 bitstream、PS init、AXI register probe 或 stage-hash 验收。常规 preflight 在 USB known candidate=0 时会跳过 Vivado probe；最新强制 Vivado probe 证据 `evidence/board_probe/recovery_preflight_force_vivado_current/board_recovery_preflight_summary.md` 也显示 target count=0。此时继续跑 Vivado/JTAG 验收不会产生有效板端输出。

## 2. 恢复动作

按以下顺序恢复：

1. 确认板卡电源已打开，电源指示灯稳定。
2. 确认使用的是板卡 JTAG/USB-UART 对应接口，不是普通 USB 外设接口。
3. 重新插拔 JTAG USB 线，优先使用主机直连 USB 口，暂时避免 USB hub。
4. 在 Windows 设备管理器中确认在线设备出现 Xilinx/Digilent/FTDI/USB Serial 相关项。
5. 如果只在历史设备中看到 `VID_0403&PID_6010`，但当前在线列表没有该 VID/PID，说明 FTDI/JTAG 当前未枚举，需要继续检查线缆、接口、板卡模式和驱动。
6. 若设备已在线，重新运行 recovery preflight，并要求 USB known candidate 非零。
7. preflight READY 后，再运行 stage-hash true2x2 acceptance。

## 3. 通过条件

恢复后必须同时满足：

```text
USB known JTAG candidate count >= 1
VIVADO_HW_TARGET_COUNT >= 1
```

之后才能继续：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance
```

若 stage-hash acceptance 进入烧录和寄存器读取阶段，再依据 `tail_b1_hash`、`tail_b6_act1_hash`、`tail_rgb_q_hash`、`writeback_hash` 判断 mismatch 位置。
