# Submission Manifest Flow Static Check

Status: PASS

| Check | Result | Detail |
| --- | --- | --- |
| `file:submission_collector` | PASS | `W8A12_3lane/tools/collect_submission_package.py` |
| `file:delivery_collector` | PASS | `W8A12_3lane/tools/collect_delivery_manifest.py` |
| `file:submission_archive` | PASS | `W8A12_3lane/tools/create_submission_archive.py` |
| `file:delivery_matrix` | PASS | `W8A12_3lane/tools/generate_delivery_evidence_matrix.py` |
| `submission_requires_ooc_raw_reports` | PASS | `OOC raw reports in final requirement list` |
| `submission_includes_ooc_raw_globs` | PASS | `OOC raw report globs` |
| `delivery_includes_ooc_raw_globs` | PASS | `delivery raw report globs` |
| `submission_requires_quality_baseline` | PASS | `traditional interpolation baseline final evidence` |
| `manifests_include_quality_baseline_globs` | PASS | `quality baseline globs` |
| `manifests_include_quality_comparison_globs` | PASS | `quality comparison globs` |
| `manifests_include_quality_metric_completion_globs` | PASS | `quality metric completion globs` |
| `manifests_include_delivery_matrix` | PASS | `delivery evidence matrix` |
| `manifests_include_report_pdf` | PASS | `PDF report evidence and artifact globs` |
| `manifests_include_delivery_run_summaries` | PASS | `delivery gate run summaries` |
| `manifests_include_board_probe_evidence` | PASS | `board probe/precondition evidence` |
| `manifests_include_nested_board_probe_evidence` | PASS | `nested USB/preflight evidence` |
| `manifests_include_board_report_md_globs` | PASS | `board report markdown globs` |
| `manifests_include_board_report_summaries` | PASS | `board report summary globs` |
| `manifests_include_board_validation_closure` | PASS | `board validation closure manifest/template` |
| `submission_keeps_core_final_evidence` | PASS | `core final evidence` |
| `submission_excludes_large_binaries` | PASS | `large binary exclusions` |
| `manifests_exclude_zip_archive` | PASS | `zip archive is not part of recursive manifests` |
| `delivery_manifest_includes_archive_summary` | PASS | `archive summary is tracked` |
| `submission_archive_is_deterministic` | PASS | `fixed timestamp, sorted entries, compressed zip, sha256` |
| `submission_archive_allows_draft_only_explicitly` | PASS | `incomplete archives are explicit drafts` |
| `delivery_matrix_reads_current_evidence` | PASS | `matrix is generated from current audit/submission/PDF evidence` |
