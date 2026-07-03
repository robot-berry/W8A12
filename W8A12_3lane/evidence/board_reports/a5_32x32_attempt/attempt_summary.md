# A5 32x32 Board Attempt

Status: FAIL

## Scope

- x4 32x32 LR -> 128x128 SR.
- Source run: `G:/UESTC/feitengspan1/board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858`
- Bitstream: `vivado/bitstreams/ps_w8a12_ddr_tile_writer_x4_imgw32x32_tile32x32_h21_f50m_ol1_tl4_sl1_ddr_runtime_plddridx_u32idx_32x32_20260624b.bit`
- PL clock: `50 MHz`.

## Result

| Check | Result |
| --- | --- |
| Vivado/JTAG preflight | PASS |
| Software W8A12 integer reference | PASS |
| Bitstream program | PASS |
| DDR input write/readback verify | PASS, mismatch `0` |
| XSCT full run | FAIL |
| Board output compare | NOT RUN, no output pixels were produced |

## Failure

- Stage: `PL compute completion / XSCT DDR/control/hardware status check`.
- Reason: `W8A12 DDR tile writer did not finish before timeout`.
- The run reached board programming and DDR input verification, so this is not a "board not plugged in" or Python-reference failure.
- The failing hardware symptom is `frame_done=0`, `output_read_pixels=0`, `rgb_output_count=0`, and no AXI writeback fire.

## Software Reference

| Compare | PSNR | MAE | Max diff | Mismatch bytes |
| --- | ---: | ---: | ---: | ---: |
| `pytorch_vs_fake` | `40.197682` | `1.450012` | `27` | `34320 / 49152` |
| `pytorch_vs_integer` | `40.216980` | `1.446065` | `27` | `34327 / 49152` |
| `fake_vs_integer` | `56.110817` | `0.159139` | `2` | `7820 / 49152` |

Reference summary: `runs/reds_span_quant_plan/span_w8a12_integer_reference_a5_32x32_fixcheck_20260703_0855/span_w8a12_integer_reference_summary.md`.

## Resource Gate

| Item | Used | Gate | Result |
| --- | ---: | ---: | --- |
| LUT | `41052` | `218600` | PASS |
| Register | `117083` | `437200` | PASS |
| BRAM tile | `415.5` | `545` | PASS |
| DSP | `128` | `900` | PASS |

## Key Registers

| Register | Value |
| --- | --- |
| status | `0x00000006` |
| error | `0x00000000` |
| frame_done | `0` |
| frame_cycles | `0` |
| tiles_done | `0` |
| block_starts | `1` |
| block_outputs | `0` |
| replay_feature | `1024` |
| rgb_output_count | `0` |
| debug_state | `0x00060427` |
| debug_c1_counts | `0x03FF03FF` |
| debug_c2_counts | `0x000003FF` |
| debug_c3_counts | `0x00000000` |
| debug_att_counts | `0x00000000` |
| debug_c1_lane_outputs | `49152` |
| debug_c2_lane_outputs | `0` |
| debug_c3_lane_outputs | `0` |
| debug_att_lane_outputs | `0` |
| debug_spab_flags | `0x81007840` |
| debug_wr_fire_count | `0x00000000` |
| debug_axi_write_counts | `0x00000000` |
| output_read_pixels | `0` |

## Interpretation

This latest A5 attempt is useful as a board bring-up checkpoint, but it is still not a valid A5 board validation. The host-to-board control path, bitstream programming, reference generation, and DDR input path passed. The remaining failure is inside the PL compute completion/writeback path: block 1 starts and C1 activity is visible, but C2/C3/attention/output and writeback do not complete before timeout.

Next debug step: add a narrow C1-to-C2 ready/valid or feature-replay ready/valid probe, then rerun the smallest true2x2/32x32 case before attempting 64x64 or 720p.

## Artifacts

- reference_preview: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/reference/span_w8a12_integer_reference_preview.png`
- integer_reference: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/reference/integer_w8a12_span.png`
- reference_rgb: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/reference.rgb`
- board_output_hex: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/board_output.hex`
- preflight_log: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/preflight/probe_vivado_hw_targets.log`
- program_log: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/program/program_ps_w8a12_tile_writer_bitstream.log`
- xsct_log: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/run_xsct_ps_w8a12_ddr_tile_writer_smoke.log`
- xsct_stdout: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/run_xsct_ps_w8a12_ddr_tile_writer_smoke.stdout.log`
- xsct_stderr: `board_runs/w8a12_ps_ddr_tile_writer_smoke/a5_32x32_acceptance_goal_continue_fixref_20260703_0858/run_xsct_ps_w8a12_ddr_tile_writer_smoke.stderr.log`
