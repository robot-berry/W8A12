# JTAG true 2x2 特殊输入与 currnodbg bitstream 复核

日期：2026-06-27

## 结论

当前最可靠的上板 baseline 是旧 `inpixfix` bitstream，以及用当前源码按 `SynthDirective=Default` 重建得到的 `defaultrebuild` bitstream。两者在标准 2x2 输入下的 `board_output.rgb` 已确认 byte-identical：

- `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_inpixfix_20260627.bit`
- 标准 2x2 输入：`153 / 192` bytes mismatch，PSNR `44.0265 dB`
- 计数器正确：`input=4`、`output=64`、`frame_done=1`、`error=0`
- `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_defaultrebuild_20260627.bit`
- 标准 2x2 输入：`153 / 192` bytes mismatch，max diff `4`，PSNR `44.0265 dB`

重新用当前 dirty RTL 构建的 `currnodbg` bitstream 可以综合、布线、生成 bitstream，也可以上板跑完，但输出比旧 baseline 更差，不应作为后续主线：

- `vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_currnodbg_20260627.bit`
- 标准 2x2 输入：`189 / 192` bytes mismatch，PSNR `24.0510 dB`
- 黑图首帧：`148 / 192` bytes mismatch，PSNR `15.9065 dB`
- 计数器仍正确：`input=4`、`output=64`、`frame_done=1`、`error=0`

因此，本轮证据说明：JTAG 传输、AXI-Lite 基地址、输入/输出计数和 frame done 通路是通的；当前阻塞点不是“板子没连上”或“配置没写进去”。`RuntimeOptimized` 综合策略会让 2x2 结果明显退化；`Default` 综合策略可恢复到旧 baseline，但仍存在 `153 / 192` 的小幅数值 mismatch，需要继续定位 PL/netlist 与 RTL/Python fixed reference 的差异。

## 32x32 历史最小 mismatch

按完整板端 SR 输出 `board_output.rgb` 对 `reference.rgb` 的口径统计，历史最小 32x32 mismatch 是：

- `24391 / 49152` bytes，约 `49.62%`
- 路径：`board_runs/w8a12_ps_ddr_tile_writer_smoke/spaberr_gate_32x32_20260623a_board`
- 现算 PSNR：`14.2888 dB`

日志中出现的 `MISMATCH=0` 属于输入 DDR 校验或探针读回，不是完整 32x32 超分输出通过，不能作为交付正确性证据。

## 旧 inpixfix bitstream：特殊输入对比

当前已生成 2x2 特殊输入：

- `runs/reds_span_quant_plan/jtag_special_inputs_2x2/black.rgb`
- `runs/reds_span_quant_plan/jtag_special_inputs_2x2/gray128.rgb`
- `runs/reds_span_quant_plan/jtag_special_inputs_2x2/ramp.rgb`

对应 RTL 输出归档：

- `runs/reds_span_quant_plan/jtag_special_inputs_2x2/rtl_outputs/black.rtl_output.rgb`
- `runs/reds_span_quant_plan/jtag_special_inputs_2x2/rtl_outputs/gray128.rtl_output.rgb`
- `runs/reds_span_quant_plan/jtag_special_inputs_2x2/rtl_outputs/ramp.rtl_output.rgb`

旧 `inpixfix` bitstream 上板结果：

| case | board run | mismatch | max diff | MAE | PSNR |
| --- | --- | ---: | ---: | ---: | ---: |
| black | `board_runs/jtag_w8a12_tile_writer/special_black_2x2_inpixfix_noprogram_20260627` | `53 / 192` | 2 | 0.302083 | 52.6387 |
| gray128 | `board_runs/jtag_w8a12_tile_writer/special_gray128_2x2_inpixfix_noprogram_20260627` | `110 / 192` | 2 | 0.635417 | 49.3203 |
| ramp | `board_runs/jtag_w8a12_tile_writer/special_ramp_2x2_inpixfix_noprogram_20260627` | `114 / 192` | 5 | 1.000000 | 44.3362 |

偏差是小幅数值差异，不是大片乱序或输出长度错误。黑图最大差仅 2，说明旧 baseline 的通路已经接近可用。

## 当前 currnodbg bitstream 复核

构建参数：

- `IMG_W=2`
- `TILE_W=2`
- `TILE_H=2`
- `HALO=21`
- `PL_FREQ=25 MHz`
- `OUT_LANES=1`
- `TAP_LANES=4`
- `SCALE_LANES=1`
- `SynthDirective=RuntimeOptimized`

构建产物：

- bitstream：`vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_currnodbg_20260627.bit`
- utilization：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_currnodbg_20260627_utilization_impl.rpt`
- timing：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_currnodbg_20260627_timing_impl.rpt`

资源和时序：

| metric | value |
| --- | ---: |
| CLB LUTs | 36135 |
| CLB registers | 115964 |
| BRAM Tile | 311 |
| URAM | 0 |
| DSP | 127 |
| setup worst slack | 15.293 ns |
| hold worst slack | 0.028 ns |

上板结果：

| case | board run | mismatch | max diff | MAE | PSNR |
| --- | --- | ---: | ---: | ---: | ---: |
| standard 2x2 | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_currnodbg_20260627` | `189 / 192` | 47 | 12.401042 | 24.0510 |
| black first frame | `board_runs/jtag_w8a12_tile_writer/special_black_2x2_currnodbg_program_20260627` | `148 / 192` | 148 | 26.281250 | 15.9065 |
| gray128 no-program | `board_runs/jtag_w8a12_tile_writer/special_gray128_2x2_currnodbg_noprogram_20260627` | `190 / 192` | 73 | 18.531250 | 20.5063 |

标准 2x2 和黑图首帧都显示 currnodbg 明显退化；这不是跨帧状态残留造成的。

## nodebugrevert bitstream 复核

移除本轮临时加入的 `ENABLE_DEBUG_WB_HASH` 相关调试/哈希逻辑后，RTL raw compare 仍然 PASS；但重新综合上板的 `nodebugrevert` bitstream 仍未恢复到旧 `inpixfix` baseline。

构建产物：
- bitstream：`vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_nodebugrevert_20260627.bit`
- utilization：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_nodebugrevert_20260627_utilization_impl.rpt`
- timing：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_nodebugrevert_20260627_timing_impl.rpt`

资源和时序：

| metric | value |
| --- | ---: |
| CLB LUTs | 36135 |
| CLB registers | 115964 |
| BRAM Tile | 311 |
| URAM | 0 |
| DSP | 127 |
| setup worst slack | 15.293 ns |
| hold worst slack | 0.010 ns |

上板结果：

| case | board run | mismatch | max diff | MAE | PSNR |
| --- | --- | ---: | ---: | ---: | ---: |
| standard 2x2 | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_nodebugrevert_20260627` | `185 / 192` | 51 | 13.333333 | 23.5145 |

计数器仍正常：`output bytes=192/192`、`frame_done=1`、`error=0x00000000`、`input counter=4`、`output counter=64`。这说明输出链路完整，但 PL 数值结果与 fixed reference 不一致。

对比旧 `inpixfix` 构建日志和 `nodebugrevert` 构建日志后，`$readmem` 文件集合与参数绑定集合一致；导致 `currnodbg`/`nodebugrevert` 退化的关键差异是综合策略：旧 baseline 使用 `SynthDirective=Default`，退化重建使用 `SynthDirective=RuntimeOptimized`。

## defaultrebuild bitstream 复核

使用当前源码、关闭临时调试逻辑，并显式指定 `SynthDirective=Default` 后，重建 bitstream 可以恢复到旧 `inpixfix` baseline。

构建参数：

- `IMG_W=2`
- `TILE_W=2`
- `TILE_H=2`
- `HALO=21`
- `PL_FREQ=25 MHz`
- `OUT_LANES=1`
- `TAP_LANES=4`
- `SCALE_LANES=1`
- `SynthDirective=Default`

构建产物：

- bitstream：`vivado/bitstreams/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_defaultrebuild_20260627.bit`
- utilization：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_defaultrebuild_20260627_utilization_impl.rpt`
- timing：`vivado/reports/jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_defaultrebuild_20260627_timing_impl.rpt`

资源和时序：

| metric | value |
| --- | ---: |
| CLB LUTs | 38975 |
| CLB registers | 115904 |
| BRAM Tile | 311 |
| URAM | 0 |
| DSP | 125 |
| setup worst slack | 14.466 ns |
| hold worst slack | 0.010 ns |

上板结果：

| case | board run | mismatch | max diff | MAE | PSNR |
| --- | --- | ---: | ---: | ---: | ---: |
| standard 2x2 | `board_runs/jtag_w8a12_tile_writer/true2x2_jtagaxi_defaultrebuild_20260627` | `153 / 192` | 4 | 1.322917 | 44.0265 |

计数器正常：`output bytes=192/192`、`frame_done=1`、`error=0x00000000`、`input counter=4`、`output counter=64`。`defaultrebuild` 的 `board_output.rgb` 与旧 `inpixfix` 复跑输出 byte-identical，因此后续正确性 bring-up 必须固定使用 `SynthDirective=Default`，不再使用 `RuntimeOptimized` 作为 correctness 主线。

剩余偏差特征为稳定的小幅数值差异：`153 / 192` bytes mismatch，最大通道差 `4`，MAE `1.3229`，PSNR `44.0265 dB`。RTL raw compare 仍然 bit-exact，因此下一步要在 post-synthesis/post-implementation netlist 仿真或低扰动输出 trace 中判断差异来自综合后网表、实现后时序行为，还是板端写回路径。

## 下一步修复路线

1. 固定 `SynthDirective=Default` 作为 W8A12 correctness bring-up 路线，继续围绕 `153 / 192` 的小幅偏差定位。
2. 不再沿 `currnodbg`/`nodebugrevert` 的 `RuntimeOptimized` bitstream 扩展 32x32；它们会把问题扩大。
3. 优先做 post-synthesis 或 post-implementation netlist raw compare，判断 `153 / 192` 是否已经在综合后网表中出现。
4. 若网表仿真仍 bit-exact，再在不扰动计算路径的前提下加入最小探针：首尾输出像素、输出写回 hash、必要时逐层 boundary hash；每次只加一个探针并复跑 2x2。
5. 等 true 2x2 上板达到 `mismatch=0` 或稳定小误差可解释后，再恢复 8x8、32x32、64x64、720p tiled 验收。
