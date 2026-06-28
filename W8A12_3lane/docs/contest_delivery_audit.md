# 赛题交付审计入口

本文档用于解释当前交付审计口径。自动审计结果以
`evidence/delivery_audit/contest_delivery_audit.md` 和
`evidence/delivery_audit/contest_delivery_audit.json` 为准；本文只作为评审阅读入口，避免旧的 TODO 草稿与现有证据链混淆。

## 当前结论

截至当前证据，严格交付审计状态为 `INCOMPLETE`，通过 `69 / 73` 项。

已形成的可审计材料包括：

- AI 模型结构、REDS 全量训练/验证口径、x4/x2 PSNR 目标说明；
- W8A12 量化、x2 导出、fixed reference 和模型到 RTL manifest/常量转换工具；
- 三路并行硬件架构、bank 映射、A4 scheduler、top shell、失败回退和上板报告流程文档；
- A0-A4 分层 RTL 仿真、top shell 仿真、OOC 综合和 XC7Z045/ZC706 等效资源门限报告；
- 传统插值 baseline 对比、PPA 汇总、赛题 Markdown/PDF 报告、提交包清单和证据矩阵；
- JTAG recovery checklist、board validation readiness 和 stage-hash 上板定位流程。

仍缺的 4 项均为真实板端 validation：

```text
a5.board_32x32
a6.board_64x64
a7.board_720p_x4
x2.board
```

这些项目必须生成对应的 `validation.md Status: PASS` 后，才能把交付状态从阶段性/相当报告提升为最终赛题交付。

## 交付物映射

| 赛题交付要求 | 当前状态 | 权威证据 |
| --- | --- | --- |
| AI 模型结构、训练、量化说明和源代码 | PARTIAL/PASS，板端 fixed/board 结果待补 | `docs/python_reference_plan.md`、`docs/x2_w8a12_export_plan.md`、`tools/w8a12_3lane_reference.py`、`evidence/x2/reference_validation/validation.md` |
| 模型到硬件加速器指令/常量转换工具 | PASS | `scripts/export_x2_w8a12_to_rtl.ps1`、`tools/check_x2_w8a12_export.py`、`rtl/generated/reds_span_x2_f48_w8a12/` |
| 硬件加速器详细设计文档 | PASS | `docs/w8a12_3lane_architecture.md`、`docs/bank_mapping_rules.md`、`docs/a4_scheduler_acceptance_flow.md`、`docs/board_report_flow.md` |
| 硬件加速器源代码、仿真和综合 | PASS for offline/OOC; board validation pending | `rtl/`、`evidence/reference/`、`evidence/resource/`、`evidence/top/`、`evidence/ppa_summary/summary.md` |
| 实际板端 32x32/64x64/720p 输出、FPS、功耗和画质 | MISSING | `evidence/board_reports/a5_32x32/validation.md`、`a6_64x64/validation.md`、`a7_720p_x4/validation.md`、`x2_720p/validation.md` |

## 评审点映射

| 评审点 | 当前可证明内容 | 剩余缺口 |
| --- | --- | --- |
| 功能实现精准无误 | Python fixed reference、A0-A4 RTL 分层验证、top shell、x2 fixed reference | 真实板端 board-vs-fixed bit-exact validation |
| 文档清晰、模块划分合理 | 架构、量化、bank、scheduler、回退、上板流程、PDF 报告均已建立 | 最终板端报告补齐后需要同步刷新 |
| 模块内部量化指标及性能分析 | REDS 全量训练/验证指标、传统插值对比、OOC PPA 汇总 | board FPS、latency、power、720p PSNR/SSIM |
| 验证方案与验证用例 | A0-A4 分层门禁、提交包门禁、stage-hash 定位、JTAG recovery checklist | A5/A6/A7/x2 board validation |
| 面积和功耗 | XC7Z045/ZC706 等效 OOC 资源门限已过 | 真实板端功耗和完整集成资源报告 |

## 当前板端状态

RTL true 2x2 raw compare 已达到 `0/192 mismatch`。历史最好板端 true 2x2 baseline 为 `153/192` byte mismatch、`max diff=4`、`PSNR=44.0265 dB`；`dbgprogress` 版本能完整输出 `192/192` 且 `frame_done=1`，但退化为 `189/192` mismatch，writeback hash 与 RTL 期望不一致。

当前 JTAG recovery preflight 状态为 `BLOCKED`：

- USB match count = `3`；
- USB known JTAG candidate count = `0`；
- 常规 preflight 的 Vivado target count = `not_checked`，因为 USB 侧没有在线的已知 Xilinx/FTDI JTAG 设备，按流程未进入 Vivado 扫描；
- 强制 Vivado probe 后 Vivado target count = `0`，对应证据为 `evidence/board_probe/recovery_preflight_force_vivado_current/board_recovery_preflight_summary.md`；
- 历史 FTDI `VID_0403&PID_6010` 仍在 PnP history，但当前状态为 `Unknown`。

恢复条件是 USB known candidate `>= 1` 且 Vivado target `>= 1`。恢复后首个动作应运行 stage-hash true2x2 acceptance，读取 `tail_b1_hash`、`tail_b6_act1_hash`、`tail_rgb_q_hash` 和 `writeback_hash`，把 mismatch 定位到 front/SPAB、tail/RGB、writer 或 endpoint/readback。

## 复核命令

```powershell
python W8A12_3lane\tools\audit_contest_delivery.py
python W8A12_3lane\tools\generate_missing_evidence_plan.py
python W8A12_3lane\tools\generate_delivery_evidence_matrix.py
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -SkipVivado -SkipX2 -ContinueOnError
```

JTAG 恢复后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance
```
