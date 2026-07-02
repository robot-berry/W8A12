# Contest Scope Package

Status: PASS_WITH_SCOPE

Scope: Contest report / RTL simulation / bitstream-PPA evidence; physical board validation is tracked as a non-blocking engineering follow-up for this package.

| Field | Value |
| --- | --- |
| archive | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\contest_scope_package\archive\W8A12_3lane_contest_scope_submission.zip` |
| bytes | `3838191` |
| sha256 | `328650efc0a303d06eb700fa1c52f35d61bbc76404ccd9c35ce5934b22e95bb9` |
| archived file count | `403` |
| source submission manifest status | `INCOMPLETE` |
| contest readiness status | `PASS_WITH_SCOPE` |
| source submission manifest sha256 | `74b8d7a66f7095ed14e22af0d9fb85be6dae7c82a224e5635af063eed9f79236` |
| contest readiness sha256 | `d3662043b4f4d6c63ff58a6c6d47662754652e5048263986509bbffce66ca135` |

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
