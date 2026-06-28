# A4 Scheduler Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:mac_core` | PASS | `W8A12_3lane/rtl/span/w8a12_lane_mac_core.v` |
| `file:single_out` | PASS | `W8A12_3lane/rtl/span/w8a12_single_out_mac_scheduler.v` |
| `file:single_lane` | PASS | `W8A12_3lane/rtl/span/w8a12_single_lane_mac_scheduler.v` |
| `file:three_lane` | PASS | `W8A12_3lane/rtl/span/w8a12_3lane_mac_scheduler.v` |
| `file:single_lane_ooc_top` | PASS | `W8A12_3lane/rtl/span/w8a12_single_lane_mac_scheduler_ooc_top.v` |
| `file:three_lane_ooc_top` | PASS | `W8A12_3lane/rtl/span/w8a12_3lane_mac_scheduler_ooc_top.v` |
| `file:single_lane_tb` | PASS | `W8A12_3lane/sim/tb_w8a12_single_lane_mac_scheduler.sv` |
| `file:three_lane_tb` | PASS | `W8A12_3lane/sim/tb_w8a12_3lane_mac_scheduler.sv` |
| `file:single_lane_sim_tcl` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_single_lane_mac_scheduler.tcl` |
| `file:single_lane_sim_ps1` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1` |
| `file:single_lane_ooc_tcl` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.tcl` |
| `file:single_lane_ooc_ps1` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.ps1` |
| `file:single_lane_ooc_cmd` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.cmd` |
| `file:three_lane_sim_tcl` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_mac_scheduler.tcl` |
| `file:three_lane_sim_ps1` | PASS | `W8A12_3lane/scripts/run_vivado_sim_w8a12_3lane_mac_scheduler.ps1` |
| `file:three_lane_ooc_tcl` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.tcl` |
| `file:three_lane_ooc_ps1` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1` |
| `file:three_lane_ooc_cmd` | PASS | `W8A12_3lane/scripts/run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.cmd` |
| `file:a0_include` | PASS | `W8A12_3lane/evidence/reference/A0_single_conv/a0_3lane_files.vh` |
| `single_lane_tb_reads_a0_vectors` | PASS | `A0 input/expected` |
| `single_lane_tb_checks_lane0` | PASS | `lane0 ch0..15` |
| `single_lane_tb_has_timeout` | PASS | `output watchdog` |
| `single_lane_tb_has_pass_line` | PASS | `PASS line` |
| `three_lane_tb_reads_a0_vectors` | PASS | `A0 input/expected` |
| `three_lane_tb_checks_full48` | PASS | `full48 channel loop` |
| `three_lane_tb_has_timeout` | PASS | `output watchdog` |
| `three_lane_tb_has_pass_line` | PASS | `PASS line` |
| `single_lane_sim_tcl_sources` | PASS | `single-lane sim source list` |
| `three_lane_sim_tcl_sources` | PASS | `3-lane sim source list` |
| `single_lane_sim_ps1_summary` | PASS | `summary/PASS extraction` |
| `three_lane_sim_ps1_summary` | PASS | `summary/PASS extraction` |
| `single_lane_ooc_tcl_reports` | PASS | `util/timing reports` |
| `three_lane_ooc_tcl_reports` | PASS | `util/timing reports` |
| `single_lane_ooc_tcl_top` | PASS | `OOC top` |
| `three_lane_ooc_tcl_top` | PASS | `OOC top` |
| `single_lane_ooc_ps1_checks_reports` | PASS | `report existence checks` |
| `three_lane_ooc_ps1_checks_reports` | PASS | `report existence checks` |
| `single_lane_ooc_cmd_summarizes` | PASS | `cmd fallback summary` |
| `three_lane_ooc_cmd_summarizes` | PASS | `cmd fallback summary` |
| `single_lane_ooc_wrapper_instantiates_scheduler` | PASS | `scheduler instance` |
| `three_lane_ooc_wrapper_instantiates_scheduler` | PASS | `scheduler instance` |
| `single_lane_ooc_wrapper_uses_a0_lane0` | PASS | `lane0 constants` |
| `three_lane_ooc_wrapper_uses_all_lanes` | PASS | `lane0/1/2 constants` |
