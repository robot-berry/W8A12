# Contest Scope Package

Status: PASS_WITH_SCOPE

Scope: Contest report / RTL simulation / bitstream-PPA evidence; physical board validation is tracked as a non-blocking engineering follow-up for this package.

| Field | Value |
| --- | --- |
| archive | `G:\UESTC\feitengspan1\W8A12_3lane\evidence\contest_scope_package\archive\W8A12_3lane_contest_scope_submission.zip` |
| bytes | `4699100` |
| sha256 | `192527dcab600972d56bd35c18176657f12fa658572f58ad23394e22cc7c2c58` |
| archived file count | `415` |
| source submission manifest status | `INCOMPLETE` |
| contest readiness status | `PASS_WITH_SCOPE` |
| source submission manifest sha256 | `150fe66295d2a21d4bc8ac3a3a5a6c00b5ee3cd3d44fa27a5aa9b0ab4bdbcab7` |
| contest readiness sha256 | `cea7ff8b09ae7b934262d11ffdac407ea12d203b8da00efdc787531a863a75e2` |

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
