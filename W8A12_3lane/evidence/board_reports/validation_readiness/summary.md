# Board Validation Readiness

Status: PASS

This readiness check prepares the four remaining real-board validation reports. It is not a substitute for `validation.md Status: PASS`.

| Tag | Audit Gate | Report | Validation | LR | HR | Tiles | PSNR Target | FPS Target |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: |
| `a5_32x32` | `a5.board_32x32` | `PENDING` | `PENDING_NO_VALIDATION` | 32x32 | 128x128 | 1x1 | 28.0 | 15.0 |
| `a6_64x64` | `a6.board_64x64` | `PENDING` | `PENDING_NO_VALIDATION` | 64x64 | 256x256 | 2x2 | 28.0 | 15.0 |
| `a7_720p_x4` | `a7.board_720p_x4` | `PENDING` | `PENDING_NO_VALIDATION` | 320x180 | 1280x720 | 10x6 | 28.0 | 15.0 |
| `x2_720p` | `x2.board` | `PENDING` | `PENDING_NO_VALIDATION` | 640x360 | 1280x720 | 20x12 | 30.0 | 15.0 |

## Checks

| Check | Result | Detail |
| --- | --- | --- |
| `tool:tools/create_board_report.py` | PASS | `tools/create_board_report.py` |
| `tool:tools/update_board_report.py` | PASS | `tools/update_board_report.py` |
| `tool:tools/validate_board_report.py` | PASS | `tools/validate_board_report.py` |
| `tool:tools/summarize_jtag_precondition.py` | PASS | `tools/summarize_jtag_precondition.py` |
| `file:missing_evidence_plan` | PASS | `W8A12_3lane/evidence/delivery_audit/missing_evidence_plan.md` |
| `file:jtag_precondition_current` | PASS | `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md` |
| `precondition_declares_status` | PASS | `current board/JTAG precondition is explicit` |
| `a5_32x32:summary_json` | PASS | `W8A12_3lane/evidence/board_reports/a5_32x32/summary.json` |
| `a5_32x32:summary_md` | PASS | `W8A12_3lane/evidence/board_reports/a5_32x32/summary.md` |
| `a5_32x32:status_not_final_without_validation` | PASS | `PENDING` |
| `a5_32x32:scale` | PASS | `4` |
| `a5_32x32:lr_size` | PASS | `[32, 32]` |
| `a5_32x32:hr_size` | PASS | `[128, 128]` |
| `a5_32x32:tile_count` | PASS | `[1, 1]` |
| `a5_32x32:tile_size_32` | PASS | `[32, 32]` |
| `a5_32x32:halo_21` | PASS | `21` |
| `a5_32x32:target_fps` | PASS | `15.0` |
| `a5_32x32:target_psnr_command` | PASS | `28.0` |
| `a5_32x32:command_chain` | PASS | `a5.board_32x32` |
| `a6_64x64:summary_json` | PASS | `W8A12_3lane/evidence/board_reports/a6_64x64/summary.json` |
| `a6_64x64:summary_md` | PASS | `W8A12_3lane/evidence/board_reports/a6_64x64/summary.md` |
| `a6_64x64:status_not_final_without_validation` | PASS | `PENDING` |
| `a6_64x64:scale` | PASS | `4` |
| `a6_64x64:lr_size` | PASS | `[64, 64]` |
| `a6_64x64:hr_size` | PASS | `[256, 256]` |
| `a6_64x64:tile_count` | PASS | `[2, 2]` |
| `a6_64x64:tile_size_32` | PASS | `[32, 32]` |
| `a6_64x64:halo_21` | PASS | `21` |
| `a6_64x64:target_fps` | PASS | `15.0` |
| `a6_64x64:target_psnr_command` | PASS | `28.0` |
| `a6_64x64:command_chain` | PASS | `a6.board_64x64` |
| `a7_720p_x4:summary_json` | PASS | `W8A12_3lane/evidence/board_reports/a7_720p_x4/summary.json` |
| `a7_720p_x4:summary_md` | PASS | `W8A12_3lane/evidence/board_reports/a7_720p_x4/summary.md` |
| `a7_720p_x4:status_not_final_without_validation` | PASS | `PENDING` |
| `a7_720p_x4:scale` | PASS | `4` |
| `a7_720p_x4:lr_size` | PASS | `[320, 180]` |
| `a7_720p_x4:hr_size` | PASS | `[1280, 720]` |
| `a7_720p_x4:tile_count` | PASS | `[10, 6]` |
| `a7_720p_x4:tile_size_32` | PASS | `[32, 32]` |
| `a7_720p_x4:halo_21` | PASS | `21` |
| `a7_720p_x4:target_fps` | PASS | `15.0` |
| `a7_720p_x4:target_psnr_command` | PASS | `28.0` |
| `a7_720p_x4:command_chain` | PASS | `a7.board_720p_x4` |
| `x2_720p:summary_json` | PASS | `W8A12_3lane/evidence/board_reports/x2_720p/summary.json` |
| `x2_720p:summary_md` | PASS | `W8A12_3lane/evidence/board_reports/x2_720p/summary.md` |
| `x2_720p:status_not_final_without_validation` | PASS | `PENDING` |
| `x2_720p:scale` | PASS | `2` |
| `x2_720p:lr_size` | PASS | `[640, 360]` |
| `x2_720p:hr_size` | PASS | `[1280, 720]` |
| `x2_720p:tile_count` | PASS | `[20, 12]` |
| `x2_720p:tile_size_32` | PASS | `[32, 32]` |
| `x2_720p:halo_21` | PASS | `21` |
| `x2_720p:target_fps` | PASS | `15.0` |
| `x2_720p:target_psnr_command` | PASS | `30.0` |
| `x2_720p:command_chain` | PASS | `x2.board` |
