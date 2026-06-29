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
| cycles_per_conv_pixel | 54 |
| equivalent_48x48_conv_stages | 22 |
| tile_overhead_cycles | 1024 |

## Results

| Tag | LR | Tiles | Total cycles | FPS @100MHz | FPS @timing clock | Target FPS | Sim gate @100MHz | Needed clock MHz | Needed spatial factor @100MHz |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| `a5_32x32` | `32x32` | `1x1` | 1217536 | 82.133 | 93.206 | 15.0 | PASS | 18.3 | 1 |
| `a6_64x64` | `64x64` | `2x2` | 4870144 | 20.533 | 23.301 | 15.0 | PASS | 73.1 | 1 |
| `a7_720p_x4` | `320x180` | `10x6` | 68490240 | 1.460 | 1.657 | 15.0 | FAIL | 1027.4 | 11 |
| `x2_720p` | `640x360` | `20x12` | 273960960 | 0.365 | 0.414 | 15.0 | FAIL | 4109.4 | 42 |

## Interpretation

- A PASS here only means the current simulation/model estimate meets the configured FPS target.
- A FAIL here identifies a performance gap in the modeled 3-lane schedule; it is not a correctness failure.
- Board FPS remains pending until `evidence/board_reports/<tag>/validation.md` is produced from real board output and runtime logs.
