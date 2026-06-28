# W8A12_3lane 交付索引

本文档作为上传到 `robot-berry/W8A12` 前的交付入口，按赛题要求索引模型、量化、转换工具、硬件设计、仿真综合和上板证据。

## 1. 模型结构、训练、量化和转换工具

| 内容 | 文件/目录 | 当前状态 |
| --- | --- | --- |
| 训练/验证集、checkpoint、PSNR 口径 | `docs/python_reference_plan.md` | 已记录 x4/x2 REDS 口径和训练证据 |
| x4 W8A12 Python reference | `tools/w8a12_3lane_reference.py` | A0-A3 已生成 evidence |
| x2 W8A12 fixed reference 契约 | `docs/x2_fixed_reference_contract.md` | READY，x2 W8A12 导出和 fixed reference 已生成 |
| x2 readiness | `evidence/x2/reference_readiness/readiness.md` | READY |
| x2 asset search | `evidence/x2/asset_search/x2_asset_search.md` | READY |
| x2 W8A12 export plan | `docs/x2_w8a12_export_plan.md`、`scripts/export_x2_w8a12_to_rtl.ps1` | 已执行，`evidence/x2/w8a12_export/summary.md` PASS |
| x2 W8A12 export cmd fallback | `scripts/export_x2_w8a12_to_rtl.cmd` | 已提供 |
| x2 W8A12 export check | `tools/check_x2_w8a12_export.py` | 已提供 |
| x2 fixed reference validation | `tools/check_x2_fixed_reference.py` | `evidence/x2/reference_validation/validation.md` PASS |
| x2 flow static | `evidence/x2/flow_static/summary.md` | PASS |
| 模型到 RTL 常量/manifest | `evidence/reference/*/lane_mems/`、`rtl/generated/reds_span_x2_f48_w8a12/` | x4 分层可复用；x2 W8A12 manifest/quant plan/postprocess 已生成 |
| 传统插值 baseline 对比 | `docs/interpolation_baseline_flow.md`、`tools/evaluate_interpolation_baseline.py` | x4/x2 REDS_val 全量 baseline 已生成 |
| 质量对比汇总报告 | `tools/generate_quality_comparison_report.py`、`evidence/quality_comparison/summary.md` | PASS |
| 画质指标闭环计划 | `docs/quality_metric_completion_plan.md`、`tools/check_quality_metric_completion_static.py`、`evidence/quality_metric_completion/summary.md` | PASS，明确 FP32、W8A12 fixed、RTL、board 指标分层和待补项 |

## 2. 硬件加速器设计文档

| 内容 | 文件 |
| --- | --- |
| 三路并行总体架构 | `docs/w8a12_3lane_architecture.md` |
| 板端顶层控制/status shell | `docs/accelerator_top_shell.md` |
| lane / feature bank / weight bank 映射 | `docs/bank_mapping_rules.md` |
| A2/A3 tile pipeline 控制契约 | `docs/a2_a3_tile_scheduler_contract.md` |
| A4 scheduler 验收流程 | `docs/a4_scheduler_acceptance_flow.md` |
| 一键门禁执行脚本 | `docs/delivery_gate_runner.md` |
| 分层 reference 流程 | `docs/layered_reference_flow.md` |
| 失败回退流程 | `docs/failure_rollback_flow.md` |
| 上板汇报流程 | `docs/board_report_flow.md` |
| 传统插值 baseline 对比流程 | `docs/interpolation_baseline_flow.md` |
| 赛题交付审计 | `docs/contest_delivery_audit.md` |
| 可提交赛题技术报告 | `docs/contest_submission_report.md` |
| 赛题提交说明 | `docs/contest_submission_readme.md` |

## 3. RTL / 仿真 / 综合源代码

| 阶段 | 关键文件 | 当前证据 |
| --- | --- | --- |
| A0 3-lane conv | `rtl/span/w8a12_3lane_conv_layer.v` | `evidence/reference/A0_single_conv/a0_rtl_sim_summary.md` |
| A1 single SPAB | A1 generated TB / 3-lane conv wrapper | `evidence/reference/A1_single_block/a1_rtl_sim_summary.md` |
| A2 six blocks | generated six-block TB | `evidence/reference/A2_six_blocks/a2_rtl_sim_summary.md` |
| A2/A3 tile shell | `rtl/span/w8a12_3lane_tile_pipeline_shell.v` | `evidence/reference/A2_tile_pipeline_shell/tile_pipeline_shell_static_check.md` |
| 板端 accelerator top shell | `rtl/top/w8a12_3lane_accel_top.v` | `evidence/top/accel_top_sim/summary.md` 和 `evidence/top/accel_top_ooc/ooc_summary.md` PASS |
| A3 tail/RGB | generated tail frame TB | `evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md` |
| A4 MAC core | `rtl/span/w8a12_lane_mac_core.v` | `evidence/resource/A4_lane_mac_core_ooc/mac_core_ooc_summary.md` |
| A4 single-output scheduler | `rtl/span/w8a12_single_out_mac_scheduler.v` | `evidence/resource/A4_single_out_mac_scheduler/single_out_scheduler_sim_summary.md` |
| A4 single-lane scheduler | `rtl/span/w8a12_single_lane_mac_scheduler.v` | xsim PASS；OOC PASS，LUT 41003、FF 85414、DSP 224、WNS 1.261ns |
| A4 3-lane scheduler | `rtl/span/w8a12_3lane_mac_scheduler.v` | xsim PASS；OOC PASS，LUT 123182、FF 256222、DSP 672、WNS 1.188ns |

## 4. 上板和 PPA 汇报

| 内容 | 文件/工具 | 当前状态 |
| --- | --- | --- |
| board report 模板 | `tools/create_board_report.py` | 已提供 |
| board report 填报 | `tools/update_board_report.py` | 已提供 |
| board report 校验 | `tools/validate_board_report.py` | 已提供 |
| Vivado JTAG probe 验收 | `tools/check_vivado_hw_probe_log.py` | 已提供，重插后 PASS |
| Vivado JTAG probe 历史证据 | `evidence/board_probe/vivado_hw_probe.md` | 历史 PASS，target count=1、device count=2；当前连接态以后续 precondition/probe 为准 |
| JTAG 当前前置条件 | `evidence/board_probe/jtag_precondition_current/summary.md` | BLOCKED：USB known candidate=0，Vivado target count=not_checked；因 USB 侧没有在线已知 JTAG 设备，按流程未进入 Vivado probe，需恢复 JTAG 后才能继续上板 validation |
| W8A12 board recovery preflight | `scripts/run_w8a12_board_recovery_preflight.ps1`、`W8A12_3lane/scripts/run_w8a12_board_recovery_preflight.ps1`、`evidence/board_probe/recovery_preflight_current/board_recovery_preflight_summary.md`、`evidence/board_probe/recovery_preflight_force_vivado_current/board_recovery_preflight_summary.md` | 已提供；常规 preflight 在 USB known candidate=0 时跳过 Vivado probe；强制 Vivado probe 也已跑，结果为 USB known candidate=0、Vivado target count=0；恢复后可选 `-RunStageHashAcceptance` 直接进入 stage-hash 验收 |
| 最新上板续跑进展 | `evidence/board_probe/latest_board_progress_20260628.md` | 2026-06-28 续跑强制 Vivado probe：USB known candidate=0、Vivado target count=0；未进入 bitstream/program/readback；true2x2 RTL/stage-hash bitstream 仍是当前待上板基线 |
| JTAG 物理恢复清单 | `docs/jtag_recovery_checklist.md`、`tools/generate_jtag_recovery_checklist.py`、`evidence/board_probe/jtag_recovery_checklist/summary.md` | BLOCKED；当前在线 USB 设备无已知 JTAG，历史 FTDI `VID_0403&PID_6010` 为 Unknown，恢复通过条件为 USB known candidate>=1 且 Vivado target>=1 |
| board validation readiness | `evidence/board_reports/validation_readiness/summary.md` | PASS；4 个剩余上板报告 skeleton 已预建，尺寸/PSNR/FPS/命令链已检查，但仍需真实 `validation.md Status: PASS` |
| board report flow static | `evidence/board_reports/flow_static/summary.md` | PASS |
| xsim 日志汇总 | `tools/summarize_xsim_result.py` | 已提供 |
| OOC 资源/时序汇总 | `tools/summarize_ooc_result.py` | 已提供，自包含解析器 |
| OOC 解析器自检 | `evidence/resource/A4_ooc_parser_selfcheck/summary.md` | PASS |
| PPA 汇总报告 | `tools/generate_ppa_summary.py`、`evidence/ppa_summary/summary.md` | PASS，汇总 MAC core、single-lane、3-lane scheduler 和 top shell |
| 赛题报告完整性检查 | `tools/check_contest_submission_report_static.py`、`evidence/report_static/summary.md` | PASS，检查章节、证据、PPA、画质和待上板口径 |
| PDF 赛题报告 | `output/pdf/W8A12_3lane_contest_submission_report.pdf`、`evidence/report_pdf/summary.md` | PASS，7 页，已渲染 PNG 并完成非空/关键文本校验 |
| 评审证据矩阵 | `tools/generate_delivery_evidence_matrix.py`、`evidence/delivery_matrix/summary.md` | PASS，按赛题交付物和评分点索引模型、文档、RTL、PPA、画质、上板缺口 |
| 最新上板报告 | `evidence/board_reports/` | 尚无 PASS |
| true 2x2 上板结果 | `evidence/board_reports/2x2_samplelatch_result_20260626.md` | 仿真/bitstream PASS，板端控制访问 FAIL |
| true 2x2 参数配置审计 | `evidence/board_reports/2x2_board_config_audit_20260626.md` | PS/DDR/AXI 参数与 32x32 已跑通例程一致 |
| 最小 AXI-Lite register-only 隔离 | `evidence/board_reports/ps_axi_lite_register_probe_20260627.md` | bitstream/烧录 PASS，板端 PS/JTAG/XSCT 访问 FAIL |
| JTAG-W8A12 参数配置审计 | `evidence/board_reports/jtag_w8a12_config_audit_20260627.md` | JTAG register probe PASS，JTAG-W8A12 true2x2 与例程参数对齐，等待 route/bitstream 后上板读图 |
| JTAG-W8A12 true2x2 上板 smoke | `scripts/run_jtag_w8a12_tile_writer_smoke.ps1` | 已提供；等待 JTAG-W8A12 true2x2 bitstream 后执行 |
| JTAG-W8A12 stage-hash 一键验收 | `scripts/run_w8a12_stagehash_true2x2_acceptance.ps1`、`W8A12_3lane/scripts/run_w8a12_stagehash_true2x2_acceptance.ps1` | 已提供；串联 target probe、PS init、2x2 smoke 和 stage hash 读数；历史 wrapper 停在 `VIVADO_HW_TARGET_COUNT=0`，当前状态以 `jtag_precondition_current` 为准 |
| 重插后 JTAG 排查 | `evidence/board_reports/jtag_after_replug_20260628.md` | target 已恢复；未做 PS init 时 `get_hw_axis` 为空 |
| PS init 后 JTAG/W8A12 排查 | `evidence/board_reports/jtag_after_psuinit_20260628.md` | 最小 JTAG-to-AXI probe PASS；W8A12 debugregs 可见 `hw_axi_1`，但 true2x2 输入后无输出；已新增 `0x04/0x08/0x10` progress 读数，RTL raw compare 仍 PASS |
| JTAG-W8A12 true2x2 debug-progress | `evidence/board_reports/jtag_true2x2_dbgprogress_20260628.md` | bitstream/timing PASS；上板完整输出 `192/192`、`frame_done=1`，但 compare FAIL：`189/192` mismatch，writeback hash 不等于 RTL |
| JTAG-W8A12 true2x2 stage-hash | `evidence/board_reports/jtag_true2x2_stagehash_20260628.md` | RTL raw compare PASS，新增 `tail_b1/tail_b6_act1/tail_rgb_q/writeback` 期望 hash；Default bitstream 已生成且 timing PASS；最新续跑 probe `board_runs/vivado_hw_target_probe_goal_continue_20260628_b` 仍为 JTAG target=0，待恢复连接后上板读取 |
| 交付审计 | `evidence/delivery_audit/contest_delivery_audit.md` | INCOMPLETE |
| 缺口执行计划 | `evidence/delivery_audit/missing_evidence_plan.md` | 已生成 |
| 硬门禁执行队列 | `evidence/delivery_audit/hard_gate_execution_queue.md` | 17 项，PASS 队列 |
| 硬门禁队列 runner | `scripts/run_hard_gate_queue.ps1` | 支持 `-OnlyCategory`、`-StartAt`、`-DryRun` |
| 缺口计划生成器静态检查 | `evidence/delivery_audit/missing_plan_flow_static/summary.md` | PASS |
| 交付审计定义静态检查 | `evidence/delivery_audit/audit_flow_static/summary.md` | PASS |
| 提交包 manifest | `evidence/submission_package/submission_manifest.md` | 上传前生成 |
| 提交包确定性归档 | `evidence/submission_package/archive/summary.md` | PASS；当前为 `INCOMPLETE` 草案 zip，缺口仍为 4 个真实上板 validation |
| 提交包 manifest 静态检查 | `evidence/submission_package/flow_static/summary.md` | PASS |
| GitHub 上传前置检查 | `tools/check_github_upload_preflight.py`、`evidence/github_upload_preflight/summary.md` | PASS；已配置 `w8a12=https://github.com/robot-berry/W8A12.git`，上传前仍只允许 stage `W8A12_3lane/` |
| GitHub 干净上传树 | `tools/export_github_upload_tree.py`、`evidence/github_upload_export/summary.md` | PASS；导出到 `output/github_upload/robot-berry_W8A12_upload_tree/`，用于不携带当前大仓库历史地单独上传 |
| GitHub 草案分支上传 | `evidence/github_upload_push/summary.md` | PASS；已推送到 `robot-berry/W8A12` 的 `codex/w8a12-3lane-delivery-draft`，commit `1ddc9657bc586db2d87be06f1545f113b18c9b2d` |
| 交付 manifest | `evidence/delivery_manifest/manifest.md` | 上传前生成 |
| 一键门禁运行记录 | `evidence/delivery_runs/current_static_boardtarget0_20260628_p/summary.md` | `-SkipVivado -SkipX2 -ContinueOnError` 轻量门禁已运行；静态项、JTAG recovery checklist、contest_report_pdf、delivery_evidence_matrix、board recovery preflight/JTAG precondition flow、board validation readiness、`submission_archive`、`submission_archive_final` 和 `hard_gate_runner_static` PASS，最终 `submission_manifest` / `delivery_audit` 因真实板端 validation 缺失保持 FAIL |

## 5. 当前硬缺口

交付完成前必须补齐：

1. A5 x4 32x32 board `validation.md Status: PASS`。
2. A6 x4 64x64 board `validation.md Status: PASS`。
3. A7 720p x4 board `validation.md Status: PASS`。
4. x2 720p board `validation.md Status: PASS`。

当前严格审计为 `69 / 73`，新增赛题报告、PDF 报告导出、PPA 汇总、报告完整性检查、画质指标闭环门禁、stage-hash 上板流程静态检查、JTAG recovery checklist 和 board validation readiness 已通过，剩余 4 项均为真实板端 validation。重插后 USB/JTAG 与 Vivado target 曾恢复：`board_runs/vivado_hw_target_probe_after_replug_20260628` 显示 target count=1、device count=2。补跑对应 `psu_init.tcl` 后，最小 JTAG-to-AXI register probe 已恢复 PASS，W8A12 debugregs bitstream 也能暴露 `hw_axi_1`。最新 `dbgprogress` bitstream 已越过 `counter_out=0`，上板完整输出 `192/192` 且 `frame_done=1`，但 compare FAIL：`189/192` mismatch，writeback hash `0xAD24396D != 0x61D3EA1D`。stage-hash Default bitstream 已生成并 timing PASS；最新 recovery preflight 仍为 `USB known JTAG candidate count=0`、`Vivado target count=not_checked`，当前在线 USB 列表无 Xilinx/FTDI known candidate，历史 FTDI `VID_0403&PID_6010` 为 Unknown，需要先恢复 JTAG target，再用已通过 RTL 的 stage-hash 映射定位差异位于 front/SPAB、tail/RGB、writer 还是 endpoint/readback。

已补充并已通过审计的离线证据：

- Accelerator top xsim/OOC：`evidence/top/accel_top_sim/summary.md`、`evidence/top/accel_top_ooc/ooc_summary.md`。
- A4 scheduler xsim/OOC：`evidence/resource/A4_single_lane_mac_scheduler/`、`evidence/resource/A4_3lane_mac_scheduler/`、`evidence/resource/A4_single_lane_mac_scheduler_ooc/`、`evidence/resource/A4_3lane_mac_scheduler_ooc/`。
- x2 W8A12 export/fixed reference：`evidence/x2/w8a12_export/summary.md`、`evidence/x2/reference/summary.md`、`evidence/x2/reference_validation/validation.md`。
- x4/x2 传统插值、质量对比和画质指标闭环计划：`evidence/quality_baseline/`、`evidence/quality_comparison/summary.md`、`evidence/quality_metric_completion/summary.md`。

以上缺口以 `evidence/delivery_audit/contest_delivery_audit.md` 为准。

每个缺口对应的下一步命令见：

```text
evidence/delivery_audit/missing_evidence_plan.md
evidence/delivery_audit/hard_gate_execution_queue.md
```

## 6. 上传前检查

```powershell
python W8A12_3lane\tools\check_a4_scheduler_vectors.py
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -ContinueOnError
python W8A12_3lane\tools\audit_contest_delivery.py
python W8A12_3lane\tools\generate_missing_evidence_plan.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete
python W8A12_3lane\tools\collect_delivery_manifest.py
```

上传计划见：

```text
docs/github_upload_plan.md
```
