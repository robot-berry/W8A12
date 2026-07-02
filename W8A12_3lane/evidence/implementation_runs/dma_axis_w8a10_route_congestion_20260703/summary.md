# DMA/AXIS W8A10 Large Implementation Attempt

Status: FAIL_ROUTE_CONGESTION_NO_BITSTREAM

Generated at: 2026-07-03 02:43 CST

## Scope

This evidence records the 2026-07-03 Vivado implementation attempt for `dma_axis_w8a10_system_wrapper` on `xczu19eg-ffvc1760-2-i`.
It is a large integration/resource stress run for the DMA/AXIS compute shell, not a successful W8A12_3lane 720p bitstream and not board-measured FPS evidence.

## Result

| Item | Value |
| --- | --- |
| Vivado run | `vivado/dma_axis_w8a10_bd/dma_axis_w8a10_bd.runs/impl_1` |
| batch script | `scripts/run_vivado_bitstream_dma_axis_w8a10.tcl` |
| final state | route failed / `.vivado.error.rst` present |
| bitstream generated | no |
| `write_bitstream` started | no |
| `route_design` completed | no |
| failure boundary | route congestion during `Phase 4 Initial Routing` |
| final route warning | `Route 35-447`: congestion prevented routing all nets |
| intermediate route WNS | `-18.104 ns` |
| intermediate route TNS | `-3913353.601 ns` |
| intermediate WHS / THS | `-0.108 ns` / `-40.190 ns` |
| route failed nets at initialization | `679311` |
| route unrouted nets at initialization | `622946` |
| route partially routed nets at initialization | `56365` |
| route node overlaps at initialization | `6` |

## Placed Utilization Snapshot

| Resource | Used | Device available | Utilization |
| --- | ---: | ---: | ---: |
| CLB LUTs | 279774 | 522720 | 53.52% |
| CLB registers | 363066 | 1045440 | 34.73% |
| CLB sites | 63744 | 65340 | 97.56% |
| Block RAM tile | 619 | 984 | 62.91% |
| DSP | 769 | 1968 | 39.08% |

## Interpretation

- DSP usage is below the xczu19eg device limit, but CLB site pressure is extremely high after placement.
- The run did not produce a `.bit`, so it must not be used as bitstream/PPA pass evidence.
- The result supports the current report wording: full large integrated hardware closure remains pending, while true2x2/JTAG-W8A12 and module/OOC evidence remain the current bitstream/PPA submission scope.
- Next implementation route should reduce CLB/routing pressure before another full route attempt, for example by smaller tile scope, reduced feature/buffer footprint, lower parallel fanout, or staged partial integration.

