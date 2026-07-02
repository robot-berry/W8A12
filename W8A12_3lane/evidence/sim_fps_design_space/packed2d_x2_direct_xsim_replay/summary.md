# Packed 2-D x2 Direct XSIM Replay

Status: PASS

Runner: direct xvlog -> xelab -> xsim.

This replay exists so x2 scheduler FPS evidence can be refreshed without starting another Vivado batch/project process while implementation runs are active.
It is still scheduler/performance-model evidence only; it is not pixel-correctness RTL closure and not board-measured FPS.

| Item | Value |
| --- | --- |
| model | REDS SPAN x2 F48 W8A12 |
| frame | 640x360 LR -> 1280x720 SR |
| clock | 250 MHz |
| resource gate | XC7Z045/ZC706 900 DSP planning gate |
| 20fps target under 900-DSP gate | FAIL |
| matches Vivado batch summary | True |
| simulate_log | G:\UESTC\feitengspan1\build\xsim_direct_w8a12_packed2d_x2_720p20_perf_scheduler\simulate.log |
| source_summary_json | G:\UESTC\feitengspan1\W8A12_3lane\evidence\sim_fps_design_space\packed2d_x2_720p20_perf_scheduler\summary.json |

## Candidates

| Candidate | Output lanes | Tap lanes | Est. DSP | Resource gate | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 24x64 | 24 | 64 | 792 | PASS | 281 | 64742400 | 3.861 | FAIL | FAIL | FAIL |
| 24x72 | 24 | 72 | 888 | PASS | 242 | 55756800 | 4.483 | FAIL | FAIL | FAIL |
| 48x144 | 48 | 144 | 3504 | FAIL | 63 | 14515200 | 17.223 | PASS | FAIL | FAIL |

## Interpretation

- Direct xsim replay reproduces the candidate metrics in the Vivado batch summary.
- 24x72 remains the lowered x2 720p4 closure point at 4.483fps and 888 DSP.
- x2 720p20 remains not claimed under the 900-DSP planning gate.
