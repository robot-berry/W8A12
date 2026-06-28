# W8A12_3lane PPA Summary

Status: PASS

This report is generated from existing Vivado OOC/resource-gate evidence.
It is intended for the contest technical report. It does not claim board-measured FPS or power.

## Resource And Timing Summary

| Module | Status | LUT | LUT % | FF | FF % | BRAM | BRAM % | DSP | DSP % | WNS(ns) | WHS(ns) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A4 MAC core TAP_PAR=8 | RESOURCE_PASS | 51 | 0.02% | 49 | 0.01% | 0 | 0.00% | 8 | 0.89% | NA | NA |
| A4 single-lane scheduler | PASS | 41003 | 18.76% | 85414 | 19.54% | 0 | 0.00% | 224 | 24.89% | 1.261 | 0.072 |
| A4 3-lane scheduler | PASS | 123182 | 56.35% | 256222 | 58.61% | 0 | 0.00% | 672 | 74.67% | 1.188 | 0.072 |
| accelerator top shell | PASS | 0 | 0.00% | 5 | 0.00% | 0 | 0.00% | 0 | 0.00% | 9.130 | 0.071 |

## Scope Notes

| Module | Evidence | Scope |
| --- | --- | --- |
| A4 MAC core TAP_PAR=8 | `W8A12_3lane/evidence/resource/A4_lane_mac_core_ooc/xc7z045_resource_gate.json` | single reusable lane MAC primitive; timing report not available in this legacy gate |
| A4 single-lane scheduler | `W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.json` | one 16-channel output lane scheduler |
| A4 3-lane scheduler | `W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.json` | three 16-channel output lanes, 48 output channels total |
| accelerator top shell | `W8A12_3lane/evidence/top/accel_top_ooc/ooc_summary.json` | control/status shell only, not full datapath resource |

## Reporting Rules

- Resource limits use the XC7Z045/ZC706-equivalent gate: LUT 218600, FF 437200, BRAM tile 545, DSP 900.
- OOC results are valid module-level synthesis evidence, not full board implementation results.
- The accelerator top shell row is only the control/status shell; it must not be reported as the full W8A12 datapath resource.
- Board FPS, latency, and measured power remain pending until real board validation produces runtime logs.
