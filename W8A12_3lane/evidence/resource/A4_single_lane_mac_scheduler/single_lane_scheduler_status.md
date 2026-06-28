# A4 Single-Lane MAC Scheduler 状态

## 状态

RTL/TB READY / VIVADO SIM PENDING

## 已完成

- RTL wrapper: `W8A12_3lane/rtl/span/w8a12_single_lane_mac_scheduler.v`
- Testbench: `W8A12_3lane/sim/tb_w8a12_single_lane_mac_scheduler.sv`
- 仿真脚本：
  - `W8A12_3lane/scripts/run_vivado_sim_w8a12_single_lane_mac_scheduler.tcl`
  - `W8A12_3lane/scripts/run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1`
  - `W8A12_3lane/scripts/run_vivado_sim_w8a12_single_lane_mac_scheduler.cmd`
- OOC 顶层与脚本：
  - `W8A12_3lane/rtl/span/w8a12_single_lane_mac_scheduler_ooc_top.v`
  - `W8A12_3lane/scripts/run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.tcl`
  - `W8A12_3lane/scripts/run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.ps1`

## 设计说明

`w8a12_single_lane_mac_scheduler` 使用 `generate` 实例化 16 个 `w8a12_single_out_mac_scheduler`：

```text
lane0 output channels 0..15
  -> each channel uses TAP_PAR=8 MAC scheduler
  -> each channel applies W8A12 requant
  -> packed 16ch lane output
```

这是从 single-output-channel scheduler 到 16ch lane scheduler 的结构推进。后续生产版可根据资源压力减少并行 single-output scheduler 数量，改成更强的时间复用。

## 本轮仿真状态

仿真命令已创建，并已加入 Tcl 自诊断输出与 build 目录清理；但当前工具层调用 Vivado 未形成 `simulate.log` 和 PASS/FAIL 结论。

这不证明 RTL 错误，只说明本轮 Vivado 调用未成功执行。需要后续重跑：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1
```

或使用重定向包装：

```cmd
W8A12_3lane\scripts\run_vivado_sim_w8a12_single_lane_mac_scheduler.cmd
```

## 依赖证据

上一层 single-output-channel scheduler 已通过：

```text
PASS w8a12_single_out_mac_scheduler pixels=16 out_ch=0
```

证据：

```text
W8A12_3lane/evidence/resource/A4_single_out_mac_scheduler/single_out_scheduler_sim_summary.md
```
