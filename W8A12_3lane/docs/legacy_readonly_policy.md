# 旧线只读与复用策略

本文档说明哪些旧文件应当只读，哪些旧资产可以复用到 `W8A12_3lane` 新主线。

## 1. 旧线定位

旧线是当前已有的 W8A12 DDR tile-writer / single-out 调试路线。它的价值是：

- 已有 W8A12 权重和 generated constants。
- 已有 Python fixed-point reference。
- 已有 Vivado/xsim 脚本模板。
- 已有 PS/DDR/XSCT 上板框架。
- 已有 resource gate。
- 已有 32x32 上板 evidence 和 mismatch/hash 调试记录。

旧线不再作为新主线继续堆补丁的地方。新架构的 RTL、仿真和脚本应优先放入 `W8A12_3lane`。

## 2. 建议只读的旧文件/目录

以下内容建议只读保留，除非明确是在修复旧线证据索引或复制到新线：

| 路径 | 处理方式 | 原因 |
| --- | --- | --- |
| `W8A12/README.md` | 只读 | 旧线当前状态和 mismatch 记录 |
| `W8A12/CODE_LOGIC.md` | 只读 | 旧线数据流和模块职责说明 |
| `W8A12/FILE_INDEX.md` | 只读 | 旧线文件索引 |
| `W8A12/EVIDENCE_INDEX.md` | 只读 | 旧线 evidence 索引 |
| `W8A12/active/` | 只读 | 旧线 runnable snapshot |
| `W8A12/evidence/` | 只读 | 旧线上板、资源、timing、mismatch 证据 |
| `W8A12/archive_notes/` | 只读 | 历史记录 |
| `W8A12/docs/` 中旧线状态文档 | 只读 | 保留旧线判断依据 |

旧线的 RTL 源路径也应谨慎处理：

| 路径 | 处理方式 | 说明 |
| --- | --- | --- |
| `rtl/board/sr_tile_halo_fetch_w8a12_*` | 默认只读参考 | 旧 tile-writer 和 scheduler 路线 |
| `rtl/board/sr_w8a12_block_group_*` | 默认只读参考 | 旧 block group 实现 |
| `rtl/span/span_w8a12_*` | 默认只读参考 | 旧 W8A12 算子实现 |
| `sim/tb_*w8a12*` | 默认只读参考 | 旧 testbench，可复制后改名 |
| `scripts/*w8a12*` | 默认只读参考 | 旧脚本模板，可复制后改名 |
| `tools/*w8a12*` | 默认只读参考 | 旧 reference/hash/resource 工具，可复制后改名 |

## 3. 可以复用的旧资产

可以复制或引用到新线的内容：

- `rtl/generated/reds_span_x4_f48_w8a12/`：权重、scale、bias、generated `.mem/.vh`。
- `tools/run_span_w8a12_integer_reference.py`：Python 定点参考的基础。
- `tools/compute_w8a12_tail_debug_hashes.py`：边界 hash 参考。
- `tools/check_vivado_zc706_resource_gate.py`：XC7Z045 resource gate。
- `scripts/run_vivado_*w8a12*.ps1/.tcl`：Vivado 脚本模板。
- `scripts/run_ps_w8a12_ddr_tile_writer_smoke.ps1`：上板 smoke 模板。
- `scripts/run_xsct_ps_w8a12_ddr_tile_writer_smoke.tcl`：XSCT 板端配置模板。

复用方式：

1. 复制到 `W8A12_3lane/tools`、`scripts`、`rtl` 或 `sim`。
2. 文件名加 `_3lane`。
3. 修改顶层 module/testbench/script 名称，避免误跑旧线。
4. 在文件头写明来源旧文件和改动目的。

## 4. 不建议继续修改旧线的情况

以下情况应在新线实现，而不是回旧线改：

- 新增 3-lane convolution。
- 新增 3-bank feature buffer。
- 新增 3-lane SPAB block engine。
- 新增 3-lane scheduler。
- 新增三路并行 testbench。
- 新增三路并行 board smoke。

## 5. 允许修改旧线的例外

只有以下情况可以修改旧线：

- 修正文档错字或索引路径。
- 补充旧 evidence 的说明。
- 为了导出新线 reference，增加不影响旧结果的只读工具参数。
- 用户明确要求继续修旧线。

