# W8A12 Parallel Frame Engine Sizing

This is a planning estimate for the next REDS-trained W8A12 RTL frame engine. It assumes one reusable convolution engine with two dimensions of parallelism: output-channel lanes and tap/input-channel lanes.

## Inputs

- manifest: `rtl\generated\reds_span_x4_f48_w8a12\span_w8a12_rtl_manifest.json`
- checkpoint: `runs\official_span\official_SPAN_REDS_x4_f48\models\net_g_295000.pth`
- scale: `X4`
- channels: `48`
- layers: `22`
- MACs per LR pixel: `425,232`
- device DSP budget: `900`
- packed MAC assumption: `2` MAC/DSP/cycle
- requant DSP estimate: `1` DSP/output lane
- requant pipeline cycles charged to throughput: `0` cycles/output group

## Best 250 MHz 720p30 Candidates

| Budget | Output lanes | Tap lanes | MAC lanes | Est. DSP | Cycles/LR px | FPS 320x180 @250MHz | FPS 320x180 @200MHz | Efficiency |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 80% DSP | `none` | `none` | `none` | `none` | `none` | `<30` | `<30` | `n/a` |
| 100% DSP | `none` | `none` | `none` | `none` | `none` | `<30` | `<30` | `n/a` |

## Pareto Candidates

| Output lanes | Tap lanes | MAC lanes | Packed MAC DSP | Requant DSP | Est. DSP | 80% DSP OK | Cycles/LR px | FPS @250MHz 320x180 | FPS @200MHz 320x180 | FPS @250MHz 480x270 | Efficiency |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `48` | `144` | `6912` | `3456` | `48` | `3504` | `no` | `63` | `68.89` | `55.11` | `30.62` | `97.7%` |
| `48` | `108` | `5184` | `2592` | `48` | `2640` | `no` | `83` | `52.29` | `41.83` | `23.24` | `98.8%` |
| `48` | `96` | `4608` | `2304` | `48` | `2352` | `no` | `103` | `42.14` | `33.71` | `18.73` | `89.6%` |
| `48` | `72` | `3456` | `1728` | `48` | `1776` | `no` | `124` | `35.00` | `28.00` | `15.56` | `99.2%` |
| `24` | `144` | `3456` | `1728` | `24` | `1752` | `no` | `126` | `34.45` | `27.56` | `15.31` | `97.7%` |
| `48` | `64` | `3072` | `1536` | `48` | `1584` | `no` | `144` | `30.14` | `24.11` | `13.40` | `96.1%` |
| `48` | `54` | `2592` | `1296` | `48` | `1344` | `no` | `165` | `26.30` | `21.04` | `11.69` | `99.4%` |
| `24` | `108` | `2592` | `1296` | `24` | `1320` | `no` | `166` | `26.15` | `20.92` | `11.62` | `98.8%` |
| `48` | `48` | `2304` | `1152` | `48` | `1200` | `no` | `185` | `23.46` | `18.77` | `10.43` | `99.8%` |
| `16` | `144` | `2304` | `1152` | `16` | `1168` | `no` | `189` | `22.96` | `18.37` | `10.21` | `97.7%` |
| `48` | `36` | `1728` | `864` | `48` | `912` | `no` | `247` | `17.57` | `14.06` | `7.81` | `99.6%` |
| `24` | `72` | `1728` | `864` | `24` | `888` | `no` | `248` | `17.50` | `14.00` | `7.78` | `99.2%` |
| `16` | `108` | `1728` | `864` | `16` | `880` | `no` | `249` | `17.43` | `13.94` | `7.75` | `98.8%` |
| `12` | `144` | `1728` | `864` | `12` | `876` | `no` | `252` | `17.22` | `13.78` | `7.65` | `97.7%` |
| `48` | `32` | `1536` | `768` | `48` | `816` | `no` | `287` | `15.12` | `12.10` | `6.72` | `96.5%` |
| `24` | `64` | `1536` | `768` | `24` | `792` | `no` | `288` | `15.07` | `12.06` | `6.70` | `96.1%` |
| `16` | `96` | `1536` | `768` | `16` | `784` | `no` | `309` | `14.05` | `11.24` | `6.24` | `89.6%` |
| `48` | `27` | `1296` | `648` | `48` | `696` | `yes` | `329` | `13.19` | `10.55` | `5.86` | `99.7%` |
| `24` | `54` | `1296` | `648` | `24` | `672` | `yes` | `330` | `13.15` | `10.52` | `5.85` | `99.4%` |
| `12` | `108` | `1296` | `648` | `12` | `660` | `yes` | `332` | `13.07` | `10.46` | `5.81` | `98.8%` |

## Interpretation

At `200 MHz`, the full REDS-trained W8A12 SPAN must sustain X4 `320x180 -> 1280x720 @30fps`. At `250 MHz`, the full-model path becomes more plausible, but still depends on high parallelism across both output channels and taps plus sustained INT8 MAC utilization.

This does not replace RTL synthesis. It selects the next frame-engine target: keep W8A12 as the quality/reference model, prototype the smallest 250 MHz candidate that reaches 720p30 in this sizing table, then compare RTL/board output against the integer W8A12 reference preview on every test.

If timing, memory banking, or DSP packing cannot sustain the selected candidate, the hardware path should branch to a trained smaller SPAN-family student while preserving this REDS-trained W8A12 model as the teacher and correctness reference.
