# W8A12 2x2 最小上板验证结果

时间：2026-06-26

## 结论

当前 2x2 验证还没有达到“板上超分输出 PASS”。分层结果如下：

| 层级 | 结果 | 说明 |
| --- | --- | --- |
| RTL 窗口单元仿真 | PASS | `span_w8a12_feature_line_window` 在 2x2 输入下输出 4 个窗口，无 mismatch。 |
| SPAB/Block 级仿真 | PASS | `sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine` 2x2 动态输出通过。 |
| DDR endpoint 仿真 | PASS | 2x2->8x8，`ENDPOINT_OUTPUT_COMPARE_MISMATCH_BYTES=0`。 |
| bitstream 生成 | PASS | `write_bitstream` 成功，DRC 0 error。 |
| 板上 JTAG/下载 | PASS | 识别 `xczu19_0`，program pass。 |
| 板上 PS/PL 控制访问 | FAIL | XSCT 写 PS/PL 控制路径时 AP transaction timeout，未进入 DDR 输出比对。 |
| 板上超分图像输出 | 未完成 | 本轮没有读到有效 8x8 输出图，不能记为上板超分通过。 |

补充配置审计：已对照 32x32 已跑通例程，true 2x2 的 PS/DDR/AXI 基础参数未发现配置错误。详见 `2x2_board_config_audit_20260626.md`。

## 本轮 bitstream

- bitstream：`b\w8a12_2x2_samplelatch_20260626_2229\psw8a12ddr_true2x2_samplelatch_20260626_2229\ps_w8a12_ddr_tile_writer.runs\impl_1\psw8a12ddr_wrapper.bit`
- 文件大小：`36343252` bytes
- 生成时间：`2026-06-26 23:32:15`

## 实现资源与时序

目标器件：`xczu19eg-ffvc1760-2-i`

| 指标 | 数值 |
| --- | ---: |
| CLB LUTs | 40588 |
| CLB Registers | 114602 |
| Block RAM Tile | 308.5 |
| DSPs | 126 |
| URAM | 0 |
| route failed nets | 0 |
| WNS | 5.910 ns |
| WHS | 0.009 ns |

## 板上失败记录

已跑六次板测/访问探测：

| 运行目录 | 失败点 |
| --- | --- |
| `true2x2_samplelatch_20260626_2229` | `psu_init` 通过后，首次写控制寄存器 `0xA0000000` 多次 AP transaction timeout。 |
| `true2x2_samplelatch_20260626_2229_rerun1` | `psu_init` 内部写 PS 寄存器 `0xFF1800B0` 时 AP transaction timeout。 |
| `true2x2_samplelatch_20260626_2229_rerun2_after_diag` | 目标诊断后重跑，仍在 `psu_init` 写 `0xFF1800B0` 时 AP transaction timeout。 |
| `true2x2_a53first_skippsu_20260626` | 跳过 `psu_init`、优先 A53 访问后，首次写 `0xA0000000` 报 `EDITR timeout` / `EDITR not ready`。 |
| `true2x2_a53first_skippsu_stop_20260626` | 对 A53 执行 `stop` 后仍无法写 `0xA0000000`，报 `Cannot read register sctlr_el3` / `EDITR not ready`。 |
| `true2x2_psu_skippsu_20260626` | 选择 PSU 访问时仍无法写 `0xA0000000`，报 `Cannot flush CPU cache` / `EDITR not ready`。 |

XSCT target 诊断结果：

- `PS TAP` 可见
- `PMU` 可见
- `PL` 可见
- `Cortex-A53 #0` 可见
- `DAP` 名称不可见，但未检测到旧的 DAP `0x30000021` 类错误
- 诊断脚本退出码为 0

因此本轮失败更像 PS/JTAG/AXI 访问状态问题，或 true 2x2 bit 下载后 PL AXI-Lite 从设备未响应；暂时不能判断为 W8A12 计算核错误。需要先恢复稳定的 PS AXI-Lite 访问，再继续看新加入的 SPAB/window debug sample。

## 参数配置对照结论

已对照 `b/w8r32a/psw8a12ddr_refddr32_20260625a`，该 32x32 例程在真实板上可以完成：

- `PSU_INIT_PASS=1`
- `IMG_W_READBACK=32`
- `CONFIG=0x00042020`
- `FRAME_DONE=1`
- `ERROR=0`
- `XSCT_PASS=1`

true 2x2 与该 32x32 例程一致的关键配置：

| 配置项 | true 2x2 | 32x32 例程 |
| --- | --- | --- |
| 器件 | `xczu19eg-ffvc1760-2-i` | `xczu19eg-ffvc1760-2-i` |
| PL0 时钟 | `50 MHz / IOPLL` | `50 MHz / IOPLL` |
| PS master 控制口 | `M_AXI_HPM0_FPD` enabled | enabled |
| PL master DDR 口 | `S_AXI_HP0_FPD` enabled | enabled |
| AXI-Lite 控制基址 | `0xA0000000` / `64K` | `0xA0000000` / `64K` |
| PL DDR 段 | `0x00000000` / `2G` | `0x00000000` / `2G` |
| input/output DDR base | `0x10000000` / `0x11000000` | 同左 |
| DDR preset | `DDR4_MICRON_MT40A256M16GE_083E` | 同左 |
| `psu_init.tcl` SHA256 | `A5ADDAE2D8E4690D19C997205D9813927F8768F10C688584E752AC50B09CCDCA` | 同左 |

差异仅是预期内的图像参数：true 2x2 为 `ImgW=2 ImgH=2 TileW=2 TileH=2`，32x32 例程为 `32x32`。

## 最小 AXI-Lite 隔离结果

2026-06-27 已生成并烧录最小 AXI-Lite register-only bitstream：

```text
vivado/bitstreams/ps_axi_lite_register_probe_f50m.bit
```

该 bitstream 不包含 W8A12 大核和 DDR master，只保留 `M_AXI_HPM0_FPD -> 0xA0000000` 的寄存器读写通路。实现结果 PASS，route clean，WNS `15.547 ns`，BRAM/DSP/URAM 均为 0。

上板结果仍 FAIL：

- 正常 `psu_init` 在写 `0xFF1800B4` 时 AP transaction timeout；
- 跳过 `psu_init` 后读 `0xA0000000` 仍报 `Cortex-A53 #0: EDITR not ready`；
- 正式 summary：`board_runs/ps_axi_lite_register_probe/f50m_20260627_0030_skippsu_psu_summary/ps_axi_lite_register_probe_summary.md`。

因此当前 true 2x2 还没有进入有效 W8A12 计算验证，必须先恢复板端 PS/AXI-Lite 调试访问。

## 已知仿真黄金结果

2x2 reference 生成成功，软件整数参考和 fake/integer 完全一致：

| 比较项 | mismatch bytes | total bytes | PSNR |
| --- | ---: | ---: | ---: |
| fake vs integer | 0 | 192 | Infinity |
| PyTorch vs integer | 108 | 192 | 48.8419 dB |

注意：这里的 PSNR 是 2x2 最小样例的参考一致性指标，不代表 REDS 全量质量指标。

## 下一步

1. 先恢复板端 PS/AXI-Lite 可访问状态：物理断电重上电后重跑最小 AXI-Lite register-only probe。
2. 若最小 probe 读写 magic/scratch PASS，再重跑 true 2x2 板测。
3. true 2x2 能写控制寄存器后，再观察 `DEBUG_SPAB_B1_C1_SAMPLE0..3`，确认窗口 reset、valid/ready、core busy/done。
4. 若 2x2 DDR 输出比对 PASS，再扩大到 32x32 快速图，并保留资源、时序、输出 PNG、mismatch 和 PSNR 证据。
