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
| 最终提交指南 | `docs/final_submission_guide.md` |
| 赛题要求追踪矩阵 | `docs/contest_requirement_traceability.md` |

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
| packed 2-D x4 720p15 scheduler | `rtl/span/w8a12_packed2d_perf_scheduler.v`、`tools/check_x4_720p15_fps_closure.py` | scheduler-level FPS closure PASS；`24x64` 为最低资源点 15.070fps/792 DSP，`24x72` 为推荐闭合点 17.501fps/888 DSP、15fps 余量 14.291%；证据 `evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.md` |
| packed 2-D x2 720p4 scheduler | `rtl/span/w8a12_packed2d_perf_scheduler.v`、`tools/check_x2_720p4_fps_closure.py` | 降目标 scheduler-level FPS closure PASS；`24x72` 为推荐闭合点 4.483fps/888 DSP、4fps 余量 10.789%；`24x64` 为 3.861fps 低资源边界但不达 4fps；证据 `evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.md` |
| packed 2-D x2 720p20 scheduler | `rtl/span/w8a12_packed2d_perf_scheduler.v`、`sim/tb_w8a12_packed2d_x2_720p20_perf_scheduler.sv` | scheduler-level xsim 已补充；900-DSP 门限下 20fps FAIL，证据 `evidence/sim_fps_design_space/packed2d_x2_720p20_perf_scheduler/summary.md` |
| packed 2-D x2 direct xsim replay | `scripts/wait_and_run_x2_direct_xsim.ps1`、`scripts/run_xsim_direct_w8a12_packed2d_x2_720p20_perf_scheduler.ps1` | wrapper 先等待空闲内存和仿真进程安全条件，再由 direct 脚本直接调用 `xvlog/xelab/xsim` 复跑同一 scheduler testbench；复跑结果与 Vivado batch summary 一致，证据 `evidence/sim_fps_design_space/packed2d_x2_direct_xsim_replay/summary.md` |

## 4. 上板和 PPA 汇报

| 内容 | 文件/工具 | 当前状态 |
| --- | --- | --- |
| board report 模板 | `tools/create_board_report.py` | 已提供 |
| board report 填报 | `tools/update_board_report.py` | 已提供 |
| board report 自动定稿 | `tools/finalize_board_report_from_outputs.py` | 已提供；从真实 board output 和 fixed reference 自动计算 mismatch/bit-exact/PSNR，并调用 validation；缺少真实资源/时序/性能/文件证据时不会 PASS |
| board report 批量定稿 | `tools/finalize_board_reports_from_manifest.py`、`scripts/finalize_board_reports_from_manifest.ps1`、`evidence/board_reports/validation_closure/manifest_template.json` | 已提供；恢复上板后可用一个 manifest 批量生成 4 个 `validation.md`，未替换 placeholder 时保持 BLOCKED/FAIL |
| board report 校验 | `tools/validate_board_report.py` | 已提供 |
| Vivado JTAG probe 验收 | `tools/check_vivado_hw_probe_log.py` | 已提供，重插后 PASS |
| Vivado JTAG probe 历史证据 | `evidence/board_probe/vivado_hw_probe.md` | 历史 PASS，target count=1、device count=2；当前连接态以后续 precondition/probe 为准 |
| JTAG 当前前置条件 | `evidence/board_probe/jtag_precondition_current/summary.md`、`evidence/board_probe/jtag_precondition_usb_only_current/summary.md` | 2026-07-03 USB-only 复测为 USB_READY：USB known JTAG candidate=3，Vivado target 未检查；历史 READY 记录只作为成功上板过程证据 |
| W8A12 board recovery preflight | `scripts/run_w8a12_board_recovery_preflight.ps1`、`W8A12_3lane/scripts/run_w8a12_board_recovery_preflight.ps1`、`board_runs/w8a12_board_recovery_preflight/dbg2_src_boundary_current/board_recovery_preflight_summary.md` | 已提供；新增 `-SkipVivadoProbe` 可在后台 Vivado 运行时只刷新 USB-only 证据，不触发 Vivado cleanup。当前 USB 已可见，下一步等现有 Vivado 任务结束后运行 Vivado target probe |
| 最新上板续跑进展 | `evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md` | 2026-06-29 stage-hash 实板续跑：JTAG/PSU/register read PASS，2x2 输出完整 `192/192`，compare FAIL `191/192`，最早失败边界为 `tail_b1_hash` |
| JTAG debug-bank 细粒度定位 | `evidence/board_reports/jtag_true2x2_debugbank_20260629.md`、`rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v`、`scripts/read_jtag_w8a12_tile_writer_regs.tcl` | RTL PASS；在 6-bit JTAG AXI-Lite 下通过 `REG_PERF_CTRL[15:8]` 暴露 bank 1/2，读取 `tail_feat0/src_feat0/src_b1/spab_b1_input/c1/c2/c3/residual/att`；同一 true2x2 输入/参考 raw compare 仍 `0/192` |
| JTAG 物理恢复清单 | `docs/jtag_recovery_checklist.md`、`tools/generate_jtag_recovery_checklist.py`、`evidence/board_probe/jtag_recovery_checklist/summary.md`、`evidence/board_probe/jtag_recovery_checklist_usb_only_current/summary.md` | 历史 BLOCKED/READY 清单保留；最新 USB-only precondition 为 USB_READY，但严格上板仍需 Vivado target count >= 1 |
| board validation readiness | `evidence/board_reports/validation_readiness/summary.md` | PASS；4 个剩余上板报告 skeleton 已预建，尺寸/PSNR/FPS/命令链已检查，但仍需真实 `validation.md Status: PASS` |
| board report flow static | `evidence/board_reports/flow_static/summary.md` | PASS |
| xsim 日志汇总 | `tools/summarize_xsim_result.py` | 已提供 |
| OOC 资源/时序汇总 | `tools/summarize_ooc_result.py` | 已提供，自包含解析器 |
| OOC 解析器自检 | `evidence/resource/A4_ooc_parser_selfcheck/summary.md` | PASS |
| PPA 汇总报告 | `tools/generate_ppa_summary.py`、`evidence/ppa_summary/summary.md` | PASS，汇总 MAC core、single-lane、3-lane scheduler 和 top shell |
| bitstream/PPA 门槛 | `evidence/bitstream_ppa_gate/summary.md` | PASS_WITH_SCOPE；true2x2/JTAG-W8A12 bitstream 已生成，implementation 为 LUT 38803、FF 116441、BRAM 311、DSP 128、WNS 12.517ns、WHS 0.010ns；不声明 720p packed 2-D 完整 bitstream |
| 赛题提交口径门禁 | `tools/check_contest_scope_readiness.py`、`evidence/contest_scope_readiness/summary.md` | PASS_WITH_SCOPE 时表示报告/RTL 仿真/PPA/FPS scheduler/质量对比/GitHub 上传前检查已具备可追溯证据，真实板端 validation 作为后续工程项单独列出 |
| 赛题口径提交包 | `tools/create_contest_scope_package.py`、`evidence/contest_scope_package/summary.md` | PASS_WITH_SCOPE；复用 submission manifest 文件列表生成无真实插板硬门槛口径的确定性提交包 |
| 赛题报告完整性检查 | `tools/check_contest_submission_report_static.py`、`evidence/report_static/summary.md` | PASS，检查章节、证据、PPA、画质、评分点映射和待上板口径 |
| PDF 赛题报告 | `output/pdf/W8A12_3lane_contest_submission_report.pdf`、`evidence/report_pdf/summary.md` | PASS，7 页，已渲染 PNG 并完成非空/关键文本校验 |
| Word 赛题报告 | `output/docx/W8A12_3lane_contest_submission_report.docx`、`evidence/report_docx/summary.md` | PASS，已生成 DOCX，并完成可见文本黑色字体审计 |
| 评审证据矩阵 | `tools/generate_delivery_evidence_matrix.py`、`evidence/delivery_matrix/summary.md` | PASS，按赛题交付物和评分点索引模型、文档、RTL、PPA、画质、上板缺口 |
| Word 完整导出版 | `output/docx/W8A12_3lane_contest_submission_report_complete_20260701.docx`、`evidence/report_docx_complete_20260701/summary.md` | PASS，标准 Word 文件被占用时使用；字体颜色审计 PASS，DOCX PNG 渲染因本机无 LibreOffice 跳过，PDF 渲染检查 PASS |
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
| JTAG-W8A12 true2x2 stage-hash | `evidence/board_reports/jtag_true2x2_stagehash_20260628.md`、`evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md` | RTL raw compare PASS；Default stage-hash bitstream 已生成且 timing PASS；2026-06-29 已上板读取，`tail_b1/tail_b6_act1/tail_rgb_q/writeback` 均与 RTL 期望不一致，最早失败边界为 `tail_b1_hash` |
| JTAG-W8A12 true2x2 debug-bank | `evidence/board_reports/jtag_true2x2_debugbank_20260629.md` | RTL raw compare PASS；all-in-one debugbank 上板曾 stall，不作为下一步首选 |
| JTAG-W8A12 dbg2 source-boundary 一键验收 | `scripts/run_w8a12_dbg2_source_boundary_acceptance.ps1`、`evidence/board_reports/jtag_true2x2_dbg2_src_boundary_prepare_20260629.md`、`evidence/board_reports/jtag_true2x2_dbg2_src_boundary_current/summary.md` | 已提供；RTL raw compare PASS、bitstream/timing/resource PASS。当前 USB-only 结果为 USB known JTAG candidate=3，但 Vivado target 尚未安全复测；target count >=1 后会自动进入 dbg2 上板验收 |
| 交付审计 | `evidence/delivery_audit/contest_delivery_audit.md` | INCOMPLETE |
| 缺口执行计划 | `evidence/delivery_audit/missing_evidence_plan.md` | 已生成 |
| 硬门禁执行队列 | `evidence/delivery_audit/hard_gate_execution_queue.md` | 17 项，PASS 队列 |
| 硬门禁队列 runner | `scripts/run_hard_gate_queue.ps1` | 支持 `-OnlyCategory`、`-StartAt`、`-DryRun` |
| 缺口计划生成器静态检查 | `evidence/delivery_audit/missing_plan_flow_static/summary.md` | PASS |
| 交付审计定义静态检查 | `evidence/delivery_audit/audit_flow_static/summary.md` | PASS |
| 提交包 manifest | `evidence/submission_package/submission_manifest.md` | 上传前生成 |
| 严格上板提交包归档 | `evidence/submission_package/archive/summary.md` | 当前为 `INCOMPLETE` 草案 zip，缺口仍为 4 个真实上板 validation |
| 提交包 manifest 静态检查 | `evidence/submission_package/flow_static/summary.md` | PASS |
| GitHub 上传前置检查 | `tools/check_github_upload_preflight.py`、`evidence/github_upload_preflight/summary.md` | PASS；已配置 `w8a12=https://github.com/robot-berry/W8A12.git`，上传前仍只允许 stage `W8A12_3lane/` |
| GitHub 干净上传树 | `tools/export_github_upload_tree.py`、`evidence/github_upload_export/summary.md` | PASS；导出到 `output/github_upload/robot-berry_W8A12_upload_tree/`，用于不携带当前大仓库历史地单独上传 |
| GitHub 草案分支上传 | `evidence/github_upload_push/summary.md` | PASS；已推送到 `robot-berry/W8A12` 的 `codex/w8a12-3lane-delivery-draft`，以远端分支级证据为准 |
| GitHub Draft PR 尝试 | `evidence/github_pr_attempt/summary.md` | BLOCKED；分支已上传，但 GitHub App 创建 PR 返回 403，需用手动 URL 创建 PR：`https://github.com/robot-berry/W8A12/pull/new/codex/w8a12-3lane-delivery-draft` |
| 交付 manifest | `evidence/delivery_manifest/manifest.md` | 上传前生成 |
| 一键门禁运行记录 | `evidence/delivery_runs/current_static_boardtarget0_20260628_p/summary.md` | `-SkipVivado -SkipX2 -ContinueOnError` 轻量门禁已运行；静态项、JTAG recovery checklist、contest_report_pdf、delivery_evidence_matrix、board recovery preflight/JTAG precondition flow、board validation readiness、`submission_archive`、`submission_archive_final` 和 `hard_gate_runner_static` PASS，最终 `submission_manifest` / `delivery_audit` 因真实板端 validation 缺失保持 FAIL |

## 5. 当前硬缺口

交付完成前必须补齐：

1. A5 x4 32x32 board `validation.md Status: PASS`。
2. A6 x4 64x64 board `validation.md Status: PASS`。
3. A7 720p x4 board `validation.md Status: PASS`。
4. x2 720p board `validation.md Status: PASS`。

当前严格审计为 `72 / 76`，新增赛题报告、PDF/Word 报告导出、PPA 汇总、报告完整性检查、画质指标闭环门禁、stage-hash 上板流程静态检查、JTAG recovery checklist、board validation readiness、submission manifest/archive 和 evidence matrix 均已形成，剩余 4 项均为真实板端 validation。历史 true2x2 stage-hash 上板曾恢复 JTAG/PSU/register read，并完整输出 `192/192` 且 `frame_done=1`、`error=0`，但 compare FAIL：`191/192` mismatch，PSNR `11.8292 dB`，最早失败边界为 `tail_b1_hash`。当前最新前置状态为 USB-only `USB_READY`：USB known JTAG candidate count=3，Vivado target 尚未在后台实现任务结束后安全复测；这不推翻历史数值定位。恢复 Vivado target probe 后直接运行 dbg2 一键脚本，继续在 `halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> b1_m_feat -> tail` 链路内收窄第一个错误点。

已补充并已通过审计的离线证据：

- Accelerator top xsim/OOC：`evidence/top/accel_top_sim/summary.md`、`evidence/top/accel_top_ooc/ooc_summary.md`。
- A4 scheduler xsim/OOC：`evidence/resource/A4_single_lane_mac_scheduler/`、`evidence/resource/A4_3lane_mac_scheduler/`、`evidence/resource/A4_single_lane_mac_scheduler_ooc/`、`evidence/resource/A4_3lane_mac_scheduler_ooc/`。
- bitstream/PPA gate：`evidence/bitstream_ppa_gate/summary.md`，用于“无需真实上板，只看 bitstream + 仿真 + PPA”的赛题评审口径。
- 赛题提交口径门禁：`evidence/contest_scope_readiness/summary.md`，将报告/PPA 可提交范围和严格 board-validation 缺口分开，避免把 4 个真实上板 validation 后续项误判为无插板评审口径下的阻断项。
- 赛题口径提交包：`evidence/contest_scope_package/summary.md`，生成 `PASS_WITH_SCOPE` 的确定性包摘要；严格上板归档仍保留 `INCOMPLETE` 风险说明。
- packed 2-D scheduler 性能边界：x4 720p15 scheduler-level closure PASS，推荐配置为 `24x72`、17.501fps @250MHz、888 DSP，最低资源配置为 `24x64`、15.070fps、792 DSP；x2 降目标 720p4 scheduler-level closure PASS，推荐配置为 `24x72`、4.483fps @250MHz、888 DSP，`24x64` 仅为 3.861fps 低资源边界；x2 720p20 scheduler-level 已补充但 900-DSP 门限下 FAIL，且新增 direct `xvlog/xelab/xsim` 复跑证据避免后台实现任务期间再启动 Vivado batch。证据 `evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.md`、`evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.md`、`evidence/sim_fps_design_space/packed2d_perf_scheduler/summary.md`、`evidence/sim_fps_design_space/packed2d_x2_720p20_perf_scheduler/summary.md`、`evidence/sim_fps_design_space/packed2d_x2_direct_xsim_replay/summary.md`。
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
