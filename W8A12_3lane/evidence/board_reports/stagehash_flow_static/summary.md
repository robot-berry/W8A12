# Board Stage-Hash Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:delivery_wrapper` | PASS | `W8A12_3lane/scripts/run_w8a12_stagehash_true2x2_acceptance.ps1` |
| `file:delivery_preflight` | PASS | `W8A12_3lane/scripts/run_w8a12_board_recovery_preflight.ps1` |
| `file:root_wrapper` | PASS | `scripts/run_w8a12_stagehash_true2x2_acceptance.ps1` |
| `file:root_preflight` | PASS | `scripts/run_w8a12_board_recovery_preflight.ps1` |
| `file:jtag_precondition_tool` | PASS | `W8A12_3lane/tools/summarize_jtag_precondition.py` |
| `file:jtag_recovery_tool` | PASS | `W8A12_3lane/tools/generate_jtag_recovery_checklist.py` |
| `file:jtag_recovery_doc` | PASS | `W8A12_3lane/docs/jtag_recovery_checklist.md` |
| `file:jtag_precondition_current` | PASS | `W8A12_3lane/evidence/board_probe/jtag_precondition_current/summary.md` |
| `file:recovery_preflight_current` | PASS | `W8A12_3lane/evidence/board_probe/recovery_preflight_current/board_recovery_preflight_summary.md` |
| `file:jtag_recovery_checklist` | PASS | `W8A12_3lane/evidence/board_probe/jtag_recovery_checklist/summary.md` |
| `file:scripts/run_w8a12_board_recovery_preflight.ps1` | PASS | `scripts/run_w8a12_board_recovery_preflight.ps1` |
| `file:scripts/run_w8a12_stagehash_true2x2_acceptance.ps1` | PASS | `scripts/run_w8a12_stagehash_true2x2_acceptance.ps1` |
| `file:scripts/probe_vivado_hw_targets.ps1` | PASS | `scripts/probe_vivado_hw_targets.ps1` |
| `file:scripts/probe_vivado_hw_targets.tcl` | PASS | `scripts/probe_vivado_hw_targets.tcl` |
| `file:scripts/check_usb_jtag_devices.ps1` | PASS | `scripts/check_usb_jtag_devices.ps1` |
| `file:scripts/cleanup_vivado_processes.ps1` | PASS | `scripts/cleanup_vivado_processes.ps1` |
| `file:scripts/run_xsct_psu_init_only.ps1` | PASS | `scripts/run_xsct_psu_init_only.ps1` |
| `file:scripts/run_xsct_psu_init_only.tcl` | PASS | `scripts/run_xsct_psu_init_only.tcl` |
| `file:scripts/run_jtag_w8a12_tile_writer_smoke.ps1` | PASS | `scripts/run_jtag_w8a12_tile_writer_smoke.ps1` |
| `file:scripts/jtag_rgb_transfer.tcl` | PASS | `scripts/jtag_rgb_transfer.tcl` |
| `file:scripts/compare_jtag_w8a12_span_output.ps1` | PASS | `scripts/compare_jtag_w8a12_span_output.ps1` |
| `file:scripts/run_read_jtag_w8a12_tile_writer_regs.ps1` | PASS | `scripts/run_read_jtag_w8a12_tile_writer_regs.ps1` |
| `file:scripts/read_jtag_w8a12_tile_writer_regs.tcl` | PASS | `scripts/read_jtag_w8a12_tile_writer_regs.tcl` |
| `file:scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.ps1` | PASS | `scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.ps1` |
| `file:scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.tcl` | PASS | `scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.tcl` |
| `file:scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl` | PASS | `scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl` |
| `delivery_wrapper_delegates_to_root` | PASS | `W8A12_3lane wrapper delegates from repo root` |
| `delivery_preflight_delegates_to_root` | PASS | `W8A12_3lane preflight delegates from repo root` |
| `root_preflight_runs_usb_precondition_and_optional_acceptance` | PASS | `board recovery preflight step chain` |
| `root_wrapper_runs_probe_psu_smoke_regread` | PASS | `root wrapper step chain` |
| `root_wrapper_records_expected_hashes` | PASS | `stage-hash expected values` |
| `report_records_bitstream_and_target0` | PASS | `stage-hash report has build and target-fail evidence` |
| `docs_list_board_root_dependencies` | PASS | `submission scope lists board root scripts` |
| `upload_plan_mentions_board_root_dependencies` | PASS | `upload plan board script scope` |
| `index_mentions_stagehash_wrapper` | PASS | `delivery index wrapper row` |
| `index_mentions_recovery_preflight` | PASS | `delivery index recovery preflight row` |
| `workflow_mentions_stagehash_wrapper` | PASS | `workflow current stage-hash wrapper state` |
| `jtag_precondition_has_current_counts` | PASS | `current board/JTAG precondition evidence` |
| `recovery_preflight_has_current_blocked_evidence` | PASS | `current board recovery preflight evidence` |
| `jtag_recovery_doc_has_physical_steps` | PASS | `physical JTAG recovery runbook` |
| `jtag_recovery_evidence_has_current_blocked_state` | PASS | `current physical/JTAG recovery evidence` |
