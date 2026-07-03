# JTAG true2x2 dbg6 bitstream build attempt

Status: BUILD PARTIAL / NO BITSTREAM

## Scope

Build a true2x2 JTAG-W8A12 bitstream with `DEBUG_EXPORT_LEVEL=3` and the dbg6 C1/C2 detail debug bank enabled.

## Commands attempted

Initial build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_w8a12_tile_writer.ps1 -RequireVivadoIdle -ImgW 2 -TileW 2 -TileH 2 -Halo 21 -PlFreqMhz 25 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -DebugExportLevel 3 -VivadoMaxThreads 1 -SynthDirective Default -AttemptLabel dbg6_c1c2_detail_20260703
```

Resume from opt checkpoint:

```powershell
D:\software\2025.2\Vivado\bin\vivado.bat -mode batch -source scripts\resume_jtag_w8a12_tile_writer_from_opt_dcp.tcl -journal vivado\logs\jwtw_dbg6_resume_from_opt_20260703.jou -log vivado\logs\jwtw_dbg6_resume_from_opt_20260703.log
```

## Result

| Item | Value |
| --- | --- |
| initial build result | interrupted before bitstream |
| latest visible stage | `place_design` in initial build output |
| bitstream generated | no |
| synth checkpoint | `vivado/jwtw_dbg6_c1c2_detail_20260703/jwtw.runs/impl_1/jwtw_wrapper_synth.dcp` |
| opt checkpoint | `vivado/jwtw_dbg6_c1c2_detail_20260703/jwtw.runs/impl_1/jwtw_wrapper_opt.dcp` |
| resume script | `scripts/resume_jtag_w8a12_tile_writer_from_opt_dcp.tcl` |
| resume result | Vivado exited with code `-1` after `open_checkpoint`; no Tcl error was printed in the captured log |
| console log | `vivado/logs/jwtw_dbg6_resume_from_opt_20260703.console.log` |
| vivado log | `vivado/logs/jwtw_dbg6_resume_from_opt_20260703.log` |

## Synth resource snapshot

Source: `vivado/jwtw_dbg6_c1c2_detail_20260703/reports/jtag_w8a12_tile_writer_utilization_synth.rpt`

| Resource | Used |
| --- | ---: |
| CLB LUTs | 42817 |
| CLB Registers | 115888 |
| Block RAM Tile | 311 |
| DSPs | 126 |

## Interpretation

The dbg6 RTL and true2x2 raw compare are valid, and synthesis produced usable checkpoints and a resource report. A board-ready dbg6 bitstream has not been produced yet. The next implementation step is to resume place/route/write_bitstream from `jwtw_wrapper_opt.dcp` or rerun the full bitstream script with a longer Vivado window.
