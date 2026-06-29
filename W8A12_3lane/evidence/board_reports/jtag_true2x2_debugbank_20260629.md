# JTAG true2x2 debug-bank update

Date: 2026-06-29

## Status

Status: RTL PASS / BOARD NEXT

This update extends the JTAG true2x2 debug path after the live board run localized the first mismatch to `tail_b1_hash`.

The old 6-bit AXI-Lite map is preserved for bank 0:

| Register | Bank 0 value |
| --- | --- |
| `0x04` | `tail_b1_hash` |
| `0x08` | `tail_b6_act1_hash` |
| `0x10` | `tail_rgb_q_hash` |
| `0x30` | `writeback_hash` |
| `0x34` | `writeback_range` |
| `0x38` | `writeback_first` |
| `0x3c` | `writeback_last` |

`REG_PERF_CTRL[15:8]` now selects the debug bank while preserving `REG_PERF_CTRL[0]` as `perf_drain_enable`.

## New debug banks

| Bank | Register | Value |
| --- | --- | --- |
| `1` | `0x04` | `tail_feat0_hash` |
| `1` | `0x08` | `src_feat0_hash` |
| `1` | `0x10` | `src_b1_hash` |
| `1` | `0x30` | `spab_b1_input_hash` |
| `1` | `0x34` | `spab_b1_c1_hash` |
| `1` | `0x38` | `spab_b1_c2_hash` |
| `1` | `0x3c` | `spab_b1_c3_hash` |
| `2` | `0x04` | `spab_b1_c1_raw_hash` |
| `2` | `0x08` | `spab_b1_c2_replay_hash` |
| `2` | `0x10` | `spab_b1_c2_window_hash` |
| `2` | `0x30` | `spab_b1_residual_hash` |
| `2` | `0x34` | `spab_b1_att_hash` |
| `2` | `0x38` | `tail_b1_hash` cross-check |
| `2` | `0x3c` | `tail_rgb_q_hash` cross-check |

## RTL verification

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 -SkipPackWeights -SimRuntime 300ms -ImageW 2 -TileW 2 -TileH 2 -Halo 21 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -MaxCycles 22000000 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -BuildRoot build\xsim_jtag_w8a12_debugbank_refcmp_20260629
```

Result:

| Item | Value |
| --- | --- |
| Behavioral raw compare | PASS |
| mismatch bytes | `0 / 192` |
| max diff | `0` |
| PSNR | `Infinity` |
| `tail_b1_hash` | `0x16ede1c2` |
| `tail_b6_act1_hash` | `0xc7a092b8` |
| `tail_rgb_q_hash` | `0xb712a61b` |
| `writeback_hash` | `0x61d3ea1d` |
| sim log | `build/xsim_jtag_w8a12_debugbank_refcmp_20260629/jtag_w8a12_tile_writer_raw_compare_sim.sim/sim_1/behav/xsim/simulate.log` |
| Vivado log | `board_runs/w8a12_partition_sim_attempts/jtag_raw_compare_2x2_tile2x2_h21_ol1_tl4_sl1.log` |

## Next board step

Regenerate a JTAG true2x2 debug-bank bitstream from the updated RTL, rerun:

```powershell
W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -ForceVivadoProbe -RunStageHashAcceptance
```

Acceptance for the next board pass:

1. JTAG/PSU/register read remains PASS.
2. Output remains full length `192 / 192`.
3. Bank 1 and bank 2 hashes are present in `read_jtag_w8a12_tile_writer_regs_summary.json`.
4. The first mismatching hash is localized to one of `tail_feat0`, `src_feat0`, `src_b1`, `spab_b1_input`, `spab_b1_c1`, `spab_b1_c2`, `spab_b1_c3`, `spab_b1_residual`, or `spab_b1_att`.

