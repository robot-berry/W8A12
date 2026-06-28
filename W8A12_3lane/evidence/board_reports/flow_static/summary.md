# Board Report Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:create` | PASS | `W8A12_3lane/tools/create_board_report.py` |
| `file:update` | PASS | `W8A12_3lane/tools/update_board_report.py` |
| `file:finalize` | PASS | `W8A12_3lane/tools/finalize_board_report_from_outputs.py` |
| `file:validate` | PASS | `W8A12_3lane/tools/validate_board_report.py` |
| `file:doc` | PASS | `W8A12_3lane/docs/board_report_flow.md` |
| `file:audit` | PASS | `W8A12_3lane/tools/audit_contest_delivery.py` |
| `file:missing_plan` | PASS | `W8A12_3lane/tools/generate_missing_evidence_plan.py` |
| `create_defaults_pending` | PASS | `skeleton cannot pass by default` |
| `create_uses_board_part` | PASS | `actual board part` |
| `create_uses_xc7z045_limits` | PASS | `ZC706/XC7Z045 equivalent limits` |
| `create_records_output_pixels` | PASS | `output size` |
| `create_records_tile_pipeline` | PASS | `SD/downsample/tile+halo metadata` |
| `create_records_perf_quality` | PASS | `perf/quality fields` |
| `update_accepts_resource_used` | PASS | `resource used CLI` |
| `update_accepts_timing_perf_quality` | PASS | `timing/perf/quality CLI` |
| `update_accepts_required_files` | PASS | `evidence file CLI` |
| `finalize_computes_mismatch_from_files` | PASS | `computed board/reference compare` |
| `finalize_computes_psnr` | PASS | `computed PSNR` |
| `finalize_requires_real_metrics` | PASS | `required resource/timing/perf metrics` |
| `finalize_runs_validator` | PASS | `final validation emission` |
| `validate_rejects_nonpass` | PASS | `status PASS` |
| `validate_requires_frame_done` | PASS | `frame done/error` |
| `validate_requires_bit_exact` | PASS | `bit exact` |
| `validate_requires_resource_limits` | PASS | `resource values within limits` |
| `validate_requires_timing` | PASS | `timing slack` |
| `validate_requires_perf_power` | PASS | `perf/power` |
| `validate_requires_psnr_targets` | PASS | `x2/x4 PSNR targets` |
| `validate_requires_files` | PASS | `required evidence files` |
| `doc_lists_four_required_reports` | PASS | `required board report tags` |
| `doc_states_x4_x2_targets` | PASS | `quality targets` |
| `doc_requires_board_summary` | PASS | `report and validation outputs` |
| `doc_lists_finalize_tool` | PASS | `auto finalize flow` |
| `doc_requires_resource_perf_quality` | PASS | `reporting cadence` |
| `doc_separates_fps_and_psnr` | PASS | `FPS and PSNR separated` |
| `audit_requires_board_validations` | PASS | `audit board gates` |
| `missing_plan_maps_board_commands` | PASS | `missing plan commands` |
