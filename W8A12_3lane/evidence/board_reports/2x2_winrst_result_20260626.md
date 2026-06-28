# W8A12 2x2 上板验证结果 - 2026-06-26

## 当前结论

最新 `true2x2_winrst_20260626_1951` 版本尚未通过 2x2 板上 smoke。

已经通过的部分：

| 项目 | 结果 | 说明 |
| --- | --- | --- |
| Python / integer reference | PASS | `2x2 -> 8x8` x4 reference 已生成 |
| RTL SPAB 行为仿真 | PASS | `outputs=4`，C1/C2/C3/ATT 动态计数完整 |
| RTL DDR endpoint 仿真 | PASS | `mismatch_bytes=0/192` |
| OOC 综合时序 | PASS | `WNS=10.481 ns`，50 MHz 约束通过 |
| full bitstream 生成 | PASS | `WNS=5.746 ns`，DRC/route/bitstream 通过 |
| JTAG 下载 | PASS | XSCT 退出码为 0 |
| DDR 输入写入校验 | PASS | `INPUT_DDR_VERIFY_MISMATCH=0` |
| 板上 2x2 smoke | FAIL | PL 启动后未产生 RGB 输出 |

## 最新板上运行

bitstream：

```text
b/w8a12_2x2_winrst_20260626_1951/psw8a12ddr_true2x2_winrst_20260626_1951/ps_w8a12_ddr_tile_writer.runs/impl_1/psw8a12ddr_wrapper.bit
```

证据目录：

```text
W8A12_3lane/evidence/board_reports/true2x2_winrst_20260626_1951
board_runs/w8a12_ps_ddr_tile_writer_smoke/true2x2_winrst_20260626_1951
```

关键寄存器：

```text
STATUS=0x00000006
ERROR=0x00000000
FRAME_DONE=0
TILES_DONE=0
BLOCK_STARTS=1
BLOCK_OUTPUTS=0
REPLAY_FEATURE=4
RGB_OUTPUT_COUNT=0
WR_FIRE_COUNT=0
AXI_WRITE_COUNTS=0
DEBUG_C1_DETAIL=0x00CA505E
DEBUG_C1_CORE_DETAIL=0x204A0155
DEBUG_C1_LANE_DETAIL=0x00030155
DEBUG_C1_IO_DETAIL=0x20000000
DEBUG_SPAB_FLAGS=0x8000F040
```

## 解释

这说明 2x2 通路不是卡在 JTAG、PSU 初始化、DDR 输入写入或 bitstream 生成阶段。输入 DDR 已经校验正确，PL 端也启动了第一个 SPAB block，并且读到了 4 个 feature 输入。

当前卡点在第一个 SPAB block 的 C1/window 输入握手路径：`BLOCK_STARTS=1`，但 `BLOCK_OUTPUTS=0`、`RGB_OUTPUT_COUNT=0`，所以还没有进入可比较输出图像的阶段。

## 下一步回退与定位

1. 保留当前 `winrst` 版本作为失败证据，不再覆盖。
2. 在 C1/window 路径增加更直接的调试寄存器：完整 window 状态、`window_reset_q`、`s_valid/s_ready`、`m_valid/m_ready`、第一拍输入样本。
3. 若新增调试仍显示 window 不推进，则回退到最小 2x2 单 C1 kernel 上板，只验证 replay -> window -> C1 的局部链路。
4. 若单 C1 能过，再逐级恢复 C2/C3/attention、6 block、DDR writeback。
