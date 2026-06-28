# W8A12 true 2x2 上板参数配置对照审计

时间：2026-06-26

## 结论

对照已能在真实板上完成寄存器读写和 `FRAME_DONE=1` 的 32x32 W8A12 PS-DDR 例程后，当前 true 2x2 bitstream 没发现 PS/PL 基础参数配置错误。

当前 `0xA0000000` 写控制寄存器失败，更像以下两类问题之一：

1. 板端 PS/XSCT/JTAG debug 状态异常，导致 A53/PSU 访问通道 `EDITR not ready` 或 AP transaction timeout；
2. true 2x2 bitstream 下载后 PL 侧 AXI-Lite 从设备没有响应，例如控制口复位/时钟/AXI-Lite slave 响应被卡住。

它暂时不像是 `ctrl_base`、DDR 基址、PS DDR preset、HPM/HP 端口没有配置好。

## 对照对象

| 对象 | 路径/证据 | 作用 |
| --- | --- | --- |
| true 2x2 新 bitstream | `b/w8a12_2x2_samplelatch_20260626_2229/psw8a12ddr_true2x2_samplelatch_20260626_2229` | 当前待上板闭环的 2x2 bit |
| 32x32 已跑通例程 | `b/w8r32a/psw8a12ddr_refddr32_20260625a` | 对照 PS/DDR/AXI 参数 |
| 32x32 板测日志 | `board_runs/w8a12_ps_ddr_tile_writer_smoke/live_retry_20260625_direct/run_xsct_ps_w8a12_ddr_tile_writer_smoke.log` | 同一控制口可读写，`FRAME_DONE=1` |
| 32x32 bit runtime 2x2 日志 | `board_runs/w8a12_ps_ddr_tile_writer_smoke/wrdebug32_runtime_2x2_20260625_2230/run_xsct_ps_w8a12_ddr_tile_writer_smoke.stdout.log` | 同一控制口可读写，输入 DDR readback mismatch=0 |

## PS/DDR 参数对照

| 参数 | true 2x2 | 32x32 例程 | 是否一致 |
| --- | --- | --- | --- |
| device | `xczu19eg-ffvc1760-2-i` | `xczu19eg-ffvc1760-2-i` | 是 |
| BD validated | `true` | `true` | 是 |
| PL0 clock | `50 MHz` | `50 MHz` | 是 |
| PL0 source | `IOPLL` | `IOPLL` | 是 |
| fabric reset | `1` | `1` | 是 |
| PS master to PL | `PSU__USE__M_AXI_GP0=1` / `M_AXI_HPM0_FPD` | 同左 | 是 |
| PL master to DDR | `PSU__USE__S_AXI_GP2=1` / `S_AXI_HP0_FPD` | 同左 | 是 |
| DDR preset | `DDR4_MICRON_MT40A256M16GE_083E` | 同左 | 是 |
| `psu_init.tcl` SHA256 | `A5ADDAE2D8E4690D19C997205D9813927F8768F10C688584E752AC50B09CCDCA` | 同左 | 是 |

## 地址段对照

| 地址项 | true 2x2 | 32x32 例程 | 是否一致 |
| --- | --- | --- | --- |
| AXI-Lite control offset | `0x00A0000000` | `0x00A0000000` | 是 |
| AXI-Lite control range | `64K` | `64K` | 是 |
| PL master DDR offset | `0x00000000` | `0x00000000` | 是 |
| PL master DDR range | `2G` | `2G` | 是 |
| input DDR base | `0x10000000` | `0x10000000` | 是 |
| output DDR base | `0x11000000` | `0x11000000` | 是 |

## W8A12 endpoint 参数差异

这些差异是本轮故意设置的 true 2x2 最小验证参数，不属于 PS/板级配置错误。

| 参数 | true 2x2 | 32x32 例程 | 说明 |
| --- | --- | --- | --- |
| `DEFAULT_IMG_W/H` | `2 x 2` | `32 x 32` | 输入图尺寸不同 |
| `TILE_W/H` | `2 x 2` | `32 x 32` | tile 尺寸不同 |
| `HALO` | `21` | `21` | 一致 |
| `OUT_LANES` | `1` | `1` | 一致 |
| `TAP_LANES` | `4` | `4` | 一致 |
| `SCALE_LANES` | `1` | `1` | 一致 |
| `M_AXI_DATA_WIDTH` | `32` | `32` | 一致 |

## 已知例程证明

32x32 板测中，同一 `0xA0000000` 控制口已经完成以下动作：

| 证据项 | 日志值 |
| --- | --- |
| `PSU_INIT_PASS` | `1` |
| `CTRL_BASE` | `0xA0000000` |
| `IMG_W_READBACK` | `32` |
| `CONFIG` | `0x00042020` |
| `STATUS` | `0x00000009` |
| `ERROR` | `0x00000000` |
| `FRAME_DONE` | `1` |
| `XSCT_PASS` | `1` |

32x32 bit 的 runtime 2x2 复测中，同一控制口也已经完成：

| 证据项 | 日志值 |
| --- | --- |
| `IMG_W_READBACK` | `2` |
| `CONFIG` | `0x00042020` |
| `INPUT_DDR_VERIFY_MISMATCH` | `0` |
| `FRAME_DONE` | `1` |

该 runtime 2x2 复测后来报 `ERROR=0x00000005`，原因是 32x32 bit 内部 tile/输出计数固化，不能作为 true 2x2 正确性验收；但它足以证明 PS/AXI-Lite/DDR 基础访问路线曾经工作。

## 最小 AXI-Lite register-only 隔离结果

2026-06-27 已生成并上板验证最小 AXI-Lite register-only bitstream：

| 项目 | 结果 |
| --- | --- |
| RTL | `rtl/board/sr_axi_lite_register_probe.v` |
| bitstream | `vivado/bitstreams/ps_axi_lite_register_probe_f50m.bit` |
| control base | `0xA0000000 / 64K` |
| implementation | PASS，route clean，WNS `15.547 ns`，WHS `0.031 ns` |
| resources | LUT 1216，FF 1279，BRAM 0，DSP 0，URAM 0 |
| normal `psu_init` run | FAIL，写 PS 寄存器 `0xFF1800B4` AP transaction timeout |
| skip `psu_init` + A53/PSU access | FAIL，读 `0xA0000000` 时 `Cortex-A53 #0: EDITR not ready` |

正式证据见 `ps_axi_lite_register_probe_20260627.md`。

该结果说明：当前失败已经不只发生在 true 2x2 W8A12 大核上，最小 AXI-Lite 从设备也无法通过 XSCT 读到 magic register。因此优先嫌疑从模型参数/2x2 tile 参数/`ctrl_base` 配置，转到板端 PS/JTAG/XSCT 调试访问状态。

## 下一步隔离验证

1. 物理断电重上电，并关闭残留 `hw_server/xsct/vivado`。
2. 先重跑最小 AXI-Lite register-only probe，确认 `0xA0000000` magic/scratch 可读写。
3. 若最小 probe PASS，再回到 true 2x2 W8A12 bitstream，检查 PL AXI-Lite slave、reset、clock 和 debug sample。
4. 若最小 probe 仍 FAIL，不继续消耗时间综合大核，先解决板端 PS/JTAG/XSCT 调试访问问题。
