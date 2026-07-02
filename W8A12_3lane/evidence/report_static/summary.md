# Contest Submission Report Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:contest_submission_report` | PASS | `W8A12_3lane/docs/contest_submission_report.md` |
| `has_title` | PASS | `report title` |
| `has_required_sections` | PASS | `['## 1. 摘要', '## 2. 赛题目标对应关系', '## 3. 数据集和训练验证口径', '## 4. 模型结构', '## 5. W8A12 量化与硬件转换', '## 6. 三路并行硬件架构', '## 7. RTL 仿真验证', '## 8. 综合资源与 PPA', '## 9. 画质指标与传统插值对比', '## 10. 板端状态和 mismatch 风险', '## 11. 最新实板定位', '## 12. 当前交付审计状态', '## 13. 可复现实验命令', '## 14. 交付文件索引', '## 15. 结论']` |
| `states_full_reds_train_val` | PASS | `full train/val dataset scope` |
| `states_model_and_quantization` | PASS | `model and W8A12 quantization` |
| `states_3lane_architecture` | PASS | `3-lane architecture` |
| `states_quality_targets_and_results` | PASS | `quality comparison values` |
| `states_ppa_summary_and_limits` | PASS | `PPA evidence and XC7Z045 limits` |
| `states_x4_720p15_fps_closure` | PASS | `x4 720p15 scheduler-level FPS closure and x2 boundary` |
| `states_x2_720p4_fps_closure` | PASS | `x2 lowered-target 720p4 scheduler-level FPS closure and x2 20fps boundary` |
| `states_contest_scope_readiness_gate` | PASS | `contest-scope readiness is separated from strict board-validation audit` |
| `states_rtl_evidence_hashes` | PASS | `RTL/fixed reference hashes` |
| `states_board_pending_not_measured` | PASS | `board metrics remain pending` |
| `states_mismatch_risk` | PASS | `mismatch and debug hash plan` |
| `states_audit_remaining_gates` | PASS | `audit count and remaining board gates` |
| `states_quality_metric_completion_plan` | PASS | `quality metric completion plan` |
| `states_pdf_export` | PASS | `PDF report export evidence` |
| `links_repro_commands` | PASS | `reproducible commands` |
| `lists_submission_archive_summary` | PASS | `submission archive summary evidence` |
| `lists_latest_board_and_upload_evidence` | PASS | `latest board progress and GitHub draft upload evidence` |
