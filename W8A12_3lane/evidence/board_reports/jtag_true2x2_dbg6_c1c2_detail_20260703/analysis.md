# JTAG true2x2 dbg6 C1/C2 detail probe

Status: RTL PASS / BOARD NEXT

## Purpose

dbg5/count-view localized the current board stall to SPAB block1 after partial C1 activity and before C2/C3/attention completion. This dbg6 probe exposes existing C1/C2 detail signals through JTAG endpoint debug bank 6 so the next board run can compare C1->C2 ready/valid and replay/window/core progress against RTL.

## RTL changes

- `rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v`
  - wires existing shell outputs:
    - `front_debug_c1_detail`
    - `front_debug_c1_core_detail`
    - `front_debug_c1_lane_detail`
    - `front_debug_c1_io_detail`
    - `front_debug_c2_detail`
    - `front_debug_c2_core_detail`
    - `front_debug_c2_lane_detail`
  - maps them to `REG_PERF_CTRL[15:8] == 8'h06`.
- `scripts/read_jtag_w8a12_tile_writer_regs.tcl`
  - reads and prints the new bank 6 values.
- `sim/tb_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.sv`
  - reads bank 6 during true2x2 raw compare so RTL expected values are in the simulation log.

## Verification command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 -RequireVivadoIdle -ImageW 2 -TileW 2 -TileH 2 -Halo 21 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -DebugExportLevel 3 -SimRuntime 300ms -MaxCycles 22000000 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -BuildRoot build\xsim_jtag_raw_compare_dbg6_c1c2_detail_rerun_20260703
```

## Result

| Item | Value |
| --- | --- |
| RTL compare | PASS |
| input pixels | 4 |
| output pixels | 64 |
| mismatch bytes | 0 / 192 |
| max diff | 0 |
| PSNR | Infinity |
| simulate log | `build/xsim_jtag_raw_compare_dbg6_c1c2_detail_rerun_20260703/jtag_w8a12_tile_writer_raw_compare_sim.sim/sim_1/behav/xsim/simulate.log` |
| simulate log SHA256 | `F72AA4778EC54C9CA2497F566D5AB799C1F0FC2F480BB85FC8AF43919C100167` |

## Bank 6 RTL expected values

| Register print | Expected value |
| --- | --- |
| `JTAG_DEBUG_BANK6_C1_DETAIL` | `0x0000200c` |
| `JTAG_DEBUG_BANK6_C1_CORE_DETAIL` | `0x17c01af5` |
| `JTAG_DEBUG_BANK6_C1_LANE_DETAIL` | `0x0dbf1af5` |
| `JTAG_DEBUG_BANK6_C1_IO_DETAIL` | `0x00021403` |
| `JTAG_DEBUG_BANK6_C2_DETAIL` | `0x0000200c` |
| `JTAG_DEBUG_BANK6_C2_CORE_DETAIL` | `0x17c01af5` |
| `JTAG_DEBUG_BANK6_C2_LANE_DETAIL` | `0x0dbf1af5` |

## Interpretation

The dbg6 instrumentation compiles and keeps the true2x2 endpoint output bit-exact against the fixed RGB reference. It does not fix the board mismatch/stall by itself. The next required step is to build/program the dbg6 bitstream, run true2x2 board acceptance, and compare the board bank 6 values against the expected values above.
