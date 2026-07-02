# W8A12 dbg2 source-boundary acceptance

Status: FAIL

| Field | Value |
| --- | --- |
| bitstream | `G:\UESTC\feitengspan1\vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg2_current_dbg2_source_b6_20260701.bit` |
| psu_init.tcl | `G:\UESTC\feitengspan1\vivado\jwtw_current_dbg2_source_b6_20260701\jwtw.gen\sources_1\bd\jwtw\ip\jwtw_ps_0\psu_init.tcl` |
| precondition | `READY` |
| USB known JTAG candidate count | `` |
| Vivado target count | `` |
| output dir | `G:\UESTC\feitengspan1\board_runs\jtag_w8a12_tile_writer\true2x2_dbg2_src_boundary_acceptance_20260703_goal_continue` |
| preflight dir | `G:\UESTC\feitengspan1\board_runs\w8a12_board_recovery_preflight\dbg2_src_boundary_current` |
| summary JSON | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\board_reports\jtag_true2x2_dbg2_src_boundary_20260703_goal_continue\summary.json` |

## Expected RTL hashes

| Signal | Value |
| --- | --- |
| tail_b1_hash | `0x16ede1c2` |
| tail_b6_act1_hash | `0xc7a092b8` |
| tail_rgb_q_hash | `0xb712a61b` |
| writeback_hash | `0x61d3ea1d` |
| bank1_tail_feat0_hash | `0x025504bf` |
| bank1_src_feat0_hash | `0xf7f21881` |
| bank1_src_b1_hash | `0x16ede581` |
| src_b6_act1_hash | `0xc7a096fb` |

## Next Step

Inspect the acceptance output directory and register-read summary to classify mismatch/stall/error.
