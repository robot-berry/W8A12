# JTAG-W8A12 true2x2 参数复核与例程对照

日期：2026-06-27

## 结论

本轮复核没有发现 `base/width/scale/JTAG/BD` 这类上板参数漏配。JTAG-W8A12 的板级连接与已跑通例程保持一致：器件为 `xczu19eg-ffvc1760-2-i`，PL0 时钟来自 PS，JTAG-to-AXI Master 经 AXI Interconnect 访问 AXI-Lite endpoint，控制基地址为 `0xA0000000`。

当前问题不应优先归因于“上板参数没有设置好”。同一块板、同一套 JTAG 脚本复烧旧 `inpixfix` bitstream 后可稳定得到 2x2->8x8 输出；新 `epwbh` debug bitstream 则卡在 `core_busy`，无输出。

## 静态参数确认

`scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl` 已显式传递依赖参数：

| 参数 | true2x2 值 |
| --- | --- |
| `IMG_W` | `2` |
| `TILE_W` | `2` |
| `TILE_H` | `2` |
| `HALO` | `21` |
| `SCALE` | `4` |
| `IN_PIXELS` | `4` |
| `OUT_PIXELS` | `64` |
| `IN_IDX_W` | `2` |
| `OUT_IDX_W` | `6` |
| `OUT_LANES` | `1` |
| `TAP_LANES` | `4` |
| `SCALE_LANES` | `1` |

`vivado/jwtw_true2x2_jtagaxi_epwbh_20260627/.../jwtw_sr0_0.xci` 中上述参数均为 user/generated 一致值。

## 与例程对照

| 项目 | TinySPAN/JTAG 例程 | W8A12 JTAG tile-writer | 结论 |
| --- | --- | --- | --- |
| 器件 | `xczu19eg-ffvc1760-2-i` | `xczu19eg-ffvc1760-2-i` | 一致 |
| 访问方式 | JTAG-to-AXI Master | JTAG-to-AXI Master | 一致 |
| AXI-Lite base | `0xA0000000` | `0xA0000000` | 一致 |
| PL clock/reset | PS PL0 clock + proc_sys_reset | PS PL0 clock + proc_sys_reset | 一致 |
| 输入格式 | RGB888 `{R,G,B}` | RGB888 `{R,G,B}` | 一致 |
| 输出格式 | RGB888 `{R,G,B}` | RGB888 `{R,G,B}` | 一致 |
| endpoint | 复用旧 `sr_sd_axi_lite_accel` | 新 `sr_jtag_w8a12_tile_writer_endpoint` | 主要差异 |

## 上板对照结果

### 旧 `inpixfix` bitstream 复跑

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_inpixfix_20260627.bit -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_inpixfix_rerun_20260627_cfgcheck -SkipCompare
```

结果：

| 指标 | 值 |
| --- | --- |
| smoke | `PASS` |
| input counter | `4` |
| output counter | `64` |
| output bytes | `192 / 192` |
| frame done | `1` |
| frame cycles | `7202120` |
| error flags | `0x00000000` |

输出与 fixed reference / RTL raw compare：

| 对比 | mismatch | max diff | MAE | MSE | PSNR |
| --- | --- | --- | --- | --- | --- |
| board vs reference | `153 / 192` | `4` | `1.3229167` | `2.5729167` | `44.0265 dB` |
| board vs RTL raw | `153 / 192` | `4` | `1.3229167` | `2.5729167` | `44.0265 dB` |

说明：旧 bitstream 证明 JTAG/BD/寄存器通路能工作，但当前输出仍不是 bit-exact。

### 新 `epwbh` debug bitstream

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_jtag_w8a12_tile_writer_smoke.ps1 -Bitstream vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_epwbh_20260627.bit -OutputDir board_runs\jtag_w8a12_tile_writer\true2x2_jtagaxi_epwbh_20260627 -SkipCompare
```

结果：

| 指标 | 值 |
| --- | --- |
| smoke | `FAIL` |
| 输入阶段 | `sent=4/4 reg_in=4 reg_out=0` |
| status | `0x00002000` |
| output bytes | `0 / 192` |
| 现象 | 一直等待输出，`core_busy` 保持置位 |

说明：`epwbh` 的 endpoint-local debug hash 在行为仿真中 bit-exact，但上板后导致 core 不完成。该现象与板级参数不匹配不同；更像 debug 逻辑扰动后触发的硬件实现差异、内部握手状态差异或需要更轻量的观测方式。

### 源码回退保护

发现 `epwbh` 上板卡住后，`rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v` 已将 writeback hash 观测做成可选参数：

| 参数 | 默认值 | 作用 |
| --- | --- | --- |
| `ENABLE_DEBUG_WB_HASH` | `0` | 默认关闭 writeback hash 更新逻辑，避免后续 bitstream 默认继承 `epwbh` 扰动 |

默认关闭后已重新运行 2x2 RTL raw compare：

| 指标 | 值 |
| --- | --- |
| RTL compare | `PASS` |
| output pixels | `64` |
| mismatch bytes | `0 / 192` |
| max diff | `0` |
| PSNR | `Infinity` |

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_jtag_w8a12_tile_writer_endpoint_raw_compare.ps1 -ImageW 2 -TileW 2 -TileH 2 -Halo 21 -OutLanes 1 -TapLanes 4 -ScaleLanes 1 -InputRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb -ReferenceRaw runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb -AllowMismatch -SkipPackWeights -SimRuntime 300ms
```

## 下一步

1. 保留旧 `inpixfix` 作为当前可上板出图的 baseline。
2. 不再把 `epwbh` 作为功能验证 bitstream 使用，除非进一步证明其 debug 逻辑不会扰动 core。
3. 若重新生成 JTAG true2x2 bitstream，应使用源码默认 `ENABLE_DEBUG_WB_HASH=0` 的路径，并先验证是否恢复到 `inpixfix` 的上板输出行为。
4. 下一轮定位应优先使用更低扰动的状态寄存器或 ILA，只观测 `core_start/core_busy/core_done/rd_req/rd_resp/wr_valid/output_count`，避免把大量内部 writer 信号接到 AXI readback。
5. 交付门禁仍然是：2x2/32x32 board output 与 Python W8A12 fixed reference bit-exact；当前还未达成。
