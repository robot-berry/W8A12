# 赛题提交说明

本文档面向赛题二“AI 超分辨率模型高效硬件加速器设计与实现”的评审提交包，说明 `W8A12_3lane/` 中各交付物和证据的位置。

当前状态分为两个口径：

- 赛题提交口径：以 `evidence/contest_scope_readiness/summary.md` 为准，覆盖模型/量化、RTL 仿真、PDF/Word 报告、x4 720p15 scheduler FPS、x2 720p4 降目标 scheduler FPS、bitstream/PPA 和提交包可追溯性。
- 严格上板口径：以 `evidence/delivery_audit/contest_delivery_audit.md` 为准，仍要求 A5/A6/A7/x2 的真实板端 `validation.md Status: PASS`。

严格上板审计入口：

```text
W8A12_3lane/evidence/delivery_audit/contest_delivery_audit.md
```

若该文件显示 `状态：INCOMPLETE`，代表真实板端验证仍未闭合；若评审口径不要求真实插板运行，则应同时查看赛题提交口径门禁：

```text
W8A12_3lane/evidence/contest_scope_readiness/summary.md
```

## 1. 赛题目标对应关系

| 赛题要求 | 本目录对应内容 | 当前状态 |
| --- | --- | --- |
| x4 超分 | SPAN x4/F48，REDS_val 目标 `>=28 dB` | 训练证据 `28.3118 dB`；A0-A4/top fixed/RTL/OOC 证据已建立；board validation 缺 |
| x2 超分 | SPAN x2/F48，REDS_val 目标 `>=30 dB` | FP32 训练证据 `34.4297 dB`；W8A12 导出、fixed reference 和 validation PASS；x2 board 缺 |
| 端侧 FPGA 加速 | `xczu19eg-ffvc1760-2-i` 本地板卡，按 XC7Z045/ZC706 门限评估 | A4 MAC core、single-lane、3-lane scheduler 和 accelerator top shell OOC PASS |
| 三路并行架构 | 48 channel 拆成 `3 lanes x 16 output channels` | 架构、映射、A4 vector check 已建立 |
| 可提交报告 | Markdown + PDF + Word 赛题报告 | `docs/contest_submission_report.md`、`output/pdf/W8A12_3lane_contest_submission_report.pdf`、标准 Word `output/docx/W8A12_3lane_contest_submission_report.docx`、当前完整 Word `output/docx/W8A12_3lane_contest_submission_report_complete_20260701.docx`、`evidence/report_pdf/summary.md`、`evidence/report_docx_complete_20260701/summary.md` |
| 评审证据矩阵 | 交付物/评分点/证据/缺口总览 | `evidence/delivery_matrix/summary.md` |
| bitstream/PPA 门槛 | 无真实上板要求时的 bitstream、仿真、实现后资源/时序证据 | `evidence/bitstream_ppa_gate/summary.md` |
| 赛题提交口径门禁 | 将报告、RTL 仿真、PPA、FPS scheduler、质量对比和真实上板缺口分开审计 | `evidence/contest_scope_readiness/summary.md` |
| 上板验证 | A5 32x32、A6 64x64、A7 720p、x2 720p | 上板 report 工具已建立；真实报告缺 |

## 2. 交付物 1：模型结构、训练、量化和转换工具

| 内容 | 文件 |
| --- | --- |
| 模型/数据/PSNR 说明 | `docs/python_reference_plan.md` |
| x2 fixed reference 契约 | `docs/x2_fixed_reference_contract.md` |
| x2 W8A12 导出计划 | `docs/x2_w8a12_export_plan.md` |
| x4/x2 W8A12 Python reference | `tools/w8a12_3lane_reference.py` |
| x2 导出检查 | `tools/check_x2_w8a12_export.py` |
| x2 fixed reference 检查 | `tools/check_x2_fixed_reference.py` |
| readiness / asset search | `evidence/x2/reference_readiness/`、`evidence/x2/asset_search/` |

已经补齐的 x2 软件/定点证据：

```text
W8A12_3lane/evidence/x2/w8a12_export/summary.md
W8A12_3lane/evidence/x2/reference/summary.md
W8A12_3lane/evidence/x2/reference_validation/validation.md
```

x2 最终仍需补齐真实板端证据：

```text
W8A12_3lane/evidence/board_reports/x2_720p/validation.md
```

## 3. 交付物 2：硬件加速器详细设计文档

| 内容 | 文件 |
| --- | --- |
| 三路并行总体架构 | `docs/w8a12_3lane_architecture.md` |
| lane / bank 映射 | `docs/bank_mapping_rules.md` |
| A2/A3 tile pipeline 契约 | `docs/a2_a3_tile_scheduler_contract.md` |
| A4 scheduler 验收 | `docs/a4_scheduler_acceptance_flow.md` |
| 上板汇报规范 | `docs/board_report_flow.md` |
| 失败回退流程 | `docs/failure_rollback_flow.md` |
| 一键门禁执行 | `docs/delivery_gate_runner.md` |

## 4. 交付物 3：硬件源代码、仿真和综合

| 层级 | 关键文件 | 当前证据 |
| --- | --- | --- |
| A0 单层 3-lane conv | `rtl/span/w8a12_3lane_conv_layer.v` | `evidence/reference/A0_single_conv/a0_rtl_sim_summary.md` |
| A1 单 SPAB block | generated reference/TB | `evidence/reference/A1_single_block/a1_rtl_sim_summary.md` |
| A2 6 blocks | generated reference/TB | `evidence/reference/A2_six_blocks/a2_rtl_sim_summary.md` |
| A2/A3 tile shell | `rtl/span/w8a12_3lane_tile_pipeline_shell.v` | `evidence/reference/A2_tile_pipeline_shell/tile_pipeline_shell_static_check.md` |
| A3 tail/RGB | generated reference/TB | `evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md` |
| A4 MAC core | `rtl/span/w8a12_lane_mac_core.v` | `evidence/resource/A4_lane_mac_core_ooc/mac_core_ooc_summary.md` |
| A4 scheduler | `rtl/span/w8a12_single_lane_mac_scheduler.v`、`rtl/span/w8a12_3lane_mac_scheduler.v` | static/vector/flow-static/xsim/OOC PASS |
| accelerator top shell | `rtl/top/w8a12_3lane_accel_top.v` | xsim/OOC PASS |

## 5. 评分点证据映射

| 评分点 | 当前证据 | 待补 |
| --- | --- | --- |
| 功能实现精准无误 | A0-A4/top summary、x2 fixed reference | board bit-exact |
| 文档清晰、模块划分合理 | `docs/` 全部架构/流程文档 | 完整上板章节随实测更新 |
| 量化指标和性能分析 | 训练 PSNR、A4/top OOC、PPA summary、传统插值 baseline、x4 720p15 scheduler-level FPS closure、x2 720p4 降目标 scheduler-level FPS closure | impl timing、board FPS/power、x2/x4 board PSNR/SSIM |
| 验证方案与用例 | A0-A4 分层门禁、failure rollback、board report validator | A5-A7/x2 board validation PASS |
| 面积和功耗 | MAC core、single-lane、3-lane scheduler 和 top shell XC7Z045 OOC gate PASS | 整机 bitstream 的实测资源/功耗 |

## 6. 运行入口

完整门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -ContinueOnError
```

审计和缺口计划：

```powershell
python W8A12_3lane\tools\audit_contest_delivery.py
python W8A12_3lane\tools\generate_missing_evidence_plan.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\check_contest_scope_readiness.py
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_contest_report_pdf.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_contest_report_docx.ps1
python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete
python W8A12_3lane\tools\collect_delivery_manifest.py
```

当前草案归档摘要：

```text
W8A12_3lane/evidence/submission_package/archive/summary.md
```

## 7. 严格上板最终提交前硬条件

若评审明确要求真实板端输出，则最终提交前必须全部满足：

```text
contest_delivery_audit.md: 状态：PASS
accel top xsim PASS and OOC utilization/timing/ooc_summary PASS
A4 single-lane / 3-lane xsim PASS
A4 single-lane / 3-lane OOC utilization/timing/ooc_summary PASS
A5 32x32 board validation PASS
A6 64x64 board validation PASS
A7 720p x4 board validation PASS
x2 W8A12 export / fixed reference / validation PASS
x2 board validation PASS
submission_manifest.md: Missing Final Evidence 为 None
submission archive summary: Status PASS
report PDF summary: Status PASS
```
