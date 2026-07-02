# 2026-07-03 dbg3 single-boundary true2x2 上板分析

Status: FAIL_CLEAN_BOARD_NUMERIC_MISMATCH_LOCALIZED_TO_SRC_B1

## 范围

本轮在已有 clean stagehash baseline 之后，新增 `DebugExportLevel=3` / bank3 source-boundary 读数，用于在 `error=0` 的前提下继续拆分 `halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> tail` 链路。

该证据不是 board validation PASS；它是 mismatch 定位证据。

## RTL 与 bitstream 结果

| 项目 | 结果 |
| --- | --- |
| RTL raw compare | PASS，`0 / 192` mismatch |
| RTL debug level | `DebugExportLevel=3` |
| 新增边界 | `src_block6_hash`、`src_b6_act1_hash`、bank3 source/tail hashes |
| bitstream | PASS generated |
| timing | PASS |
| WNS / WHS | 13.131 ns / 0.010 ns |
| LUT / FF / BRAM tile / DSP | 39231 / 116534 / 311 / 128 |
| bitstream path | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg3_dbg3_single_boundary_20260703.bit` |

## 板端结果

| 项目 | 结果 |
| --- | --- |
| probe | PASS |
| PSU init | PASS |
| Smoke / compare | FAIL |
| Register read | PASS |
| output bytes | 192 / 192 |
| frame_done | 1 |
| input / output counter | 4 / 64 |
| error flags | 0x00000000 |
| frame cycles | 7521176 |
| mismatch bytes | 192 / 192 |
| max channel diff | 157 |
| PSNR | 7.7239212457414 dB |

## 边界对比

| Boundary | RTL expected | Board observed | 结果 |
| --- | --- | --- | --- |
| src_feat0_hash | 0xf7f21881 | 0xF7F21881 | MATCH |
| src_b1_hash | 0x16ede581 | 0xF657C1B4 | MISMATCH |
| src_block6_hash | 0xae4b81bc | 0x547AB9F3 | MISMATCH |
| src_b6_act1_hash | 0xc7a096fb | 0x599FE8A9 | MISMATCH |
| tail_b1_hash | 0x16ede1c2 | 0xF657C5F7 | MISMATCH |
| tail_b6_act1_hash | 0xc7a092b8 | 0x599FECEA | MISMATCH |
| tail_rgb_q_hash | 0xb712a61b | 0xE5EDCFCD | MISMATCH |
| writeback_hash | 0x61d3ea1d | 0xDE37538E | MISMATCH |

## 解释

本轮保持了 clean failure 条件：`error=0`、`frame_done=1`、输出完整、寄存器读取 PASS，因此比 dbg2/source-b6 的 `error=0xC` 结果更适合作为定位依据。

`src_feat0_hash` 与 RTL 完全一致，说明输入写入、halo/RGB 前端以及 conv1 feat0 源边界在本轮可视范围内是可信的。首个已知 mismatch 前移到 `src_b1_hash`，后续 `src_block6/src_b6_act1/tail/writeback` 均随之 mismatch。因此下一轮应优先检查 SPAB block1 输出/feature buffer replay 到 `src_b1` 的边界，而不是优先改 writer、PSU、JTAG 或末端 RGB readback。

## 下一步

1. 保持 `DebugExportLevel=3` 的 `error=0` 条件。
2. 新增更细的 block1 内部边界或复用 bank2：`spab_b1_input -> c1_raw -> c1 -> c2_replay/window -> c3/residual/att -> src_b1`。
3. 若下一轮仍保持 `error=0`，以第一个 mismatch 的 block1 子边界作为 RTL 修复依据。

## 证据快照

| 文件 | 说明 |
| --- | --- |
| `analysis.md` | 本摘要 |
| `analysis.json` | 机器可读分析 |
| `artifacts/stagehash_acceptance_summary.md` | 本轮验收总表 |
| `artifacts/smoke_summary.md` | 上板输出、计数、error、frame_done |
| `artifacts/compare_summary.md` | board-vs-reference 图像指标 |
| `artifacts/reg_read_summary.md` | bank1/bank2/bank3 寄存器读数 |
| `artifacts/jtag_w8a12_validation_preview.png` | 输入、参考、板端输出和差分预览 |
