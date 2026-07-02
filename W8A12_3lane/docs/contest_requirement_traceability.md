# 赛题要求追踪矩阵

日期：2026-07-03

本文档按赛题原始交付要求和评审要点逐项映射当前 `W8A12_3lane/` 的证据、可声明状态和剩余风险。它用于评审快速核对，不替代完整技术报告。

## 1. 交付内容追踪

| 赛题交付内容 | 当前材料 | 状态 | 说明 |
| --- | --- | --- | --- |
| AI 模型结构说明 | `docs/contest_submission_report.md`、`docs/python_reference_plan.md` | PASS_WITH_SCOPE | 采用 SPAN x4/F48 和 SPAN x2/F48；6 个 SPAB block，48 feature channels |
| 训练说明和源代码 | `external/SPAN/`、`docs/python_reference_plan.md`、训练记录证据 | PASS_WITH_SCOPE | 训练/验证口径写明 REDS train/val 官方全量；x4 FP32 PSNR 28.3118 dB，x2 FP32 PSNR 34.4297 dB |
| 量化说明 | `docs/contest_submission_report.md`、`runs/reds_span_quant_plan/`、`rtl/generated/` | PASS_WITH_SCOPE | W8A12：权重 INT8、激活 12-bit；x2 export/fixed reference 已通过 |
| 模型到硬件指令/常量转换工具 | `tools/w8a12_3lane_reference.py`、`scripts/export_x2_w8a12_to_rtl.ps1`、`tools/check_x2_w8a12_export.py` | PASS_WITH_SCOPE | 生成/检查 quant plan、RTL manifest、postprocess manifest、lane mems |
| 硬件加速器详细设计文档 | `docs/w8a12_3lane_architecture.md`、`docs/bank_mapping_rules.md`、`docs/a4_scheduler_acceptance_flow.md`、`docs/board_report_flow.md` | PASS_WITH_SCOPE | 3-lane output-channel 并行，6 个 SPAB block 串行推进，含 bank 映射、回退和上板报告流程 |
| 硬件源代码 | `rtl/span/`、`rtl/top/`、`rtl/generated/` | PASS_WITH_SCOPE | A0-A4/top shell、packed 2-D scheduler、generated W8A12 常量已纳入上传树 |
| Vivado 仿真验证 | `evidence/reference/`、`evidence/resource/`、`evidence/top/`、`evidence/sim_fps_design_space/` | PASS_WITH_SCOPE | A0/A1/A2/A3/A4/top shell 分层 xsim/OOC 证据齐全；x4/x2 FPS 为 scheduler/performance-model 级 |
| 综合/资源评估 | `evidence/ppa_summary/summary.md`、`evidence/bitstream_ppa_gate/summary.md` | PASS_WITH_SCOPE | 以 XC7Z045/ZC706 门限评估；A4 3-lane scheduler 672 DSP；true2x2 bitstream implementation timing/resource PASS |

## 2. 评审要点追踪

| 评审要点 | 当前可证明内容 | 状态 | 剩余风险 |
| --- | --- | --- | --- |
| 功能实现精准无误 | A0-A4/top shell/x2 fixed reference PASS；true2x2 行为级 raw compare 0/192 mismatch；bitstream/PPA gate PASS_WITH_SCOPE | PARTIAL_FOR_STRICT_BOARD / PASS_WITH_SCOPE_FOR_REPORT | 真实板端 32x32/64x64/720p validation 未闭合 |
| 设计方案文档清晰 | 架构、bank 映射、scheduler、上板报告、回退流程、最终提交指南均已提供 | PASS_WITH_SCOPE | 后续真实上板完成后需同步更新报告 |
| 模块量化指标和性能分析 | REDS 全量 FP32 PSNR、传统插值 baseline、PPA summary、x4 720p15 scheduler closure、x2 720p4 scheduler closure | PASS_WITH_SCOPE | W8A12 fixed 全量 PSNR/SSIM、真实板端 FPS/power 仍待实测 |
| 完善验证方案与用例 | Python reference、分层 RTL xsim、OOC、bitstream/PPA gate、mismatch 排查清单、board report validator | PASS_WITH_SCOPE | 严格 board validation 仍缺 4 个 `validation.md` |
| 面积越小、功耗越低 | A4 3-lane scheduler 672 DSP/74.67%；true2x2 implementation LUT 38803、FF 116441、BRAM 311、DSP 128、WNS 12.517ns | PASS_WITH_SCOPE | 720p packed 2-D 完整硬件集成资源和真实功耗未声明 |

## 3. 画质和性能声明边界

| 指标 | 当前数值 | 证据 | 可声明性 |
| --- | ---: | --- | --- |
| x4 FP32 PSNR RGB | 28.3118 dB | `evidence/quality_comparison/summary.md` | 可声明，REDS val 全量 |
| x2 FP32 PSNR RGB | 34.4297 dB | `evidence/quality_comparison/summary.md` | 可声明，REDS val 全量 |
| x4 bicubic PSNR RGB | 26.2949 dB | `evidence/quality_baseline/x4_interpolation/summary.md` | 可声明，用于传统插值对比 |
| x2 bicubic PSNR RGB | 30.8645 dB | `evidence/quality_baseline/x2_interpolation/summary.md` | 可声明，用于传统插值对比 |
| x4 720p15 scheduler FPS | 17.501 FPS @250MHz | `evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.md` | 可声明为 scheduler/performance-model，不是板端实测 |
| x2 720p4 scheduler FPS | 4.483 FPS @250MHz | `evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.md` | 可声明为降目标 scheduler/performance-model，不是板端实测 |
| x2 720p20 | FAIL under 900-DSP gate | `evidence/sim_fps_design_space/packed2d_x2_720p20_perf_scheduler/summary.md` | 不可声明达成 |
| 真实板端 720p 输出 | NOT_CLAIMED | `evidence/contest_scope_readiness/summary.md` | 不可声明完成 |

## 4. 最终提交口径

赛题报告/PPA 提交口径以以下两个文件为准：

```text
evidence/contest_scope_readiness/summary.md
evidence/contest_scope_package/summary.md
```

如果评审要求真实板端输出，则以严格审计为准：

```text
evidence/delivery_audit/contest_delivery_audit.md
evidence/submission_package/archive/summary.md
```

当前严格上板缺口：

```text
evidence/board_reports/a5_32x32/validation.md
evidence/board_reports/a6_64x64/validation.md
evidence/board_reports/a7_720p_x4/validation.md
evidence/board_reports/x2_720p/validation.md
```
