# A4 资源综合收敛计划

当前 A0-A2 已证明三路 output-channel 并行的数学语义正确，但 A4 资源评估不能直接综合 reference 级 `span_w8a12_conv_layer`。原因是该 wrapper 面向仿真和 bit-exact 验证，常量 bank 和 48x9 tap 乘加网络会被综合器大规模展开，导致 OOC 综合长时间不收敛。

## 1. 已尝试

| 对象 | Top | 结果 | 证据 |
| --- | --- | --- | --- |
| 3-lane conv | `w8a12_3lane_conv_layer_ooc_top` | 超时，未生成 utilization report | `evidence/resource/A4_conv_ooc/ooc_timeout_summary.md` |
| single-lane conv | `w8a12_single_lane_conv_ooc_top` | 超时，未生成 utilization report | `evidence/resource/A4_single_lane_conv_ooc/ooc_timeout_summary.md` |
| MAC core | `w8a12_lane_mac_core` | OOC resource gate PASS，TAP_PAR=8 使用 8 DSP | `evidence/resource/A4_lane_mac_core_ooc/mac_core_ooc_summary.md` |
| single-output scheduler | `w8a12_single_out_mac_scheduler` | RTL sim PASS，对齐 A0 lane0 ch0 | `evidence/resource/A4_single_out_mac_scheduler/single_out_scheduler_sim_summary.md` |
| single-lane scheduler | `w8a12_single_lane_mac_scheduler` | RTL 已实现，Vivado sim 需重跑 | `evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_status.md` |

## 2. 收敛路线

A4 后续改为三级资源基线：

1. `lane_mac_core_ooc`
   - 输入：一个输出通道的 48x9 taps。
   - 参数：`TAP_PAR`，建议从 8 或 16 起步。
   - 目标：证明 MAC 核资源、Fmax、DSP/LUT 取舍。
   - 当前进度：TAP_PAR=8 已通过功能仿真和 XC7Z045 resource gate，使用 8 DSP、51 LUT、49 FF。

2. `single_lane_scheduler_ooc`
   - 输入：完整 48ch window。
   - 输出：16 个 output channels。
   - 常量：同步 ROM/BRAM 读，不使用大规模组合常量展开。
   - 目标：得到单 lane 可综合资源。
   - 当前进度：已完成 single-output-channel scheduler RTL 仿真，证明 TAP_PAR=8 分批 MAC + requant 可对齐 A0 output channel 0；single-lane wrapper 已实现，等待 Vivado sim 重跑确认。

3. `three_lane_block_ooc`
   - 三个 single lane 并行。
   - 每 lane 输出 16ch。
   - 目标：得到一个 3-lane conv stage 的资源估计。

## 3. XC7Z045 门限

资源报告必须继续按 ZC706 / XC7Z045 口径检查：

| 资源 | 门限 |
| --- | --- |
| LUT | 218600 |
| FF/REG | 437200 |
| BRAM Tile | 545 |
| DSP | 900 |

检查工具：

```powershell
python tools\check_vivado_zc706_resource_gate.py <utilization.rpt> --json-out <gate.json>
```

## 4. 验收

A4 不能只给脚本，必须至少包含：

- `utilization_ooc.rpt`
- `timing_ooc.rpt`
- `xc7z045_resource_gate.json`
- 中文 summary，说明资源占比、频率、是否低于 XC7Z045 门限
- 与 A0/A1/A2 的 bit-exact 证据对应关系

## 5. MAC IP 选择

Vivado 有 MAC 相关 IP/硬核可用，但本项目建议优先使用 RTL 推断或显式 `DSP48E2` primitive：

- RTL `a * b + acc` 已可推断为 `DSP48E2`，当前 MAC core OOC 证明 `TAP_PAR=8` 会使用 8 个 DSP。
- 显式 `DSP48E2` primitive 可用于后续严格控制 pipeline 和 cascade。
- IP Catalog 中的 Multiplier/FIR/Math IP 不适合作为整个 SPAN 卷积核心，因为本项目还需要自定义 window、weight ROM、per-channel requant 和 3-lane scheduler。
