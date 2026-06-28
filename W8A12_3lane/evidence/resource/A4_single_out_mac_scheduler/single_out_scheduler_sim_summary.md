# A4 Single-Out MAC Scheduler 仿真记录

## 状态

RTL SIM PASS / OOC TODO

## RTL

- Scheduler: `W8A12_3lane/rtl/span/w8a12_single_out_mac_scheduler.v`
- MAC core: `W8A12_3lane/rtl/span/w8a12_lane_mac_core.v`
- Requant: `rtl/span/span_w8a12_requant.v`
- Testbench: `W8A12_3lane/sim/tb_w8a12_single_out_mac_scheduler.sv`

## 覆盖范围

本次验证将 A0 deterministic `4x4x48` feature 输入送入 single-output-channel scheduler：

- 输入窗口：48 input channels x 3x3 taps。
- TAP_PAR：8。
- 输出通道：lane0 的 output channel 0。
- 对齐对象：A0 `full48_output.txt` 的 channel 0。

## 通过信息

```text
PASS w8a12_single_out_mac_scheduler pixels=16 out_ch=0
```

## 仿真命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_single_out_mac_scheduler.ps1
```

注：当前 Vivado batch 在 `$finish` 后偶发返回非零退出码，但 `simulate.log` 已明确输出 PASS。后续可继续清理脚本退出码；该问题不影响 RTL 语义证据。

## OOC 状态

`w8a12_single_out_mac_scheduler_ooc_top` 和对应脚本已创建，但本轮 OOC 未形成 utilization report。A4 当前可用资源门限证据仍以 `A4_lane_mac_core_ooc` 为准。
