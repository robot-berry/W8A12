# Missing Evidence Plan Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:generate_missing_evidence_plan` | PASS | `W8A12_3lane/tools/generate_missing_evidence_plan.py` |
| `self_bootstrap_audit` | PASS | `can compute audit items without existing audit JSON` |
| `skips_self_missing_plan` | PASS | `does not require its own output before creation` |
| `accel_cmd_fallbacks` | PASS | `accel top cmd fallbacks` |
| `a4_cmd_fallbacks` | PASS | `A4 cmd fallbacks` |
| `board_resource_args` | PASS | `board report resource used arguments` |
| `vivado_probe_gate_mapped` | PASS | `Vivado JTAG probe pre-board gate` |
| `board_psnr_targets` | PASS | `x4/x2 PSNR placeholders` |
| `x2_export_is_separate` | PASS | `x2 export commands` |
| `x2_reference_validation_is_separate` | PASS | `x2 validation command` |
| `quality_baseline_commands` | PASS | `traditional interpolation baseline commands` |
| `board_tags_mapped` | PASS | `board tags` |
| `manifest_commands_mapped` | PASS | `manifest commands` |
