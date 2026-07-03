# Contest Scope Package

Status: PASS_WITH_SCOPE

Scope: Contest report / RTL simulation / bitstream-PPA evidence; physical board validation is tracked as a non-blocking engineering follow-up for this package.

| Field | Value |
| --- | --- |
| archive | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\contest_scope_package\archive\W8A12_3lane_contest_scope_submission.zip` |
| bytes | `4261625` |
| sha256 | `a5b4273f3f02920ea030adfb6283ef3016a8585520a72a86a3f93e9b1df87b1f` |
| archived file count | `411` |
| source submission manifest status | `INCOMPLETE` |
| contest readiness status | `PASS_WITH_SCOPE` |
| source submission manifest sha256 | `515bb222adf95607210aeb3f85c9e6c1d30304cc14bc1183f9b011e1797c288b` |
| contest readiness sha256 | `21860699fe584f515934f1fecb0fb889a997aa499d56fb33319fdc4b9859fc7e` |

## Non-Blocking Board Validation Gaps

- `evidence/board_reports/a5_32x32/validation.md`
- `evidence/board_reports/a6_64x64/validation.md`
- `evidence/board_reports/a7_720p_x4/validation.md`
- `evidence/board_reports/x2_720p/validation.md`

## Claims

| Claim | Status |
| --- | --- |
| `x4_720p15_scheduler_fps` | `PASS_WITH_SCOPE` |
| `x2_720p4_scheduler_fps` | `PASS_WITH_SCOPE` |
| `x2_direct_xsim_replay` | `PASS_WITH_SCOPE` |
| `x2_720p20_scheduler_fps` | `NOT_CLAIMED` |
| `true2x2_bitstream_ppa` | `PASS_WITH_SCOPE` |
| `physical_board_720p_output` | `NOT_CLAIMED` |

This package is for the contest scope where physical board validation is not a hard gate. The stricter board-validation archive remains separate.
