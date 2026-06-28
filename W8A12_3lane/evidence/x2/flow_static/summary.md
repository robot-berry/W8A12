# x2 W8A12 Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:export_ps1` | PASS | `W8A12_3lane/scripts/export_x2_w8a12_to_rtl.ps1` |
| `file:export_cmd` | PASS | `W8A12_3lane/scripts/export_x2_w8a12_to_rtl.cmd` |
| `file:export_check` | PASS | `W8A12_3lane/tools/check_x2_w8a12_export.py` |
| `file:fixed_check` | PASS | `W8A12_3lane/tools/check_x2_fixed_reference.py` |
| `file:readiness_check` | PASS | `W8A12_3lane/tools/check_x2_reference_readiness.py` |
| `file:asset_search` | PASS | `W8A12_3lane/tools/find_x2_assets.py` |
| `file:reference` | PASS | `W8A12_3lane/tools/w8a12_3lane_reference.py` |
| `file:export_doc` | PASS | `W8A12_3lane/docs/x2_w8a12_export_plan.md` |
| `file:fixed_doc` | PASS | `W8A12_3lane/docs/x2_fixed_reference_contract.md` |
| `file:root_calibrate_tool` | PASS | `tools/calibrate_span_activation_scales.py` |
| `file:root_quant_tool` | PASS | `tools/export_span_w8a12_quant_plan.py` |
| `file:root_rtl_export_tool` | PASS | `tools/export_span_quant_plan_to_rtl.py` |
| `file:root_postprocess_export_tool` | PASS | `tools/export_span_w8a12_postprocess_to_rtl.py` |
| `file:root_rtl_check_tool` | PASS | `tools/check_span_w8a12_rtl_export.py` |
| `file:checkpoint` | PASS | `runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth` |
| `file:official_manifest` | PASS | `rtl/generated/official_span_x2/official_span_manifest.json` |
| `export_ps1_calibrates_a12` | PASS | `activation calibration` |
| `export_ps1_exports_quant_w8a12` | PASS | `W8A12 quant plan` |
| `export_ps1_exports_rtl` | PASS | `RTL manifest` |
| `export_ps1_exports_postprocess` | PASS | `postprocess manifest` |
| `export_ps1_runs_root_check` | PASS | `root RTL export check` |
| `export_ps1_runs_x2_check` | PASS | `x2 export evidence check` |
| `export_ps1_uses_x2_assets` | PASS | `x2 checkpoint/manifest` |
| `root_export_tools_present` | PASS | `root-level export/check tools` |
| `export_cmd_redirects_stdout` | PASS | `stdout evidence` |
| `export_cmd_runs_ps1` | PASS | `ps1 fallback` |
| `export_cmd_runs_check` | PASS | `post-export check` |
| `export_check_requires_scale2` | PASS | `scale x2` |
| `export_check_requires_f48` | PASS | `48 channels` |
| `export_check_requires_w8a12` | PASS | `W8A12` |
| `export_check_requires_postprocess` | PASS | `postprocess` |
| `fixed_check_requires_a3` | PASS | `A3 tail RGB` |
| `fixed_check_requires_x2_dims` | PASS | `x2 output size` |
| `fixed_check_requires_rgb_hash` | PASS | `RGB hash` |
| `reference_supports_a3_tail_rgb` | PASS | `fixed reference subcommand` |
| `doc_mentions_28_30_targets` | PASS | `quality targets documented` |
| `doc_mentions_export_cmd` | PASS | `export command documented` |
