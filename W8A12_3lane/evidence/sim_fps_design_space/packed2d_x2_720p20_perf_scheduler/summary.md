# Packed 2-D x2 720p20 FPS Scheduler Simulation

Status: PASS

20fps target under 900-DSP gate: FAIL

This is a scheduler/performance-model xsim result for the x2 route. It is not a pixel-correctness simulation and not a board-measured FPS report.

| Item | Value |
| --- | --- |
| model | REDS SPAN x2 F48 W8A12 |
| layers | 22 convolution layers |
| frame | 640x360 LR -> 1280x720 SR |
| clock | 250 MHz |
| resource gate | XC7Z045/ZC706 900 DSP planning gate |
| tail output channels | 12 |
| simulate_log | G:\UESTC\feitengspan1\build\vivado_w8a12_packed2d_x2_720p20_perf_scheduler_sim\w8a12_packed2d_x2_720p20_perf_scheduler_sim.sim\sim_1\behav\xsim\simulate.log |

## Candidates

| Candidate | Output lanes | Tap lanes | Est. DSP | Resource gate | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 24x64 | 24 | 64 | 792 | PASS | 281 | 64742400 | 3.861 | FAIL | FAIL | FAIL |
| 24x72 | 24 | 72 | 888 | PASS | 242 | 55756800 | 4.483 | FAIL | FAIL | FAIL |
| 48x144 | 48 | 144 | 3504 | FAIL | 63 | 14515200 | 17.223 | PASS | FAIL | FAIL |

## Interpretation

- The 900-DSP resource-gated candidates do not reach x2 720p20 at 250 MHz.
- Even the non-gated 48x144 sizing point remains below 20fps at 250 MHz and exceeds the ZC706/XC7Z045 DSP planning gate.
- Therefore x2 720p20 is not closed by the current full W8A12/F48 packed 2-D plan. Closing this target needs a smaller student model, higher resource budget/clock, or a more aggressive architecture than this planning gate permits.

