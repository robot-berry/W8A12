# Contest Scope Readiness

Status: PASS_WITH_SCOPE

Scope: Contest report / RTL simulation / bitstream-PPA evidence. Physical board validation remains an engineering follow-up.

This gate is intentionally separate from the stricter board-validation audit.

## Claims

| Claim | Status |
| --- | --- |
| `x4_720p15_scheduler_fps` | `PASS_WITH_SCOPE` |
| `x2_720p4_scheduler_fps` | `PASS_WITH_SCOPE` |
| `x2_direct_xsim_replay` | `PASS_WITH_SCOPE` |
| `x2_720p20_scheduler_fps` | `NOT_CLAIMED` |
| `true2x2_bitstream_ppa` | `PASS_WITH_SCOPE` |
| `physical_board_720p_output` | `NOT_CLAIMED` |

## Non-Blocking Board Validation Gaps

- `evidence/board_reports/a5_32x32/validation.md`
- `evidence/board_reports/a6_64x64/validation.md`
- `evidence/board_reports/a7_720p_x4/validation.md`
- `evidence/board_reports/x2_720p/validation.md`

## Checks

| Check | Result | Evidence | Detail |
| --- | --- | --- | --- |
| `file:README.md` | PASS | `README.md` | `"required contest document"` |
| `file:WORKFLOW.md` | PASS | `WORKFLOW.md` | `"required contest document"` |
| `file:DELIVERY_INDEX.md` | PASS | `DELIVERY_INDEX.md` | `"required contest document"` |
| `file:docs/contest_submission_readme.md` | PASS | `docs/contest_submission_readme.md` | `"required contest document"` |
| `file:docs/contest_submission_report.md` | PASS | `docs/contest_submission_report.md` | `"required contest document"` |
| `file:docs/final_submission_guide.md` | PASS | `docs/final_submission_guide.md` | `"required contest document"` |
| `file:docs/contest_requirement_traceability.md` | PASS | `docs/contest_requirement_traceability.md` | `"required contest document"` |
| `file:docs/w8a12_3lane_architecture.md` | PASS | `docs/w8a12_3lane_architecture.md` | `"required contest document"` |
| `file:docs/bank_mapping_rules.md` | PASS | `docs/bank_mapping_rules.md` | `"required contest document"` |
| `file:docs/board_report_flow.md` | PASS | `docs/board_report_flow.md` | `"required contest document"` |
| `file:docs/failure_rollback_flow.md` | PASS | `docs/failure_rollback_flow.md` | `"required contest document"` |
| `model.full_reds_train_val_scope` | PASS | `docs/contest_submission_report.md` | `"full train/val scope stated"` |
| `doc.final_submission_guide_scope_boundary` | PASS | `docs/final_submission_guide.md` | `"submission boundary stated"` |
| `doc.contest_requirement_traceability` | PASS | `docs/contest_requirement_traceability.md` | `"contest requirements traced"` |
| `quality.fp32_targets` | PASS | `evidence/quality_comparison/summary.json` | `{"x2_span_fp32_psnr_rgb_db": 34.4297, "x4_span_fp32_psnr_rgb_db": 28.3118}` |
| `quality.file:evidence/quality_baseline/x4_interpolation/summary.md` | PASS | `evidence/quality_baseline/x4_interpolation/summary.md` | `"quality/baseline evidence"` |
| `quality.file:evidence/quality_baseline/x2_interpolation/summary.md` | PASS | `evidence/quality_baseline/x2_interpolation/summary.md` | `"quality/baseline evidence"` |
| `quality.file:evidence/quality_comparison/summary.md` | PASS | `evidence/quality_comparison/summary.md` | `"quality/baseline evidence"` |
| `quality.file:evidence/quality_metric_completion/summary.md` | PASS | `evidence/quality_metric_completion/summary.md` | `"quality/baseline evidence"` |
| `x2.status:evidence/x2/w8a12_export/summary.json` | PASS | `evidence/x2/w8a12_export/summary.json` | `"PASS"` |
| `x2.status:evidence/x2/reference/summary.json` | PASS | `evidence/x2/reference/summary.json` | `"PASS"` |
| `x2.status:evidence/x2/reference_validation/validation.json` | PASS | `evidence/x2/reference_validation/validation.json` | `"PASS"` |
| `x2.status:evidence/x2/flow_static/summary.json` | PASS | `evidence/x2/flow_static/summary.json` | `"PASS"` |
| `rtl.layered_sim_and_ooc_evidence` | PASS | `evidence/reference + evidence/resource + evidence/top` | `"all present"` |
| `gate.status:evidence/ppa_summary/summary.json` | PASS | `evidence/ppa_summary/summary.json` | `"PASS"` |
| `gate.status:evidence/bitstream_ppa_gate/summary.json` | PASS | `evidence/bitstream_ppa_gate/summary.json` | `"PASS_WITH_SCOPE"` |
| `gate.status:evidence/report_static/summary.json` | PASS | `evidence/report_static/summary.json` | `"PASS"` |
| `gate.status:evidence/report_pdf/summary.json` | PASS | `evidence/report_pdf/summary.json` | `"PASS"` |
| `gate.status:evidence/report_docx_complete_20260701/summary.json` | PASS | `evidence/report_docx_complete_20260701/summary.json` | `"PASS"` |
| `gate.status:evidence/delivery_matrix/summary.json` | PASS | `evidence/delivery_matrix/summary.json` | `"PASS"` |
| `gate.status:evidence/github_upload_preflight/summary.json` | PASS | `evidence/github_upload_preflight/summary.json` | `"PASS"` |
| `report.docx_black_font_audit` | PASS | `evidence/report_docx_complete_20260701/summary.json` | `{"non_black_text_color_count": 0, "non_black_text_colors": [], "status": "PASS", "text_color_count": 773}` |
| `fps.x4_720p15_scheduler_closure` | PASS | `evidence/sim_fps_design_space/x4_720p15_fps_closure/summary.json` | `{"closure_level": "scheduler/performance-model", "minimum_resource": {"candidate": "24x64", "cycles_per_lr_pixel": 288, "estimated_dsp": 792, "fps": 15.07, "fps_x1000": 15070, "frame_cycle_slack_pct_of_15fps_budget": 0.467, "frame_cycles": 16588800, "output_lanes": 24, "passes_15fps": true, "passes_20fps": false, "passes_30fps": false, "tap_lanes": 64}, "recommended": {"candidate": "24x72", "cycles_per_lr_pixel": 248, "estimated_dsp": 888, "fps": 17.501, "fps_x1000": 17501, "frame_cycle_slack_pct_of_15fps_budget": 14.291, "frame_cycles": 14284800, "output_lanes": 24, "passes_15fps": true, "passes_20fps": false, "passes_30fps": false, "tap_lanes": 72}, "status": "PASS"}` |
| `fps.x2_720p4_scheduler_closure` | PASS | `evidence/sim_fps_design_space/x2_720p4_fps_closure/summary.json` | `{"closure_level": "scheduler/performance-model", "recommended": {"candidate": "24x72", "cycles_per_lr_pixel": 242, "estimated_dsp": 888, "fps": 4.483, "fps_x1000": 4483, "frame_cycle_slack_pct_of_4fps_budget": 10.789, "frame_cycles": 55756800, "output_lanes": 24, "passes_15fps": false, "passes_20fps": false, "passes_30fps": false, "passes_4fps": true, "resource_gate": true, "tap_lanes": 72}, "resource_boundary": {"candidate": "24x64", "cycles_per_lr_pixel": 281, "estimated_dsp": 792, "fps": 3.861, "fps_x1000": 3861, "frame_cycle_slack_pct_of_4fps_budget": -3.588, "frame_cycles": 64742400, "output_lanes": 24, "passes_15fps": false, "passes_20fps": false, "passes_30fps": false, "passes_4fps": false, "resource_gate": true, "tap_lanes": 64}, "scope_boundary": "Not board-measured FPS and not full packed 2-D pixel RTL bit-exact closure. x2 720p20 remains FAIL under the 900-DSP gate.", "status": "PASS"}` |
| `fps.x2_direct_xsim_replay` | PASS | `evidence/sim_fps_design_space/packed2d_x2_direct_xsim_replay/summary.json` | `{"boundary_24x64": {"candidate": "24x64", "cycles_per_lr_pixel": 281, "estimated_dsp": 792, "fps": 3.861, "fps_x1000": 3861, "frame_cycles": 64742400, "frame_pixels": 230400, "output_lanes": 24, "pass15": false, "pass20": false, "pass30": false, "resource_gate": true, "tap_lanes": 64}, "matches_vivado_batch_summary": true, "recommended_24x72": {"candidate": "24x72", "cycles_per_lr_pixel": 242, "estimated_dsp": 888, "fps": 4.483, "fps_x1000": 4483, "frame_cycles": 55756800, "frame_pixels": 230400, "output_lanes": 24, "pass15": false, "pass20": false, "pass30": false, "resource_gate": true, "tap_lanes": 72}, "runner": "direct_xvlog_xelab_xsim", "status": "PASS", "target_status": "FAIL"}` |
| `scope.strict_audit_gaps_are_board_only` | PASS | `evidence/delivery_audit/contest_delivery_audit.json` | `{"non_blocking_for_contest_scope": ["evidence/board_reports/a5_32x32/validation.md", "evidence/board_reports/a6_64x64/validation.md", "evidence/board_reports/a7_720p_x4/validation.md", "evidence/board_reports/x2_720p/validation.md"], "strict_audit_status": "INCOMPLETE", "strict_failed_paths": ["evidence/board_reports/a5_32x32/validation.md", "evidence/board_reports/a6_64x64/validation.md", "evidence/board_reports/a7_720p_x4/validation.md", "evidence/board_reports/x2_720p/validation.md"]}` |
| `scope.submission_missing_is_board_only` | PASS | `evidence/submission_package/submission_manifest.json` | `{"missing_final_evidence": ["evidence/board_reports/a5_32x32/validation.md", "evidence/board_reports/a6_64x64/validation.md", "evidence/board_reports/a7_720p_x4/validation.md", "evidence/board_reports/x2_720p/validation.md"], "submission_manifest_status": "INCOMPLETE"}` |
