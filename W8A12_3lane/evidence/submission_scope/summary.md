# Submission Scope Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `root_tool:tools/calibrate_span_activation_scales.py` | PASS | `tools/calibrate_span_activation_scales.py` |
| `root_tool:tools/export_span_w8a12_quant_plan.py` | PASS | `tools/export_span_w8a12_quant_plan.py` |
| `root_tool:tools/export_span_quant_plan_to_rtl.py` | PASS | `tools/export_span_quant_plan_to_rtl.py` |
| `root_tool:tools/export_span_w8a12_postprocess_to_rtl.py` | PASS | `tools/export_span_w8a12_postprocess_to_rtl.py` |
| `root_tool:tools/check_span_w8a12_rtl_export.py` | PASS | `tools/check_span_w8a12_rtl_export.py` |
| `root_tool:tools/run_span_ptq_reference.py` | PASS | `tools/run_span_ptq_reference.py` |
| `model_source:external/SPAN/basicsr/archs/span_arch.py` | PASS | `external/SPAN/basicsr/archs/span_arch.py` |
| `mainline_doc:W8A12_3lane/docs/submission_scope_policy.md` | PASS | `W8A12_3lane/docs/submission_scope_policy.md` |
| `mainline_doc:W8A12_3lane/docs/github_upload_plan.md` | PASS | `W8A12_3lane/docs/github_upload_plan.md` |
| `mainline_doc:W8A12_3lane/docs/x2_w8a12_export_plan.md` | PASS | `W8A12_3lane/docs/x2_w8a12_export_plan.md` |
| `ptq_imports_span` | PASS | `run_span_ptq_reference.py imports SPAN` |
| `calibrate_uses_ptq_reference` | PASS | `calibration uses PTQ reference` |
| `quant_export_uses_ptq_reference` | PASS | `quant export uses PTQ reference` |
| `upload_plan_mentions_scope` | PASS | `GitHub upload plan points to scope policy` |
| `scope_doc_mentions_basicsr_span` | PASS | `scope doc names SPAN dependency` |
| `scope_doc_lists_root_tools` | PASS | `scope doc lists required root tools` |
