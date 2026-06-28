# JTAG true2x2 debug-progress board run

Date: 2026-06-28

## Summary

After board replug and `psu_init.tcl` recovery, a new true2x2 JTAG W8A12 bitstream was built with endpoint/datapath progress registers exposed at `0x04/0x08/0x10`.

Result: the new `dbgprogress` bitstream no longer stalls at `counter_out=0`; it produces the full `192 / 192` output bytes and reaches `frame_done=1`. However, the output is not bit-exact and is worse than the historical Default baseline.

This is useful debug evidence, but not a correctness baseline.

## Build

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_w8a12_tile_writer.ps1 -ImgW 2 -TileW 2 -TileH 2 -Halo 21 -PlFreqMhz 25 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -SynthDirective Default -VivadoMaxThreads 1 -AttemptLabel true2x2_jtagaxi_dbgprogress_20260628
```

Important artifacts:

| Item | Path |
| --- | --- |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgprogress_20260628.bit` |
| Vivado log | `board_runs/w8a12_tile_writer_bitstream_attempts/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgprogress_20260628.log` |
| utilization | `vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgprogress_20260628_utilization_impl.rpt` |
| timing | `vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgprogress_20260628_timing_impl.rpt` |

Build status:

| Metric | Value |
| --- | ---: |
| Timing | PASS, all user constraints met |
| WNS | `12.317 ns` |
| WHS | `0.010 ns` |
| CLB LUTs | `39337` |
| CLB Registers | `116119` |
| BRAM Tile | `311` |
| DSP | `126` |
| URAM | `0` |

RTL regression before board build:

```text
PASS sr_jtag_w8a12_tile_writer_endpoint_raw_compare inputs=4 outputs=64
mismatch bytes = 0 / 192
expected_writeback_hash = 0x61d3ea1d
```

## Board commands

PS init:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_xsct_psu_init_only.ps1 -PsuInitTcl vivado\jwtw_true2x2_jtagaxi_dbgprogress_20260628\jwtw.gen\sources_1\bd\jwtw\ip\jwtw_ps_0\psu_init.tcl -OutputDir board_runs\psu_init_only\jwtw_true2x2_jtagaxi_dbgprogress_20260628
```

Short-wait smoke:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgprogress_20260628.bit -ImgW 2 -ImgH 2 -Scale 4 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_dbgprogress_shortwait_20260628 -OutputWaitTries 5000 -PerfWaitTries 5000 -InputReadyTries 1000000
```

Register readback:

```powershell
cmd.exe /d /s /c "call D:\software\2025.2\Vivado\bin\vivado.bat -mode batch -log board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_dbgprogress_shortwait_20260628\reg_read_after_smoke\read_regs.log -journal board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_dbgprogress_shortwait_20260628\reg_read_after_smoke\read_regs.jou -source scripts\read_jtag_w8a12_tile_writer_regs.tcl -tclargs --poll-count 3 --poll-delay-ms 200"
```

## Board result

| Item | Value |
| --- | ---: |
| JTAG-to-AXI | PASS, `hw_axi_1` |
| Vivado transfer exit | `0` |
| Input counter | `4` |
| Output counter | `64` |
| Output bytes | `192 / 192` |
| Frame done | `1` |
| Frame cycles | `6704456` |
| E2E cycles | `6704456` |
| Error flags | `0x00000000` |
| Compare | FAIL |
| Mismatch bytes | `189 / 192` |
| Max channel diff | `106` |
| PSNR | `16.3034184420509 dB` |

Comparison artifacts:

| Item | Path |
| --- | --- |
| smoke summary | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgprogress_shortwait_20260628/jtag_w8a12_tile_writer_smoke_summary.md` |
| compare summary | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgprogress_shortwait_20260628/compare/w8a12_compare_summary_x4_2x2.md` |
| board output | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgprogress_shortwait_20260628/board_output.rgb` |
| preview | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgprogress_shortwait_20260628/compare/jtag_w8a12_validation_preview.png` |

## Register readback

Stable across three samples:

| Register/field | Value |
| --- | --- |
| `REG_STATUS` | `0x00001000` |
| `REG_INPUT_FLAGS` | `0x00508401` |
| `REG_INPUT_PIXEL` / `DEBUG_FRONT_STATE` | `0x00017800` |
| `REG_OUTPUT_FLAGS` | `0x00060018` |
| `REG_COUNTER_IN` | `4` |
| `REG_COUNTER_OUT` | `64` |
| `REG_ERROR` | `0x00000000` |
| `REG_FRAME_CYCLES` | `6704456` |
| `REG_FRAME_DONE` | `0x00000001` |
| `REG_E2E_CYCLES` | `6704456` |
| `REG_DEBUG_WRITEBACK_HASH` | `0xAD24396D` |
| `REG_DEBUG_WRITEBACK_RANGE` | `0x009C0040` |
| `REG_DEBUG_WRITEBACK_FIRST` | `0x006F7761` |
| `REG_DEBUG_WRITEBACK_LAST` | `0x0010161B` |

Decoded progress:

```text
core_start=0 core_busy=0 core_done=0 core_error=0
frame_active=0 frame_done=1
rd_req_valid=0 rd_req_ready=1 rd_resp_valid=0 rd_resp_pending=0 rd_resp_bad=0
wr_valid=0 wr_ready=1
input_drop=0 output_overrun=0 mem_addr_error=0
input_low4=4 output_low4=0 tiles_low4=1
block_start=6 replay_feature_low16=24
writer_live: valid_h=0 valid_w=156 tile_is_full=1 state=0
```

RTL expected writeback values:

```text
expected_writeback_hash  = 0x61d3ea1d
expected_writeback_range = 0x4e9f0040
expected_writeback_first = 0x0061605d
expected_writeback_last  = 0x007a6366
```

## Interpretation

1. The board no longer has the earlier `counter_out=0` no-output symptom for this `dbgprogress` bitstream.
2. The endpoint, JTAG-to-AXI path, output FIFO/cache, and readback path can move a complete 2x2 -> 8x8 frame.
3. The board writeback hash/first/last do not match the RTL expected values, so the current mismatch is produced before or at the writer data-generation boundary, not only after the endpoint output register.
4. This debug-progress build should not replace the correctness baseline: it reports `189/192` mismatch and `16.30 dB`, while the historical Default/inpixfix baseline is `153/192` mismatch and `44.03 dB`.

Next recommended checks:

1. Return correctness bring-up to the historical Default/inpixfix baseline and avoid using wide debug-progress registers as the final candidate.
2. Add narrower, latched stage hashes to isolate which stage diverges: front/SPAB output, tail/pixelshuffle/RGB, then writer input.
3. Run post-synth or post-impl netlist raw compare for the exact Default baseline if simulation capacity allows.
4. Add writer-only pattern, postprocess-only, and tail/pixelshuffle-only board tests before scaling to 32x32.
