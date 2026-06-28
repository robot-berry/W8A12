# JTAG-W8A12 true2x2 上板报告（IN_PIXELS 修复后）

日期：2026-06-27

## 结论

- 上板参数配置问题已定位并修复：`IMG_W=2` 虽然已经传入 BD，但 Vivado IP Integrator 没有自动传播 `IN_PIXELS=IMG_W*IMG_W`、`OUT_PIXELS=IMG_W*IMG_W*SCALE*SCALE` 以及索引宽度，导致旧 bitstream 实际仍按默认 `32x32` 等待输入。
- 修复后重新生成 bitstream，综合、布局布线、bitstream 全部通过。
- JTAG-to-AXI 上板通路已跑通：2x2 LR 输入 4 像素写入，8x8 HR 输出 64 像素读回，`FRAME_DONE=1`，`ERROR=0x00000000`。
- 板上输出稳定：不重新下载 bitstream 连续复跑，两个 `board_output.rgb` 完全一致（192/192 bytes repeat match）。
- 当前仍未通过 bit-exact 交付门禁：板上输出相对 CPU integer W8A12 reference 有 `153 / 192` 字节不同，`max_channel_diff=4`，`PSNR=44.0265 dB`。视觉预览正确，但需要继续定位 RTL/CPU reference 的定点舍入或版本差异。

## 修复内容

修改文件：

- `scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl`
- `scripts/compare_jtag_w8a12_span_output.ps1`

关键修复：

- 显式下发 `CONFIG.IN_PIXELS=4`
- 显式下发 `CONFIG.OUT_PIXELS=64`
- 显式下发 `CONFIG.IN_IDX_W=2`
- 显式下发 `CONFIG.OUT_IDX_W=6`
- compare 脚本支持绝对 `BuildDir`
- compare 摘要增加 `MAE/MSE/PSNR/mean_signed_diff`

参数检查证据：

- `vivado/jwtw_paramcheck_inpixfix/jwtw.srcs/sources_1/bd/jwtw/ip/jwtw_sr0_0/jwtw_sr0_0.xci`
- xci 中 `IMG_W=2`、`TILE_W=2`、`IN_PIXELS=4`、`OUT_PIXELS=64`、`IN_IDX_W=2`、`OUT_IDX_W=6`
- 综合日志显示 `input_mem_reg depth=4 x width=24`，不再是旧版 1024 深度

## Bitstream

Bitstream：

```text
vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_inpixfix_20260627.bit
```

生成日志：

```text
board_runs/w8a12_tile_writer_bitstream_attempts/driver_true2x2_jtagaxi_inpixfix_20260627.stdout.log
```

实现结果：

| 指标 | 结果 |
| --- | ---: |
| WNS | 14.466 ns |
| WHS | 0.010 ns |
| CLB LUTs | 38,975 |
| CLB Registers | 115,904 |
| BRAM Tile | 311 |
| URAM | 0 |
| DSP | 125 |
| Timing | PASS |
| Route failed nets | 0 |
| Route unrouted nets | 0 |

说明：该 bitstream 用于上板 bring-up。FF/BRAM 仍不是最终 ZC706/XC7Z045 资源门限候选。

## 上板结果

首次烧录并读回：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_inpixfix_20260627_0829
```

关键寄存器结果：

| 项目 | 值 |
| --- | ---: |
| input counter | 4 |
| output counter | 64 |
| frame done | 1 |
| error flags | 0x00000000 |
| frame cycles | 7,202,120 |
| e2e cycles | 7,202,120 |
| board output bytes | 192 / 192 |

板上输出：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_inpixfix_20260627_0829/board_output.rgb
```

复跑稳定性：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_inpixfix_20260627_0831_noprogram
```

结果：

```text
repeat_mismatch=0 length=192
```

## Reference Compare

CPU integer reference：

```text
runs/reds_span_quant_plan/endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1/reference.rgb
```

compare 摘要：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_inpixfix_20260627_0829/compare/w8a12_compare_summary_x4_2x2.json
```

结果：

| 指标 | 值 |
| --- | ---: |
| status | FAIL |
| mismatch bytes | 153 / 192 |
| max channel diff | 4 |
| MAE | 1.3229166667 |
| MSE | 2.5729166667 |
| PSNR | 44.026546 dB |
| mean signed diff | -0.0104166667 |

预览图：

```text
board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_inpixfix_20260627_0829/compare/jtag_w8a12_validation_preview.png
```

## 下一步

1. 以当前 bitstream 为硬件稳定基线，继续定位 `max diff <= 4` 的来源。
2. 对齐 RTL endpoint sim 与当前 JTAG endpoint 的同一份输入、同一份 CPU integer reference，确认差异是在 RTL 仿真已有，还是仅综合/上板后出现。
3. 优先检查 final RGB 后处理、requant rounding、signed multiply/shift、tile halo 边界策略是否与 CPU reference 完全一致。
4. 修到 `mismatch=0` 后，再扩大到 4x4 / 8x8 / 32x32，并进入 720p tiled 输出链路。
