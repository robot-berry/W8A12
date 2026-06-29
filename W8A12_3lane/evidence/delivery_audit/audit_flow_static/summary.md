# Delivery Audit Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:audit_tool` | PASS | `W8A12_3lane/tools/audit_contest_delivery.py` |
| `file:gate_runner` | PASS | `W8A12_3lane/scripts/run_delivery_gates.ps1` |
| `manifest_not_forced_incomplete` | PASS | `final PASS manifests remain valid` |
| `includes_all_flow_static_gates` | PASS | `flow-static audit gates` |
| `includes_core_reference_gates` | PASS | `A0-A3 gates` |
| `includes_mac_dsp_mapping_doc` | PASS | `MAC/DSP mapping policy doc gate` |
| `includes_submission_scope_doc` | PASS | `submission scope policy doc gate` |
| `includes_contest_report_gate` | PASS | `contest report doc gate` |
| `includes_report_static_gate` | PASS | `contest report static evidence gate` |
| `includes_report_pdf_gate` | PASS | `contest report PDF evidence gate` |
| `includes_report_docx_gate` | PASS | `contest report DOCX evidence gate` |
| `includes_ppa_summary_gate` | PASS | `PPA summary evidence gate` |
| `includes_sim_fps_estimate_gate` | PASS | `simulated FPS estimate evidence gate` |
| `includes_quality_metric_completion_gate` | PASS | `quality metric completion evidence gate` |
| `includes_vivado_ooc_gates` | PASS | `Vivado/xsim/OOC gates` |
| `includes_board_gates` | PASS | `board gates` |
| `includes_x2_gates` | PASS | `x2 W8A12 gates` |
| `gate_order_support_before_audit` | PASS | `support files are generated before strict audit` |
| `gate_order_final_manifests_after_audit` | PASS | `final manifests refresh after strict audit` |
| `gate_order_final_archive_after_final_submission` | PASS | `final archive is regenerated before final delivery manifest` |
