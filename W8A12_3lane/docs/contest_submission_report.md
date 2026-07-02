# W8A12 三路并行 AI 超分硬件加速器赛题报告

版本：赛题相当报告阶段性交付版  
工程目录：`W8A12_3lane/`  
当前状态：离线模型、W8A12 定点参考、RTL 仿真、bitstream 生成、实现后资源/时序和 PPA 证据已形成；真实板端 32x32/64x64/720p 输出仍作为工程实测补充项推进。

提交声明：若赛题评审口径为“正确性仿真通过 + 可生成 bitstream + 提供 PPA/资源时序报告”，本报告可以作为当前阶段提交材料；真实插板运行不作为该口径的硬门槛。若按本工程更严格的 board-validation 口径，则最终闭环还需要补齐 A5 32x32、A6 64x64、A7 720p x4 和 x2 720p 的真实板端 `validation.md Status: PASS`。

## 1. 摘要

本方案面向“AI 超分辨率模型高效硬件加速器设计与实现”赛题，选择 SPAN x4/F48 和 SPAN x2/F48 作为基础模型，采用 W8A12 定点量化，即权重 INT8、激活 12-bit。硬件主线采用 block 内三路 output-channel 并行架构，将 48 个 feature channels 拆分为 `3 lanes x 16ch` 并行计算，同时保持 6 个 SPAB block 按 `block_1 -> block_6` 串行推进。

当前报告优先完成赛题评审需要的模型说明、训练/验证口径、量化与转换工具、RTL 架构、仿真验证、bitstream、综合/实现资源和 PPA 分析。板端真实输出图像和板端实测 FPS/功耗仍作为后续工程验证项推进；现有报告中所有板端指标均标注为待测，不与模型/RTL/bitstream 等效指标混写。

当前可提交范围：

- 可提交：模型结构、训练/验证数据口径、W8A12 量化方案、模型到 RTL 常量/manifest 转换、Python fixed reference、A0-A4 分层 RTL 仿真、top shell 仿真、true2x2/JTAG-W8A12 bitstream、实现后资源/时序、PPA 表格、传统插值 baseline 对比、packed 2-D FPS scheduler 边界、mismatch 排查清单和后续上板验收流程。
- 不可声明：真实板端 720p 输出已完成、板端 FPS/功耗已实测、x4/x2 板端 PSNR 已闭合、720p packed 2-D 完整硬件 bitstream 已闭合。
- 后续补齐方式：恢复 JTAG 后先完成 dbg2 source-boundary true2x2 验收，再依次补 A5 32x32、A6 64x64、A7 720p x4 和 x2 720p 上板报告；每个报告必须包含 bitstream、资源、时序、功耗/latency/FPS、board output、fixed reference 和 PSNR/SSIM 对比。

## 2. 赛题目标对应关系

| 赛题要求 | 本工程对应实现 | 当前证据 |
| --- | --- | --- |
| AI 模型结构、训练、量化说明和源码 | SPAN x2/x4 F48，W8A12 量化，Python fixed reference 和导出工具 | `docs/python_reference_plan.md`、`tools/w8a12_3lane_reference.py`、`scripts/export_x2_w8a12_to_rtl.ps1` |
| 模型到硬件指令/常量转换工具 | 生成 quant plan、RTL manifest、postprocess manifest、lane mems | `runs/reds_span_quant_plan/`、`rtl/generated/reds_span_*_w8a12/` |
| 硬件加速器详细设计文档 | 3-lane 架构、bank 映射、scheduler、top shell、回退流程 | `docs/w8a12_3lane_architecture.md`、`docs/bank_mapping_rules.md`、`docs/a4_scheduler_acceptance_flow.md` |
| RTL 源码与仿真验证 | A0/A1/A2/A3/A4/top xsim 证据 | `evidence/reference/`、`evidence/resource/`、`evidence/top/` |
| 资源开销评估 | Vivado OOC utilization/timing、true2x2/JTAG-W8A12 bitstream implementation PPA | `evidence/resource/*_ooc/`、`evidence/top/accel_top_ooc/`、`evidence/bitstream_ppa_gate/summary.md` |
| 画质和性能表现 | REDS val 全量模型指标、传统插值对比、PPA 估计；板端实测待补 | `evidence/quality_comparison/summary.md` |

评审要点当前完成度：

| 评审要点 | 当前可证明内容 | 当前风险/待补 |
| --- | --- | --- |
| 功能实现精准无误 | A0-A4/top shell/x2 fixed reference 已有 PASS 证据，true2x2/JTAG-W8A12 bitstream 生成且 timing PASS，模型拓扑和 W8A12 参考链路清楚 | 真实板端 32x32/64x64/720p validation 是工程实测待补 |
| 文档清晰、模块划分合理 | 架构、bank 映射、量化、scheduler、回退、上板报告流程均有文档和索引 | 最终板端报告完成后需同步刷新 |
| 量化指标和性能分析 | REDS 全量 FP32 PSNR、传统插值对比、OOC 资源/时序、packed 2-D FPS scheduler 边界已形成 | W8A12 fixed 全量 PSNR/SSIM、板端 FPS/功耗待补 |
| 验证方案与用例 | Python reference、RTL xsim、OOC、bitstream/PPA gate、stage-hash、board report validator 和 missing evidence plan 已建立 | A5-A7/x2 board validation 作为后续工程实测补充 |
| 面积/功耗/PPA | A4 3-lane scheduler 672 DSP 低于 900 DSP 规划门限；true2x2/JTAG-W8A12 implementation 为 LUT 38803、FF 116441、BRAM 311、DSP 128、WNS 12.517ns | 720p packed 2-D 完整集成资源、真实板端功耗/FPS 仍待补 |

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

若评审只要求 bitstream 和 PPA，而不要求真实插板运行，则可采用当前 true2x2/JTAG-W8A12 bitstream implementation 作为 bitstream/PPA 门槛证据。该配置已经生成 `.bit`，实现后资源和时序如下，独立证据见 `evidence/bitstream_ppa_gate/summary.md`：

| 项目 | 数值 | ZC706/XC7Z045 规划门限 | 结论 |
| --- | ---: | ---: | --- |
| CLB LUTs | 38803 | 218600 | PASS |
| CLB Registers | 116441 | 437200 | PASS |
| BRAM Tile | 311 | 545 | PASS |
| DSPs | 128 | 900 | PASS |
| WNS | 12.517 ns | >= 0 ns | PASS |
| WHS | 0.010 ns | >= 0 ns | PASS |

该 bitstream 对应 `ImgW=2 / TileW=2 / TileH=2 / Halo=21` 的 JTAG-W8A12 x4 tile-writer/debug source-boundary 配置，行为级 RTL raw compare 为 `0 / 192` mismatch。它证明当前 W8A12 tile 计算和写回配置能够生成 bitstream 并满足资源/时序门限；但不声明 720p packed 2-D 完整硬件 bitstream 已闭合。

性能 scheduler 侧已补充 packed 2-D 规划证据，并新增独立 `x4_720p15_fps_closure` 门禁。该门禁明确输出分辨率为 `1280x720`，输入为 `320x180 LR`，闭合层级为 scheduler/performance-model，不声明板端实测 FPS 或完整 packed 2-D 像素 RTL bit-exact 闭合。证据见 `evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.md`。

| 目标 | Candidate | DSP | FPS @250MHz | 15fps 余量 | 当前结论 |
| --- | --- | ---: | ---: | ---: | --- |
| x4 720p15 最低资源点 | `24x64` | 792 | 15.070 | 0.467% | PASS，但余量很小 |
| x4 720p15 推荐闭合点 | `24x72` | 888 | 17.501 | 14.291% | PASS，作为本报告推荐 FPS 闭合配置 |
| x2 720p4 降目标闭合点 | `24x72` | 888 | 4.483 | 10.789% | PASS，作为 x2 降目标 FPS 闭合配置 |
| x2 720p20 资源门限内 | `24x64/24x72` | 792/888 | 3.861/4.483 | 不达标 | FAIL，不能声明 x2 720p20 |

x2 720p20 已新增独立 xsim 证据，但 900-DSP 门限内 `24x64/24x72` 仅为 3.861/4.483fps，非门限内 `48x144` 为 17.223fps 且 DSP=3504，因此当前完整 W8A12/F48 packed 2-D 规划不能声明 x2 720p20 已达标。按“降低 x2 FPS 目标”的补充口径，新增 `x2_720p4_fps_closure` 门禁；其中 `24x72` 为 4.483fps @250MHz、888 DSP、4fps 余量 10.789%，在 900-DSP 门限内达成 x2 720p4 scheduler-level 闭合；`24x64` 为 3.861fps，仅作为低资源边界点。证据见 `evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.md`。

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
- 当前已切换为更窄 stage-hash 映射，行为级 RTL raw compare PASS，Default stage-hash bitstream 已生成且 timing PASS；2026-06-29 续跑曾恢复 JTAG/PSU/register read，并完成 true2x2 stage-hash 上板读回：输出完整 `192/192`，但 compare FAIL `191/192`、PSNR 11.8292 dB；`tail_b1=0x031DA1C9` 已与 RTL 期望 `0x16ede1c2` 不一致，最早失败边界定位到 front/SPAB block1 或更前输入/halo 路径。
- 已新增 `docs/jtag_recovery_checklist.md` 和 `evidence/board_probe/jtag_recovery_checklist/summary.md`，当前证据显示在线 USB 设备无已知 JTAG；强制 Vivado probe 后 `Vivado target count=0`。这只是当前物理/JTAG 前置条件阻塞，不推翻上面的历史 stage-hash 数值定位；恢复通过条件为 USB known candidate>=1 且 Vivado target>=1。
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

## 11. 最新实板定位

2026-06-29 续跑 `run_w8a12_stagehash_true2x2_acceptance.ps1 -ContinueOnError` 后，板端状态从“JTAG target 不可见”推进到真实数值 mismatch：

| 项目 | 结果 |
| --- | --- |
| USB/JTAG/Vivado target | PASS |
| `psu_init.tcl` | PASS |
| 输出长度 | `192 / 192` bytes |
| frame_done / error | `1 / 0x00000000` |
| compare | FAIL，`191 / 192` mismatch |
| PSNR | `11.8292 dB` |
| `tail_b1_hash` | `0x031DA1C9 != 0x16ede1c2` |
| `tail_b6_act1_hash` | `0x75D95D8A != 0xc7a092b8` |
| `tail_rgb_q_hash` | `0x6B02FBCF != 0xb712a61b` |
| `writeback_hash` | `0x14D11085 != 0x61d3ea1d` |

结论：这次有效 stage-hash 上板不是板卡插拔、JTAG、PSU init 或寄存器读回问题，而是 PL 计算路径的实板数值偏差。由于 `tail_b1_hash` 是本轮最早失败边界，后续排查不再从头开始，而是在 `halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> b1_m_feat -> tail` 链路内继续找第一个错误点。

证据见 `evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md`。

2026-06-29 已落实下一层 debug-bank 路线：JTAG endpoint 保持 6-bit AXI-Lite 地址宽度不变，通过 `REG_PERF_CTRL[15:8]` 选择 bank。bank 0 保持旧 `tail/writeback` 读数，bank 1 读取 `tail_feat0/src_feat0/src_b1/spab_b1_input/c1/c2/c3`，bank 2 读取 `spab_b1_c1_raw/c2_replay/c2_window/residual/att`。同一 true2x2 输入/参考的 RTL raw compare 已重新通过，`0 / 192` mismatch，旧 hash 仍为 `0x16ede1c2/0xc7a092b8/0xb712a61b/0x61d3ea1d`。证据见 `evidence/board_reports/jtag_true2x2_debugbank_20260629.md`。

由于 all-in-one debug-bank 上板曾出现 busy stall，当前改成低侵入 `DebugExportLevel=2` source-boundary 路线：只导出 `tail_feat0=0x000004bf`、`src_feat0=0x00000004`、`src_b1=0x00070004`，不打开 SPAB deep bank。该版本 RTL raw compare PASS，bitstream/timing/resource PASS；当前一键验收脚本因 USB known JTAG candidate `0` 生成 `BLOCKED` summary。恢复 JTAG 后，直接运行 dbg2 一键脚本即可继续在上述历史链路内收窄，而不是重新排查。

## 12. 当前交付审计状态

严格 board-validation 审计当前状态为 `INCOMPLETE`，历史计数为 `72 / 76`。如果赛题不要求真实插板运行，这 4 项不应作为提交阻断项；它们只代表后续工程实测补充。新增赛题报告、PDF/Word 报告导出、PPA 汇总、报告完整性检查、画质指标闭环门禁、bitstream/PPA gate、stage-hash 上板流程静态检查、board validation readiness、submission manifest/archive 和 evidence matrix 后，当前严格审计剩余 4 项均为真实板端 validation：

```text
a5.board_32x32
a6.board_64x64
a7.board_720p_x4
x2.board
```

为避免将真实上板后续项误判为报告/PPA 口径阻断项，本工程新增赛题提交口径门禁 `evidence/contest_scope_readiness/summary.md`。该门禁状态为 `PASS_WITH_SCOPE` 时，表示模型/训练口径、量化与转换、RTL 分层仿真、PDF/Word 报告、画质 baseline、x4 720p15 scheduler FPS、x2 720p4 降目标 scheduler FPS、bitstream/PPA 和 GitHub 上传前检查均已具备可追溯证据；同时明确 `a5.board_32x32`、`a6.board_64x64`、`a7.board_720p_x4`、`x2.board` 是真实板端 validation 后续项，不作为“无真实插板要求”的赛题提交口径阻断项。

在报告/PPA 优先主线下，当前可以先提交离线模型、RTL 仿真、bitstream、OOC/implementation PPA 和风险说明材料；若评审没有真实上板要求，上述 4 项不会影响 bitstream/PPA 口径的提交。

因此，本报告的提交性质是“阶段性交付/相当报告 + bitstream/PPA 可提交版”。它已经覆盖赛题文档、模型、量化、RTL、仿真、bitstream、PPA 和验证流程要求；不足之处集中在真实板端输出、板端 FPS/功耗和 720p packed 2-D 完整硬件 bitstream。若评审确实不要求真实上板，则主要风险转为“提交 bitstream 的作用域需说明为 true2x2/tile-writer 配置，而不是 720p 完整实现”。

## 13. 可复现实验命令

关键门禁命令：

```powershell
python W8A12_3lane\tools\w8a12_3lane_reference.py a0-single-conv
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -ContinueOnError
python W8A12_3lane\tools\audit_contest_delivery.py
python W8A12_3lane\tools\generate_missing_evidence_plan.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\check_contest_scope_readiness.py
python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete
python W8A12_3lane\tools\collect_delivery_manifest.py
```

恢复 JTAG 后的首个板端命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_dbg2_source_boundary_acceptance.ps1
```

## 14. 交付文件索引

| 类别 | 路径 |
| --- | --- |
| 工作流 | `WORKFLOW.md` |
| 交付索引 | `DELIVERY_INDEX.md` |
| 状态看板 | `STATUS.md` |
| PDF 赛题报告 | `output/pdf/W8A12_3lane_contest_submission_report.pdf`、`evidence/report_pdf/summary.md` |
| Word 赛题报告 | 标准路径：`output/docx/W8A12_3lane_contest_submission_report.docx`、`evidence/report_docx/summary.md`；当前完整导出版：`output/docx/W8A12_3lane_contest_submission_report_complete_20260701.docx`、`evidence/report_docx_complete_20260701/summary.md` |
| 架构说明 | `docs/w8a12_3lane_architecture.md` |
| bank 映射 | `docs/bank_mapping_rules.md` |
| A4 scheduler 验收 | `docs/a4_scheduler_acceptance_flow.md` |
| 上板汇报规范 | `docs/board_report_flow.md` |
| JTAG 恢复清单 | `docs/jtag_recovery_checklist.md`、`evidence/board_probe/jtag_recovery_checklist/summary.md` |
| 最新上板进展 | `evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md` |
| 质量对比 | `evidence/quality_comparison/summary.md` |
| 画质指标闭环计划 | `docs/quality_metric_completion_plan.md`、`evidence/quality_metric_completion/summary.md` |
| A0-A3 reference | `evidence/reference/` |
| A4 OOC | `evidence/resource/A4_*_ooc/` |
| bitstream/PPA gate | `evidence/bitstream_ppa_gate/summary.md` |
| 赛题提交口径门禁 | `evidence/contest_scope_readiness/summary.md` |
| packed 2-D FPS scheduler | `evidence/sim_fps_design_space/packed2d_perf_scheduler/summary.md`、`evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.md`、`evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.md`、`evidence/sim_fps_design_space/packed2d_x2_720p20_perf_scheduler/summary.md` |
| x2 W8A12 导出 | `evidence/x2/w8a12_export/summary.md` |
| x2 fixed reference | `evidence/x2/reference/summary.md` |
| delivery audit | `evidence/delivery_audit/contest_delivery_audit.md` |
| submission archive summary | `evidence/submission_package/archive/summary.md` |
| GitHub 草案上传证明 | `evidence/github_upload_push/summary.md` |

## 15. 结论

当前 W8A12_3lane 已经形成可用于赛题阶段性交付/相当报告的完整离线证据链：模型训练和验证口径明确，x4/x2 FP32 画质达到目标，传统插值 baseline 已对比，W8A12 定点导出和 x2 fixed reference 已通过，A0-A4 和 top shell 的 RTL 仿真/OOC 综合均有 PASS 证据，3-lane scheduler 在 XC7Z045 资源门限内。报告、Word/PDF 导出、交付索引、证据矩阵和 GitHub 草案上传链路也已经建立。

剩余主要风险集中在真实板端 validation：true 2x2 当前历史最好仍是 `153/192` byte mismatch；2026-06-29 有效 stage-hash 续跑已经恢复 JTAG/PSU/register read，并完成上板读回，证明历史数值问题不是硬件 target 不可见，而是 PL 计算路径数值不一致。该 stage-hash 结果为输出完整 `192/192`、`frame_done=1`、`error=0`，但 compare FAIL `191/192`、PSNR 11.8292 dB，且 `tail_b1_hash` 首个边界已经不等于 RTL 期望。当前最新物理连接又回到 USB/JTAG 枚举阻塞，强制 Vivado probe 后 `Vivado target count=0`，因此不能继续板上读 dbg2 bank；恢复连接后，应直接用低侵入 dbg2 source-boundary 验证 `tail_feat0/src_feat0/src_b1`，在 `halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> b1_m_feat -> tail` 链路内收窄第一个错误点，再逐步补齐 32x32、64x64、720p x4 和 720p x2 board validation。

最终结论：若评审口径为“正确性仿真通过 + 可生成 bitstream + 提供 PPA/资源时序报告”，当前材料可以作为赛题报告/PPA 提交版，并以 `evidence/contest_scope_readiness/summary.md` 的 `PASS_WITH_SCOPE` 作为提交前门禁；若评审明确要求真实板端 32x32/64x64/720p 输出和板端 FPS/功耗实测，则严格 board-validation 口径仍为 `INCOMPLETE`，必须继续完成上板任务后刷新报告和交付包。
