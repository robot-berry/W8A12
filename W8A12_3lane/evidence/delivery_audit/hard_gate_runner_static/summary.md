# Hard Gate Runner Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:runner` | PASS | `W8A12_3lane/scripts/run_hard_gate_queue.ps1` |
| `file:delivery_runner` | PASS | `W8A12_3lane/scripts/run_delivery_gates.ps1` |
| `file:queue_tool` | PASS | `W8A12_3lane/tools/generate_hard_gate_execution_queue.py` |
| `file:doc` | PASS | `W8A12_3lane/docs/delivery_gate_runner.md` |
| `delivery_runner_powershell_parse` | PASS | `parse ok` |
| `delivery_runner_param_first` | PASS | `param block is first statement` |
| `delivery_runner_skip_flags` | PASS | `SkipVivado/SkipX2/ContinueOnError` |
| `delivery_runner_allowed_exit_codes` | PASS | `missing evidence plan can be incomplete` |
| `delivery_runner_safe_file_interpolation` | PASS | `no invalid $File: interpolation` |
| `delivery_runner_summary_interpolation` | PASS | `summary rows expand step names` |
| `delivery_runner_stagehash_static` | PASS | `stage-hash static gate` |
| `delivery_runner_jtag_recovery_checklist` | PASS | `JTAG recovery checklist gate` |
| `delivery_runner_contest_report_pdf` | PASS | `contest report PDF gate` |
| `delivery_runner_contest_report_docx` | PASS | `contest report DOCX gate` |
| `delivery_runner_evidence_matrix` | PASS | `delivery evidence matrix gate` |
| `delivery_runner_final_gates` | PASS | `final manifest/audit gates` |
| `delivery_runner_jtag_recovery_before_stagehash_static` | PASS | `recovery evidence generated before stage-hash static check` |
| `delivery_runner_matrix_before_final_archive` | PASS | `evidence matrix is generated after audit and before final archive` |
| `supports_start_at` | PASS | `resume from step` |
| `supports_only_category` | PASS | `category filter` |
| `supports_continue_on_error` | PASS | `continue on error` |
| `supports_dry_run` | PASS | `dry-run mode` |
| `writes_hard_gate_runs` | PASS | `run output directory` |
| `captures_stdout_stderr` | PASS | `stdout/stderr logs` |
| `records_commands` | PASS | `per-step commands` |
| `checks_required_evidence` | PASS | `evidence validation` |
| `queue_marks_external_process` | PASS | `hard gates flagged external` |
| `queue_has_all_hard_names` | PASS | `representative hard gates` |
| `queue_orders_probe_before_board` | PASS | `probe before A5` |
| `doc_lists_hard_queue_runner` | PASS | `hard queue runner documented` |
| `doc_lists_categories` | PASS | `category examples documented` |
