# W8A12_3lane FPS 目标状态

日期：2026-06-29；x2 720p20 补充：2026-06-30

状态：PARTIAL / x4 15fps scheduler gate PASS / x2 720p20 scheduler gate FAIL

本文只汇总 FPS 仿真和估算证据，不声明板端实测 FPS。当前结论需要分成两层：

1. 当前 3-lane correctness RTL 只能支撑小图 A5 的 15fps 估算，不能支撑 720p x4 15fps。
2. 新的 packed 2-D performance scheduler 在 720p x4、250MHz、XC7Z045/ZC706 900-DSP 规划门限下，已经通过 15fps scheduler-level xsim gate。
3. 新增 x2 720p20 packed 2-D scheduler 证据后，900-DSP 门限内 candidate 均未达到 20fps。

## 当前 3-lane RTL 吞吐

| 项目 | 结果 |
| --- | --- |
| A4 3-lane scheduler xsim | PASS |
| 单 48x48 3x3 stage 输入 | 16 LR pixels |
| 单 stage 周期 | 1761 cycles |
| 单 stage cycles/pixel ceil | 111 |
| 当前 full W8A12 cycles/LR pixel 估算 | 2282 |
| 证据 | `W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md`、`W8A12_3lane/evidence/sim_fps_estimate/summary.md` |

| 场景 | LR 输入 | 输出 | FPS @100MHz | timing inferred FPS | 15fps |
| --- | --- | --- | ---: | ---: | --- |
| A5 | 32x32 | 128x128 x4 | 42.775 | 48.542 | PASS |
| A6 | 64x64 | 256x256 x4 | 10.694 | 12.136 | FAIL |
| A7 | 320x180 | 1280x720 x4 | 0.760 | 0.863 | FAIL |
| x2 | 640x360 | 1280x720 x2 | 0.190 | 0.216 | FAIL |

结论：当前 3-lane RTL 是 correctness/bring-up 架构，不是 720p 实时架构。

## Packed 2-D FPS scheduler gate

新增 performance-only RTL/xsim gate：

| 文件 | 路径 |
| --- | --- |
| RTL | `W8A12_3lane/rtl/span/w8a12_packed2d_perf_scheduler.v` |
| testbench | `W8A12_3lane/sim/tb_w8a12_packed2d_perf_scheduler.sv` |
| 脚本 | `W8A12_3lane/scripts/run_vivado_sim_w8a12_packed2d_perf_scheduler.ps1` |
| 证据 | `W8A12_3lane/evidence/sim_fps_design_space/packed2d_perf_scheduler/summary.md` |

仿真结果：

| Candidate | Output lanes | Tap lanes | Est. DSP | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| 24x64 | 24 | 64 | 792 | 288 | 16,588,800 | 15.070 | PASS | FAIL | FAIL |
| 24x72 | 24 | 72 | 888 | 248 | 14,284,800 | 17.501 | PASS | FAIL | FAIL |

解释：

- `24x64` 是 900-DSP 规划门限内的最小 15fps candidate，但几乎没有控制、访存、halo 复用开销余量。
- `24x72` 有更好的 15fps 余量，但估算 DSP 已达 888，接近 900-DSP 门限。
- 该 PASS 是 scheduler/performance-model 级别，不是完整 packed 2-D 像素计算 RTL 的 bit-exact PASS，也不是板端实测 FPS。

## x2 720p20 packed 2-D scheduler gate

新增 x2 路径 performance-only RTL/xsim gate，输入为 `640x360 LR`，输出为 `1280x720 SR`。尾层 `TAIL_OUT_CHANNELS=12`，用于匹配 x2 pixelshuffle 输出通道。

| 文件 | 路径 |
| --- | --- |
| RTL | `W8A12_3lane/rtl/span/w8a12_packed2d_perf_scheduler.v` |
| testbench | `W8A12_3lane/sim/tb_w8a12_packed2d_x2_720p20_perf_scheduler.sv` |
| 脚本 | `W8A12_3lane/scripts/run_vivado_sim_w8a12_packed2d_x2_720p20_perf_scheduler.ps1` |
| 证据 | `W8A12_3lane/evidence/sim_fps_design_space/packed2d_x2_720p20_perf_scheduler/summary.md` |

仿真结果：

| Candidate | Output lanes | Tap lanes | Est. DSP | Resource gate | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 24x64 | 24 | 64 | 792 | PASS | 281 | 64,742,400 | 3.861 | FAIL | FAIL | FAIL |
| 24x72 | 24 | 72 | 888 | PASS | 242 | 55,756,800 | 4.483 | FAIL | FAIL | FAIL |
| 48x144 | 48 | 144 | 3504 | FAIL | 63 | 14,515,200 | 17.223 | PASS | FAIL | FAIL |

解释：

- 900-DSP 门限内的 `24x64` 和 `24x72` 均远低于 x2 720p20。
- `48x144` 已经超过 900-DSP 门限，且 250MHz 下仍只有 17.223fps。
- 因此 x2 720p20 不能由当前完整 W8A12/F48 packed 2-D 规划闭合，需要更小模型、更高资源/频率，或进一步架构优化。

## 15/20/30fps 结论

| 目标 | 当前结论 |
| --- | --- |
| 15fps x4 720p | scheduler-level PASS，需继续实现 packed 2-D engine + memory banking + line-buffer/halo reuse |
| 20fps x4 720p | 当前完整 W8A12/F48 在 900-DSP 门限内无可行 candidate |
| 30fps x4 720p | 当前完整 W8A12/F48 在 900-DSP 门限内无可行 candidate |
| 20fps x2 720p | scheduler-level FAIL，当前完整 W8A12/F48 在 900-DSP 门限内无可行 candidate |

## Tile/halo 约束

朴素 tile+halo 每块重算会严重损失 FPS，并显著增加 BRAM：

| 输出 tile | compute tile | halo overhead | FPS @250MHz | BRAM36 估算 |
| --- | --- | ---: | ---: | ---: |
| 32x32 | 74x74 | 5.35x | 2.64 | 599 |
| 64x64 | 106x106 | 2.74x | 5.15 | 1229 |
| 96x96 | 138x138 | 2.07x | 5.70 | 2083 |

因此 720p15 的后续 RTL 不能走朴素 halo 重算，必须走 line-buffer/strip/halo reuse。

## 当前验收口径

1. 可以声明：A4 3-lane scheduler bit-exact xsim PASS，A5 32x32 在 measured-compatible FPS 模型下满足 15fps。
2. 可以声明：packed 2-D performance scheduler xsim 在 `24x64` 和 `24x72` 两个 candidate 下满足 720p x4 15fps。
3. 可以声明：x2 720p20 packed 2-D scheduler/performance-model xsim 已补充，结论为 900-DSP 门限下不达标。
4. 不能声明：当前 3-lane RTL 已满足 720p x4 15fps。
5. 不能声明：x4 20/30fps 或 x2 20fps 已满足。
6. 后续必须实现 packed 2-D engine、memory banking 和 halo reuse 后，重新跑 RTL correctness、OOC/PPA 和板端 FPS。
