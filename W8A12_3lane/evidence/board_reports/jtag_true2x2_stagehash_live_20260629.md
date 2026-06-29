# JTAG true2x2 stage-hash 实板续跑记录

日期：2026-06-29

## 结论摘要

本轮 mismatch 排查仍在继续，并且已经越过了之前的“板卡/JTAG 不可见”阻塞点。

当前结论：

| 项目 | 结果 |
| --- | --- |
| USB/JTAG 预检 | PASS，known JTAG candidate = 3 |
| Vivado hardware target | PASS，probe exit = 0 |
| `psu_init.tcl` | PASS，`PSU_INIT_ONLY_PASS=1` |
| JTAG-to-AXI smoke | FAIL，但已完整输出 `192 / 192` bytes |
| frame done | PASS，`frame_done=1` |
| error flags | PASS，`0x00000000` |
| register readback | PASS |
| 输出 compare | FAIL，`191 / 192` byte mismatch，PSNR `11.8292 dB` |

这说明当前问题已经不是“板子没插上 / JTAG 不通 / PS 初始化失败”，而是真正的板端数值 mismatch。最新 stage-hash 读数显示最早的 `tail_b1_hash` 已经偏离 RTL 期望，因此当前优先怀疑 front/SPAB block1 边界或更前的输入/halo/feature 生成路径。

## 本轮修复的脚本问题

在第一次续跑时，`run_w8a12_stagehash_true2x2_acceptance.ps1` 发生假失败：`probe_vivado_hw_targets.ps1` 实际 exit 为 0，但 wrapper 函数把 `Tee-Object` 的日志行也作为函数返回值，导致 `$probeExit -ne 0` 误判为真。

已修复：

```text
scripts/run_w8a12_stagehash_true2x2_acceptance.ps1
scripts/run_w8a12_board_recovery_preflight.ps1
```

随后 PSU init 进入下一层后又暴露绝对路径拼接问题：上层传入绝对 `OutputDir`，`run_xsct_psu_init_only.ps1` 又执行 `Join-Path $root $OutputDir`，在 Windows 下形成非法路径。

已修复：

```text
scripts/run_xsct_psu_init_only.ps1
```

这些修复只影响板端自动化脚本，不改变 RTL datapath 数学逻辑。

## 上板命令

预检 + stage-hash acceptance：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1 -OutputDir board_runs\w8a12_board_recovery_preflight\stagehash_current_20260629_144313 -PreconditionOutDir W8A12_3lane\evidence\board_probe\jtag_precondition_stagehash_current -ForceVivadoProbe -RunStageHashAcceptance
```

由于默认 wrapper 在 smoke mismatch 后停止，随后使用 `ContinueOnError` 续跑，让流程继续读 debug hash 寄存器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_w8a12_stagehash_true2x2_acceptance.ps1 -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_stagehash_continue_20260629_144641 -ContinueOnError
```

## 关键证据

| 证据 | 路径 |
| --- | --- |
| preflight summary | `board_runs/w8a12_board_recovery_preflight/stagehash_current_20260629_144313/board_recovery_preflight_summary.md` |
| stage-hash continue summary | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/stagehash_true2x2_acceptance_summary.md` |
| smoke summary | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/smoke/jtag_w8a12_tile_writer_smoke_summary.md` |
| compare summary | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/smoke/compare/w8a12_compare_summary_x4_2x2.md` |
| register readback summary | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/reg_read_after_smoke/read_jtag_w8a12_tile_writer_regs_summary.md` |
| board output | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/smoke/board_output.rgb` |
| board preview | `board_runs/jtag_w8a12_tile_writer/true2x2_stagehash_continue_20260629_144641/smoke/compare/w8a12_board_x4_2x2.png` |

## 实板输出指标

| 指标 | 数值 |
| --- | ---: |
| 输入像素 | `4` |
| 输出像素 | `64` |
| 输出字节 | `192 / 192` |
| mismatch bytes | `191 / 192` |
| max channel diff | `155` |
| MAE | `53.90625` |
| MSE | `4267.34375` |
| PSNR | `11.8292273260548 dB` |
| frame cycles | `7202120` |
| e2e cycles | `7202120` |

## stage-hash 对比

行为级 RTL true2x2 期望：

| 边界 | RTL 期望 |
| --- | --- |
| `tail_b1_hash` | `0x16ede1c2` |
| `tail_b6_act1_hash` | `0xc7a092b8` |
| `tail_rgb_q_hash` | `0xb712a61b` |
| `writeback_hash` | `0x61d3ea1d` |
| `writeback_range` | `0x4e9f0040` |
| `writeback_first` | `0x0061605d` |
| `writeback_last` | `0x007a6366` |

本轮实板读回：

| 边界 | 实板读回 | 是否匹配 |
| --- | --- | --- |
| `tail_b1_hash` | `0x031DA1C9` | FAIL |
| `tail_b6_act1_hash` | `0x75D95D8A` | FAIL |
| `tail_rgb_q_hash` | `0x6B02FBCF` | FAIL |
| `writeback_hash` | `0x14D11085` | FAIL |
| `writeback_range` | `0x00FE0040` | FAIL |
| `writeback_first` | `0x00403C51` | FAIL |
| `writeback_last` | `0x000D0000` | FAIL |

解释：

1. JTAG endpoint 的 AXI-Lite 地址宽度为 6 bit，因此当前 JTAG true2x2 bitstream 将 `tail_b1_hash/tail_b6_act1_hash/tail_rgb_q_hash` 重映射到低地址 `0x04/0x08/0x10`，这是预期设计。
2. `tail_b1_hash` 是本轮最早读到的边界 hash，它已经与 RTL 期望不一致。
3. 因此当前 mismatch 优先定位到 front/SPAB block1 边界或更前的输入/halo/feature 生成路径，而不是 endpoint/JTAG 读回路径。

## 后续排查清单

| 排查项 | 目的 | 当前状态 |
| --- | --- | --- |
| JTAG/PSU/preflight | 确认板端可烧录、可访问 AXI-Lite | PASS |
| 2x2 output full length | 确认输出通路不再卡死 | PASS，`192 / 192` |
| register readback | 确认 debug hash 可读 | PASS |
| `tail_b1_hash` 对齐 | 判断 block1/更前路径是否正确 | FAIL |
| 加 `feat0/input/halo` hash | 区分输入 fetch/halo 与 block1 compute | TODO |
| block1 单模块板端小核/ILA 或更窄 debug regs | 定位 block1 C1/C2/C3/attention 哪一段偏 | TODO |
| writer-only pattern test | 排除 writer/endpoint 输出缓存问题 | TODO，优先级低于 block1 |

下一步建议先在 JTAG endpoint 增加更窄的 `feat0_hash`、`src_b1_hash`、`block1 c1/c2/c3/att hash` 读数，保持 true2x2、小 lanes、小 tap lanes，重新生成 debug bitstream。目标是把 `tail_b1_hash` 的首次偏差继续向前拆到 input/halo、block1 C1、block1 C2、block1 C3 或 attention。
