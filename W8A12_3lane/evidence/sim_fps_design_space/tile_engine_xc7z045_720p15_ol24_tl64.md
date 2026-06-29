# W8A12 Hardware Tile Engine Sizing

This estimate is for the hardware-side SD/DDR large-image tiling route. It is not a Vivado utilization report.

## Assumptions

- frame_w: `320`
- frame_h: `180`
- clock_mhz: `250.0`
- output_lanes: `24`
- tap_lanes: `64`
- cycles_per_compute_pixel: `288`
- halo_radius_lr: `21`
- working_feature_maps: `7`
- scale: `4`
- channels: `48`
- activation_bits: `12`
- spatial_3x3_layers: `21`
- note: `Halo radius is one LR pixel per sequential 3x3 layer; exact RTL may use line buffering instead of padded tile recompute.`

## Tile Candidates

| Output tile | Compute tile with halo | Halo overhead | Tiles/frame | Cycles/frame | FPS | 10fps | 15fps | 30fps | Feature BRAM36 est. |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | ---: |
| `16x16` | `58x58` | `13.14x` | `240` | `232,519,680` | `1.08` | `no` | `no` | `no` | `368` |
| `32x32` | `74x74` | `5.35x` | `60` | `94,625,280` | `2.64` | `no` | `no` | `no` | `599` |
| `48x48` | `90x90` | `3.52x` | `28` | `65,318,400` | `3.83` | `no` | `no` | `no` | `886` |
| `64x64` | `106x106` | `2.74x` | `15` | `48,539,520` | `5.15` | `no` | `no` | `no` | `1229` |
| `80x80` | `122x122` | `2.33x` | `12` | `51,439,104` | `4.86` | `no` | `no` | `no` | `1628` |
| `96x96` | `138x138` | `2.07x` | `8` | `43,877,376` | `5.70` | `no` | `no` | `no` | `2083` |
| `128x128` | `170x170` | `1.76x` | `6` | `49,939,200` | `5.01` | `no` | `no` | `no` | `3161` |

## Interpretation

- Exact full-image tiling needs halo or an equivalent cross-tile/line-buffer design. A no-halo per-tile run only proves isolated-tile parity.
- Smaller tiles amplify halo work. If the compute engine can fit, `32x32` is a better board/video route than `16x16` because the halo overhead is much lower.
- If this estimate misses 15fps/30fps, lowering the acceptance gate to 10fps does not fix the architecture; it only makes the first board demo easier.
- The next RTL gate should be a time-multiplexed tile compute engine that consumes halo-padded tiles and emits only the valid interior tile.
