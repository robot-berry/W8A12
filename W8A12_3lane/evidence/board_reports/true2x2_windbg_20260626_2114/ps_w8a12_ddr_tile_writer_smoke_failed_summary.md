# W8A12 DDR Tile-Writer 上板 Smoke 失败记录

时间：2026-06-26 22:24:26

## 本次目标

- 路线：PS/XSCT 写 DDR 输入帧，PL 端 AXI master 从 DDR 读整帧并在硬件内完成 tile/halo/W8A12，再写回 DDR。
- 输入/输出：`2 x 2 -> 8 x 8`，x4。
- PL 时钟：`50 MHz`。
- 控制寄存器基地址：`0xA0000000`。
- DDR 输入基地址：`0x10000000`。
- DDR 输出基地址：`0x11000000`。
- bitstream：`G:\UESTC\feitengspan1\b\w8a12_2x2_windbg_20260626_2114\psw8a12ddr_true2x2_windbg_20260626_2114\ps_w8a12_ddr_tile_writer.runs\impl_1\psw8a12ddr_wrapper.bit`。

## 失败阶段

- 阶段：`XSCT DDR/控制/硬件状态检查`。
- 原因：`XSCT did not report W8A12_DDR_TILE_WRITER_XSCT_PASS=1`。

本次未完成板端输出逐字节比较；如果失败发生在 bitstream 下载前，则没有进入 DDR 写入、PL 计算或 DDR 读回阶段。

## 已捕获调试寄存器

| 寄存器/解码 | 数值 |
| --- | --- |
| DEBUG_STATE | `0x00060427` |
| RGB 输出计数 | `0` |
| DEBUG_C1_DETAIL | `0x00CA505E` |
| DEBUG_C1 首因 | `无` |
| DEBUG_C2_DETAIL | `0x0060200C` |
| DEBUG_C2 首因 | `无` |
| DEBUG_C3_DETAIL | `0x0060200C` |
| DEBUG_C3 首因 | `无` |
| DEBUG_ATT_DETAIL | `0x26480000` |
| DEBUG_SPAB_FLAGS | `0x8000F040` |
| SPAB 置位标志 | `start_take(bit31)；att_done(bit15)；residual_stream_done(bit14)；c3_done(bit13)；c2_done(bit12)；att_error(bit6)` |
| tail feat0 hash | `0x7FFF8000` |
| tail block6 hash | `0x00000000` |
| tail b1 hash | `0x811C9DC5` |
| tail b6_act1 hash | `0x811C9DC5` |
| tail RGB q hash | `0x811C9DC5` |
| SPAB block1 C1 sample0 | `0x00000000` |
| SPAB block1 C1 sample1 | `0x00000000` |
| SPAB block1 C1 sample2 | `0x00000000` |
| SPAB block1 C1 sample3 | `0x00000000` |
| SPAB block1 input hash | `0x811C9DC5` |
| SPAB block1 C1/act1 hash | `0x811C9DC5` |
| SPAB block1 C2/act2 hash | `0x811C9DC5` |
| SPAB block1 C2 replay hash | `0x811C9DC5` |
| SPAB block1 C2 window hash | `0x811C9DC5` |
| SPAB block1 C1 raw hash | `0x811C9DC5` |
| writeback wr_data hash | `0x02029843` |
| writeback wr_data range/count | `0x02029843` |
| writeback wr_data first | `0x00000000` |
| writeback wr_data last | `0x00000202` |
| SPAB block1 C3 hash | `0x811C9DC5` |
| SPAB block1 residual hash | `0x811C9DC5` |
| SPAB block1 attention/output hash | `0x811C9DC5` |

## 资源和时序报告

- utilization：`未找到`
- timing：`未找到`

## 日志

- program log：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_windbg_20260626_2114\program\program_ps_w8a12_tile_writer_bitstream.log`
- XSCT log：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_windbg_20260626_2114\run_xsct_ps_w8a12_ddr_tile_writer_smoke.log`
- preflight log：``
