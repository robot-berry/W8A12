# Simulated FPS Estimate

Status: FAIL

This is a model-level throughput estimate from the current A4 3-lane MAC schedule. It is not board-measured FPS and does not replace board validation.

## Assumptions

| Field | Value |
| --- | ---: |
| clock_mhz | 100.000 |
| timing_inferred_clock_mhz | 113.482 |
| feature_channels | 48 |
| kernel_taps | 9 |
| tap_par | 8 |
| cycle_source | A4 RTL sim measured-compatible model |
| layer_count | 22 |
| ideal_one_cycle_tap_groups_per_lr_pixel | 1108 |
| measured_reference_stage_cycles_per_pixel | 111 |
| derived_per_layer_overhead_cycles | 3 |
| cycles_per_lr_pixel | 2282 |
| tile_overhead_cycles | 1024 |

## Results

| Tag | LR | Tiles | Total cycles | FPS @100MHz | FPS @timing clock | Target FPS | Sim gate @100MHz | Needed clock MHz | Needed spatial factor @100MHz |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| `a5_32x32` | `32x32` | `1x1` | 2337792 | 42.775 | 48.542 | 15.0 | PASS | 35.1 | 1 |
| `a6_64x64` | `64x64` | `2x2` | 9351168 | 10.694 | 12.136 | 15.0 | FAIL | 140.3 | 2 |
| `a7_720p_x4` | `320x180` | `10x6` | 131504640 | 0.760 | 0.863 | 15.0 | FAIL | 1972.6 | 20 |
| `x2_720p` | `640x360` | `20x12` | 526018560 | 0.190 | 0.216 | 15.0 | FAIL | 7890.3 | 79 |

## Interpretation

- A PASS here only means the current simulation/model estimate meets the configured FPS target.
- A FAIL here identifies a performance gap in the modeled 3-lane schedule; it is not a correctness failure.
- Board FPS remains pending until `evidence/board_reports/<tag>/validation.md` is produced from real board output and runtime logs.
