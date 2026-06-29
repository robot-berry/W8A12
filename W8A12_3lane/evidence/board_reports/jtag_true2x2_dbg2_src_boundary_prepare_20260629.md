# JTAG true2x2 dbg2 source-boundary prepare

日期：2026-06-29

## 目的

历史 stage-hash 已把板端 mismatch 收敛到：

```text
halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> b1_m_feat -> tail
```

本轮准备一个低侵入 `DebugExportLevel=2` 位流，只打开 source/tap 边界 hash，不打开 SPAB block1 深层 hash。这样板子恢复可见后，优先确认 `src_feat0/src_b1` 与 tail 侧 `b1_m_feat` 的关系，再决定是否进入更重的 `DebugExportLevel=3` SPAB 内部探针。

## RTL 变更

| 文件 | 变更 |
| --- | --- |
| `rtl/board/sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v` | 新增 `DEBUG_SPAB_HASH`，将 scheduler 深层 hash 从 `DEBUG_SRC_HASH` 中拆出 |
| `rtl/board/sr_tile_halo_fetch_w8a12_front_tail_writer_shell.v` | 透传 `DEBUG_SPAB_HASH` |
| `rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v` | `DEBUG_EXPORT_LEVEL>=2` 只开 source/tap hash；`>=3` 才开 SPAB deep bank2 |
| `sim/tb_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.sv` | 增加 bank1/bank2 debug readback 打印 |
| `scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.ps1` | `DebugExportLevel` 支持 `0..3`，bitstream tag 始终包含 `_dbgN` |
| `scripts/run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1` | `DebugExportLevel` 支持 `0..3` |

## RTL 行为仿真

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 `
  -ImageW 2 -TileW 2 -TileH 2 -Halo 21 `
  -OutLanes 1 -TapLanes 4 -ScaleLanes 1 `
  -DebugExportLevel 2 `
  -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb `
  -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb `
  -BuildRoot build\xsim_jtag_w8a12_tile_writer_raw_compare_dbg2_src_boundary_bankread `
  -SkipPackWeights
```

结果：

| 项目 | 值 |
| --- | --- |
| status | PASS |
| output | `64` pixels / `192` bytes |
| mismatch | `0 / 192` |
| max diff | `0` |
| frame cycles | `7202120` |
| tail b1 hash | `0x16ede1c2` |
| tail b6 act1 hash | `0xc7a092b8` |
| tail rgb q hash | `0xb712a61b` |
| writeback hash | `0x61d3ea1d` |
| bank1 tail feat0 hash | `0x000004bf` |
| bank1 src feat0 hash | `0x00000004` |
| bank1 src b1 hash | `0x00070004` |

仿真日志：

```text
build/xsim_jtag_w8a12_tile_writer_raw_compare_dbg2_src_boundary_bankread/jtag_w8a12_tile_writer_raw_compare_sim.sim/sim_1/behav/xsim/simulate.log
```

## Bitstream

| 项目 | 值 |
| --- | --- |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg2_true2x2_jtagaxi_dbg2_src_boundary_20260629.bit` |
| SHA256 | `BC596A62105EA7C413673B9494C1D480EBF55EB3063A6E3303E349EED650220F` |
| psu_init | `vivado/jwtw_true2x2_jtagaxi_dbg2_src_boundary_20260629/jwtw.gen/sources_1/bd/jwtw/ip/jwtw_ps_0/psu_init.tcl` |
| project | `vivado/jwtw_true2x2_jtagaxi_dbg2_src_boundary_20260629/jwtw.xpr` |
| vivado log | `board_runs/w8a12_tile_writer_bitstream_attempts/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg2_true2x2_jtagaxi_dbg2_src_boundary_20260629.log` |

Implementation：

| 项目 | 值 |
| --- | --- |
| timing | PASS，all user specified timing constraints met |
| WNS | `12.072 ns` |
| WHS | `0.010 ns` |
| CLB LUTs | `40501` |
| CLB Registers | `116379` |
| BRAM Tile | `311` |
| URAM | `0` |
| DSPs | `126` |
| peak memory | `6574.535 MB` |

## 当前上板状态

当前板端 preflight 仍为 `BLOCKED`：

```text
USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=0
Vivado target count=not_checked
```

也就是说本轮只完成了“下一轮板端定位位流准备”，尚未得到 dbg2 source-boundary 实板 hash。

## 板子恢复后直接执行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_stagehash_true2x2_acceptance.ps1 `
  -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg2_true2x2_jtagaxi_dbg2_src_boundary_20260629.bit `
  -PsuInitTcl vivado\jwtw_true2x2_jtagaxi_dbg2_src_boundary_20260629\jwtw.gen\sources_1\bd\jwtw\ip\jwtw_ps_0\psu_init.tcl `
  -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_dbg2_src_boundary_acceptance_20260629 `
  -OutputWaitTries 5000 -PerfWaitTries 5000 -InputReadyTries 1000000 `
  -ContinueOnError
```

## 下一步判定

| 板端现象 | 判定 |
| --- | --- |
| dbg2 输出完整且 bank1 source hash 与 RTL 一致，但 tail b1 仍不一致 | 优先查 tail 输入 buffer/replay 到 tail 的交接 |
| dbg2 输出完整但 source hash 已不一致 | 优先查 halo fetch / conv1 / source tap |
| dbg2 仍然 stall | 说明 source-boundary debug 仍过重，回退到 stage-hash baseline 或只读一组寄存器 |
| dbg2 完整且全部 hash 一致但 board output mismatch | 优先查 writeback/output buffer/JTAG 读回 |
