# Contest Scope Package

Status: PASS_WITH_SCOPE

Scope: Contest report / RTL simulation / bitstream-PPA evidence; physical board validation is tracked as a non-blocking engineering follow-up for this package.

| Field | Value |
| --- | --- |
| archive | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\contest_scope_package\archive\W8A12_3lane_contest_scope_submission.zip` |
| bytes | `3844331` |
| sha256 | `7de857347d29e639962f4b9b68a6652100e9fa8b3a909949dd7b948f2b899eb2` |
| archived file count | `407` |
| source submission manifest status | `INCOMPLETE` |
| contest readiness status | `PASS_WITH_SCOPE` |
| source submission manifest sha256 | `613d7576c6c86a625fad34a9b9f500eb3e92c1215688bc2242d9a033281a145f` |
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
