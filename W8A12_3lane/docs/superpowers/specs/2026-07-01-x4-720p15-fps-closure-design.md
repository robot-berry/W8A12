# X4 720p15 FPS Closure Design

## Goal

本轮只闭合 `x4 720p >= 15fps` 的性能证据链：输入为 `320x180 LR`，输出为 `1280x720 SR`，模型保持 REDS SPAN x4/F48/W8A12。闭合口径限定为 scheduler/performance-model 级别，不声称完整像素计算 RTL、板端实测 FPS 或 x2 720p20 已达成。

## Current Context

现有 `w8a12_packed2d_perf_scheduler.v` 已能在 xsim 中给出两个 x4 720p candidate：

| Candidate | DSP | Cycles/LR pixel | Frame cycles | FPS @250MHz |
| --- | ---: | ---: | ---: | ---: |
| 24x64 | 792 | 288 | 16,588,800 | 15.070 |
| 24x72 | 888 | 248 | 14,284,800 | 17.501 |

二者都对应 `320x180 LR -> 1280x720 SR`。其中 `24x64` 是最低资源 15fps candidate，但 15fps 余量很小；`24x72` 接近 900-DSP 门限，但有更合理的控制/访存/调度余量。

## Options

### Option A: 24x64 minimum-resource closure

优点是 DSP 只有 792，PPA 表述更保守；缺点是 15fps 余量只有约 `0.47%`，任何调度、line-buffer、控制或访存开销都会让它跌破 15fps。因此它适合作为“最低资源数学闭合点”，不适合作为最终推荐实现点。

### Option B: 24x72 recommended closure

优点是 FPS 为 `17.501`，相对 15fps 有约 `16.67%` frame-cycle 余量，仍在 900-DSP 规划门限内；缺点是 DSP 达到 888，接近门限，对后续额外控制逻辑和综合策略要求更严格。它是本轮推荐提交口径。

### Option C: Continue chasing x4 20/30fps or x2 720p20

现有 sizing table 显示完整 W8A12/F48 在 900-DSP 门限内无法闭合这些目标。继续追会变成模型压缩或全新架构问题，不适合作为当前交付闭合主线。

## Selected Design

采用 Option B 为主、Option A 为辅：

1. `24x72` 标记为 `recommended_closure_candidate`，作为 x4 720p15 FPS 闭合点。
2. `24x64` 保留为 `minimum_resource_candidate`，作为面积更小但余量不足的边界点。
3. 新增 `x4_720p15_fps_closure` 证据目录，明确写出输出分辨率、FPS、DSP、余量、资源门限和 scope boundary。
4. 新增检查脚本，读取 packed scheduler 的 `summary.json`，验证 candidate、FPS、DSP、frame size、输出分辨率和报告口径。
5. 更新报告和索引，只声明 x4 720p15 scheduler-level closure；继续保留完整 RTL/board FPS 未闭合的说明。

## Acceptance Criteria

本轮完成后，以下条件必须同时满足：

| Gate | Required Result |
| --- | --- |
| Vivado xsim | `packed2d_perf_scheduler` fresh run PASS |
| Minimum resource candidate | `24x64` FPS >= 15，DSP <= 900，输出 1280x720 |
| Recommended candidate | `24x72` FPS >= 15，DSP <= 900，输出 1280x720 |
| Recommended margin | `24x72` frame-cycle slack >= 10% relative to 15fps budget |
| x2 separation | 报告不得声明 x2 720p20 达成 |
| Scope boundary | 报告必须标注 scheduler-level，不声明板端实测 FPS |

## Files

Create:

- `W8A12_3lane/evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.md`
- `W8A12_3lane/evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.json`
- `W8A12_3lane/tools/check_x4_720p15_fps_closure.py`

Modify:

- `W8A12_3lane/docs/contest_submission_report.md`
- `W8A12_3lane/docs/contest_submission_readme.md`
- `W8A12_3lane/DELIVERY_INDEX.md`
- `W8A12_3lane/tools/collect_delivery_manifest.py`
- `W8A12_3lane/tools/collect_submission_package.py`

No full engine or board RTL path is changed in this design. That keeps the work scoped to FPS evidence closure and avoids disturbing the mismatch debug branch.

## Self Review

- No unresolved TBD/TODO remains.
- The design does not claim full 720p pixel RTL or board FPS.
- The selected target matches the user's approved direction: both candidates output 720p, with 24x72 used as the recommended closure.
- x2 720p20 remains explicitly out of scope for this closure.
