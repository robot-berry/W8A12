# A5 32x32 Board Attempt

Status: FAIL

## Scope

- x4 32x32 LR -> 128x128 SR
- Source run: `G:/UESTC/feitengspan1/board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a`
- Bitstream: `vivado/bitstreams/ps_w8a12_ddr_tile_writer_x4_imgw32x32_tile32x32_h21_f50m_ol1_tl4_sl1_ddr_runtime_wrdebug32_20260625a.bit`

## Result

| Check | Result |
| --- | --- |
| Vivado JTAG probe | PASS |
| Bitstream program | PASS |
| XSCT full run | FAIL |

## Failure

- Stage: `XSCT DDR/control/hardware status check`
- Reason: `W8A12 DDR tile writer did not finish before timeout /     while executing / "error "W8A12 DDR tile writer did not finish before timeout"" /     invoked from within / "if {$done == 0} { /     error "W8A12 DDR tile writer did not finish before timeout" / }" /     (file "scripts\run_xsct_ps_w8a12_ddr_tile_writer_smoke.tcl" line 538)`

## Key Registers

| Register | Value |
| --- | --- |
| status | `0x00000006` |
| error | `0x00000000` |
| frame_done | `0` |
| frame_cycles | `0` |
| tiles_done | `0` |
| rgb_output_count | `0` |
| debug_state | `0x00017800` |
| debug_spab_flags | `0x01E00F00` |
| debug_axi_state | `0x00030504` |
| wr_fire_count | `0x00000000` |

## Artifacts

- reference_preview: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/reference/span_w8a12_integer_reference_preview.png`
- integer_reference: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/reference/integer_w8a12_span.png`
- board_output_hex: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/board_output.hex`
- preflight_log: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/preflight/probe_vivado_hw_targets.log`
- program_log: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/program/program_ps_w8a12_tile_writer_bitstream.log`
- xsct_stdout: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/run_xsct_ps_w8a12_ddr_tile_writer_smoke.stdout.log`
- xsct_stderr: `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_baboon32_plddrindexed_20260625a/run_xsct_ps_w8a12_ddr_tile_writer_smoke.stderr.log`

## Interpretation

板卡识别和 bitstream 下载已经通过；本次没有生成有效 board 超分图。失败点是 PL 计算未在 timeout 前拉高 FRAME_DONE，RGB output count 为 0，AXI write fire count 为 0。
