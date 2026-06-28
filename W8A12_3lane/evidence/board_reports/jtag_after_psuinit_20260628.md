# JTAG after PSU init board debug

Date: 2026-06-28

## Summary

After re-plugging the board, Vivado target enumeration was recovered. The remaining `get_hw_axis` failure was reproduced and then cleared by running the matching ZynqMP `psu_init.tcl` before programming/probing the JTAG AXI design.

Current status:

| Item | Result |
| --- | --- |
| Vivado target | PASS, `xczu19_0` and `arm_dap_1` visible |
| PSU init, minimal JTAG AXI probe | PASS |
| Minimal JTAG AXI register probe | PASS, `hw_axi_1`, magic/scratch read-write OK |
| PSU init, W8A12 debugregs | PASS |
| W8A12 true2x2 debugregs transfer | FAIL, input accepted but no output |

This means the active board-side blocker has moved from JTAG AXI visibility to W8A12 endpoint/datapath progress after accepting the 2x2 input frame.

## PSU init and JTAG AXI recovery

Helper added:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_xsct_psu_init_only.ps1 -PsuInitTcl <psu_init.tcl> -OutputDir <out>
```

Minimal register-probe recovery sequence:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_xsct_psu_init_only.ps1 -PsuInitTcl b\jtag_axi_probe_build\jtag_axi_register_probe_after_replug_20260628\jtag_axi_register_probe.gen\sources_1\bd\jtagaxiprobe\ip\jtagaxiprobe_ps_0\psu_init.tcl -OutputDir board_runs\psu_init_only\jtag_axi_probe_after_replug_20260628
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_axi_register_probe.ps1 -Bitstream vivado\bitstreams\jtag_axi_register_probe_f26m.bit -OutputDir board_runs\jtag_axi_register_probe\after_replug_f26m_after_psuinit_20260628
```

Result:

| Item | Value |
| --- | --- |
| PSU init summary | `board_runs/psu_init_only/jtag_axi_probe_after_replug_20260628/psu_init_only_summary.md` |
| Register probe summary | `board_runs/jtag_axi_register_probe/after_replug_f26m_after_psuinit_20260628/jtag_axi_register_probe_summary.md` |
| Register probe status | PASS |
| `hw_axi` | `hw_axi_1` |
| magic | `0x57384158` |
| version | `0x00010000` |
| status | `0x00000001` |
| scratch | `0xA5A55A5A` |

Conclusion: after board replug/cold state, PS/PL clock initialization is required before relying on Vivado Hardware Manager JTAG-to-AXI enumeration. The earlier `no supported soft debug core(s)` symptom was caused by missing PS/PL initialization, not by the W8A12 RTL itself.

## W8A12 true2x2 debugregs run

W8A12 PSU init:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_xsct_psu_init_only.ps1 -PsuInitTcl vivado\jwtw_true2x2_jtagaxi_dbgregs_20260627\jwtw.gen\sources_1\bd\jwtw\ip\jwtw_ps_0\psu_init.tcl -OutputDir board_runs\psu_init_only\jwtw_true2x2_jtagaxi_dbgregs_20260628
```

W8A12 board transfer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627.bit -ImgW 2 -ImgH 2 -Scale 4 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_dbgregs_after_psuinit_20260628
```

Observed result before manually stopping the long wait:

| Item | Value |
| --- | --- |
| `get_hw_axis` | PASS, `hw_axi_1` |
| Input sent | `4 / 4` pixels |
| `REG_COUNTER_IN` | `4` |
| `REG_COUNTER_OUT` | `0` |
| `REG_STATUS` | `0x00002000` |
| `REG_ERROR` | `0x00000000` |
| `REG_FRAME_DONE` | `0x00000000` |
| `REG_FRAME_CYCLES` | `0` |
| Board output bytes | `0 / 192` |
| Compare | not reached |

The run entered the image path and accepted all four input pixels, but no output pixel was produced.

In `rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v`, `0x00002000` decodes to `core_busy=1`. Therefore the endpoint did assert `core_start` after the last input pixel and the core remained busy, but `core_done`, `wr_valid`, and `frame_done` did not arrive during the wait window.

## Readback after timeout

The read-only register script was extended to include the debug writeback registers at `0x30..0x3c`.

Stable readback across three samples:

| Register | Value |
| --- | --- |
| `REG_COUNTER_IN` | `4` |
| `REG_COUNTER_OUT` | `0` |
| `REG_ERROR` | `0x00000000` |
| `REG_FRAME_DONE` | `0x00000000` |
| `REG_FRAME_CYCLES` | `0` |
| `REG_DEBUG_WRITEBACK_HASH` | `0x02029843` |
| `REG_DEBUG_WRITEBACK_RANGE` | `0x02029843` |
| `REG_DEBUG_WRITEBACK_FIRST` | `0x00000000` |
| `REG_DEBUG_WRITEBACK_LAST` | `0x00000202` |

RTL expected debugregs remain:

```text
expected_writeback_hash  = 0x61d3ea1d
expected_writeback_range = 0x4e9f0040
expected_writeback_first = 0x0061605d
expected_writeback_last  = 0x007a6366
```

## Current conclusion

The JTAG/board access layer is now validated again:

1. USB/JTAG target is visible.
2. PS initialization passes.
3. Minimal JTAG-to-AXI register read-write passes after PS init.
4. W8A12 debugregs bitstream exposes `hw_axi_1`.

The remaining issue is inside the W8A12 true2x2 endpoint/datapath after input acceptance: the board run accepts the whole input frame (`counter_in=4`) and enters `core_busy`, but never reaches output (`counter_out=0`, `frame_done=0`, `frame_cycles=0`).

This supersedes the temporary `JTAG AXI not visible` blocker from `jtag_after_replug_20260628.md`.

## Progress/debug register update

After the no-output board run, the JTAG endpoint was extended with low-intrusion progress readback:

| Register | New debug meaning |
| --- | --- |
| `0x04 REG_INPUT_FLAGS` | endpoint progress bits: `core_start/core_busy/core_done`, input/output low counters, AXI read/write handshakes, error bits |
| `0x08 REG_INPUT_PIXEL` | `front_debug_state` from the W8A12 front/tail shell |
| `0x10 REG_OUTPUT_FLAGS` | `{block_start_count, replay_feature_count[15:0]}` |
| `0x30..0x3c` | writeback hash/range/first/last, unchanged |

The register dump script `scripts/read_jtag_w8a12_tile_writer_regs.tcl` now decodes these fields as:

```text
JTAG_W8A12_REG_DEBUG_ENDPOINT_PROGRESS=...
JTAG_W8A12_REG_DEBUG_FRONT_STATE=...
JTAG_W8A12_REG_DEBUG_BLOCK_COUNTS=...
JTAG_W8A12_REG_DEBUG_WRITER_LIVE=...
```

RTL regression after this instrumentation remains bit-exact:

```text
PASS sr_jtag_w8a12_tile_writer_endpoint_raw_compare inputs=4 outputs=64
mismatch bytes = 0 / 192
expected_writeback_hash = 0x61d3ea1d
```

Therefore the new readback path can be used for the next board probe without changing the true2x2 mathematical output in behavioral RTL simulation.

Follow-up board run: `jtag_true2x2_dbgprogress_20260628.md` built this instrumentation into a new bitstream. That bitstream produced the full `192 / 192` output bytes and reached `frame_done=1`, but compare still failed with `189 / 192` mismatch and board writeback hash `0xAD24396D` instead of RTL expected `0x61D3EA1D`. The no-output symptom was therefore bypassed by the new build, but correctness is still open and the debug-progress bitstream is not a final correctness candidate.

## Next checks

1. Return to the historical Default/inpixfix `153/192` baseline for correctness bring-up.
2. Add narrower, lower-perturbation stage hashes around front/SPAB output, tail/pixelshuffle/RGB, and writer input.
3. Keep `scripts/read_jtag_w8a12_tile_writer_regs.tcl --poll-count 3` as the standard post-run snapshot.
4. If a future build reaches `counter_out=64` and writeback hash matches RTL, then check endpoint output cache/JTAG readback.
5. If writeback/stage hash remains different from RTL, continue isolating front/SPAB vs tail/RGB vs writer input.
