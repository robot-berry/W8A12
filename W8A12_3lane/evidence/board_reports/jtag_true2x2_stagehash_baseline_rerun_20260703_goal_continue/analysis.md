# 2026-07-03 stagehash baseline 上板复跑摘要

Status: FAIL_CLEAN_BOARD_NUMERIC_MISMATCH

## 范围

本次证据使用已有非侵入 `stagehash` true2x2 bitstream，在真实板端执行 JTAG/Vivado target probe、PSU init、2x2 输入写入、8x8 输出读回、board-vs-reference 比对和寄存器读取。

它是 clean baseline mismatch 证据，不是正确性通过证据，也不能作为最终 board validation PASS。

## 结果

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
| frame cycles | 7202120 |
| mismatch bytes | 192 / 192 |
| max channel diff | 133 |
| PSNR | 11.883879766827 dB |

## Stage Hash 对比

| Boundary | RTL expected | Board observed | 结果 |
| --- | --- | --- | --- |
| tail_b1_hash | 0x16ede1c2 | 0x59F2850F | MISMATCH |
| tail_b6_act1_hash | 0xc7a092b8 | 0x755918A6 | MISMATCH |
| tail_rgb_q_hash | 0xb712a61b | 0x86BF4216 | MISMATCH |
| writeback_hash | 0x61d3ea1d | 0x44A4F24C | MISMATCH |

## 与 dbg2/source-b6 结果的区别

| 项目 | stagehash baseline rerun | dbg2/source-b6 rerun |
| --- | --- | --- |
| 证据性质 | clean baseline | debug probe 可能侵入 |
| error flags | 0x00000000 | 0x0000000C |
| output bytes | 192 / 192 | 192 / 192 |
| mismatch bytes | 192 / 192 | 188 / 192 |
| PSNR | 11.883879766827 dB | 19.2633707572237 dB |
| frame cycles | 7202120 | 3762894 |
| 是否可作为 datapath 定位依据 | 是，适合作为下一轮低侵入定位基线 | 否，只作探针侵入性风险证据 |

## 解释

本轮证明板端链路已经恢复：JTAG target 可见、PSU init 通过、输入写入和输出读回完整、寄存器读取通过，并且 `error=0`。因此当前失败不是连接、PSU、JTAG 或 writer 读回缺失问题，而是 W8A12 PL 计算路径的数值输出仍不等于 RTL/Python fixed reference。

由于本轮最早可见的非侵入边界 `tail_b1_hash` 已经不等于 RTL 期望，下一步不应优先修改 writer 或 RGB readback，而应继续向前拆分：

1. 保持 stagehash baseline 的低侵入特性。
2. 每次只导出一个 source 边界，例如 `src_feat0` 或 `src_b1`。
3. 只有当下一轮同时满足 `error=0`、`frame_done=1`、`output=192/192` 时，才把 first mismatching boundary 作为 RTL 修改依据。

## 证据快照

| 文件 | 说明 |
| --- | --- |
| `analysis.md` | 本摘要 |
| `artifacts/stagehash_acceptance_summary.md` | stage-hash 验收总表 |
| `artifacts/smoke_summary.md` | JTAG W8A12 smoke 输出与计数 |
| `artifacts/compare_summary.md` | board-vs-reference 图像指标 |
| `artifacts/reg_read_summary.md` | stage hash 寄存器读取 |
| `artifacts/jtag_w8a12_validation_preview.png` | 输入、参考、板端输出和差分预览 |
