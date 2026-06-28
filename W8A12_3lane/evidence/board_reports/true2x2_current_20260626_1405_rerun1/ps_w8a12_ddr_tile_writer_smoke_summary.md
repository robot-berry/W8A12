# DDR W8A12 Tile-Writer 上板 Smoke 记录

测试状态：`FAIL`

| 项目 | 数值 |
| --- | --- |
| 输入/输出尺寸 | `2 x 2 -> 8 x 8` |
| PL 时钟 MHz | `50` |
| 帧处理周期 | `7202570` |
| 小图折算 FPS | `6.941967` |
| 输出读回来源 | `DDR_DIRECT` |
| mirror 输出/读出计数 | `0 / 0` |
| mirror status | `0x00000000` |
| 完成 tile 数 | `1` |
| block starts / outputs | `6 / 24` |
| replay feature | `24` |
| RGB 输出计数 | `64` |
| DEBUG_STATE | `0x00017800` |
| DEBUG_C1_DETAIL | `0x0000200C` |
| DEBUG_C1 首因 | `无` |
| DEBUG_C2_DETAIL | `0x0000200C` |
| DEBUG_C2 首因 | `无` |
| DEBUG_C3_DETAIL | `0x0000200C` |
| DEBUG_C3 首因 | `无` |
| DEBUG_ATT_DETAIL | `0x00000603` |
| DEBUG_C3_CORE_DETAIL | `0x17C01AF5` |
| DEBUG_C3_LANE_DETAIL | `0x0DBF1AF5` |
| DEBUG_C3_IO_DETAIL | `0x0085001F` |
| DEBUG_SPAB_FLAGS | `0x01E00F00` |
| SPAB 置位标志 | `residual_load_busy(bit24)；att_ready(bit23)；c3_ready(bit22)；c2_ready(bit21)；c1_done(bit11)；residual_stream_done_seen(bit10)；c3_done_seen(bit9)；c2_done_seen(bit8)` |
| tail feat0 hash | `0xF80007FF` |
| tail block6 hash | `0xFFFF0047` |
| tail b1 hash | `0x36004310` |
| tail b6_act1 hash | `0x0543D164` |
| tail RGB q hash | `0xD24D3224` |
| source feat0 hash | `0x00000004` |
| source block6 hash | `0x00070004` |
| source b1 hash | `0x00070004` |
| source b6_act1 hash | `0x00070004` |
| SPAB input hash | `` |
| SPAB C1 hash | `` |
| SPAB C2 hash | `` |
| SPAB C3 hash | `` |
| SPAB residual hash | `0x811C9DC5` |
| SPAB attention/output hash | `0x811C9DC5` |
| SPAB block1 C1 sample0 | `0x00000000` |
| SPAB block1 C1 sample1 | `0x00000000` |
| SPAB block1 C1 sample2 | `0x00000000` |
| SPAB block1 C1 sample3 | `0x00000000` |
| SPAB block1 input hash | `0x811C9DC5` |
| SPAB block1 C1/act1 hash | `0x811C9DC5` |
| SPAB block1 C1 raw hash | `0x811C9DC5` |
| writeback wr_data hash | `0xB76B8597` |
| writeback wr_data range/count | `0x00FF0040` |
| writeback wr_data first | `0x0053582F` |
| writeback wr_data last | `0x00000789` |
| DDR writer wr valid/ready cycles | `0x03E2FFFF` |
| DDR writer wr fire count | `0x00000040` |
| DDR writer last addr | `0x110000FC` |
| DDR writer last data | `0x00000789` |
| AXI write counts aw/w | `0x00400040` |
| AXI resp/read counts b/ar/r | `0x00400404` |
| AXI live state | `0x00000504` |
| reference writeback hash | `0xEDB8BCAC` |
| reference writeback range/count | `0x4E9F0040` |
| reference writeback first | `0x0061605D` |
| reference writeback last | `0x007A6366` |
| writeback 签名匹配 | `False` |
| SPAB block1 C2/act2 hash | `0x811C9DC5` |
| SPAB block1 C2 replay hash | `0x811C9DC5` |
| SPAB block1 C2 window hash | `0x811C9DC5` |
| SPAB block1 C3 hash | `0x811C9DC5` |
| SPAB block1 residual hash | `0x811C9DC5` |
| SPAB block1 attention/output hash | `0x811C9DC5` |
| 不一致字节数 | `192 / 192` |
| 最大通道差值 | `164` |
| 控制寄存器基地址 | `0xA0000000` |
| DDR 输入基地址 | `0x10000000` |
| DDR 输出基地址 | `0x11000000` |
| 对比预览图 | `G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\ps_w8a12_ddr_tile_writer_preview.png` |
| bitstream | `G:\UESTC\feitengspan1\b\w8a12_2x2_current_20260626_1405\psw8a12ddr_true2x2_current_20260626_1405\ps_w8a12_ddr_tile_writer.runs\impl_1\psw8a12ddr_wrapper.bit` |

## 资源和时序

| 资源/时序 | 使用量 |
| --- | ---: |
| CLB LUT |  |
| CLB register |  |
| Block RAM Tile |  |
| URAM |  |
| DSP |  |
| WNS ns |  |
| WHS ns |  |

## 产物

- 中文 summary：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\ps_w8a12_ddr_tile_writer_smoke_summary.md`
- 机器可读 JSON：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\ps_w8a12_ddr_tile_writer_smoke_summary.json`
- XSCT 日志：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\run_xsct_ps_w8a12_ddr_tile_writer_smoke.log`
- 板端输出 PNG：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\board_output.png`
- 软件参考 PNG：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\reference\integer_w8a12_span.png`
- 对比预览图：`G:\UESTC\feitengspan1\board_runs\w8a12_ps_ddr_tile_writer_smoke\true2x2_current_20260626_1405_noprogram_rerun1\ps_w8a12_ddr_tile_writer_preview.png`

## 结论

本次测试把输入 RGB888 写入 DDR，经 PL 端 W8A12 tile-writer 读取、超分、写回 DDR，再由 XSCT 读回并和同一量化权重的软件整数参考逐字节比较。`PASS` 表示板端输出和软件整数参考完全一致。
