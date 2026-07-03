# W8A12_3lane Delivery Evidence Matrix

Status: PASS

Contest delivery status: `INCOMPLETE`

Audit pass count: `72 / 76`

Submission package status: `INCOMPLETE`

Submission file count: `411`

PDF report SHA256: `cb4a05635f2e5c5cbd3570cd5704b778cca09b81a32e12dd36f57d0504fc4389`

DOCX report SHA256: `c1cec510db5071843079e7f0f53dfed9e9b1d52c1206692e77df6f05a5c701fb`

## Evidence Matrix

| Area | Item | Status | Evidence | Note |
| --- | --- | --- | --- | --- |
| 交付物1 模型/训练/量化/转换 | x4/x2 SPAN F48 模型说明和全量 REDS 训练/验证口径 | `PASS` | `docs/python_reference_plan.md`<br>`docs/contest_submission_report.md` | 训练使用 REDS train 官方全量，验证使用 REDS val 官方全量；x4 28.3118 dB，x2 34.4297 dB。 |
| 交付物1 模型/训练/量化/转换 | W8A12 fixed reference 与 x2 导出 | `PASS` | `tools/w8a12_3lane_reference.py`<br>`evidence/x2/w8a12_export/summary.md`<br>`evidence/x2/reference_validation/validation.md` | x2 W8A12 manifest、quant plan、postprocess 和 fixed reference 已闭环；x4 A0-A3 分层 reference 已作为 RTL golden。 |
| 交付物2 硬件设计文档 | 3-lane 架构、bank 映射、scheduler、top shell、回退和上板流程 | `PASS` | `docs/w8a12_3lane_architecture.md`<br>`docs/bank_mapping_rules.md`<br>`docs/board_report_flow.md` | 文档覆盖 48ch 拆为 3x16ch、6 个 SPAB 串行、tile+halo 和 board report 验收口径。 |
| 交付物3 RTL/仿真/综合 | A0-A4/top shell RTL 仿真 | `PASS` | `evidence/reference/`<br>`evidence/resource/A4_single_lane_mac_scheduler/`<br>`evidence/resource/A4_3lane_mac_scheduler/`<br>`evidence/top/accel_top_sim/summary.md` | 分层 bit-exact/hash 验证已通过，top shell 控制/status 仿真 PASS。 |
| 交付物3 RTL/仿真/综合 | OOC 综合资源与 PPA 汇总 | `PASS` | `evidence/ppa_summary/summary.md`<br>`evidence/top/accel_top_ooc/`<br>`evidence/resource/A4_3lane_mac_scheduler_ooc/` | A4 3-lane scheduler: LUT 56.35%、FF 58.61%、DSP 74.67%，低于 XC7Z045/ZC706 门限；完整 board FPS/power 待上板。 |
| 评分点 功能正确性 | 离线功能闭环与板端剩余验证 | `PARTIAL` | `evidence/reference/`<br>`evidence/board_reports/jtag_true2x2_stagehash_20260628.md`<br>`evidence/board_reports/jtag_true2x2_dbg3_single_boundary_20260703/analysis.md`<br>`evidence/board_reports/jtag_true2x2_dbg5_countview_20260703/analysis.md`<br>`evidence/board_reports/jtag_true2x2_dbg6_c1c2_detail_20260703/analysis.md`<br>`evidence/delivery_audit/missing_evidence_plan.md` | RTL true2x2 raw compare PASS；dbg3 clean run 已把首个已知 mismatch 前移到 src_b1_hash；dbg5/count-view 进一步定位到 block1 C1->C2/feature replay 握手；dbg6 已导出 C1/C2 detail bank 并保持 RTL bit-exact；真实 board validation 仍缺 A5/A6/A7/x2 四项。 |
| 评分点 文档清晰度 | Markdown + PDF 赛题报告 | `PASS` | `docs/contest_submission_report.md`<br>`output/pdf/W8A12_3lane_contest_submission_report.pdf`<br>`evidence/report_pdf/summary.md`<br>`output/docx/W8A12_3lane_contest_submission_report.docx`<br>`evidence/report_docx/summary.md` | PDF 已生成并完成全页渲染/关键文本校验。 |
| 评分点 量化指标和性能分析 | 画质 baseline、PPA、板端指标口径 | `PASS` | `evidence/quality_comparison/summary.md`<br>`evidence/quality_metric_completion/summary.md`<br>`evidence/ppa_summary/summary.md` | 传统插值对比已纳入；W8A12 fixed/board 全量 PSNR/SSIM 和 FPS/power 待真实 board output 后补齐。 |
| 评分点 验证方案与用例 | 分层门禁、缺口计划、JTAG 恢复清单 | `PASS` | `evidence/delivery_runs/current_post_upload_refresh_20260630/summary.md`<br>`evidence/delivery_audit/missing_evidence_plan.md`<br>`evidence/board_probe/jtag_recovery_checklist/summary.md`<br>`evidence/board_probe/jtag_precondition_current/summary.md`<br>`evidence/board_reports/jtag_true2x2_stagehash_baseline_rerun_20260703_goal_continue/analysis.md`<br>`evidence/board_reports/jtag_true2x2_dbg2_src_boundary_20260703_goal_continue/analysis.md`<br>`evidence/board_reports/jtag_true2x2_dbg3_single_boundary_20260703/analysis.md`<br>`evidence/board_reports/jtag_true2x2_dbg5_countview_20260703/analysis.md`<br>`evidence/board_reports/jtag_true2x2_dbg6_c1c2_detail_20260703/analysis.md` | 当前 full precondition 为 READY：USB known JTAG candidate=3，Vivado target=1；stagehash baseline 和 dbg3/single-boundary 均已完成 clean board mismatch 复跑：输出完整 `192/192`、`frame_done=1`、`error=0`，但 compare 仍 FAIL。dbg3 中 `src_feat0_hash` 已与 RTL 匹配，首个已知 mismatch 为 `src_b1_hash`；dbg5/count-view 显示 block1 仅 C1 有部分计数，C2/C3/attention 为 0；dbg6 已接出 C1/C2 detail bank 且 true2x2 RTL raw compare 仍为 0 mismatch；下一步应生成 dbg6 bitstream 并上板比对 bank6，不把 dbg2/source-b6 的 `error=0xC` run 作为根因证据。 |
| 评分点 面积/功耗 | 资源门限已过，真实功耗待板端报告 | `PARTIAL` | `evidence/ppa_summary/summary.md`<br>`evidence/board_reports/validation_readiness/summary.md` | OOC 资源/时序可报告；真实 board power、FPS、latency 需 `validation.md Status: PASS` 后才能声明。 |

## Remaining Final Evidence

- `evidence/board_reports/a5_32x32/validation.md`
- `evidence/board_reports/a6_64x64/validation.md`
- `evidence/board_reports/a7_720p_x4/validation.md`
- `evidence/board_reports/x2_720p/validation.md`

This matrix is a reviewer index. Final contest completion still depends on `contest_delivery_audit.md` reaching `PASS`.
