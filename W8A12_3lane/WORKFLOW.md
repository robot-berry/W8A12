# W8A12_3lane 工作流

本文档是 W8A12 三路并行新主线的总入口。旧 `W8A12/` 目录只作为 legacy/reference 和 evidence 来源；新实现、验证、上板汇报优先在 `W8A12_3lane/` 下推进。

## 1. 主线目标

- 模型：SPAN x4/F48 和 SPAN x2/F48。
- 量化：W8A12，权重 INT8，激活 12-bit。
- 新架构：block 内三路 output-channel 并行。
- 通道拆分：`48ch = 3 lanes x 16ch`。
- 调度：6 个 SPAB/block 仍按 `block_i=0..5` 串行执行。
- 本地板卡：`xczu19eg-ffvc1760-2-i`。
- 资源评估：ZC706 / XC7Z045 或资源相当 FPGA。
- 报告目标：生成一份可用于赛题提交/答辩的中文技术报告，覆盖模型、量化、RTL 架构、验证方案、PPA、画质指标、风险与待上板项。

当前执行优先级调整为：

```text
P0 FPS 仿真目标 + mismatch 排查主线：
  先形成 720p x4 15fps 仿真级证据，并继续把 true2x2 板端 mismatch
  拆到更窄的 PL 数值边界。当前不先写报告，不用报告工作打断定位。

P1 可综合 RTL/PPA 主线：
  只要 Python reference、RTL xsim 和 OOC 综合报告可通过，就继续推进
  resource/timing/power/performance 表格。若板端 mismatch 尚未修复，
  PPA/性能结论必须标注为仿真/综合级或 scheduler 级。

P2 赛题报告主线：
  根据已经完成的模型、量化、RTL 仿真、PPA 和 mismatch 排查证据写报告。
  报告只汇总已完成结果和明确风险，不提前替代工程闭环。
```

第一阶段目标：

```text
32x32 LR tile + halo=21
  -> W8A12 x4
  -> 128x128 RGB
  -> bit-exact match Python W8A12 fixed-point reference
```

最终赛题目标：

```text
SD card / video frame input
  -> PS/software downsample to LR
  -> tile + halo split
  -> PL W8A12 tiled super-resolution
  -> tile stitch / crop halo
  -> 1280x720 SR output, FPS phased target: 15 first, 20 optimized, 30 stretch

x4 path: source/frame -> 320x180 LR -> tiled x4 -> 1280x720 SR, PSNR >= 28 dB
x2 path: source/frame -> 640x360 LR -> tiled x2 -> 1280x720 SR, PSNR >= 30 dB
```

## 2. 输入和输出总览

### 2.1 总输入

| 类别 | 输入 | 当前路径/来源 |
| --- | --- | --- |
| 数据集 | REDS train GT | `G:/REDS/train_sharp` |
| 数据集 | REDS train x4 LQ | `G:/REDS/train/train_sharp_bicubic/X4` |
| 数据集 | REDS val GT | `G:/REDS/val_sharp` |
| 数据集 | REDS val x4 LQ | `G:/REDS/val/val_sharp_bicubic/X4` |
| 数据清单 | REDS train meta | `configs/meta_info_REDS_train_GT.txt`，24000 images |
| 数据清单 | REDS val meta | `configs/meta_info_REDS_val_GT.txt`，3000 images |
| 数据划分口径 | 训练/验证 | 训练使用 REDS train 官方全量划分，验证使用 REDS val 官方全量划分 |
| x4 模型 | SPAN x4/F48 checkpoint、manifest、quant plan | 根目录 `runs/`、`rtl/generated/` 中已冻结资产 |
| x2 模型 | SPAN x2/F48 FP32 checkpoint | `runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth` |
| x2 模型结构 | official x2 manifest | `rtl/generated/official_span_x2/official_span_manifest.json` |
| 量化配置 | W8A12 | weight int8，activation 12-bit |
| 硬件目标 | 本地上板 | `xczu19eg-ffvc1760-2-i` |
| 资源评估目标 | 赛题等效门限 | ZC706 / `xc7z045` |

### 2.2 总输出

| 类别 | 输出 | 目标路径/证据 |
| --- | --- | --- |
| 模型说明 | x2/x4 结构、训练、量化说明 | `docs/`、`README.md`、`DELIVERY_INDEX.md` |
| 模型到硬件转换 | W8A12 quant plan、RTL manifest、postprocess manifest | `rtl/generated/reds_span_*_w8a12/`、`runs/reds_span_quant_plan/` |
| Python 定点参考 | A0/A1/A2/A3/x2 reference summary、hash、RGB 输出 | `evidence/reference/`、`evidence/x2/reference/` |
| RTL 源码 | 3-lane MAC/scheduler/tile/top RTL | `rtl/span/`、`rtl/top/` |
| 仿真证据 | xsim PASS summary/log | `evidence/top/`、`evidence/resource/` |
| 综合证据 | OOC utilization/timing/resource summary | `evidence/top/*_ooc/`、`evidence/resource/*_ooc/` |
| bitstream/上板 | bitstream、SD/DDR 输入、tile 输出拼接后的 720p board output、board-vs-fixed 比对 | `evidence/board_reports/<tag>/` |
| PPA 汇报 | LUT/FF/BRAM/DSP、timing、latency、FPS、target_fps、power | `evidence/board_reports/<tag>/summary.md` |
| 赛题报告 | 可提交中文技术报告，含摘要、方案、模型训练量化、硬件架构、验证、PPA、画质对比、风险说明 | `docs/contest_submission_report.md`、`output/pdf/W8A12_3lane_contest_submission_report.pdf`、`output/docx/W8A12_3lane_contest_submission_report.docx`、`evidence/report_pdf/summary.md`、`evidence/report_docx/summary.md` |
| 交付清单 | 审计、缺口、submission manifest、确定性提交草案归档、repository scope manifest | `evidence/delivery_audit/`、`evidence/submission_package/`、`evidence/submission_scope/` |

### 2.3 分阶段输入输出

| 阶段 | 输入 | 输出 | 通过条件 |
| --- | --- | --- | --- |
| A0 单层 conv | W8A12 x4 manifest、单层权重、测试 feature tile | lane0/1/2/full48 输出和 hash | RTL 与 Python bit-exact |
| A1 单 SPAB block | A0 输出、block1 C1/C2/C3/LUT/attention 参数 | block output hash | RTL 与 Python bit-exact |
| A2 6 blocks | 6 个 SPAB block 参数、feature ping-pong 规则 | block1..block6 boundary hash | block6 hash 匹配 |
| A3 tail/RGB | A2 feature、tail/reconstruct/pixelshuffle 参数 | RGB tile、`rgb_q_hash` | RGB 与 Python fixed reference bit-exact |
| A4 scheduler/OOC | A0-A3 reference、3-lane MAC scheduler RTL | xsim summary、OOC utilization/timing | xsim PASS，XC7Z045 resource/timing PASS |
| x2 export/reference | x2 checkpoint、official manifest、REDS val calibration input | x2 W8A12 manifest、quant plan、reference summary | scale=2、F48、W8A12、RGB hash、PSNR 目标证据 |
| A5 board 32x32 | bitstream、32x32 LR tile、fixed reference | board output、validation report | `FRAME_DONE=1`、`ERROR=0`、bit-exact |
| A6 board 64x64 | bitstream、64x64 LR tile、fixed reference | board output、resource/perf report | 正确性、资源、时序 PASS |
| A7 720p | SD 输入帧、PS 降采样 LR、tile+halo 切块、bitstream、board runtime | 拼接后的 1280x720 输出、FPS/latency/power/PSNR/SSIM/preview | 初版 `fps >= 15`，优化 `fps >= 20`，冲刺 `fps >= 30`；x4 PSNR >=28 dB、x2 PSNR >=30 dB |

## 3. 双倍率画质目标

| 倍率 | 目标 | 当前训练证据 | 硬件验收要求 |
| --- | --- | --- | --- |
| x4 | REDS_val PSNR `>= 28 dB` | SPAN x4/F48 `28.3118 dB @ 295000 iter` | W8A12 fixed-point、RTL、board 输出一致 |
| x2 | REDS_val PSNR `>= 30 dB` | SPAN x2/F48 `34.4297 dB @ 300000/300001 iter` | W8A12 quant plan、RTL manifest、postprocess manifest、fixed reference 和 validation 已 PASS；board evidence 待补 |

x2 训练 PSNR 已超过 30 dB；当前已经生成 x2 W8A12 导出和固定点 reference。最终仍需给出 x2 bitstream、板端输出和 `x2_720p/validation.md Status: PASS`。

## 4. 核心文档

| 文档 | 作用 |
| --- | --- |
| `README.md` | 新主线目录入口 |
| `DELIVERY_INDEX.md` | 上传/评审交付索引 |
| `STATUS.md` | A0-A7 状态看板 |
| `docs/contest_submission_report.md` | 可提交赛题中文技术报告主文档 |
| `docs/legacy_readonly_policy.md` | 旧线只读和复用策略 |
| `docs/w8a12_3lane_architecture.md` | 三路并行架构说明 |
| `docs/accelerator_top_shell.md` | 板端 accelerator top shell 和 status 映射 |
| `docs/bank_mapping_rules.md` | lane、feature bank、weight bank、tail 和 hash 映射 |
| `docs/layered_reference_flow.md` | A0-A5 分层 reference 和验收流程 |
| `docs/python_reference_plan.md` | Python reference、数据集、checkpoint、A0 计划 |
| `docs/a4_scheduler_acceptance_flow.md` | A4 MAC scheduler 仿真、资源验收和回退流程 |
| `docs/delivery_gate_runner.md` | 一键门禁执行脚本、日志目录和结果解读 |
| `docs/a2_a3_tile_scheduler_contract.md` | A2/A3 tile pipeline 控制接口和 ping-pong 契约 |
| `docs/x2_fixed_reference_contract.md` | x2 W8A12 fixed reference 输入、输出和验收契约 |
| `docs/failure_rollback_flow.md` | 分层失败回退流程 |
| `docs/board_report_flow.md` | 全流程上板汇报规范 |
| `docs/quality_metric_completion_plan.md` | 画质指标分层、W8A12 fixed 全量评测和 board 实测补齐计划 |
| `docs/contest_delivery_audit.md` | 赛题交付项和当前缺口审计 |
| `docs/github_upload_plan.md` | 上传到 robot-berry/W8A12 前的文件清单和注意事项 |
| `evidence/board_reports/2x2_board_config_audit_20260626.md` | true 2x2 与 32x32 已跑通例程的 PS/DDR/AXI 参数对照 |
| `evidence/board_reports/ps_axi_lite_register_probe_20260627.md` | 最小 AXI-Lite register-only bitstream 的上板隔离结果 |
| `evidence/board_reports/jtag_w8a12_config_audit_20260627.md` | JTAG-to-AXI 例程与 JTAG-W8A12 true2x2 的器件、时钟、复位、AXI 地址参数对照 |

## 5. 硬性验收门

| 验收门 | 要求 | 证据 |
| --- | --- | --- |
| 软件定点参考 | 选定 x2/x4 模型可以跑通 Python integer reference | reference JSON、输出 RGB/PNG、hash |
| RTL 仿真 | xsim 在模块级和 tile 级对齐 fixed-point reference | xsim 日志、compare summary |
| bitstream | Vivado implementation 完成并生成 `.bit` | bitstream、implementation log |
| 上板 smoke | `FRAME_DONE=1`，`ERROR=0` | XSCT/JTAG 或 SD/DDR summary |
| 正确性 | board output 与 fixed reference bit-exact | mismatch 报告、preview |
| 资源门限 | 不超过 XC7Z045/ZC706 口径 | resource gate JSON/MD |
| 时序门限 | WNS/WHS 非负 | timing report |
| 上板汇报 | 每次完整上板必须生成 board report | `evidence/board_reports/<tag>/summary.md` |
| 赛题报告 | 形成可提交中文技术报告，明确已完成证据和待上板风险 | `docs/contest_submission_report.md` |

赛题报告是 P0 主线的最终提交入口，不只作为过程说明文档。报告完成标准如下：

- `docs/contest_submission_report.md` 可以独立阅读，覆盖赛题要求的模型结构、训练、量化、转换工具、硬件架构、验证方案、PPA、画质对比和风险说明。
- 报告中的关键指标和结论必须能追溯到 `evidence/`、`rtl/generated/`、`runs/` 或 Vivado/xsim 输出，不能只写口头结论。
- `tools/check_contest_submission_report_static.py` 必须 PASS，并生成 `evidence/report_static/summary.md`。
- `DELIVERY_INDEX.md` 和 submission manifest 必须收录该报告及其依赖证据。
- PDF 赛题报告由 `scripts/export_contest_report_pdf.ps1` 从 Markdown 报告导出，并在 `evidence/report_pdf/summary.md` 记录页数、SHA256、关键文本和渲染检查。
- Word 赛题报告由 `scripts/export_contest_report_docx.ps1` 从 Markdown 报告导出，并在 `evidence/report_docx/summary.md` 记录 SHA256 和可见文本黑色字体审计；`output/docx/W8A12_3lane_contest_submission_report.docx` 作为可提交 Word 版本。

赛题报告至少包含以下章节：

```text
1. 摘要和赛题目标对应关系
2. REDS 数据集、训练/验证全量口径和 x2/x4 画质目标
3. SPAN x2/x4 F48 模型结构
4. W8A12 量化方法、校准口径、fixed reference 和模型到 RTL 转换
5. 三路并行硬件架构、feature/weight bank、scheduler、top shell
6. RTL 仿真验证：A0/A1/A2/A3/A4/top/x2 reference
7. 综合与 PPA：LUT/FF/BRAM/DSP、WNS/WHS、功耗/性能估计口径
8. 画质对比：FP32、W8A12 fixed、传统插值 baseline
9. 上板计划和当前风险：JTAG、2x2 mismatch、32x32/64x64/720p 待测
10. 结论、可复现实验命令和交付文件索引
```

### 5.1 最小上板 bring-up 当前断点

当前必须优先完成“最小图像上板通路”，再进入交付审计和 720p 拼接：

| 阶段 | 当前结论 | 证据/路径 |
| --- | --- | --- |
| 32x32 bitstream | 已能生成并上板运行，但输出不正确 | `vivado/bitstreams/ps_w8a12_ddr_tile_writer_x4_imgw32x32_tile32x32_h21_f50m_ol1_tl4_sl1_ddr_runtime_wrdebug32_20260625a.bit` |
| 32x32 上板 smoke | `FRAME_DONE=1`、写回计数非零，但 board-vs-reference mismatch 约 49k/49k，PSNR 约 5 dB | `board_runs/w8a12_ps_ddr_tile_writer_smoke/live_retry_20260625_direct` |
| 输入 DDR | 已验证 PS 写入 DDR 的输入像素正确；2x2 runtime readback mismatch=0 | `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_runtime_2x2_20260625_2230` |
| 2x2 runtime 复用 32x32 bit | 不可行；32x32 bit 内部 `TILE_W/TILE_H/OUT_PIXELS` 固化，2x2 runtime 会触发 core error | 同上，`STATUS=0x00000039`、`ERROR=0x00000005` |
| 真 2x2 RTL/endpoint 仿真 | PASS；2x2->8x8 endpoint compare mismatch=0 | `W8A12_3lane/evidence/board_reports/2x2_samplelatch_result_20260626.md` |
| 真 2x2 bitstream | PASS；`ImgW=2 ImgH=2 TileW=2 TileH=2`，route/timing/bitstream 已完成 | `b/w8a12_2x2_samplelatch_20260626_2229/.../psw8a12ddr_wrapper.bit` |
| 真 2x2 参数配置对照 | PS/DDR/AXI 基础参数与 32x32 已跑通例程一致；未发现 `ctrl_base`、DDR preset、HPM/HP 端口配置错误 | `W8A12_3lane/evidence/board_reports/2x2_board_config_audit_20260626.md` |
| 最小 AXI-Lite register-only probe | bitstream/implementation PASS，烧录 PASS；但正常 `psu_init` AP timeout，跳过 `psu_init` 后读 `0xA0000000` 仍报 A53 `EDITR not ready` | `W8A12_3lane/evidence/board_reports/ps_axi_lite_register_probe_20260627.md` |
| JTAG-to-AXI register probe | 历史 PASS；`0xA0000000` magic/scratch 曾可通过 Vivado Hardware Manager JTAG-to-AXI 读写。重插后 target 可见；补跑对应 `psu_init.tcl` 后最小 `jtag_axi_register_probe_f26m.bit` 已恢复 PASS，`hw_axi_1` 可见 | `W8A12_3lane/evidence/board_reports/jtag_w8a12_config_audit_20260627.md`、`W8A12_3lane/evidence/board_reports/jtag_after_replug_20260628.md`、`W8A12_3lane/evidence/board_reports/jtag_after_psuinit_20260628.md` |
| JTAG-W8A12 true 2x2 smoke 工具 | 已补齐脚本；bitstream 生成后可直接执行烧录、2x2 输入、8x8 输出读回、bit-exact 对比和 summary 生成 | `scripts/run_jtag_w8a12_tile_writer_smoke.ps1` |
| 真 2x2 JTAG 上板 smoke baseline | PASS；旧 `inpixfix` bitstream 复跑得到 `input=4/output=64/frame_done=1/error=0` 和 192B 输出，但 board-vs-reference 仍非 bit-exact，PSNR `44.0265 dB` | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_inpixfix_rerun_20260627_cfgcheck`、`W8A12_3lane/evidence/board_reports/jtag_true2x2_config_recheck_20260627.md` |
| 真 2x2 JTAG 参数复核 | BD/JTAG 参数与例程对齐；`IMG_W=2/IN_PIXELS=4/OUT_PIXELS=64/OUT_IDX_W=6` 已写入 XCI。新 `epwbh` debug bitstream 上板卡在 `status=0x00002000(core_busy)`，说明当前主要问题不是上板 base/width/scale 漏配；源码已将 `ENABLE_DEBUG_WB_HASH` 默认关闭，2x2 RTL raw compare 仍 PASS/mismatch=0 | `W8A12_3lane/evidence/board_reports/jtag_true2x2_config_recheck_20260627.md` |
| 真 2x2 特殊输入与重建 bitstream 复核 | 旧 `inpixfix` 特殊输入为小幅数值偏差：black `53/192`、gray128 `110/192`、ramp `114/192`；当前源码用 `SynthDirective=Default` 重建后与旧 baseline 上板输出 byte-identical，标准 2x2 为 `153/192`、max diff 4、PSNR 44.0265 dB；`RuntimeOptimized` 的 `currnodbg`/`nodebugrevert` 会退化到 `189/192`、`185/192`，不作为 correctness 主线 | `W8A12_3lane/evidence/board_reports/jtag_true2x2_special_input_and_currnodbg_20260627.md` |
| 真 2x2 debugregs/progress trace | 已接出 writer writeback hash/range/first/last 到 AXI-Lite `0x30..0x3c`；`dbgregs` 版本补跑 PS init 后可见 `hw_axi_1`，但停在 `counter_out=0/frame_done=0`。随后新增 `0x04` endpoint progress、`0x08` front state、`0x10` block/replay 计数，RTL raw compare 仍 PASS；新 `dbgprogress` bitstream 上板可完整输出 `192/192` 且 `frame_done=1`，但退化为 `189/192` mismatch、PSNR 16.3034 dB，writeback hash `0xAD24396D != 0x61D3EA1D` | `W8A12_3lane/evidence/board_reports/jtag_true2x2_dbgregs_20260627.md`、`W8A12_3lane/evidence/board_reports/jtag_after_replug_20260628.md`、`W8A12_3lane/evidence/board_reports/jtag_after_psuinit_20260628.md`、`W8A12_3lane/evidence/board_reports/jtag_true2x2_dbgprogress_20260628.md` |
| 真 2x2 stage-hash 定位 | 已把 `0x04/0x08/0x10` 从宽 progress 读数改为更窄的 `tail_b1_hash/tail_b6_act1_hash/tail_rgb_q_hash`；行为级 RTL raw compare 仍 PASS，期望 hash 为 `0x16ede1c2/0xc7a092b8/0xb712a61b/0x61d3ea1d`；Default bitstream 已生成且 timing PASS；已新增 `scripts/run_w8a12_stagehash_true2x2_acceptance.ps1` 一键入口；当前 wrapper 与续跑 probe 均卡在 `VIVADO_HW_TARGET_COUNT=0`，最新证据为 `board_runs/vivado_hw_target_probe_goal_continue_20260628_b` | `W8A12_3lane/evidence/board_reports/jtag_true2x2_stagehash_20260628.md` |
| Vivado 策略 | correctness bring-up 固定 `SynthDirective=Default`；`RuntimeOptimized` 只可在 bit-exact 闭环后作为 PPA 优化候选重新评估 | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_defaultrebuild_20260627.bit` |

最小上板递进顺序：

```text
2x2 true bitstream PASS
  -> JTAG-to-AXI register probe 恢复 PASS，0xA0000000 可写可读
  -> 上板校验输入计数 input=4，输出计数 output=64
  -> 校验 FRAME_DONE=1 / ERROR=0 / output bytes=192/192
  -> 当前 Default baseline 为 153/192 mismatch、max diff 4
  -> debug-progress bitstream 已证明 2x2 可完整输出，但输出退化到 189/192 mismatch，不能作为 correctness baseline
  -> 回到 Default/inpixfix 153/192 baseline，加更窄 stage hash，对齐 tail_b1/tail_b6_act1/tail_rgb_q/writeback 与 RTL 期望
  -> board output bit-exact match 2x2 Python W8A12 fixed reference
  -> 4x4
  -> 8x8
  -> 32x32
  -> tile+halo 720p 拼接
```

Vivado 启动注意事项：

1. 不要从 PowerShell 直接 `& vivado.bat ...` 作为主流程；`.bat` 参数可能被错误解析。
2. 优先使用 `scripts/run_vivado_bitstream_ps_w8a12_ddr_tile_writer.ps1`，它内部通过 `cmd.exe /d /s /c call vivado.bat ...` 启动 Vivado。
3. 2x2/4x4 bring-up 优先使用 `-SynthDirective Default`，不要使用默认 `RuntimeOptimized`。
4. 2x2 完整实现可能超过 15 分钟；不要用短超时截断。若已经生成 synth DCP，可尝试 `scripts/resume_vivado_ps_w8a12_ddr_tile_writer_from_synth_dcp.tcl` 从 checkpoint 继续实现。
5. 若 Codex/shell stdout 出现 `Exception ignored on flushing sys.stdout`，不要判定设计失败；以 Vivado log、monitor log、`.bit`、`.dcp` 文件为准。
6. Vivado 2025.2 在当前环境下对一批很长的 Tcl 全局变量名或环境变量名不稳定；多个 `PS_W8A12_DDR_TILE_WRITER_*` 或 `::psw8a12ddr_*` 变量可能导致 Vivado 只写 log 头部后 `-1` 退出。
7. 已验证可执行自定义 Tcl 的稳定入口是 `scripts/run_vivado_tcl_checkstyle.ps1`；最小 probe `scripts/vivado_puts_probe.tcl` 和许可证 probe 均 PASS。
8. 当前 true 2x2 已有完整 bitstream，路径为 `b/w8a12_2x2_samplelatch_20260626_2229/psw8a12ddr_true2x2_samplelatch_20260626_2229/ps_w8a12_ddr_tile_writer.runs/impl_1/psw8a12ddr_wrapper.bit`。
9. 后续若重新生成 true 2x2 bitstream，再使用 `Default` synthesis 路径，并以 `.bit`、route status、timing report 和 resource gate 为准。

为什么 TinySPAN 上板更顺：

```text
TinySPAN:
  模型小，buffer 少，BD/RTL/bitstream 链路短，之前已有较稳定的上板 smoke 路线。

W8A12 SPAN F48:
  6 个 SPAB + 48ch + W8A12 定点 + DDR writer + tile/halo + XC7Z045 资源门限一起 bring-up。
  true 2x2 bitstream 已生成；当前主要难点是板端 PS/AXI-Lite 控制口或 PL AXI-Lite slave 响应恢复。
```

### 5.2 2026-06-29 stage-hash 实板续跑补充

本轮 mismatch 排查已经从“JTAG target 不可见”推进到真实板端数值 mismatch：

| 项目 | 结果 |
| --- | --- |
| USB/JTAG/Vivado target | PASS，USB known candidate=3，Vivado probe exit=0 |
| PS 初始化 | PASS，`PSU_INIT_ONLY_PASS=1` |
| true2x2 输出 | 完整输出 `192 / 192` bytes |
| frame_done / error | `1 / 0x00000000` |
| compare | FAIL，`191 / 192` mismatch |
| PSNR | `11.8292 dB` |
| 最早失败边界 | `tail_b1_hash=0x031DA1C9 != 0x16ede1c2` |

当前判断：问题不是板子未插、JTAG 不通、PSU init 失败或寄存器读回失败，而是 PL 计算路径实板数值偏差。由于 `tail_b1_hash` 已经偏离 RTL 期望，下一轮优先增加 `feat0/input/halo/block1 c1/c2/c3/att` 更窄 hash，把问题继续拆到 front/SPAB block1 或更前路径。

证据：

```text
W8A12_3lane/evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md
board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/
```

### 5.3 2026-06-29 debug-bank 细粒度定位补充

已在 `rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v` 中给 6-bit JTAG AXI-Lite endpoint 增加 debug bank，而不扩展地址宽度。`REG_PERF_CTRL[15:8]` 选择 bank，`REG_PERF_CTRL[0]` 仍为 `perf_drain_enable`，因此旧 stage-hash 脚本在 bank 0 下保持兼容。

| Bank | 读数 |
| --- | --- |
| `0` | 原 `tail_b1/tail_b6_act1/tail_rgb_q/writeback_*` |
| `1` | `tail_feat0/src_feat0/src_b1/spab_b1_input/c1/c2/c3` |
| `2` | `spab_b1_c1_raw/c2_replay/c2_window/residual/att` 以及 tail cross-check |

`scripts/read_jtag_w8a12_tile_writer_regs.tcl` 现在会自动切换 bank 1/2 并输出 `JTAG_W8A12_REG_DEBUG_SPAB_B1_*` 字段，`scripts/run_read_jtag_w8a12_tile_writer_regs.ps1` 会把这些字段写入 summary JSON/Markdown。

行为级 true2x2 raw compare 已按 stage-hash 同一输入/参考重新通过：

| 项目 | 结果 |
| --- | --- |
| mismatch | `0 / 192` |
| max diff | `0` |
| `tail_b1_hash` | `0x16ede1c2` |
| `tail_b6_act1_hash` | `0xc7a092b8` |
| `tail_rgb_q_hash` | `0xb712a61b` |
| `writeback_hash` | `0x61d3ea1d` |

下一步：重新生成 debug-bank bitstream 并上板读取 bank 1/2，把 `tail_b1_hash` 的首次偏差继续拆到 `tail_feat0/src_feat0/src_b1/spab_b1_input/c1/c2/c3/residual/att`。

证据：

```text
W8A12_3lane/evidence/board_reports/jtag_true2x2_debugbank_20260629.md
build/xsim_jtag_w8a12_debugbank_refcmp_20260629/
```

### 5.4 2026-06-29 debug-bank 实板结果

debug-bank bitstream 已完成实现并生成 `.bit`：

| 项目 | 结果 |
| --- | --- |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_debugbank_20260629.bit` |
| timing | PASS，WNS `12.267ns`，WHS `0.009ns` |
| resource | LUT `40363`，FF `116367`，BRAM tile `311`，DSP `126` |
| board preflight | READY，USB known JTAG candidate `3` |
| PSU init | PASS |

但该 all-in-one debug-bank 版本上板后没有输出像素：

| 项目 | 结果 |
| --- | --- |
| output bytes | `0 / 192` |
| counter in/out | `4 / 0` |
| frame_done | `0x00000000` |
| error | `0x00000000` |
| status | `0x00002000` |
| delayed read | 延迟 10 秒后仍为 `counter_out=0/frame_done=0` |
| live state | `writer_busy=1/front_busy=1/state=3` |

为排除板子/JTAG/脚本问题，复跑旧 `stagehash_20260628` baseline bitstream。baseline 可完整输出：

| 项目 | 结果 |
| --- | --- |
| output bytes | `192 / 192` |
| frame_done / error | `1 / 0x00000000` |
| counter in/out | `4 / 64` |
| compare | FAIL，`190 / 192` mismatch |
| PSNR | `14.3819 dB` |

当前判断：

1. 板子、JTAG、PSU、输出读回脚本仍然可用。
2. baseline 仍然是 PL 数值 mismatch，最早可见边界仍需围绕 `tail_b1_hash` 之前继续拆。
3. 一次性挂上 bank1/bank2 多组内部 hash 的 debug-bank 版本太侵入，导致板端 busy stall，不能作为下一步定位依据。
4. 下一步应回退到旧 stage-hash baseline，新增低侵入 single-bank/single-group bitstream；每轮只导出 `feat0/src_feat0/src_b1` 或只导出 `block1 C1` 一组信号。

证据：

```text
W8A12_3lane/evidence/board_reports/jtag_true2x2_debugbank_board_20260629.md
board_runs/jtag_w8a12_tile_writer/true2x2_debugbank_acceptance_20260629/
board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_baseline_recheck_after_debugbank_20260629/
```

### 5.4.1 2026-06-29 dbg0/nondebug 当前复测

为区分“调试探针导致板端 stall”和“当前源码在不导出调试信号时是否仍可回到 baseline 行为”，已生成 `DebugExportLevel=0` bitstream：

| 项目 | 结果 |
| --- | --- |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg0_true2x2_jtagaxi_dbg0_nondebug_20260629.bit` |
| implementation | PASS，WNS `12.797ns`，WHS `0.009ns` |
| resource | LUT `38964`，FF `115912`，BRAM tile `311`，DSP `125` |
| RTL raw compare | PASS，`0 / 192` mismatch |
| board probe | FAIL，`VIVADO_HW_TARGET_COUNT=0` |
| XSCT psu_init | FAIL，未发现 PS/PMU/DAP target |
| smoke | FAIL，Vivado exit `1`，输出 `0 / 192` bytes |

本轮未进入 W8A12 计算路径，不能作为新的数值 mismatch 证据；失败原因是 Vivado/XSCT 当前没有枚举到 hardware target。历史有效定位不回退：最早可见的数值失败边界仍在 `tail_b1_hash`，待 JTAG target 恢复后继续在 `halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> b1_m_feat -> tail` 链路内查找第一个错误点。

证据：

```text
W8A12_3lane/evidence/board_reports/jtag_true2x2_dbg0_nondebug_board_20260629.md
board_runs/jtag_w8a12_tile_writer/true2x2_dbg0_nondebug_acceptance_20260629/
```

### 5.4.2 2026-06-29 dbg2/source-boundary 低侵入探针准备

已将 debug 等级拆分为：

| Level | 含义 | 用途 |
| --- | --- | --- |
| `0` | 不导出 debug bank | 恢复非调试语义 |
| `1` | 只导出 tail/writeback stage-hash | 复现历史 `tail_b1_hash` 边界 |
| `2` | 只打开 source/tap 边界 hash，不打开 SPAB deep hash | 下一轮优先上板定位 |
| `3` | 打开 SPAB block1 deep hash bank2 | 仅当 level2 证明需要深入 SPAB 内部时使用 |

`DebugExportLevel=2` true2x2 source-boundary 版本已经完成 RTL 仿真和 bitstream 生成：

| 项目 | 结果 |
| --- | --- |
| RTL raw compare | PASS，`0 / 192` mismatch |
| frame cycles | `7202120` |
| bank0 tail b1/b6/rgb/writeback | `0x16ede1c2 / 0xc7a092b8 / 0xb712a61b / 0x61d3ea1d` |
| bank1 source-boundary | `tail_feat0=0x000004bf`，`src_feat0=0x00000004`，`src_b1=0x00070004` |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg2_true2x2_jtagaxi_dbg2_src_boundary_20260629.bit` |
| timing | PASS，WNS `12.072ns`，WHS `0.010ns` |
| resource | LUT `40501`，FF `116379`，BRAM tile `311`，DSP `126` |
| board status | 当前 USB known JTAG candidate `0`，Vivado/JTAG 上板仍 blocked |

已新增一键入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_dbg2_source_boundary_acceptance.ps1
```

该脚本会先执行 board recovery preflight；若 `jtag_precondition_current` 为 `READY`，自动使用上述 dbg2 位流进入 true2x2 上板验收；若板卡不可见，则生成 `BLOCKED` summary，不误入烧录。当前实测结果为 `BLOCKED`：USB known JTAG candidate `0`，强制 Vivado probe 后 target count `0`。

板子恢复可见后，重新运行上述一键脚本即可；若 dbg2 完整输出，则比较 bank1 source-boundary hash，用于判断错误是在 halo/conv1/source tap 之前，还是在 `b1_m_feat` replay/tail 交界之后。

证据：

```text
W8A12_3lane/evidence/board_reports/jtag_true2x2_dbg2_src_boundary_prepare_20260629.md
W8A12_3lane/evidence/board_reports/jtag_true2x2_dbg2_src_boundary_current/summary.md
build/xsim_jtag_w8a12_tile_writer_raw_compare_dbg2_src_boundary_bankread/
vivado/jwtw_true2x2_jtagaxi_dbg2_src_boundary_20260629/
```

### 5.5 2026-06-29 FPS 仿真目标补充

当前 FPS 结论必须区分 correctness RTL 与 performance scheduler：

| 层级 | 结论 |
| --- | --- |
| 当前 3-lane correctness RTL | A5 32x32 可满足 15fps 估算；A6/720p/x2 不满足 |
| packed 2-D performance scheduler | 720p x4 scheduler-level xsim 已满足 15fps |
| 20/30fps | 当前完整 W8A12/F48 在 900-DSP 规划门限内不满足 |

packed 2-D xsim gate：

| Candidate | Est. DSP | Cycles/LR pixel | FPS @250MHz | 15fps |
| --- | ---: | ---: | ---: | --- |
| `24x64` | 792 | 288 | 15.070 | PASS |
| `24x72` | 888 | 248 | 17.501 | PASS |

该 PASS 是 scheduler/performance-model 级别，不是完整 packed 2-D 像素计算 RTL 的 bit-exact PASS，也不是板端实测 FPS。后续要把 720p15 变成可交付实现，必须继续实现 packed 2-D engine、memory banking 和 line-buffer/halo reuse。

x2 720p20 packed 2-D scheduler 补充：

| Candidate | Est. DSP | Cycles/LR pixel | FPS @250MHz | 900-DSP gate | 20fps |
| --- | ---: | ---: | ---: | --- | --- |
| `24x64` | 792 | 281 | 3.861 | PASS | FAIL |
| `24x72` | 888 | 242 | 4.483 | PASS | FAIL |
| `48x144` | 3504 | 63 | 17.223 | FAIL | FAIL |

结论：新增 x2 720p20 的 scheduler/performance-model xsim 证据已经生成，但当前完整 W8A12/F48 packed 2-D 规划在 XC7Z045/ZC706 900-DSP 门限下不能闭合 20fps。该项作为性能边界证据收录；若要达成 x2 720p20，需要更小的 student model、更高资源/频率，或比当前 packed 2-D 规划更激进的复用和并行架构。

证据：

```text
W8A12_3lane/evidence/sim_fps_design_space/fps_target_status_20260629.md
W8A12_3lane/evidence/sim_fps_design_space/packed2d_perf_scheduler/summary.md
W8A12_3lane/evidence/sim_fps_design_space/packed2d_x2_720p20_perf_scheduler/summary.md
```

## 6. 资源口径

| 项目 | 数值 |
| --- | --- |
| 本地板卡器件 | `xczu19eg-ffvc1760-2-i` |
| 赛题等效目标 | ZC706 / `xc7z045` |
| LUT 上限 | 218600 |
| FF/REG 上限 | 437200 |
| BRAM Tile 上限 | 545 |
| DSP 上限 | 900 |

规则：

1. 本地上板可以使用 `xczu19eg-ffvc1760-2-i`。
2. 每份 utilization report 必须按 XC7Z045/ZC706 门限检查。
3. 通过大板卡但超过 XC7Z045 资源门限的版本，不是有效赛题候选。

## 7. 分层执行流程

| 阶段 | 目标 | 通过标准 |
| --- | --- | --- |
| A0 | 单层 3-lane conv | 与 Python layer reference bit-exact |
| A1 | 单个 SPAB block | block output 与 Python block reference bit-exact |
| A2 | 6 block feature | block6 feature hash 匹配 |
| A3 | tail/pixelshuffle/RGB | RGB tile 与 Python reference bit-exact |
| A4 | OOC/resource/timing | XC7Z045 resource gate PASS，timing PASS |
| A5 | board 32x32 | `FRAME_DONE=1`，`ERROR=0`，board RGB 匹配 reference |
| A6 | board 64x64 | 正确性、资源、时序均 PASS |
| A7 | tile-based 720p 输出 | SD/DDR 输入 -> PS 降采样 -> LR tile+halo -> PL tiled SR -> crop halo 拼接 1280x720；FPS 分级目标 15/20/30 |

不允许跳过失败阶段。

## 8. 三路并行规则

按输出通道拆分：

```text
lane0: output channels  0..15
lane1: output channels 16..31
lane2: output channels 32..47
```

每个 lane 必须读取完整 48 个输入通道：

```text
for out_ch in lane range:
  acc = sum(in_ch=0..47, ky=0..2, kx=0..2)
```

禁止第一版按 input-channel 拆 lane。

## 9. Feature Bank 规则

```text
feature_bank0: channels  0..15
feature_bank1: channels 16..31
feature_bank2: channels 32..47
```

公式：

```text
bank_id = ch / 16
bank_ch = ch % 16
ch = bank_id * 16 + bank_ch
```

ping-pong 第一版：

| block_i | input buffer | output buffer |
| ---: | --- | --- |
| 0 | A | B |
| 1 | B | A |
| 2 | A | B |
| 3 | B | A |
| 4 | A | B |
| 5 | B | A |

block5 完成后，最终 feature 在 buffer A。

## 10. Python Reference 流程

当前训练/验证集：

```text
REDS train: 24000 images，官方 train 全量训练集
REDS val:   3000 images，官方 val 全量验证集
```

模型侧训练和 PSNR/SSIM 验证均按 REDS 官方全量划分统计；上板 smoke、tile 级 correctness 和量化校准样本只用于工程闭环，不替代全量 REDS val 画质指标。

第一步建立：

```text
tools/w8a12_3lane_reference.py
```

第一版命令：

```powershell
python W8A12_3lane/tools/w8a12_3lane_reference.py a0-single-conv
```

输出：

```text
evidence/reference/A0_single_conv/
  input_feature.npy
  lane0_output.npy
  lane1_output.npy
  lane2_output.npy
  full48_output.npy
  hashes.json
  summary.md
```

## 11. 上板汇报流程

上板前必须先形成 Vivado JTAG target 探测证据：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe_vivado_hw_targets.ps1 -OutputDir board_runs\vivado_hw_target_probe_w8a12_3lane
W8A12_3lane\scripts\check_vivado_hw_probe_log.cmd --probe-dir board_runs\vivado_hw_target_probe_w8a12_3lane
```

验收条件：`evidence/board_probe/vivado_hw_probe.md` 显示 `Status: PASS`，且 Vivado probe 日志包含 `VIVADO_HW_TARGET_PROBE_PASS=1`。若当前板卡连接状态变化，先运行 `W8A12_3lane/scripts/run_w8a12_board_recovery_preflight.ps1` 并查看 `evidence/board_probe/jtag_precondition_current/summary.md`；只有 USB known candidate 非 0 且 `VIVADO_HW_TARGET_COUNT>=1` 时，才进入 stage-hash 上板验收。

每次完成全流程上板后，必须生成：

```text
evidence/board_reports/<tag>/summary.md
evidence/board_reports/<tag>/summary.json
```

必须汇报：

- 上板状态：`FRAME_DONE`、`ERROR`、输出像素数、mismatch；
- 资源：LUT、FF/REG、BRAM Tile、DSP 和 XC7Z045 占比；
- 时序：WNS、WHS；
- 性能：clock、latency、FPS、target_fps、DDR 读写量、power；
- 超分效果：PSNR、SSIM、board-vs-fixed bit-exact、preview；
- 文件证据：bitstream、utilization/timing/power report、resource gate、reference output、board output。

详细模板见：

```text
docs/board_report_flow.md
```

## 12. 失败回退规则

总原则：

1. 哪一层失败，就回退到该层最小复现。
2. 不跳过失败层。
3. 不同时修改多个可疑模块。
4. 每次只改变一个变量。
5. 失败记录写入 `failure_summary.md`。

详细规则见：

```text
docs/failure_rollback_flow.md
```

## 13. 当前下一步

当前离线门禁已推进到 `72 / 76`。新增赛题报告、PDF/Word 报告导出、PPA 汇总、报告完整性检查、画质指标闭环门禁、stage-hash 上板流程静态检查、board validation readiness、submission manifest/archive、contest scope readiness 和 evidence matrix 已通过或纳入门禁，原严格交付审计剩余 4 项仍均为真实板端 validation：

```text
a5.board_32x32
a6.board_64x64
a7.board_720p_x4
x2.board
```

当前阶段不把真实上板作为唯一主线，而是先完成赛题相当报告和 PPA 材料。执行顺序调整为：

1. 汇总模型结构、训练/验证全量口径、x2/x4 PSNR/SSIM、传统插值 baseline 对比。
2. 汇总 W8A12 量化导出、manifest、Python fixed reference 和 RTL 对齐证据。
3. 汇总 A0/A1/A2/A3/A4/top shell 的 xsim、OOC utilization、timing 和资源占比。
4. 对 PPA 表格明确标注统计范围：模块级 OOC、scheduler OOC、top shell OOC、真实板端估计/待测，不能把轻量 top shell 资源误写成完整 accelerator datapath 资源。
5. 继续生成交付索引、硬件设计说明、验证方案和回退流程。
6. 运行 `tools/check_contest_scope_readiness.py`，把“赛题提交口径 PASS_WITH_SCOPE”和“严格 board-validation INCOMPLETE”分开记录。
7. 运行 `tools/create_contest_scope_package.py`，生成赛题口径提交包摘要；严格上板归档继续保留 `INCOMPLETE` 风险说明。
8. mismatch 修复作为次级风险项放入第 14 节清单，恢复 JTAG 后继续按清单推进。

当前硬件探测结果仍作为板端风险记录。历史 stage-hash 续跑曾恢复 USB/JTAG、PSU init 和寄存器读回，并定位到 `tail_b1_hash` 首个边界失败；最新 dbg2/source-boundary 一键验收则因 USB known JTAG candidate count=0 处于 `BLOCKED`，待连接恢复后继续读 `tail_feat0/src_feat0/src_b1`：

```text
Historical stage-hash: W8A12_3lane/evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md
Current dbg2/source-boundary: W8A12_3lane/evidence/board_reports/jtag_true2x2_dbg2_src_boundary_current/summary.md
Current blocker: USB known JTAG candidate count = 0, Vivado target count = 0 after forced probe
Next command after recovery: W8A12_3lane/scripts/run_w8a12_dbg2_source_boundary_acceptance.ps1
```

当前第一步仍不是直接跑 32x32，而是先固定 PS init + JTAG-to-AXI 前置流程，再重跑 debugregs true 2x2：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_dbgregs_20260627.bit -ImgW 2 -ImgH 2 -Scale 4 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_dbgregs_retry
```

判定规则：

- RTL 期望 writeback hash：`0x61d3ea1d`。
- 若冷启动或重插后显示 `design has no supported soft debug core(s)`，先运行对应工程的 `psu_init.tcl`，再检查/重建 JTAG AXI probe bitstream、`.ltx`/probes 和 `refresh_hw_device` 识别链路。
- 若板端 debug hash 一致但 `board_output.rgb` 仍 mismatch，则重点查 endpoint 输出缓存/JTAG 读回。
- 若板端 debug hash 不一致，则重点查 writer 前 PL 计算路径或综合后行为。

板端 2x2 修到 bit-exact 或误差边界被解释后，再进入板端扩展：

```text
32x32 x4 -> 64x64 x4 -> 720p x4 -> 720p x2
```

## 14. 板图缺失对指标的影响

没有真实板端输出图时，指标必须分层汇报，不能混写：

| 指标类别 | 当前能否汇报 | 口径 |
| --- | --- | --- |
| FP32 模型画质 | 可以 | 使用 REDS val 全量 GT/LQ 计算 PSNR/SSIM；x4 当前证据 `28.3118 dB`，x2 当前证据 `34.4297 dB` |
| 传统插值 baseline | 可以 | 使用 REDS val 全量 nearest/bilinear/bicubic，与 FP32 SPAN 对比 |
| W8A12 fixed-point 画质 | 可以继续补 | 使用 Python fixed reference 输出和 REDS val GT 计算；若 RTL 与 fixed reference bit-exact，则可作为 RTL 等效画质 |
| RTL 仿真正确性 | 可以 | xsim/compare 证明 RTL 输出与 Python fixed reference bit-exact，但这是仿真正确性，不是板端实测 |
| OOC 资源/时序 PPA | 可以 | Vivado OOC utilization/timing 可汇报 LUT/FF/BRAM/DSP/WNS/WHS；需标明统计对象是 MAC/scheduler/top shell 等模块级结果 |
| 功耗估计 | 可以作为估计 | 可用 Vivado power report 或向量缺省估计；必须标注为 estimated，不等同板端实测功耗 |
| FPS/latency 理论值 | 可以作为估计 | 可由仿真 cycle count 和 clock 推算；必须标注为 simulated/estimated |
| 板端 PSNR/SSIM/preview | 不能声称已完成 | 需要真实 `board_output.rgb/png` 后才能计算和展示 |
| 板端 FPS/power | 不能声称已完成 | 需要真实 bitstream 运行日志、计时和功耗记录 |

报告主线允许先完成“赛题相当”的离线和 RTL/PPA 证据，但最终板端章节必须明确写 `待上板验证` 或 `board evidence pending`。在没有板图输出前，超分效果指标只能写为模型/定点/RTL 等效指标，不能写成板端实测指标。

## 15. Mismatch 次级排查清单

当前有效板端 baseline：

```text
true 2x2 x4: 2x2 -> 8x8
output bytes: 192 / 192
frame_done: 1
error: 0
mismatch: 153 / 192 bytes
max channel diff: 4
PSNR: 44.0265 dB
```

已通过/已排查项：

| 项目 | 状态 | 证据/结论 |
| --- | --- | --- |
| A0 单层 3-lane conv | PASS | RTL 与 Python bit-exact |
| A1 单 SPAB block | PASS | block output hash 匹配 |
| A2 6 block feature | RTL SIM PASS | block6 hash 匹配 |
| A3 tail/pixelshuffle/RGB | RTL SIM PASS | `rgb_q_hash` 匹配 |
| A4 single-lane/3-lane scheduler | PASS | xsim/OOC 均 PASS |
| top shell | PASS | xsim/OOC 均 PASS |
| x2 W8A12 export/reference | PASS | manifest、postprocess、fixed reference validation 均 PASS |
| 输入 DDR readback | PARTIAL PASS | 2x2 runtime input readback mismatch=0 |
| true 2x2 RTL endpoint | PASS | RTL raw compare `0/192 mismatch` |
| true 2x2 bitstream/timing | BUILD PASS | bitstream 已生成，timing PASS |
| PS/DDR/AXI 参数审计 | PASS | true 2x2 与已跑通例程参数对齐 |
| JTAG-to-AXI register probe | PASS after PS init | 6 月 27 日 `0xA0000000` magic/scratch 曾可读写；6 月 28 日重插后未 PS init 时不可见，补跑 `psu_init.tcl` 后 `jtag_axi_register_probe_f26m.bit` PASS |
| Default synthesis baseline | REPRODUCED | 当前源码 Default 重建与旧 baseline 输出 byte-identical |

未通过/风险项：

| 项目 | 状态 | 影响 |
| --- | --- | --- |
| true 2x2 board output bit-exact | FAIL | 当前 `153/192` mismatch，不能作为最终板端正确性证据 |
| RuntimeOptimized bitstream | FAIL/DEGRADED | mismatch 退化到 `189/192` 或 `185/192`，暂不用于 correctness |
| debugregs/progress 上板读取 | FAIL / MORE LOCALIZED | Vivado hardware target 与 JTAG-to-AXI master 已恢复；`dbgregs` 版本曾停在 `counter_out=0`，新 `dbgprogress` 版本可完整输出 `192/192`、`frame_done=1`，但 `189/192` mismatch 且 writeback hash 不等于 RTL 期望 |
| 32x32 board validation | FAIL/PENDING | 旧 32x32 有 frame_done 和写回，但 mismatch 很大 |
| 64x64/720p/x2 board validation | PENDING | 依赖 2x2/32x32 正确性闭环 |

下一步排查顺序：

1. 冷启动/重插后先运行对应工程的 `psu_init.tcl`，再恢复 `get_hw_axis`。
2. 以最小 `jtag_axi_register_probe_f26m.bit` PASS 作为 JTAG-to-AXI 前置门禁。
3. 已重跑 debug-progress true 2x2：`counter_in=4`、`counter_out=64`、`frame_done=1`、输出 `192/192`，但 `189/192` mismatch。
4. 因 `writeback_hash=0xAD24396D` 不等于 RTL 期望 `0x61D3EA1D`，当前优先查 writer 前或 writer 数据生成边界，而不是 endpoint 输出缓存/JTAG 读回。
5. 回退到 Default/inpixfix 的 `153/192` 历史最好 baseline，加更窄、低扰动的 `tail_rgb_q_hash`、`block6_hash`、writer input first/last。
6. 若新 hash 一致但 board output 仍 mismatch，再查 endpoint 输出缓存/JTAG 读回；若 hash 不一致，继续查 front/SPAB、tail/pixelshuffle/RGB。
7. 若继续不收敛，优先补 writer-only pattern、postprocess-only、tail/pixelshuffle-only 三个最小上板验证。

已完成的离线门禁仍可一键复跑：

完整门禁入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_delivery_gates.ps1 -ContinueOnError
```

该脚本会把每一步日志写入：

```text
evidence/delivery_runs/<RunId>/
```

已通过的关键离线证据：

```text
evidence/top/accel_top_sim/summary.md
evidence/top/accel_top_ooc/ooc_summary.md
evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md
evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md
evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.md
evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.md
evidence/ppa_summary/summary.md
evidence/contest_scope_readiness/summary.md
evidence/contest_scope_package/summary.md
evidence/report_static/summary.md
evidence/x2/w8a12_export/summary.md
evidence/x2/reference/summary.md
evidence/x2/reference_validation/validation.md
evidence/quality_comparison/summary.md
```

当前交付审计见：

```text
evidence/delivery_audit/contest_delivery_audit.md
```

OOC 和上板校验工具：

```text
tools/summarize_ooc_result.py
tools/validate_board_report.py
tools/check_vivado_hw_probe_log.py
tools/generate_missing_evidence_plan.py
tools/collect_delivery_manifest.py
tools/check_contest_scope_readiness.py
tools/create_contest_scope_package.py
scripts/run_delivery_gates.ps1
```

x2 readiness 见：

```text
evidence/x2/reference_readiness/readiness.md
evidence/x2/w8a12_export/summary.md
evidence/x2/reference_validation/validation.md
```
