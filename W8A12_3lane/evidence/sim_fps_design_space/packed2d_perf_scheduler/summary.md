# Packed 2-D FPS Scheduler Simulation

Status: PASS

This is the 720p x4 FPS simulation gate for the next W8A12 performance-engine route. It is a scheduler-level xsim result, not a pixel-correctness simulation and not a board-measured FPS report.

| Item | Value |
| --- | --- |
| model | REDS SPAN x4 F48 W8A12 |
| layers | 22 convolution layers |
| frame | 320x180 LR -> 1280x720 SR |
| clock | 250 MHz |
| resource gate | XC7Z045/ZC706 900 DSP planning gate |
| simulate_log | G:\UESTC\feitengspan1\build\vivado_w8a12_packed2d_perf_scheduler_sim\w8a12_packed2d_perf_scheduler_sim.sim\sim_1\behav\xsim\simulate.log |

## Candidates

| Candidate | Output lanes | Tap lanes | Est. DSP | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| 24x64 | 24 | 64 | 792 | 288 | 16588800 | 15.07 | PASS | FAIL | FAIL |
| 24x72 | 24 | 72 | 888 | 248 | 14284800 | 17.501 | PASS | FAIL | FAIL |

## Interpretation

- 24x64 is the minimum-resource 15fps candidate found under the 900-DSP planning gate; it has almost no timing/overhead margin.
- 24x72 gives more FPS margin but uses nearly the full 900-DSP gate.
- This closes the FPS target only at scheduler/performance-model level. The remaining engineering work is to implement the packed 2-D engine, memory banking, and line-buffer/halo reuse RTL, then re-run correctness and OOC/PPA gates.

