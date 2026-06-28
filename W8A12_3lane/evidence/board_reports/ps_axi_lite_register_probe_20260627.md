# PS AXI-Lite register-only 上板隔离报告

时间：2026-06-27

## 结论

本轮专门生成了一个最小 AXI-Lite register-only bitstream，只保留 PS `M_AXI_HPM0_FPD -> AXI interconnect -> PL AXI-Lite slave` 控制路径，不包含 W8A12 计算核和 DDR master。

结果显示：

1. 最小 bitstream 已成功生成并可烧录到板上。
2. Vivado implementation/timing/route 均通过。
3. 正常 `psu_init` 路径在写 PS 寄存器 `0xFF1800B4` 时 AP transaction timeout。
4. 跳过 `psu_init` 后，无论 A53 优先还是 PSU 访问，读取 `0xA0000000` 仍被 `Cortex-A53 #0: EDITR not ready` 阻断。

因此，当前上板失败不优先怀疑 W8A12 true 2x2 的模型参数、tile 参数或 `ctrl_base` 配置；更像板端 PS/JTAG/XSCT 调试访问状态异常。需要先恢复稳定的 PS/AXI-Lite 读写，再继续 true 2x2、32x32 和 720p 输出。

## 最小 probe 设计

| 项目 | 值 |
| --- | --- |
| RTL | `rtl/board/sr_axi_lite_register_probe.v` |
| BD 脚本 | `scripts/create_vivado_ps_axi_lite_register_probe_bd_project.tcl` |
| bitstream 脚本 | `scripts/run_vivado_bitstream_ps_axi_lite_register_probe.ps1` |
| 上板脚本 | `scripts/run_ps_axi_lite_register_probe.ps1` |
| device | `xczu19eg-ffvc1760-2-i` |
| PL clock | `50 MHz` |
| PS->PL control | `M_AXI_HPM0_FPD` |
| control base | `0xA0000000 / 64K` |
| magic register | `0x00 -> 0x57384158` |
| scratch register | `0x04` writable/readable |

## 构建结果

| 项目 | 结果 |
| --- | --- |
| bitstream | `vivado/bitstreams/ps_axi_lite_register_probe_f50m.bit` |
| source bitstream | `b/ps_axi_probe_build/ps_axi_lite_register_probe_f50m_20260626/ps_axi_lite_register_probe.runs/impl_1/psaxilprobe_wrapper.bit` |
| psu_init | `b/ps_axi_probe_build/ps_axi_lite_register_probe_f50m_20260626/ps_axi_lite_register_probe.gen/sources_1/bd/psaxilprobe/ip/psaxilprobe_ps_0/psu_init.tcl` |
| route status | clean, failed/unrouted/partial nets all 0 |
| timing | WNS `15.547 ns`, WHS `0.031 ns`, all constraints met |
| LUT | 1216 |
| FF | 1279 |
| BRAM | 0 |
| DSP | 0 |
| URAM | 0 |

说明：Vivado `write_bitstream` 成功，`write_hw_platform -include_bit` 在当前环境下报无法从 implementation run 取得 bit；脚本已改成 XSA 导出失败不阻断 bitstream 验证。

## 上板尝试

| Run | 方式 | 结果 |
| --- | --- | --- |
| `f50m_20260627_0018` | program bit + 正常 `psu_init` | bit 烧录 PASS；`psu_init` 写 `0xFF1800B4` AP transaction timeout |
| `f50m_20260627_0018_skippsu_a53` | no-program + skip `psu_init` + A53 first | 读 `0xA0000000` 失败，`Cortex-A53 #0: EDITR not ready` |
| `f50m_20260627_0018_skippsu_psu` | no-program + skip `psu_init` + PSU access | 读 `0xA0000000` 失败，`Cannot flush CPU cache` / `EDITR not ready` |
| `f50m_20260627_0030_skippsu_psu_summary` | 同上，生成正式 summary | `Status: FAIL`，证据已落盘 |
| `f50m_20260627_0040_skippsu_psu_force` | no-program + skip `psu_init` + PSU access + `mrd/mwr -force` fallback | 仍 FAIL，`mrd -force` 返回同类 `Cannot flush CPU cache` / `EDITR not ready` |

正式 summary：

```text
board_runs/ps_axi_lite_register_probe/f50m_20260627_0030_skippsu_psu_summary/ps_axi_lite_register_probe_summary.md
```

关键失败日志：

```text
mrd failed after retries addr=0xA0000000
Memory read error at 0xA0000000.
Cannot flush CPU cache.
Cannot read register r0.
Cortex-A53 #0: EDITR not ready
```

## 与 32x32 已跑通例程的关系

32x32 W8A12 PS-DDR 例程曾经在同一控制口完成：

```text
CTRL_BASE=0xA0000000
PSU_INIT_PASS=1
IMG_W_READBACK=32
FRAME_DONE=1
ERROR=0
XSCT_PASS=1
```

这说明工程历史上 PS/AXI-Lite/DDR 基础通路可工作。当前最小 probe 都无法读 `0xA0000000`，并且失败点出现在 PS init/AP/EDITR 层，说明优先处理方向应从 W8A12 计算 RTL 切到板端调试访问恢复。

## 下一步

1. 物理断电重上电，并关闭所有残留 `hw_server/xsct/vivado` 后，先跑 `ps_axi_lite_register_probe`。
2. 若最小 probe PASS，再回到 true 2x2 W8A12 bitstream，检查 PL AXI-Lite slave、reset、clock 和 debug sample。
3. 若最小 probe 仍 FAIL，不继续消耗时间综合大核，先解决板端 PS/JTAG/XSCT 调试访问问题。
4. 最小 probe PASS 后，验收顺序恢复为 true 2x2 -> 4x4 -> 8x8 -> 32x32 -> tiled 720p。

补充：已在 `scripts/run_xsct_ps_axi_lite_register_probe.tcl` 中加入 `mrd/mwr -force` fallback，但本轮 `f50m_20260627_0040_skippsu_psu_force` 仍失败，因此单纯改用 force 访问不能解决当前板端状态。
