# W8A12 三路并行 AI 超分硬件加速器赛题报告

版本：赛题相当报告初稿  
工程目录：`W8A12_3lane/`  
当前状态：离线模型、W8A12 定点参考、RTL 仿真、OOC 综合和 PPA 证据已形成；真实板端 32x32/64x64/720p 输出仍待完成。

## 1. 摘要

本方案面向“AI 超分辨率模型高效硬件加速器设计与实现”赛题，选择 SPAN x4/F48 和 SPAN x2/F48 作为基础模型，采用 W8A12 定点量化，即权重 INT8、激活 12-bit。硬件主线采用 block 内三路 output-channel 并行架构，将 48 个 feature channels 拆分为 `3 lanes x 16ch` 并行计算，同时保持 6 个 SPAB block 按 `block_1 -> block_6` 串行推进。

当前报告优先完成赛题评审需要的模型说明、训练/验证口径、量化与转换工具、RTL 架构、仿真验证、综合资源和 PPA 分析。板端真实输出图像和板端实测 FPS/功耗仍作为后续上板验证项推进；现有报告中所有板端指标均标注为待测，不与模型/RTL 等效指标混写。

## 2. 赛题目标对应关系

| 赛题要求 | 本工程对应实现 | 当前证据 |
| --- | --- | --- |
| AI 模型结构、训练、量化说明和源码 | SPAN x2/x4 F48，W8A12 量化，Python fixed reference 和导出工具 | `docs/python_reference_plan.md`、`tools/w8a12_3lane_reference.py`、`scripts/export_x2_w8a12_to_rtl.ps1` |
| 模型到硬件指令/常量转换工具 | 生成 quant plan、RTL manifest、postprocess manifest、lane mems | `runs/reds_span_quant_plan/`、`rtl/generated/reds_span_*_w8a12/` |
| 硬件加速器详细设计文档 | 3-lane 架构、bank 映射、scheduler、top shell、回退流程 | `docs/w8a12_3lane_architecture.md`、`docs/bank_mapping_rules.md`、`docs/a4_scheduler_acceptance_flow.md` |
| RTL 源码与仿真验证 | A0/A1/A2/A3/A4/top xsim 证据 | `evidence/reference/`、`evidence/resource/`、`evidence/top/` |
| 资源开销评估 | Vivado OOC utilization/timing | `evidence/resource/*_ooc/`、`evidence/top/accel_top_ooc/` |
| 画质和性能表现 | REDS val 全量模型指标、传统插值对比、PPA 估计；板端实测待补 | `evidence/quality_comparison/summary.md` |

## 3. 数据集和训练验证口径

本工程使用 REDS 官方数据划分：

| 用途 | 路径 | 数量 | 口径 |
| --- | --- | ---: | --- |
| 训练 GT | `G:/REDS/train_sharp` | 24000 images | REDS train 官方全量 |
| 训练 x4 LQ | `G:/REDS/train/train_sharp_bicubic/X4` | 24000 images | REDS train 官方全量 |
| 验证 GT | `G:/REDS/val_sharp` | 3000 images | REDS val 官方全量 |
| 验证 x4 LQ | `G:/REDS/val/val_sharp_bicubic/X4` | 3000 images | REDS val 官方全量 |
| 验证 x2 LQ | `G:/REDS/val/val_sharp_bicubic/X2` | 3000 images | REDS val 官方全量 |

模型训练和 PSNR/SSIM 验证均按 REDS 官方全量划分统计。量化校准当前用于快速硬件闭环，采用 REDS val 代表性子集；最终交付前可扩展到 REDS val 全量校准，再重新导出 W8A12 quant plan 和 fixed reference。

## 4. 模型结构

基础模型为 SPAN，硬件主线使用 48 feature channels 和 6 个 SPAB block。x4 路径用于 `320x180 LR -> 1280x720 SR`，x2 路径用于 `640x360 LR -> 1280x720 SR`。模型包含：

- front feature extraction；
- 6 个 SPAB block；
- tail / conv_cat / upsampler；
- pixelshuffle；
- RGB 输出后处理。

当前 x4 模型训练证据为 `SPAN x4/F48 28.3118 dB @ 295000 iter`；x2 模型训练证据为 `SPAN x2/F48 34.4297 dB @ 300000/300001 iter`。

## 5. W8A12 量化与硬件转换

量化目标为 W8A12：

| 项目 | 口径 |
| --- | --- |
| 权重 | signed INT8 |
| 激活 | 12-bit 定点 |
| bias/requant | Q31 multiplier + shift |
| 非线性 | 导出 LUT |
| 转换产物 | quant plan、RTL manifest、postprocess manifest、lane mems |

x2 W8A12 导出已经完成，检查项全部 PASS：

| 检查项 | 结果 |
| --- | --- |
| RTL manifest | PASS |
| postprocess manifest | PASS |
| quant plan | PASS |
| scale=2 | PASS |
| feature channels=48 | PASS |
| activation_bits=12 | PASS |
| weight_bits=8 | PASS |

x2 fixed reference 也已经通过，关键输出 hash 为 `rgb_q_hash = 0xBC30F107`。x4 分层 reference 已完成 A0-A3，作为 RTL 分层验证的 golden reference。

## 6. 三路并行硬件架构

本工程采用 block 内 output-channel 三路并行：

```text
48 output channels
  -> lane0: ch 0..15
  -> lane1: ch 16..31
  -> lane2: ch 32..47
```

每个 lane 独立计算 16 个 output channels，3 路结果在 feature 维度拼接。SPAB block 之间仍按 `block_1 -> block_6` 串行推进，因此不会改变模型拓扑，也不会因并行拆分降低超分画质。该方案的工程优点是：

- 与现有 scheduler 更容易对接；
- 每个 lane 的权重和 feature bank 边界清晰；
- 能在保持模型数学等价的前提下提升吞吐；
- 可按 single-lane、3-lane、block、tail 分层验证。

## 7. RTL 仿真验证

当前 RTL 验证采用分层 golden reference，对每层输出和关键 hash 做 bit-exact 对齐。

| 阶段 | 覆盖内容 | 结果 | 关键证据 |
| --- | --- | --- | --- |
| A0 | 单层 3-lane conv | PASS | `stitched_hash == full48_hash == 0x080D3C47` |
| A1 | 单个 SPAB block | PASS | `block_output = 0xD12E1B43` |
| A2 | 6 个 SPAB blocks | PASS | `block_6_output = 0xD2AC6553` |
| A3 | tail / pixelshuffle / RGB | PASS | `rgb_q = 0x280F9356` |
| A4 | single-lane scheduler | PASS | xsim PASS |
| A4 | 3-lane scheduler | PASS | xsim PASS |
| top shell | accelerator control/status shell | PASS | `spab_count=6 cycles=24 status=0000edcb` |
| x2 reference | x2 W8A12 fixed reference | PASS | `rgb_q_hash = 0xBC30F107` |

上述验证证明了三路 output-channel 并行不会改变 W8A12 fixed reference 的数学结果。需要注意，A3 目前是 RTL 语义仿真；真实板端 writer 和 DDR 读回仍需单独完成上板闭环。

## 8. 综合资源与 PPA

资源评估以 ZC706 / XC7Z045 等效门限为目标。当前已经完成 MAC core、A4 single-lane scheduler、A4 3-lane scheduler 和 accelerator top shell 的 OOC/资源门限汇总，独立证据见 `evidence/ppa_summary/summary.md`。

| 模块 | LUT | LUT 占比 | FF | FF 占比 | BRAM | DSP | DSP 占比 | WNS(ns) | 结论 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| A4 MAC core TAP_PAR=8 | 51 | 0.02% | 49 | 0.01% | 0 | 8 | 0.89% | NA | RESOURCE_PASS |
| A4 single-lane scheduler | 41003 | 18.76% | 85414 | 19.54% | 0 | 224 | 24.89% | 1.261 | PASS |
| A4 3-lane scheduler | 123182 | 56.35% | 256222 | 58.61% | 0 | 672 | 74.67% | 1.188 | PASS |
| accelerator top shell | 0 | 0.00% | 5 | 0.00% | 0 | 0 | 0.00% | 9.130 | PASS |

XC7Z045 参考门限：

| 资源 | 门限 |
| --- | ---: |
| LUT | 218600 |
| FF | 437200 |
| BRAM tile | 545 |
| DSP | 900 |

当前 A4 3-lane scheduler 的 DSP 使用量为 672，占 XC7Z045 门限 74.67%，低于 900 DSP 门限；LUT 占比 56.35%，FF 占比 58.61%，均低于对应门限。BRAM 为 0 是因为该 OOC 统计对象是计算 scheduler，不包含完整 tile/frame buffer。完整 accelerator 的最终 BRAM、DDR bandwidth、power 和 board FPS 需在完整集成后重新统计。

## 9. 画质指标与传统插值对比

REDS val 全量 baseline 已生成，模型 FP32 结果与传统插值对比如下：

| Scale | Method | PSNR RGB | PSNR Y | SSIM Y | Delta vs Bicubic RGB |
| --- | --- | ---: | ---: | ---: | ---: |
| x4 | nearest | 25.0921 | 25.1077 | 0.969136 | -1.2029 |
| x4 | bilinear | 25.7670 | 25.7734 | 0.972569 | -0.5279 |
| x4 | bicubic | 26.2949 | 26.2980 | 0.975825 | 0.0000 |
| x4 | SPAN FP32 | 28.3118 | 待跑 | 待跑 | +2.0169 |
| x2 | nearest | 29.0969 | 29.1166 | 0.987690 | -1.7676 |
| x2 | bilinear | 29.7218 | 29.7359 | 0.988867 | -1.1427 |
| x2 | bicubic | 30.8645 | 30.8855 | 0.991444 | 0.0000 |
| x2 | SPAN FP32 | 34.4297 | 待跑 | 待跑 | +3.5652 |

当前结论：

- x4 FP32 SPAN 已达到赛题设定的 `PSNR >= 28 dB` 目标；
- x2 FP32 SPAN 已超过 `PSNR >= 30 dB` 目标；
- x4 相对 bicubic 提升约 `+2.0169 dB`；
- x2 相对 bicubic 提升约 `+3.5652 dB`。

W8A12 fixed-point 和 board 输出的全量 REDS val PSNR/SSIM 仍待补充。没有真实板图输出前，不将模型/RTL 等效指标写成板端实测指标。补齐流程和填报规则见 `docs/quality_metric_completion_plan.md`，当前静态检查证据为 `evidence/quality_metric_completion/summary.md`。

## 10. 板端状态和 mismatch 风险

当前有效板端 baseline 为 true 2x2 x4：

| 项目 | 数值 |
| --- | --- |
| 输入/输出 | `2x2 -> 8x8` |
| 输出字节 | `192 / 192` |
| frame_done | `1` |
| error | `0` |
| mismatch | `153 / 192 bytes` |
| max channel diff | `4` |
| PSNR | `44.0265 dB` |

已通过项：

- 输入 DDR readback 曾达到 `mismatch=0`；
- JTAG-to-AXI register probe 曾验证 `0xA0000000` magic/scratch 可读写；
- 重插后 Vivado target 历史上曾恢复，`xczu19_0` 和 `arm_dap_1` 可见；当前连接态以 `evidence/board_probe/jtag_precondition_current/summary.md` 为准；
- 补跑对应 `psu_init.tcl` 后，最小 JTAG-to-AXI register probe 已恢复 PASS，`hw_axi_1` 可见，magic/scratch 可读写；
- true 2x2 RTL endpoint raw compare 为 `0/192 mismatch`；
- 更窄的 stage-hash 版本行为级 RTL raw compare 仍为 `0/192 mismatch`，期望边界 hash 为 `tail_b1=0x16ede1c2`、`tail_b6_act1=0xc7a092b8`、`tail_rgb_q=0xb712a61b`、`writeback=0x61d3ea1d`；
- Default synthesis 重建 bitstream 与旧 baseline 输出 byte-identical。

未通过或待补项：

- true 2x2 board output 仍不是 bit-exact；
- debugregs 上板读取已经越过 JTAG-to-AXI master 识别异常：W8A12 debugregs bitstream 可见 `hw_axi_1`，但 true 2x2 输入 `counter_in=4` 后 `counter_out=0/frame_done=0`，输出 `0/192`；
- 为继续定位，已在 JTAG endpoint 增加 `0x04` endpoint progress、`0x08` front state、`0x10` block/replay 计数读数；新增读数后的 true 2x2 RTL raw compare 仍为 `0/192 mismatch`；
- 新 `dbgprogress` bitstream 上板可完整输出 `192/192` 且 `frame_done=1`，但退化为 `189/192` mismatch、PSNR 16.3034 dB，`writeback_hash=0xAD24396D` 与 RTL 期望 `0x61d3ea1d` 不一致。
- 当前已切换为更窄 stage-hash 映射，行为级 RTL raw compare PASS，Default stage-hash bitstream 已生成且 timing PASS；当前 JTAG precondition 为 BLOCKED，恢复 target 后直接烧录并读取 `tail_b1/tail_b6_act1/tail_rgb_q/writeback`。
- 已新增 `docs/jtag_recovery_checklist.md` 和 `evidence/board_probe/jtag_recovery_checklist/summary.md`，当前证据显示在线 USB 设备无已知 JTAG，历史 FTDI `VID_0403&PID_6010` 为 Unknown；常规 preflight 因 USB 侧阻塞将 Vivado target 记为 `not_checked`，强制 Vivado probe 也得到 target count=0；恢复通过条件为 USB known candidate>=1 且 Vivado target>=1。
- 32x32/64x64/720p x4 和 720p x2 board validation 均待补。

后续排查优先级：

1. 冷启动/重插后先运行对应工程的 `psu_init.tcl`，把最小 JTAG-to-AXI register probe PASS 作为前置门禁；
2. 重跑 debugregs true 2x2；
3. 先对比 `counter_in/counter_out/frame_done/frame_cycles`，当前卡点为输入已接收但无输出；
4. `dbgprogress` 已确认 `counter_out=64/frame_done=1`，但 writeback hash 不一致，因此当前重点不是 JTAG 读回本身，而是 writer 前或 writer 数据生成边界；
5. 回到历史最好 Default/inpixfix baseline，加更窄的 `tail_b1_hash`、`tail_b6_act1_hash`、`tail_rgb_q_hash` 和 writer `hash/first/last`；
6. 若 writeback/stage hash 一致但 board output mismatch，查 endpoint 输出缓存/JTAG 读回；
7. 若 hash 不一致，继续查 front/SPAB、tail/pixelshuffle/RGB；
8. 补 writer-only pattern、postprocess-only、tail/pixelshuffle-only 三个最小上板验证。

## 11. 当前交付审计状态

严格交付审计当前状态为 `INCOMPLETE`。新增赛题报告、PDF 报告导出、PPA 汇总、报告完整性检查、画质指标闭环门禁、stage-hash 上板流程静态检查和 board validation readiness 后，当前审计为 `69 / 73`，剩余 4 项均为真实板端 validation：

```text
a5.board_32x32
a6.board_64x64
a7.board_720p_x4
x2.board
```

在报告/PPA 优先主线下，当前可以先提交离线模型、RTL 仿真、OOC 综合、PPA 和风险说明材料；最终正式板端交付仍需补齐上述 4 项 board validation。

## 12. 可复现实验命令

关键门禁命令：

```powershell
python W8A12_3lane\tools\w8a12_3lane_reference.py a0-single-conv
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -ContinueOnError
python W8A12_3lane\tools\audit_contest_delivery.py
python W8A12_3lane\tools\generate_missing_evidence_plan.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete
python W8A12_3lane\tools\collect_delivery_manifest.py
```

恢复 JTAG 后的首个板端命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance
```

## 13. 交付文件索引

| 类别 | 路径 |
| --- | --- |
| 工作流 | `WORKFLOW.md` |
| 交付索引 | `DELIVERY_INDEX.md` |
| 状态看板 | `STATUS.md` |
| PDF 赛题报告 | `output/pdf/W8A12_3lane_contest_submission_report.pdf`、`evidence/report_pdf/summary.md` |
| 架构说明 | `docs/w8a12_3lane_architecture.md` |
| bank 映射 | `docs/bank_mapping_rules.md` |
| A4 scheduler 验收 | `docs/a4_scheduler_acceptance_flow.md` |
| 上板汇报规范 | `docs/board_report_flow.md` |
| JTAG 恢复清单 | `docs/jtag_recovery_checklist.md`、`evidence/board_probe/jtag_recovery_checklist/summary.md` |
| 最新上板进展 | `evidence/board_probe/latest_board_progress_20260628.md` |
| 质量对比 | `evidence/quality_comparison/summary.md` |
| 画质指标闭环计划 | `docs/quality_metric_completion_plan.md`、`evidence/quality_metric_completion/summary.md` |
| A0-A3 reference | `evidence/reference/` |
| A4 OOC | `evidence/resource/A4_*_ooc/` |
| x2 W8A12 导出 | `evidence/x2/w8a12_export/summary.md` |
| x2 fixed reference | `evidence/x2/reference/summary.md` |
| delivery audit | `evidence/delivery_audit/contest_delivery_audit.md` |
| submission archive summary | `evidence/submission_package/archive/summary.md` |
| GitHub 草案上传证明 | `evidence/github_upload_push/summary.md` |

## 14. 结论

当前 W8A12_3lane 已经形成可用于赛题中期/相当报告的完整离线证据链：模型训练和验证口径明确，x4/x2 FP32 画质达到目标，传统插值 baseline 已对比，W8A12 定点导出和 x2 fixed reference 已通过，A0-A4 和 top shell 的 RTL 仿真/OOC 综合均有 PASS 证据，3-lane scheduler 在 XC7Z045 资源门限内。

剩余主要风险集中在真实板端 validation：true 2x2 当前历史最好仍是 `153/192` byte mismatch；重插后 Vivado target 历史上曾恢复，补跑 `psu_init.tcl` 后 JTAG-to-AXI master 也曾恢复。当前 JTAG precondition 为 BLOCKED：USB known candidate=0；常规 preflight 的 Vivado target count=not_checked，强制 Vivado probe 后 target count=0，说明当前确实没有可用硬件 target。`dbgregs` 版本曾停在输入已接收但无输出：`counter_in=4`、`counter_out=0`、`frame_done=0`；新增 endpoint/datapath progress 只读寄存器后，`dbgprogress` bitstream 已能完整输出并 `frame_done=1`，但退化为 `189/192` mismatch，且 writeback hash 与 RTL 期望不一致。后续应在恢复 USB/JTAG target 后直接运行 stage-hash true2x2 acceptance，定位 writer 前偏差，再逐步补齐 32x32、64x64、720p x4 和 720p x2 board validation。
