# W8A12_3lane 状态看板

| 阶段 | 状态 | 最新证据 | 备注 |
| --- | --- | --- | --- |
| A0 单层 3-lane conv | PASS | `evidence/reference/A0_single_conv/a0_rtl_sim_summary.md` | Python reference 和 RTL xsim 均通过，`stitched_hash == full48_hash == 0x080D3C47` |
| A1 单个 SPAB block | PASS | `evidence/reference/A1_single_block/a1_rtl_sim_summary.md` | Python reference 和 RTL xsim 均通过，`block_output_hash == 0xD12E1B43` |
| A2 6 block feature | RTL SIM PASS / TILE SHELL STATIC PASS | `evidence/reference/A2_tile_pipeline_shell/tile_pipeline_shell_static_check.md` | 6 个 SPAB block 的 3-lane RTL 语义仿真已通过，`block_6_output_hash == 0xD2AC6553`；tile pipeline shell 静态检查 22 项 PASS，真实 tile scheduler 待接入 datapath |
| A3 tail/pixelshuffle/RGB | RTL SIM PASS / BOARD TODO | `evidence/reference/A3_tail_rgb/a3_rtl_sim_summary.md` | Tail/RGB RTL 语义仿真已通过，`rgb_q_hash == 0x280F9356`；板端 writer 待接入 |
| A4 OOC/resource/timing | PASS | `evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md`；`evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md`；`evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.md`；`evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.md` | single-lane xsim PASS；3-lane xsim PASS；single-lane OOC：LUT 41003、FF 85414、DSP 224、WNS 1.261ns、WHS 0.072ns；3-lane OOC：LUT 123182、FF 256222、DSP 672、WNS 1.188ns、WHS 0.072ns，均低于 ZC706/XC7Z045 门限 |
| A5 board bring-up | IN_PROGRESS | `evidence/board_reports/2x2_samplelatch_result_20260626.md`；`evidence/board_reports/2x2_board_config_audit_20260626.md`；`evidence/board_reports/ps_axi_lite_register_probe_20260627.md`；`evidence/board_reports/jtag_w8a12_config_audit_20260627.md`；`evidence/board_reports/jtag_true2x2_special_input_and_currnodbg_20260627.md`；`evidence/board_reports/jtag_true2x2_dbgregs_20260627.md`；`evidence/board_reports/jtag_after_replug_20260628.md`；`evidence/board_reports/jtag_after_psuinit_20260628.md`；`evidence/board_reports/jtag_true2x2_dbgprogress_20260628.md` | true 2x2 RTL raw compare PASS；旧 `inpixfix` 与当前 `Default` 重建 bitstream 的上板输出 byte-identical，均为 `153/192` mismatch、max diff 4、PSNR 44.0265 dB；重插后 Vivado target 与最小 JTAG-to-AXI 已恢复。`dbgregs` 版本曾停在 `counter_out=0`；新 `dbgprogress` 版本能完整输出 `192/192` 且 `frame_done=1`，但退化为 `189/192` mismatch、PSNR 16.3034 dB，writeback hash `0xAD24396D != 0x61D3EA1D`，说明偏差在 writer 前或 writer 数据生成边界 |
| A6 64x64 tile | TODO |  | 依赖 A5 |
| A7 tile-based 720p 输出 | TODO |  | SD/DDR 输入，PS 降采样，LR tile+halo 送 PL，拼接 1280x720；FPS 分级目标 15/20/30 |

## 当前画质目标

| 倍率 | 目标 | 当前训练证据 | 硬件状态 |
| --- | --- | --- | --- |
| x4 | REDS_val PSNR >= 28 dB | 28.3118 dB @ 295000 iter | W8A12_3lane 尚未闭环 |
| x2 | REDS_val PSNR >= 30 dB | 34.4297 dB @ 300000/300001 iter | W8A12 x2 quant plan、RTL manifest、postprocess manifest、fixed reference 和 validation 已 PASS；板端 x2_720p 仍待上板 |

## 最新上板汇报

| Tag | 状态 | 关键结果 | 后续动作 |
| --- | --- | --- | --- |
| `live_retry_20260625_direct` | FAIL | 32x32 bitstream 上板 `FRAME_DONE=1`、写回非零，但 board-vs-reference mismatch 约 49k/49k，PSNR 约 5 dB | 不作为交付证据；用于定位 PL compute/writeback 问题 |
| `wrdebug32_runtime_2x2_20260625_2230` | PARTIAL PASS | 使用 32x32 bitstream 跑 2x2 runtime 时，输入 DDR 校验 mismatch=0；但内部 tile 尺寸固化导致 `ERROR=0x00000005` | 必须生成 true 2x2 bitstream |
| `true2x2_samplelatch_20260626_2229` | BUILD PASS / BOARD FAIL | true 2x2 bitstream 已生成，timing PASS；板测 JTAG/program PASS，但首次写 `0xA0000000` AP transaction timeout | 下一个动作是物理重上电后重跑，若仍失败则用最小 AXI-Lite register-only bit 隔离 |
| `true2x2_a53first_skippsu_stop_20260626` | BOARD ACCESS FAIL | 跳过 `psu_init`、优先 A53 并执行 stop 后，仍报 `EDITR not ready` | 表明当前失败不只是 `psu_init` 顺序问题 |
| `2x2_board_config_audit_20260626` | CONFIG PASS | true 2x2 与 32x32 已跑通例程的 PS/DDR/AXI 参数一致，`psu_init.tcl` hash 一致 | 参数配置不是当前首要嫌疑 |
| `ps_axi_lite_register_probe_20260627` | BUILD/PROGRAM PASS / BOARD ACCESS FAIL | 最小 AXI-Lite register-only bitstream 已生成并烧录；正常 `psu_init` 在 `0xFF1800B4` AP timeout，skip `psu_init` 后读 `0xA0000000` 仍 `EDITR not ready` | 当前优先处理板端 PS/JTAG/XSCT 调试访问状态 |
| `jtag_w8a12_config_audit_20260627` | JTAG CONFIG PASS / ROUTE RUNNING | JTAG register probe 已验证 `0xA0000000` magic/scratch 读写；JTAG-W8A12 true2x2 与例程在器件、PL clock/reset、AXI-Lite 地址上对齐 | 当前瓶颈是完整 W8A12 JTAG endpoint 的 Vivado route 收敛，不是板卡参数漏配 |
| `run_jtag_w8a12_tile_writer_smoke.ps1` | TOOL READY | 已补齐 JTAG-W8A12 上板包装脚本，可生成 raw 输出、bit-exact compare、JSON/Markdown summary | 等待 true2x2 JTAG-W8A12 bitstream 生成后执行 |
| `jtag_true2x2_special_input_and_currnodbg_20260627` | BOARD BASELINE RECOVERED / MISMATCH OPEN | 旧 `inpixfix` 特殊输入偏差为小幅数值误差；当前 `Default` 重建 bitstream 与旧 baseline 上板输出 byte-identical：标准 2x2 为 `153/192`、max diff 4、PSNR 44.0265 dB；`RuntimeOptimized` 的 `currnodbg`/`nodebugrevert` 会退化到 `189/192`、`185/192` | correctness bring-up 固定 `SynthDirective=Default`；下一步做 post-synth/post-impl netlist raw compare，或加首尾输出/hash 低扰动 trace，定位剩余 `153/192` 小幅偏差 |
| `jtag_true2x2_dbgregs_20260627` | RTL/BUILD PASS / JTAG AXI NOT VISIBLE | endpoint 已接出只读 writeback debug regs；行为 RTL raw compare 仍 PASS，`mismatch=0/192`，期望 hash/range/first/last 为 `0x61d3ea1d`/`0x4e9f0040`/`0x0061605d`/`0x007a6366`；debugregs bitstream timing PASS，LUT 39261、REG 116070、BRAM 311、DSP 126；重插后 target 可见，但 `get_hw_axis` 返回空，输出 0/192，尚未进入数据 compare | 先让最小 register probe 重新识别 `1 JTAG AXI core(s)`，再用 debugregs bitstream 重跑 2x2，对比板端 debug hash 判断 mismatch 在 writer 前还是 endpoint/读回后 |
| `jtag_after_replug_20260628` | TARGET PASS / JTAG AXI FAIL | Vivado target count=1，device count=2，`xczu19_0` 可见；`jtag_axi_register_probe_f25m.bit` 和 W8A12 debugregs bitstream program 后均提示 no supported soft debug core，`get_hw_axis` 为空 | 优先检查/重建 JTAG AXI register-probe bitstream、`.ltx`/probes 和 refresh/hw_server 识别链路 |
| `jtag_after_psuinit_20260628` | JTAG AXI PASS / W8A12 NO OUTPUT | 先跑对应 `psu_init.tcl` 后，`jtag_axi_register_probe_f26m.bit` PASS：`hw_axi_1`、magic `0x57384158`、scratch `0xA5A55A5A`；W8A12 debugregs bitstream 也可见 `hw_axi_1`，输入 `4/4`、`REG_COUNTER_IN=4`，状态 `0x00002000=core_busy`，但 `REG_COUNTER_OUT=0`、`FRAME_DONE=0`、输出 `0/192` | JTAG/PS 初始化问题已排除；下一步查 endpoint/datapath 在输入接受后为何 core busy 不结束、没有推进到 output/writeback |
| `jtag_true2x2_dbgprogress_20260628` | BUILD PASS / BOARD FAIL | 新 progress bitstream timing PASS，WNS `12.317 ns`；LUT 39337、REG 116119、BRAM 311、DSP 126。上板 `frame_done=1`、`counter_in=4`、`counter_out=64`、输出 `192/192`，但 compare FAIL：`189/192` mismatch、PSNR 16.3034 dB；寄存器读数 `block_start=6`、`replay_feature=24`、writeback hash `0xAD24396D` | 证明 no-output 被越过，但该宽 debug 版本不能作为 correctness baseline；下一步回到 Default/inpixfix baseline，加更窄的 stage hash 查 front/SPAB、tail/RGB、writer input |
| `jtag_true2x2_stagehash_20260628` | RTL/BUILD PASS / JTAG TARGET FAIL | stage-hash 寄存器映射已改为 `tail_b1_hash`、`tail_b6_act1_hash`、`tail_rgb_q_hash` 和 `writeback_*`；行为级 RTL raw compare 仍为 `0/192` mismatch，期望 hash 为 `0x16ede1c2`、`0xc7a092b8`、`0xb712a61b`、`0x61d3ea1d`；Default bitstream 已生成，WNS `11.772 ns`、WHS `0.009 ns`、LUT 39951、REG 116172、BRAM 311、DSP 126；post-synth 长跑未形成 PASS/FAIL；最新 JTAG probe `vivado_hw_target_probe_goal_continue_20260628_b` 仍为 `VIVADO_HW_TARGET_COUNT=0`，当前 USB 在线列表无 Xilinx/FTDI known candidate | stage-hash 上板物料已就绪；下一步先恢复 JTAG target，再烧录 bitstream 读取 stage hash，把 mismatch 定位到 front/SPAB、tail/RGB、writer 或 endpoint/readback |
| `jtag_true2x2_stagehash_live_20260629` | BOARD FAIL / LOCALIZED | 重插后续跑已恢复 USB/JTAG 与 Vivado target：USB known candidate=3，Vivado probe exit=0，`psu_init.tcl` PASS。stage-hash Default bitstream 上板后完整输出 `192/192`、`frame_done=1`、`error=0`，但 compare FAIL：`191/192` mismatch、PSNR 11.8292 dB。寄存器读回 PASS，实板 hash 为 `tail_b1=0x031DA1C9`、`tail_b6_act1=0x75D95D8A`、`tail_rgb_q=0x6B02FBCF`、`writeback=0x14D11085`，均不等于 RTL 期望 | 已确认当前不是 JTAG/PSU/读回阻塞，而是真实板端数值 mismatch；最早失败边界为 `tail_b1_hash`，下一步加 `feat0/input/halo/block1 c1/c2/c3/att` 更窄 hash |
| `jtag_true2x2_debugbank_20260629` | RTL PASS / BOARD NEXT | JTAG endpoint 已新增 `REG_PERF_CTRL[15:8]` debug bank；bank 0 保持旧 `tail/writeback` 读数，bank 1 暴露 `tail_feat0/src_feat0/src_b1/spab_b1_input/c1/c2/c3`，bank 2 暴露 `spab_b1_c1_raw/c2_replay/c2_window/residual/att`。同一 true2x2 输入/参考行为级 raw compare PASS：`0/192` mismatch、max diff 0，旧 hash 仍为 `0x16ede1c2/0xc7a092b8/0xb712a61b/0x61d3ea1d` | 下一步生成 debug-bank bitstream 并上板读 bank 1/2，把 `tail_b1_hash` 偏差拆到 block1 内部或更前输入路径 |
| `jtag_true2x2_dbg2_src_boundary_20260629` | RTL/BUILD PASS / CURRENT JTAG BLOCKED | 已将 debug 等级拆为 0/1/2/3；dbg2 只打开 source/tap 边界 hash，不打开 SPAB deep bank。RTL raw compare PASS：`0/192` mismatch；bank0 hash 为 `0x16ede1c2/0xc7a092b8/0xb712a61b/0x61d3ea1d`，bank1 为 `tail_feat0=0x000004bf`、`src_feat0=0x00000004`、`src_b1=0x00070004`。bitstream 已生成，WNS `12.072ns`、WHS `0.010ns`、LUT `40501`、FF `116379`、BRAM `311`、DSP `126`。一键验收 wrapper 当前输出 BLOCKED：USB known JTAG candidate=0 | 恢复板卡 USB/JTAG 枚举后，直接运行 `W8A12_3lane/scripts/run_w8a12_dbg2_source_boundary_acceptance.ps1`，用 bank1 hash 判断错误是在 halo/conv1/source tap 之前，还是 replay/tail 交界之后 |
| `p2_project_impl_1` | BUILD DEBUG | 项目 run 模式能启动 `synth_1/impl_1`，但生成的 run Tcl 子进程只写 Vivado 头部，未执行 source 内容 | 暂不作为交付路径；用于 Vivado 环境诊断 |

## 当前板卡探测

| 项目 | 状态 | 证据 | 备注 |
| --- | --- | --- | --- |
| Windows/USB 级探测 | CURRENT BLOCKED / HISTORICAL READY | `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md`；`board_runs/w8a12_board_recovery_preflight/dbg2_src_boundary_current/board_recovery_preflight_summary.md` | 最新 current summary：USB match=3、known JTAG candidate=0；历史 USB known candidate=3 记录只作上板过程证据 |
| Vivado JTAG target 探测 | CURRENT BLOCKED / HISTORICAL READY | `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md`；`board_runs/w8a12_board_recovery_preflight/dbg2_src_boundary_current/vivado_probe`；历史 `board_runs/w8a12_board_recovery_preflight/vivado_probe` | 当前强制 Vivado probe 后 target count=0；历史 Vivado target count=1 证明链路曾恢复 |
| JTAG-to-AXI master 探测 | PASS after PS init | `board_runs/jtag_axi_register_probe/after_replug_f26m_after_psuinit_20260628` | `psu_init` 后最小 register probe PASS，`hw_axi_1` 可见，magic/scratch 可读写 |
| W8A12 true2x2 debugregs | FAIL after input | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_dbgregs_after_psuinit_20260628` | 输入 `counter_in=4`，但 `counter_out=0`、`frame_done=0`、输出 `0/192` |
| stage-hash prebuild target probe | FAIL | `board_runs/vivado_hw_target_probe_stagehash_prebuild_20260628`、`board_runs/jtag_w8a12_tile_writer/stagehash_prebuild_jtag_alive_20260628` | 最新探测 `VIVADO_HW_TARGET_COUNT=0`，当前不能继续板上读 stage hash；需先恢复 JTAG target |
| stage-hash bitstream 后 target probe | FAIL | `board_runs/vivado_hw_target_probe_after_stagehash_bit_20260628` | `VIVADO_HW_TARGET_COUNT=0`，USB 当前在线列表无 known Xilinx/FTDI candidate；bitstream 已生成但尚未能上板烧录 |
| stage-hash acceptance wrapper | FAIL at probe | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_acceptance_wrapper_20260628` | 一键入口已补齐；当前第一步 probe 返回 `VIVADO_HW_TARGET_COUNT=0`，尚未进入 PS init/smoke/reg-read |
| goal continuation target probe | FAIL | `board_runs/vivado_hw_target_probe_goal_continue_20260628_b` | `VIVADO_HW_TARGET_COUNT=0`；USB 在线 match=3、known candidate=0，历史可见 FTDI `VID_0403&PID_6010`，说明当前 PC 侧没有在线 Xilinx/FTDI JTAG 枚举 |
| JTAG precondition current | BLOCKED | `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md` | USB known candidate=0、Vivado target count=0；下一步先恢复 USB/JTAG 枚举 |
| JTAG force Vivado probe current | HISTORICAL READY | `W8A12_3lane/evidence/board_probe/recovery_preflight_force_vivado_current/board_recovery_preflight_summary.md` | 历史强制 Vivado probe 显示 USB known candidate=3、Vivado target count=1；不代表当前连接态 |
| W8A12 board recovery preflight | BLOCKED | `board_runs/w8a12_board_recovery_preflight/dbg2_src_boundary_current/board_recovery_preflight_summary.md` | 当前板卡链路不能进入 stage-hash/debug-bank 上板；恢复后重新运行 dbg2 wrapper |
| JTAG recovery checklist | CURRENT BLOCKED / HISTORICAL READY | `W8A12_3lane/evidence/board_probe/jtag_recovery_checklist/summary.md`；`W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md` | checklist 保留物理恢复流程；最新 current precondition 为 BLOCKED |
| 2026-06-29 stage-hash live retry | PASS TO MISMATCH | `W8A12_3lane/evidence/board_reports/jtag_true2x2_stagehash_live_20260629.md` | JTAG/PSU/register read 均已通过，true2x2 输出完整但 `tail_b1_hash` 首个边界失败，继续查 front/SPAB block1 或更前输入/halo 路径 |

## 当前交付审计

```text
状态：INCOMPLETE
通过：72 / 76
剩余缺口：4
剩余项：a5.board_32x32、a6.board_64x64、a7.board_720p_x4、x2.board
最新轻量门禁：evidence/delivery_runs/current_usb_diag_enhanced_20260630/summary.md，静态项、JTAG recovery checklist、contest_report_pdf、contest_report_docx、contest_report_docx_artifact、delivery_evidence_matrix、board stage-hash flow、board validation readiness、submission_archive / submission_archive_final 和 hard_gate_runner_static 均 PASS，最终 submission_manifest / delivery_audit 因真实板端 validation 缺失保持 FAIL
提交草案归档：evidence/submission_package/archive/summary.md，Status=INCOMPLETE，SHA256 见该文件；该 zip 是草案，不代表最终赛题交付完成
```

审计入口：

```text
W8A12_3lane/evidence/delivery_audit/contest_delivery_audit.md
W8A12_3lane/evidence/delivery_audit/missing_evidence_plan.md
```

## 当前最近缺口

1. A5 x4 32x32 board validation 仍缺 `Status: PASS`，当前 true 2x2 上板有效 baseline 是 `153/192` bytes mismatch、max diff 4、PSNR 44.0265 dB。
2. A6 x4 64x64 board validation 依赖 A5 正确性闭环。
3. A7 x4 720p tiled board validation 依赖 A6 和完整 tile+halo crop-stitch，上板汇报需包含资源、时序、FPS、latency、power、PSNR/SSIM 和输出文件。
4. x2_720p board validation 的 W8A12 x2 导出和 fixed reference 已具备，仍缺真实板端 bitstream/output/validation。
5. 当前技术阻塞点已推进到“W8A12 true2x2 板端数值不一致”，但最新物理连接前置条件又回到 JTAG 枚举阻塞：USB known JTAG candidate=0，强制 Vivado probe 后 Vivado target count=0。恢复 JTAG 后，需直接运行 dbg2/source-boundary 验收，在历史 `tail_b1_hash` 边界之前继续收窄。
