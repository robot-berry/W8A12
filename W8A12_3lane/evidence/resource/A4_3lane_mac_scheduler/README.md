# A4 3-Lane MAC Scheduler Evidence

## 状态

STATIC CHECK PASS / VIVADO SIM PENDING

## 验收目标

该阶段验证 3 个 16ch lane 同时接入后的 48ch 卷积输出：

```text
input:  A0 4x4x48 feature
output: A0 full48_output.txt
check:  every pixel, every channel bit-exact
PASS:   PASS w8a12_3lane_mac_scheduler pixels=16 channels=48
```

## 文件

- RTL: `W8A12_3lane/rtl/span/w8a12_3lane_mac_scheduler.v`
- TB: `W8A12_3lane/sim/tb_w8a12_3lane_mac_scheduler.sv`
- Tcl: `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_mac_scheduler.tcl`
- PowerShell: `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_mac_scheduler.ps1`
- Cmd wrapper: `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_mac_scheduler.cmd`
- OOC top: `W8A12_3lane/rtl/span/w8a12_3lane_mac_scheduler_ooc_top.v`
- OOC Tcl: `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.tcl`
- OOC PowerShell: `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1`

## 依赖

- `W8A12_3lane/evidence/reference/A0_single_conv/a0_3lane_files.vh`
- `W8A12_3lane/rtl/span/w8a12_single_lane_mac_scheduler.v`
- `W8A12_3lane/rtl/span/w8a12_single_out_mac_scheduler.v`
- `W8A12_3lane/rtl/span/w8a12_lane_mac_core.v`

当前环境的 Vivado batch 调用仍未稳定进入 Tcl；恢复后先跑 single-lane，再跑本 3-lane 验收。

## 当前静态检查

已生成：

```text
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_static_check.md
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_static_check.json
```

结果：

```text
PASS, 62 checks
```

该检查确认 3-lane scheduler、TB、OOC Tcl 和 A0 golden fixture 的 lane 绑定一致；它不替代 Vivado/xsim 仿真。
