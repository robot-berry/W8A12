# W8A12_3lane BRAM 消耗计算

Status: PASS

## 口径

- BRAM36 按 `36864` bit/tile 计算；XC7Z045/ZC706 等效门限按 `545` BRAM tile。
- 模型常量按 unique layer weight/bias/requant/LUT 逻辑位宽计算，不重复统计导出目录中的 raw/grouped 多视图文件。
- 32x32 tile buffer 是理论存储下限；真实 Vivado BRAM 会因为 banking、端口、位宽对齐、FIFO 和调试/PS 壳产生额外开销。

## 模型常量存储

| Model | Scale | Act bits | Layers | Weights bits | Bias/Requant bits | LUT bits | Total bits | BRAM36 exact | BRAM36 ceil |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| x4 W8A12/F48 | 4 | 12 | 22 | 3401856 | 109824 | 884736 | 4398656 | 119.32 | 120 |
| x2 W8A12/F48 | 2 | 12 | 22 | 3277440 | 106080 | 884736 | 4270496 | 115.84 | 116 |

## 32x32 Tile Buffer 下限

| Model | Scale | Tile/Halo | Feature buffers | Buffer bits | BRAM36 exact | BRAM36 ceil |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| x4 W8A12/F48 | 4 | 32x32 / h21 | 8 | 5243232 | 142.23 | 143 |
| x2 W8A12/F48 | 2 | 32x32 / h21 | 8 | 4948320 | 134.23 | 135 |

### x4 32x32 明细

| Item | Formula | Bits | BRAM36 exact | BRAM36 ceil |
| --- | --- | ---: | ---: | ---: |
| rgb_halo_tile | `(32+2*21)*(32+2*21)*3*8` | 131424 | 3.57 | 4 |
| feature_buffer_x8 | `8*32*32*48*12` | 4718592 | 128.00 | 128 |
| sr_rgb_output_tile | `(32*4)*(32*4)*3*8` | 393216 | 10.67 | 11 |

## Vivado 实际 BRAM 口径

| Implementation / OOC | Status | BRAM tile | XC7Z045 % | Evidence |
| --- | --- | ---: | ---: | --- |
| A4 single-lane scheduler | `PASS` | 0.0 | 0.00% | `W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.json` |
| A4 3-lane scheduler | `PASS` | 0.0 | 0.00% | `W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.json` |
| true2x2 JTAG-W8A12 dbg5 implementation | `PASS_WITH_SCOPE` | 311.0 | 57.06% | `W8A12_3lane/evidence/bitstream_ppa_gate/summary.json` |
| true2x2 JTAG-W8A12 dbg6 synth snapshot | `BUILD_PARTIAL_NO_BITSTREAM` | 311.0 | 57.06% | `W8A12_3lane/evidence/implementation_runs/jtag_true2x2_dbg6_build_attempt_20260703/summary.json` |
| A5 32x32 PS-DDR tile-writer attempt | `PASS` | 415.5 | 76.24% | `W8A12_3lane/evidence/board_reports/a5_32x32_attempt/attempt_summary.json` |
| large DMA/AXIS integration stress run | `FAIL_ROUTE_CONGESTION_NO_BITSTREAM` | 619.0 | 113.58% | `W8A12_3lane/evidence/implementation_runs/dma_axis_w8a10_route_congestion_20260703/summary.json` |

## 结论

- A4 scheduler OOC BRAM 为 0，是因为该 OOC 只覆盖计算调度逻辑，不含 tile/frame buffer 与权重 ROM。
- x4 W8A12/F48 的模型常量逻辑下限约为 `119.32` BRAM36；32x32 tile buffer 下限约为 `142.23` BRAM36。
- 当前可用于 PPA 提交口径的 true2x2/JTAG-W8A12 实现为 `311` BRAM tile，占 XC7Z045/ZC706 等效门限 `57.06%`；A5 32x32 attempt 为 `415.5` BRAM tile，占 `76.24%`，资源门限 PASS 但板端完成信号未通过。
- 大集成压力测试使用 `619` BRAM tile，超过 XC7Z045/ZC706 等效门限且 route 未完成，只能作为后续降资源风险证据。
