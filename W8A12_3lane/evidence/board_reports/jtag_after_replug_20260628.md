# JTAG after replug board probe and mismatch debug

Date: 2026-06-28

## Summary

After re-plugging the board, Vivado hardware target enumeration recovered. The board is now visible through Digilent USB-JTAG, but the current JTAG-to-AXI access path does not expose any `hw_axi` master after programming, so the W8A12 true2x2 debugregs run cannot yet reach image transfer or mismatch comparison.

This is progress compared with the previous `VIVADO_HW_TARGET_COUNT=0` state: the failure moved from cable/target enumeration to JTAG AXI soft debug core recognition.

## Vivado target probe

| Item | Result |
| --- | --- |
| Probe run | `board_runs/vivado_hw_target_probe_after_replug_20260628` |
| USB known JTAG candidates | 3 |
| Vivado hardware targets | 1 |
| Target | `localhost:3121/xilinx_tcf/Digilent/210203367162A` |
| Devices | `xczu19_0`, `arm_dap_1` |
| PASS marker | `VIVADO_HW_TARGET_PROBE_PASS=1` |
| Audit evidence | `W8A12_3lane/evidence/board_probe/vivado_hw_probe.md` |

The probe evidence is now `Status: PASS` after filtering out Tcl source comments from the log checker.

## W8A12 true2x2 debugregs smoke

Command target:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627.bit -ImgW 2 -ImgH 2 -Scale 4 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_dbgregs_after_replug_20260628
```

Result:

| Item | Result |
| --- | --- |
| Status | FAIL |
| Vivado exit | 1 |
| Output bytes | 0 / 192 |
| Compare | SKIPPED |
| Failure point | `No JTAG-to-AXI Master found. Regenerate bitstream with jtag_axi IP.` |
| Summary | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgregs_after_replug_20260628/jtag_w8a12_tile_writer_smoke_summary.md` |

The run did not reach `FRAME_DONE`, `ERROR`, `writeback_hash`, or RGB compare. Therefore it does not update the historical `153 / 192` mismatch baseline.

## Minimal JTAG AXI register probe

To separate W8A12 datapath issues from JTAG AXI visibility, the minimal register-probe bitstream was retried:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_axi_register_probe.ps1 -Bitstream vivado\bitstreams\jtag_axi_register_probe_f25m.bit -OutputDir board_runs\jtag_axi_register_probe\after_replug_20260628
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_axi_register_probe.ps1 -Bitstream vivado\bitstreams\jtag_axi_register_probe_f25m.bit -OutputDir board_runs\jtag_axi_register_probe\after_replug_retry2_20260628
```

Both attempts failed at the same point:

| Item | Result |
| --- | --- |
| Target | visible |
| Program | completed, startup HIGH |
| Vivado debug-core message | `design that has no supported soft debug core(s)` |
| `get_hw_axis` | none |
| Probe status | FAIL |

Historical contrast:

| Run | Result |
| --- | --- |
| `board_runs/jtag_axi_register_probe/f25m_20260627_0048` | PASS, Vivado reported `1 JTAG AXI core(s)` and `hw_axi_1` |
| `board_runs/jtag_axi_register_probe/after_replug_20260628` | FAIL, Vivado reported no supported soft debug core |
| `board_runs/jtag_axi_register_probe/after_replug_retry2_20260628` | FAIL, same failure |

## Current conclusion

The board cable and Vivado target are now visible, so the earlier hard gap `VIVADO_HW_TARGET_COUNT=0` is cleared. The active board-side blocker is now JTAG AXI soft debug core recognition after programming.

This is not yet an algorithm/RTL mismatch result. The W8A12 true2x2 RTL/debugregs expected writeback hash remains:

```text
expected_writeback_hash = 0x61d3ea1d
```

The next mismatch-debug step is still to read the board-side debugregs hash, but that depends on restoring `get_hw_axis` visibility first.

## Next checks

1. Rebuild the minimal `jtag_axi_register_probe_f25m.bit` and verify whether a fresh bitstream again reports `1 JTAG AXI core(s)`.
2. If a fresh register-probe bitstream passes, rebuild the W8A12 true2x2 JTAG debugregs bitstream from the same Vivado/JTAG AXI recipe.
3. If rebuilt register-probe still shows no soft debug core, inspect Vivado 2025.2 debug core recognition state: `.ltx`/probes handling, `refresh_hw_device`, `cs_server` startup, and JTAG clock/device properties.
4. After `get_hw_axis` is restored, rerun `true2x2_jtagaxi_dbgregs` and compare board `writeback_hash` with `0x61d3ea1d`.
