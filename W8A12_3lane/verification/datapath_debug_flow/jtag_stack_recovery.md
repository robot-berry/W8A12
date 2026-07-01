# JTAG 访问栈恢复门禁

本文用于处理“板端 USB 可见，但 Vivado 读不到 hardware target”的情况。进入任何板端数据通路 mismatch 调试前，必须先确认下面三层同时通过。

## 三层判定

```text
Layer A: Windows PnP
  目标：能看到 USB\VID_0403&PID_6010\210203367162
  通过：USB Composite Device、USB Serial Converter A/B 可见

Layer B: FTDI D2XX
  目标：FTD2XX.dll 能枚举到 FTDI device
  通过：FT_CreateDeviceInfoList num > 0
  说明：该层用于诊断驱动状态；若 Vivado hw_target 已可见，可以继续板端验证

Layer C: Vivado hw_server
  目标：Vivado Hardware Manager 能看到 hw_target
  通过：get_hw_targets 数量 > 0，且能看到 xczu19_0
```

只有 Layer A 通过而 Layer C 失败时，不要继续跑 bitstream、JTAG AXI 或数据通路 hash；此时问题还不在 RTL。Layer B 的 D2XX 结果用于辅助判断驱动是否异常，但不再作为高于 Vivado target 的硬门禁。

## 当前工程的历史正确目标

历史成功日志中，同一块板的 target 是：

```text
localhost:3121/xilinx_tcf/Digilent/210203367162A
```

成功时应能看到：

```text
VIVADO_HW_TARGET_COUNT = 1
VIVADO_HW_DEVICE = xczu19_0
VIVADO_HW_DEVICE = arm_dap_1
```

## 快速复测命令

优先使用一键脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\check_w8a12_jtag_stack.ps1 -OutputDir W8A12_3lane\verification\datapath_debug_flow\runs\jtag_stack_current
```

通过条件：

```text
W8A12_JTAG_STACK_STATUS = READY
W8A12_JTAG_STACK_VIVADO_TARGET_COUNT > 0
```

如果只想单独测 FTDI D2XX，可运行：

```powershell
@'
import ctypes
from ctypes import wintypes
for path in [
    r'D:\software\2025.2\Vivado\lib\win64.o\FTD2XX.dll',
    r'C:\Program Files (x86)\Digilent\Runtime\UsbDriver\amd64\ftd2xx64.dll',
]:
    dll = ctypes.WinDLL(path)
    num = wintypes.DWORD(0)
    status = dll.FT_CreateDeviceInfoList(ctypes.byref(num))
    print(path, 'status=', status, 'num=', num.value)
'@ | python -
```

通过条件：

```text
status = 0
num > 0
```

再测 Vivado target：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\probe_vivado_hw_targets.ps1 -OutputDir G:\UESTC\feitengspan1\board_runs\vivado_hw_target_probe_current
```

通过条件：

```text
VIVADO_HW_TARGET_COUNT > 0
VIVADO_HW_DEVICE_COUNT > 0
```

访问层通过后，再进入当前选定的边界验收。当前 dbg1 已证明 `tail_b1` 处不一致，因此优先使用带 preflight 的 current dbg2 源边界验收入口，继续读取 `src_feat0/src_b1/tail_feat0/tail_b1` 细分 hash。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\W8A12_3lane\scripts\run_w8a12_dbg2_source_boundary_acceptance.ps1 -OutputDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\current_dbg2_source_tail_20260630_board_acceptance_retry -PreflightDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\current_dbg2_source_tail_20260630_preflight_retry -PreconditionOutDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\current_dbg2_source_tail_20260630_precondition_retry -EvidenceDir G:\UESTC\feitengspan1\W8A12_3lane\verification\datapath_debug_flow\runs\current_dbg2_source_tail_20260630_evidence_retry -ForceVivadoProbe -ContinueOnError
```

或者使用完整继续入口，让脚本自动完成 JTAG 栈门禁、dbg2 验收和 hash 对比：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\continue_w8a12_mismatch_flow.ps1 -OutputDir W8A12_3lane\verification\datapath_debug_flow\runs\continue_w8a12_mismatch_current
```

## 管理员恢复入口

当 Windows 能看到 FTDI USB 设备，但 `program_ftdi -read` 和 Vivado `get_hw_targets` 都为 0 时，优先使用恢复脚本生成计划：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\repair_w8a12_jtag_stack_admin.ps1 -OutputDir W8A12_3lane\verification\datapath_debug_flow\runs\repair_jtag_stack_current
```

默认不修改系统，只写出 dry-run 计划。当前 dry-run 计划包括：

```text
pnputil /restart-device USB\VID_0403&PID_6010&MI_00\...
pnputil /restart-device USB\VID_0403&PID_6010&MI_01\...
pnputil /restart-device USB\VID_0403&PID_6010\210203367162
D:\software\2025.2\Vivado\data\xicom\cable_drivers\nt64\install_drivers_wrapper.bat
pnputil /scan-devices
```

确认要执行系统修复时，用管理员 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\repair_w8a12_jtag_stack_admin.ps1 -OutputDir W8A12_3lane\verification\datapath_debug_flow\runs\repair_jtag_stack_current -Apply
```

执行后脚本会自动跑 postcheck；只有 `postcheck_status = READY` 时，才能继续 `continue_w8a12_mismatch_flow.ps1`。

如果需要由脚本触发 UAC，可使用自提升启动器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\launch_repair_w8a12_jtag_stack_admin.ps1 -OutputDir W8A12_3lane\verification\datapath_debug_flow\runs\launch_repair_jtag_stack_current
```

该入口会以普通窗口启动管理员 PowerShell，便于观察 UAC 和修复日志。若 UAC 被取消，summary 会记录 `status = LAUNCH_FAILED` 和取消原因。

先查看计划：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File G:\UESTC\feitengspan1\scripts\launch_repair_w8a12_jtag_stack_admin.ps1 -OutputDir W8A12_3lane\verification\datapath_debug_flow\runs\launch_repair_jtag_stack_current -PlanOnly
```

## 当前访问层证据

2026-06-30 板端曾恢复并完成 dbg1 验收：

```text
script = G:/UESTC/feitengspan1/scripts/check_w8a12_jtag_stack.ps1
status = READY
D2XX device count = 2
Vivado hardware target count = 1
ForceVivadoProbe = enabled
```

同轮板端基础状态：

```text
PL0 clock register check = PASS
PL0_REF_CTRL = 0x01012800
PL0_DIVISOR0 = 0x28
PL0_DIVISOR1 = 0x1
```

结论：

```text
历史 READY 证明 RTL/JTAG 工程入口可用。
但 dbg2 构建后再次复发为 PnP 断开，当前必须先恢复访问层。
恢复到 READY 前，不要把 dbg2 验收失败解释为 datapath mismatch。
```

2026-06-30 dbg2 验收前最新复测：

```text
status = BLOCKED_PNP
D2XX device count = 0
Vivado hardware target count = not_run
USB Composite Device = Disconnected / CM_PROB_PHANTOM
USB Serial Converter A/B = Disconnected / CM_PROB_PHANTOM
```

2026-06-30 板子重新插上后复测：

```text
status = BLOCKED_PNP
D2XX device count = 0
PresentOnly FTDI/Digilent device = none
pnputil /scan-devices = Access is denied
dbg2 wrapper status = BLOCKED
```

## 历史阻塞证据

恢复前曾出现过以下状态；这些只作为复发时的参考，不是当前状态：

```text
Windows 能看到 USB Serial Converter A/B
D2XX device count = 0
program_ftdi -read = Detected 0 devices
Vivado VIVADO_HW_TARGET_COUNT = 0
非管理员 pnputil /restart-device = Access is denied
```

## 复发时推荐恢复顺序

1. 关闭 Vivado GUI、Vitis、串口工具和所有可能占用 FTDI 的程序。
2. 断开板卡 USB-JTAG，板卡重新上电，再插回同一个 USB 口。
3. 在设备管理器中确认 `USB Serial Converter A` 和 `USB Serial Converter B` 都正常启动。
4. 如果 B 仍显示 `Stopped` 或 `program_ftdi -read` 持续显示 0 devices，用管理员权限重新安装 Vivado/Digilent cable driver：

```powershell
D:\software\2025.2\Vivado\data\xicom\cable_drivers\nt64\install_drivers_wrapper.bat
```

5. 复测 `probe_vivado_hw_targets.ps1`，必须看到 `VIVADO_HW_TARGET_COUNT > 0`。
6. 只有 Vivado target 恢复后，才继续当前边界 hash 或最终 compare。
