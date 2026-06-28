# W8A12_3lane 新主线工程

本目录是 W8A12 的新架构主线入口。目标是在不改变模型语义的前提下，重新建立三路 block 内 output-channel 并行架构。

## 主线目标

- 模型：REDS SPAN x4。
- 量化：W8A12，权重 INT8，激活 12-bit。
- 特征通道：48 channels。
- SPAB/block：6 个，仍按 `block_i=0..5` 串行执行。
- 并行方式：每个 block 内按输出通道拆成 `3 x 16ch` lane。
- 第一验收目标：`32x32 LR tile + halo=21 -> x4 -> 128x128 RGB`，与 Python W8A12 fixed-point reference bit-exact。
- 本地板卡：`xczu19eg-ffvc1760-2-i`。
- 资源评估：按 ZC706 / XC7Z045 门限。

## 目录说明

```text
W8A12_3lane/
  README.md
  WORKFLOW.md
  STATUS.md
  docs/
    legacy_readonly_policy.md
    layered_reference_flow.md
    bank_mapping_rules.md
    mac_dsp_mapping_policy.md
    submission_scope_policy.md
    failure_rollback_flow.md
    python_reference_plan.md
    board_report_flow.md
  rtl/
    span/
    board/
  sim/
  scripts/
  tools/
  evidence/
```

## 关键文档

- `docs/legacy_readonly_policy.md`：旧线哪些文件只读、哪些资产可以复用。
- `docs/layered_reference_flow.md`：A0-A5 分层 reference 和验收流程。
- `docs/bank_mapping_rules.md`：lane、feature bank、weight bank、tail 读取和 hash 映射规则。
- `docs/failure_rollback_flow.md`：A0-A5 失败时的回退和排查范围。

## 开发顺序

1. 冻结旧线，只复用旧线的 reference、权重导出、上板框架和 resource gate。
2. 建立单层 3-lane convolution reference。
3. 实现单层 3-lane RTL，并与 reference bit-exact。
4. 接入单个 SPAB block，并与 block reference bit-exact。
5. 接入 6 block scheduler，验证 block6 feature hash。
6. 接入 tail/pixelshuffle/RGB，验证完整 tile RGB 输出。
7. 通过 OOC synthesis 和 XC7Z045 resource gate。
8. 上板验证 32x32，再扩展到 64x64 和 720p。

## 当前状态

当前不是空骨架：A0-A3 已有 Python/RTL 语义证据，A4 single-lane/3-lane scheduler xsim 与 OOC、accelerator top shell xsim/OOC、x2 W8A12 export 和 fixed reference validation 均已有 PASS 证据；真实上板 validation 仍在补齐中。最新状态以 `STATUS.md` 和 `evidence/delivery_audit/contest_delivery_audit.md` 为准。

## 交付入口

- `DELIVERY_INDEX.md`：按赛题交付项索引模型、量化、RTL、仿真、综合和上板证据。
- `docs/contest_delivery_audit.md`：交付项审计规则和缺口。
- `evidence/delivery_audit/contest_delivery_audit.md`：当前自动审计结果。

## 总工作流

- `WORKFLOW.md`：W8A12_3lane 新主线总工作流。

## Python Reference

- `docs/python_reference_plan.md`：记录 W8A12 Python reference、训练/验证集口径、checkpoint 和 A0 落地计划。

## Board Report

- `docs/board_report_flow.md`：每次全流程上板后的资源、时序、吞吐、功耗和超分效果汇报规范。
- `STATUS.md`：A0-A7 状态看板和最新上板汇报入口。

## 当前硬缺口

交付完成前必须补齐：

- A5 x4 32x32 board validation；
- A6 x4 64x64 board validation；
- A7 x4 720p board validation；
- x2 720p board validation。

当前严格审计为 `INCOMPLETE`，通过 `69 / 73`，上述 4 项均要求真实 `validation.md Status: PASS`。PDF 赛题报告见 `output/pdf/W8A12_3lane_contest_submission_report.pdf`，导出校验证据见 `evidence/report_pdf/summary.md`；提交草案 zip 和 SHA256 见 `evidence/submission_package/archive/summary.md`。这些归档当前仍标记为 `INCOMPLETE`，不能替代最终板端证据。

不要用 PENDING 骨架或静态检查替代 PASS evidence。最新缺口以 `evidence/delivery_audit/contest_delivery_audit.md` 和 `evidence/submission_package/submission_manifest.md` 为准。
