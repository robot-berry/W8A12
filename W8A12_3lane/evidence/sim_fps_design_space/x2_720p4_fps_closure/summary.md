# X2 720p4 FPS Closure

Status: PASS

This evidence closes the lowered x2 720p 4fps target at scheduler/performance-model level.
It does not claim board-measured FPS, full packed 2-D pixel RTL bit-exact completion, or x2 720p20 completion.

| Item | Value |
| --- | --- |
| model | REDS SPAN x2 F48 W8A12 |
| scale | x2 |
| LR input | 640x360 |
| SR output | 1280x720 |
| clock | 250 MHz |
| lowered target | 4.0 fps |
| DSP gate | 900 |
| closure level | scheduler/performance-model |

## Candidates

| Role | Candidate | DSP | Resource gate | Cycles/LR pixel | Frame cycles | FPS @250MHz | 4fps slack |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: |
| resource boundary | 24x64 | 792 | True | 281 | 64742400 | 3.861 | -3.588% |
| recommended closure | 24x72 | 888 | True | 242 | 55756800 | 4.483 | 10.789% |
| non-gated reference | 48x144 | 3504 | False | 63 | 14515200 | 17.223 | 76.776% |

## Checks

| Candidate | Check | Result | Detail |
| --- | --- | --- | --- |
| global | `source_status_pass` | PASS | `PASS` |
| global | `source_stage` | PASS | `packed2d_x2_720p20_perf_scheduler` |
| global | `source_frame_720p_x2` | PASS | `640x360 LR -> 1280x720 SR` |
| global | `source_clock_250mhz` | PASS | `250` |
| global | `source_20fps_still_fails` | PASS | `FAIL` |
| global | `has_boundary_candidate_24x64` | PASS | `["24x64", "24x72", "48x144"]` |
| global | `has_recommended_candidate_24x72` | PASS | `["24x64", "24x72", "48x144"]` |
| global | `scope_scheduler_level` | PASS | `scheduler/performance-model only; not board-measured FPS` |
| 24x64 | `dsp_le_900` | PASS | `792` |
| 24x64 | `documents_4fps_fail` | PASS | `3861` |
| 24x64 | `lr_frame_pixels` | PASS | `230400` |
| 24x72 | `fps_ge_4` | PASS | `4483` |
| 24x72 | `dsp_le_900` | PASS | `888` |
| 24x72 | `resource_gate_true` | PASS | `True` |
| 24x72 | `lr_frame_pixels` | PASS | `230400` |
| 24x72 | `recommended_slack_ge_min` | PASS | `10.789` |
| 24x72 | `does_not_claim_20fps` | PASS | `False` |
| 48x144 | `documents_resource_gate_fail` | PASS | `3504` |

## Interpretation

- `24x64` remains under 900 DSP but reaches only 3.861fps, so it is documented as a boundary point rather than a 4fps closure point.
- `24x72` is the recommended x2 lowered-target closure point: 4.483fps @250MHz, 888 DSP, and 10.789% frame-cycle slack against the 4fps budget.
- `48x144` reaches higher FPS but uses 3504 DSP, so it is not valid under the ZC706/XC7Z045 900-DSP planning gate.
- x2 720p20, x4 20fps, and x4 30fps are not claimed by this gate.
