# Board Validation Closure

Status: FAIL

Manifest: `W8A12_3lane\evidence\board_reports\validation_closure\manifest_template.json`

Dry run: `True`

| Tag | Status | Detail |
| --- | --- | --- |
| `a5_32x32` | `BLOCKED` | `['board_output', 'fixed_reference', 'resource.lut_used', 'resource.ff_used', 'resource.bram_tile_used', 'resource.dsp_used', 'timing.wns_ns', 'timing.whs_ns', 'performance.clock_mhz', 'performance.latency_ms', 'performance.fps', 'performance.power_w', 'files.bitstream', 'files.utilization_report', 'files.timing_report']` |
| `a6_64x64` | `BLOCKED` | `['board_output', 'fixed_reference', 'resource.lut_used', 'resource.ff_used', 'resource.bram_tile_used', 'resource.dsp_used', 'timing.wns_ns', 'timing.whs_ns', 'performance.clock_mhz', 'performance.latency_ms', 'performance.fps', 'performance.power_w', 'files.bitstream', 'files.utilization_report', 'files.timing_report']` |
| `a7_720p_x4` | `BLOCKED` | `['board_output', 'fixed_reference', 'resource.lut_used', 'resource.ff_used', 'resource.bram_tile_used', 'resource.dsp_used', 'timing.wns_ns', 'timing.whs_ns', 'performance.clock_mhz', 'performance.latency_ms', 'performance.fps', 'performance.power_w', 'files.bitstream', 'files.utilization_report', 'files.timing_report']` |
| `x2_720p` | `BLOCKED` | `['board_output', 'fixed_reference', 'resource.lut_used', 'resource.ff_used', 'resource.bram_tile_used', 'resource.dsp_used', 'timing.wns_ns', 'timing.whs_ns', 'performance.clock_mhz', 'performance.latency_ms', 'performance.fps', 'performance.power_w', 'files.bitstream', 'files.utilization_report', 'files.timing_report']` |

This closure runner does not generate final PASS evidence unless each referenced board output, fixed reference, resource report, timing report, and measured performance value is real and passes `validate_board_report.py`.
