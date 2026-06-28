# 一键门禁执行脚本

## 目标

`scripts/run_delivery_gates.ps1` 用于在普通 Windows PowerShell 中串行执行当前交付门禁，并把每一步日志收集到：

```text
W8A12_3lane/evidence/delivery_runs/<RunId>/
```

它不会把失败步骤伪装为通过；任何一步缺少预期 evidence 或未出现 PASS 文本，都会在 run summary 中标为 FAIL。

## 推荐执行

完整执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -ContinueOnError
```

如果当前机器暂时不能跑 Vivado，只跑 Python/reference/audit 侧：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -SkipVivado -ContinueOnError
```

如果只想先推进 x4/A4，不跑 x2：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -SkipX2 -ContinueOnError
```

固定 run id，方便记录到汇报：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -RunId a4_first_full_gate -ContinueOnError
```

## 当前包含步骤

| 步骤 | 作用 | 通过证据 |
| --- | --- | --- |
| `a4_scheduler_vector_check` | 复现 A0 fixture 下 3-lane MAC 输出 | `evidence/resource/A4_scheduler_vector_check/summary.md` |
| `a4_scheduler_flow_static` | 检查 A4 scheduler 仿真/OOC 脚本、TB 和 wrapper 链路 | `evidence/resource/A4_scheduler_flow_static/summary.md` |
| `accel_top_flow_static` | 检查 accelerator top 仿真/OOC 脚本和 TB 链路 | `evidence/top/accel_top_flow_static/summary.md` |
| `accel_top_xsim` | Vivado xsim 验证 accelerator top 控制/status 时序 | `evidence/top/accel_top_sim/summary.md` |
| `accel_top_ooc` | accelerator top OOC 综合 | `evidence/top/accel_top_ooc/utilization_ooc.rpt` |
| `accel_top_ooc_summary` | accelerator top XC7Z045 门限汇总 | `evidence/top/accel_top_ooc/ooc_summary.md` |
| `a4_single_lane_xsim` | Vivado xsim 验证 lane0 16ch | `evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md` |
| `a4_3lane_xsim` | Vivado xsim 验证完整 48ch | `evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md` |
| `a4_single_lane_ooc` | single-lane scheduler OOC 综合 | `evidence/resource/A4_single_lane_mac_scheduler_ooc/utilization_ooc.rpt` |
| `a4_3lane_ooc` | 3-lane scheduler OOC 综合 | `evidence/resource/A4_3lane_mac_scheduler_ooc/utilization_ooc.rpt` |
| `a4_single_lane_ooc_summary` | XC7Z045 门限汇总 | `ooc_summary.md Status: PASS` |
| `a4_3lane_ooc_summary` | XC7Z045 门限汇总 | `ooc_summary.md Status: PASS` |
| `x2_flow_static` | 检查 x2 导出/fixed-reference 工具链路 | `evidence/x2/flow_static/summary.md` |
| `x2_w8a12_export` | 生成 x2 W8A12 RTL/postprocess manifest | `rtl/generated/reds_span_x2_f48_w8a12/` |
| `x2_w8a12_export_check` | 校验 x2 W8A12 manifest/量化字段 | `evidence/x2/w8a12_export/summary.md` |
| `x2_readiness` | 检查 x2 reference 输入资产 | `evidence/x2/reference_readiness/readiness.md` |
| `x2_fixed_reference` | 生成 x2 W8A12 A3 fixed reference | `evidence/x2/reference/summary.md` |
| `x2_fixed_reference_validation` | 校验 x2 fixed reference 输出尺寸和状态 | `evidence/x2/reference_validation/validation.md` |
| `delivery_audit` | 严格交付审计 | `evidence/delivery_audit/contest_delivery_audit.md` |
| `board_report_flow_static` | 检查上板汇报工具、资源门限和 PSNR 验收链路 | `evidence/board_reports/flow_static/summary.md` |
| `missing_evidence_plan` | 生成剩余缺口命令 | `evidence/delivery_audit/missing_evidence_plan.md` |
| `missing_plan_flow_static` | 检查缺口计划生成器包含 cmd 回退、board 资源参数和 x2 映射 | `evidence/delivery_audit/missing_plan_flow_static/summary.md` |
| `audit_flow_static` | 检查交付审计不会阻断最终 PASS，且覆盖核心门禁 | `evidence/delivery_audit/audit_flow_static/summary.md` |
| `delivery_manifest` | 生成上传 manifest | `evidence/delivery_manifest/manifest.md` |
| `submission_manifest` | 生成 GitHub 上传包 manifest | `evidence/submission_package/submission_manifest.md` |
| `submission_manifest_flow_static` | 检查提交包包含 OOC 原始报告和最终证据 | `evidence/submission_package/flow_static/summary.md` |

## 输出解读

每次运行都会生成：

```text
summary.md
summary.json
<step>/stdout.txt
<step>/stderr.txt
```

如果 `summary.md` 中某步 FAIL，先看该步骤的 `stderr.txt`；若是 Vivado 失败，再看对应 evidence 目录下的 Vivado `.log/.jou` 和 `build/` 目录。

## 和最终交付的关系

该脚本只是执行器，最终状态仍以：

```text
W8A12_3lane/evidence/delivery_audit/contest_delivery_audit.md
```

为准。审计显示 `状态：PASS` 前，不能视为赛题交付完成。

## 硬门禁队列执行器

`scripts/run_hard_gate_queue.ps1` 用于执行 `evidence/delivery_audit/hard_gate_execution_queue.json` 中仍缺的真实硬门禁。它适合从当前 `45 / 62` 状态继续推进，因为队列只包含未完成项，不会重复跑已经 PASS 的 A0-A3 静态证据。

完整 dry-run，先确认命令和顺序：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_hard_gate_queue.ps1 -DryRun
```

只跑 Vivado/JTAG 板卡探测：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_hard_gate_queue.ps1 -OnlyCategory board_probe
```

只跑 A4 scheduler 的 Vivado/xsim/OOC 门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_hard_gate_queue.ps1 -OnlyCategory a4_scheduler_vivado -ContinueOnError
```

只跑传统插值 baseline 对比：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_hard_gate_queue.ps1 -OnlyCategory quality_baseline -ContinueOnError
```

从板卡探测开始继续执行后续上板项：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_hard_gate_queue.ps1 -StartAt board.vivado_hw_probe -ContinueOnError
```

硬门禁类别：

| Category | 范围 |
| --- | --- |
| `accelerator_top_vivado` | accel top xsim/OOC |
| `a4_scheduler_vivado` | single-lane / 3-lane scheduler xsim/OOC |
| `x2_export_reference_board` | x2 W8A12 export、fixed reference、x2 board |
| `quality_baseline` | x4/x2 REDS_val nearest / bilinear / bicubic baseline |
| `board_probe` | Vivado JTAG target/device 探测 |
| `board_x4` | A5/A6/A7 x4 上板报告 |

每次运行会写入：

```text
W8A12_3lane/evidence/hard_gate_runs/<RunId>/
```

其中 `summary.md` 是本次执行结果；每个步骤目录下的 `commands.txt`、`stdout.txt`、`stderr.txt` 是问题定位入口。
