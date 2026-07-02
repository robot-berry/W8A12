# 2026-07-03 dbg2 source-boundary 上板排查摘要

Status: FAIL_BOARD_NUMERIC_MISMATCH_DBG2_ERROR

## 范围

本次证据使用已有 `dbg2 current source-b6` true2x2 bitstream，在真实板端执行 JTAG/Vivado target probe、PSU init、2x2 输入写入、8x8 输出读回、board-vs-reference 比对和 debug bank 寄存器读取。

它是 mismatch 排查证据，不是正确性通过证据，也不能作为最终 board validation PASS。

## 结果

| 项目 | 结果 |
| --- | --- |
| JTAG precondition | READY |
| USB known JTAG candidate | 3 |
| Vivado target count | 1 |
| PSU init | PASS |
| Smoke / compare | FAIL |
| Register read | PASS |
| output bytes | 192 / 192 |
| frame_done | 1 |
| input / output counter | 4 / 64 |
| error flags | 0x0000000C |
| frame cycles | 3762894 |
| mismatch bytes | 188 / 192 |
| max channel diff | 89 |
| PSNR | 19.2633707572237 dB |

## Hash 对比

| Boundary | RTL expected | Board observed | 结果 |
| --- | --- | --- | --- |
| src_feat0_hash | 0xf7f21881 | 0x6576E40D | MISMATCH |
| src_b1_hash | 0x16ede581 | 0x227F387A | MISMATCH |
| src_b6_act1_hash | 0xc7a096fb | 0x66F9655B | MISMATCH |
| tail_b1_hash | 0x16ede1c2 | 0x227F3C39 | MISMATCH |
| tail_b6_act1_hash | 0xc7a092b8 | 0x66F96118 | MISMATCH |
| tail_rgb_q_hash | 0xb712a61b | 0x2FCBACF2 | MISMATCH |
| writeback_hash | 0x61d3ea1d | 0x135E672B | MISMATCH |

## 解释

本轮已经证明板卡、JTAG、PSU init、输入写入、输出读回和寄存器读取通路可用；失败不再是“板子未连接”或 “Vivado target 不可见”。

同时，本轮出现 `error flags = 0x0000000C`。因此这些 source/tail hash 不能直接作为纯 datapath 根因结论，只能说明 `dbg2 current source-b6` 版本在真实板端仍存在数值错误，并且本轮 debug probe 可能具有侵入性。

当前最稳妥的下一步不是修改 tail/writeback，而是回到低侵入探针：

1. 先复跑非侵入 stagehash baseline，确认无 debug source-b6 时仍能完整输出。
2. 重新生成 single-boundary probe，每次只导出一组边界，例如只导出 `src_feat0/src_b1` 或只导出 `src_b6_act1`。
3. 要求下一轮定位证据同时满足 `error=0`、`frame_done=1`、`output=192/192` 后，才把 first mismatching boundary 作为 RTL 修改依据。

## 证据快照

| 文件 | 说明 |
| --- | --- |
| `summary.md` | dbg2 wrapper 总结 |
| `artifacts/preflight_summary.md` | USB/JTAG/Vivado target preflight |
| `artifacts/stagehash_acceptance_summary.md` | stage-hash 验收总表 |
| `artifacts/smoke_summary.md` | JTAG W8A12 smoke 输出与计数 |
| `artifacts/compare_summary.md` | board-vs-reference 图像指标 |
| `artifacts/reg_read_summary.md` | debug bank 寄存器读取 |
| `artifacts/jtag_w8a12_validation_preview.png` | 输入、参考、板端输出和差分预览 |
