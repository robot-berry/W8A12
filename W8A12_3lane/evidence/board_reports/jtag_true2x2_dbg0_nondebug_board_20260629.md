# JTAG true2x2 dbg0/nondebug board check

日期：2026-06-29

## 目的

验证 `DebugExportLevel=0` 的当前源码 bitstream 是否能恢复到旧 stage-hash baseline 的行为：即 true2x2 板端可完整输出，但仍存在 board-vs-reference 数值 mismatch。

## 结果

本轮未进入 W8A12 计算路径，不能作为数值 mismatch 证据。

| 项目 | 结果 |
| --- | --- |
| bitstream | `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg0_true2x2_jtagaxi_dbg0_nondebug_20260629.bit` |
| implementation | PASS，WNS `12.797ns`，WHS `0.009ns` |
| resource | LUT `38964`，FF `115912`，BRAM tile `311`，DSP `125` |
| Vivado target probe | FAIL，`VIVADO_HW_TARGET_COUNT=0` |
| XSCT psu_init | FAIL，未发现 PS/PMU/DAP target |
| smoke | FAIL，Vivado exit `1` |
| output bytes | `0 / 192` |

## 关键日志

Vivado smoke 日志报错：

```text
No hardware target found. Check USB-JTAG cable and board power.
```

XSCT psu_init 日志报错：

```text
Could not select a ZynqMP PS/PMU/DAP target for psu_init
```

USB 诊断显示当前在线 USB 设备不包含已知 Xilinx/FTDI JTAG 候选：

```text
USB_JTAG_DIAG_MATCH_COUNT=3
USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=0
USB_JTAG_DIAG_PNP_HISTORY_KNOWN_CANDIDATE_COUNT=4
```

## 结论

1. 本轮失败点在 Vivado/XSCT 硬件 target 枚举阶段，尚未烧录 bitstream，也没有启动 W8A12 RTL。
2. 这不是新的 RTL 数值 mismatch 结论，也不能推翻历史 stage-hash 结论。
3. 历史有效定位仍保持为：`halo fetch / conv1 feat0 -> SPAB block1 -> feature buffer/replay -> b1_m_feat -> tail`。下一步需要在 JTAG target 恢复可见后，用低侵入探针继续找该链路内的第一个错误点。

## 证据路径

```text
board_runs/jtag_w8a12_tile_writer/true2x2_dbg0_nondebug_acceptance_20260629/
board_runs/jtag_w8a12_tile_writer/true2x2_dbg0_nondebug_acceptance_20260629/probe/probe_vivado_hw_targets.stdout.log
board_runs/jtag_w8a12_tile_writer/true2x2_dbg0_nondebug_acceptance_20260629/psu_init/run_xsct_psu_init_only.log
board_runs/jtag_w8a12_tile_writer/true2x2_dbg0_nondebug_acceptance_20260629/smoke/jtag_w8a12_tile_writer_smoke_summary.md
```
