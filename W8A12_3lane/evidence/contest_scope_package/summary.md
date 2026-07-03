# Contest Scope Package

Status: PASS_WITH_SCOPE

Scope: Contest report / RTL simulation / bitstream-PPA evidence; physical board validation is tracked as a non-blocking engineering follow-up for this package.

| Field | Value |
| --- | --- |
| archive | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\contest_scope_package\archive\W8A12_3lane_contest_scope_submission.zip` |
| bytes | `4187362` |
| sha256 | `88eb3e04f4e841f44b525d22b1c4c43d1789f02a8d314890f357a1ae7f7cef45` |
| archived file count | `411` |
| source submission manifest status | `INCOMPLETE` |
| contest readiness status | `PASS_WITH_SCOPE` |
| source submission manifest sha256 | `4dbe961e518bbaf605a593172ebe736c3c146877505faa712c359daef9e771f2` |
| contest readiness sha256 | `ebd61247eadd1fb6eebb69229789aed90b2236d76a86436baf669970f462aefb` |

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
