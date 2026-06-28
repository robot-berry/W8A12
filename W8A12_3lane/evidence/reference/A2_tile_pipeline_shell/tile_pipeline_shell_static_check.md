# A2/A3 Tile Pipeline Shell Static Check

状态：PASS

| 检查项 | 结果 | 说明 |
| --- | --- | --- |
| `exists:W8A12_3lane/docs/a2_a3_tile_scheduler_contract.md` | PASS | W8A12_3lane/docs/a2_a3_tile_scheduler_contract.md |
| `exists:W8A12_3lane/rtl/span/w8a12_3lane_tile_pipeline_shell.v` | PASS | W8A12_3lane/rtl/span/w8a12_3lane_tile_pipeline_shell.v |
| `exists:W8A12_3lane/sim/tb_w8a12_3lane_tile_pipeline_shell.sv` | PASS | W8A12_3lane/sim/tb_w8a12_3lane_tile_pipeline_shell.sv |
| `exists:W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_tile_pipeline_shell.tcl` | PASS | W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_tile_pipeline_shell.tcl |
| `exists:W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_tile_pipeline_shell.ps1` | PASS | W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_tile_pipeline_shell.ps1 |
| `phase:PH_IDLE` | PASS | phase defined in RTL |
| `phase:PH_LOAD` | PASS | phase defined in RTL |
| `phase:PH_CONV1` | PASS | phase defined in RTL |
| `phase:PH_SPAB` | PASS | phase defined in RTL |
| `phase:PH_TAIL` | PASS | phase defined in RTL |
| `phase:PH_WRITE` | PASS | phase defined in RTL |
| `phase:PH_DONE` | PASS | phase defined in RTL |
| `phase:PH_ERROR` | PASS | phase defined in RTL |
| `blocks_param_6` | PASS | default BLOCKS=6 |
| `lane_valid_all` | PASS | all 3 lanes enabled |
| `read_pingpong` | PASS | read buffer follows block parity |
| `write_pingpong` | PASS | write buffer inverse block parity |
| `six_block_exit` | PASS | SPAB exits after BLOCKS |
| `tb_six_spab` | PASS | TB drives six SPAB completions |
| `tb_pass_banner` | PASS | TB pass banner |
| `tcl_adds_rtl` | PASS | Tcl adds shell RTL |
| `tcl_adds_tb` | PASS | Tcl adds shell TB |

该检查不替代 Vivado/xsim；它只确认 shell 接口、FSM、ping-pong 规则和仿真入口一致。