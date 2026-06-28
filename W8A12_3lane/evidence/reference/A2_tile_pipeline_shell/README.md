# A2/A3 Tile Pipeline Shell Evidence

## 状态

STATIC CHECK PASS / VIVADO SIM PENDING

## 目标

该阶段固定 A2/A3 走向 A5 上板所需的 tile 级控制接口：

```text
load -> conv1 -> SPAB block0..5 -> tail -> write -> done
```

它不替代 A0-A3 的数学验证，也不声明 32x32 tile 已经通过；它只是建立可综合调度外壳和观测信号。

## 文件

- 规格：`W8A12_3lane/docs/a2_a3_tile_scheduler_contract.md`
- RTL：`W8A12_3lane/rtl/span/w8a12_3lane_tile_pipeline_shell.v`
- TB：`W8A12_3lane/sim/tb_w8a12_3lane_tile_pipeline_shell.sv`
- Tcl：`W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_tile_pipeline_shell.tcl`
- PowerShell：`W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_tile_pipeline_shell.ps1`

## 期望仿真通过信息

```text
PASS w8a12_3lane_tile_pipeline_shell spab_blocks=6
```

## 当前静态检查

```text
tile_pipeline_shell_static_check.md
tile_pipeline_shell_static_check.json
```

结果：

```text
PASS, 22 checks
```

该检查不替代 Vivado/xsim；它只确认 shell 接口、FSM、ping-pong 规则和仿真入口一致。
