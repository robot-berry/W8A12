# Bitstream And PPA Gate Summary

Status: PASS_WITH_SCOPE

This evidence records the contest-style gate where a real board run is not required, but correctness simulation, bitstream generation, implementation timing/resource reports, and PPA reporting are required.

## Current Implemented Bitstream

| Item | Value |
| --- | --- |
| scope | JTAG-W8A12 true2x2 x4 tile-writer/debug count-view configuration |
| scale | x4 |
| image/tile | `ImgW=2 ImgH=2 TileW=2 TileH=2 Halo=21` |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg5_countview_20260703.bit` |
| sha256 | `4C596961793015A30A972BB89A375C5133874B3FBA5EEB7979CDD84533ACD8F5` |
| utilization report | `vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg5_countview_20260703_utilization_impl.rpt` |
| timing report | `vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg5_countview_20260703_timing_impl.rpt` |

## Correctness Simulation

The same true2x2 JTAG-W8A12 endpoint route has behavior-level RTL raw-compare evidence with `0 / 192` mismatch in the dbg5/count-view preparation evidence.

| Evidence | Result |
| --- | --- |
| `evidence/board_reports/jtag_true2x2_dbg5_countview_20260703/analysis.md` | RTL raw compare PASS, `0 / 192` mismatch |
| expected writeback hash | `0x61d3ea1d` |

## Implementation PPA

Implementation results from the 2026-07-03 dbg5/count-view bitstream:

| Metric | Used | ZC706/XC7Z045 planning gate | Gate |
| --- | ---: | ---: | --- |
| CLB LUTs | 39799 | 218600 | PASS |
| CLB Registers | 116685 | 437200 | PASS |
| BRAM Tile | 311 | 545 | PASS |
| DSPs | 128 | 900 | PASS |
| URAM | 0 | 0 expected | PASS |
| WNS | 12.580 ns | >= 0 ns | PASS |
| WHS | 0.010 ns | >= 0 ns | PASS |

Vivado reports: all user specified timing constraints are met.

## Scope Boundary

- This is a bitstream/PPA evidence item, not a real-board output image report.
- It proves that the current W8A12 tile-writer/debug configuration can generate a bitstream and meet implementation timing/resource gates.
- It does not prove that the full 720p packed 2-D engine has been implemented as a complete bitstream. The packed 2-D 720p numbers remain scheduler/performance-model evidence until the full engine, memory banking, and halo reuse datapath are integrated.
- If the contest accepts bitstream + simulation + PPA without physical board execution, this evidence is sufficient for the implemented true2x2/tile-writer scope. If the contest requires a full x2/x4 720p accelerator bitstream, a larger integration pass is still needed.
