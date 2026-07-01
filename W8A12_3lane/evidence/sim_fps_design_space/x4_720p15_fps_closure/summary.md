# X4 720p15 FPS Closure

Status: PASS

This evidence closes the x4 720p 15fps target at scheduler/performance-model level.
It does not claim board-measured FPS or full packed 2-D pixel RTL bit-exact completion.

| Item | Value |
| --- | --- |
| model | REDS SPAN x4 F48 W8A12 |
| scale | x4 |
| LR input | 320x180 |
| SR output | 1280x720 |
| clock | 250 MHz |
| target | 15.0 fps |
| DSP gate | 900 |
| closure level | scheduler/performance-model |

## Candidates

| Role | Candidate | DSP | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps slack |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| minimum resource | 24x64 | 792 | 288 | 16588800 | 15.070 | 0.467% |
| recommended closure | 24x72 | 888 | 248 | 14284800 | 17.501 | 14.291% |

## Checks

| Candidate | Check | Result | Detail |
| --- | --- | --- | --- |
| global | `source_status_pass` | PASS | `PASS` |
| global | `source_stage` | PASS | `packed2d_perf_scheduler` |
| global | `source_frame_720p_x4` | PASS | `320x180 LR -> 1280x720 SR` |
| global | `source_clock_250mhz` | PASS | `250` |
| global | `has_minimum_candidate_24x64` | PASS | `["24x64", "24x72"]` |
| global | `has_recommended_candidate_24x72` | PASS | `["24x64", "24x72"]` |
| global | `scope_scheduler_level` | PASS | `scheduler/performance-model only; not board-measured FPS` |
| 24x64 | `fps_ge_15` | PASS | `15070` |
| 24x64 | `dsp_le_900` | PASS | `792` |
| 24x64 | `lr_frame_pixels` | PASS | `57600` |
| 24x64 | `declares_pass15` | PASS | `True` |
| 24x64 | `not_claiming_20_or_30` | PASS | `{"pass20": false, "pass30": false}` |
| 24x64 | `positive_frame_cycles` | PASS | `16588800` |
| 24x64 | `positive_slack_to_15fps_budget` | PASS | `0.467` |
| 24x72 | `fps_ge_15` | PASS | `17501` |
| 24x72 | `dsp_le_900` | PASS | `888` |
| 24x72 | `lr_frame_pixels` | PASS | `57600` |
| 24x72 | `declares_pass15` | PASS | `True` |
| 24x72 | `not_claiming_20_or_30` | PASS | `{"pass20": false, "pass30": false}` |
| 24x72 | `positive_frame_cycles` | PASS | `14284800` |
| 24x72 | `positive_slack_to_15fps_budget` | PASS | `14.291` |
| 24x72 | `recommended_slack_ge_min` | PASS | `14.291` |

## Interpretation

- `24x64` is retained as the minimum-resource 15fps point. Its slack is small, so it is not the recommended implementation point.
- `24x72` is the recommended closure point because it remains under 900 DSP and has more than 10% frame-cycle slack against the 15fps budget.
- x2 720p20, x4 20fps, and x4 30fps are not claimed by this gate.
