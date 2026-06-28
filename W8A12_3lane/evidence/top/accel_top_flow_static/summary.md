# Accelerator Top Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:top` | PASS | `W8A12_3lane/rtl/top/w8a12_3lane_accel_top.v` |
| `file:ooc_top` | PASS | `W8A12_3lane/rtl/top/w8a12_3lane_accel_top_ooc_top.v` |
| `file:tile_shell` | PASS | `W8A12_3lane/rtl/span/w8a12_3lane_tile_pipeline_shell.v` |
| `file:tb` | PASS | `W8A12_3lane/sim/tb_w8a12_3lane_accel_top.sv` |
| `file:sim_tcl` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_accel_top.tcl` |
| `file:sim_ps1` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_accel_top.ps1` |
| `file:sim_cmd` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_accel_top.cmd` |
| `file:ooc_tcl` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_accel_top_ooc.tcl` |
| `file:ooc_ps1` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_accel_top_ooc.ps1` |
| `file:ooc_cmd` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_accel_top_ooc.cmd` |
| `file:xsim_summary` | PASS | `W8A12_3lane/tools/summarize_xsim_result.py` |
| `sim_tcl_adds_tile_shell` | PASS | `tile shell source` |
| `sim_tcl_adds_accel_top` | PASS | `accel top source` |
| `sim_tcl_adds_tb` | PASS | `testbench` |
| `sim_ps1_checks_pass` | PASS | `PASS line` |
| `sim_ps1_writes_summary` | PASS | `summary outputs` |
| `sim_cmd_summarizes` | PASS | `cmd fallback summary` |
| `xsim_summary_has_accel_preset` | PASS | `accel xsim preset` |
| `tb_checks_spab_count` | PASS | `six SPAB starts` |
| `tb_checks_status_bits` | PASS | `done/irq status bits` |
| `tb_checks_clear` | PASS | `clear path` |
| `tb_has_pass_line` | PASS | `PASS line` |
| `ooc_tcl_adds_tile_shell` | PASS | `tile shell source` |
| `ooc_tcl_adds_accel_top` | PASS | `accel top source` |
| `ooc_tcl_adds_ooc_top` | PASS | `OOC wrapper source` |
| `ooc_tcl_reports_util` | PASS | `utilization report` |
| `ooc_tcl_reports_timing` | PASS | `timing report` |
| `ooc_ps1_checks_reports` | PASS | `report existence checks` |
| `ooc_cmd_summarizes` | PASS | `cmd fallback summary` |
| `ooc_wrapper_instantiates_top` | PASS | `top instance` |
| `ooc_wrapper_no_errors` | PASS | `error ties` |
