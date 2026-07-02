# GitHub Upload Preflight

Status: PASS

Target repository: `https://github.com/robot-berry/W8A12.git`

Current branch: `codex/w8a12-3lane-delivery-draft`

| Check | Result | Detail |
| --- | --- | --- |
| `git.branch_detected` | PASS | `codex/w8a12-3lane-delivery-draft` |
| `git.target_remote_configured` | PASS | `{"target": "https://github.com/robot-berry/W8A12.git", "configured": ["https://github.com/robot-berry/W8A12.git"]}` |
| `git.w8a12_changes_present` | PASS | `14 W8A12_3lane status lines` |
| `git.outside_changes_detected` | PASS | `8 outside status lines; do not stage them for W8A12 upload` |
| `git.no_staged_outside_upload_scope` | PASS | `[]` |
| `git.upload_candidate_count` | PASS | `1380` |
| `git.no_forbidden_upload_candidates` | PASS | `[]` |
| `submission_scope.required_root_files_present` | PASS | `[]` |
| `submission_scope.required_root_rtl_present` | PASS | `[]` |
| `submission_scope.span_basicsr_present` | PASS | `external/SPAN/basicsr/archs/span_arch.py` |
| `delivery_audit.exists` | PASS | `evidence/delivery_audit/contest_delivery_audit.json` |
| `delivery_audit.not_claiming_final_pass` | PASS | `INCOMPLETE` |
| `delivery_audit.missing_only_board_validation` | PASS | `["a5.board_32x32", "a6.board_64x64", "a7.board_720p_x4", "x2.board"]` |
| `submission_manifest.exists` | PASS | `evidence/submission_package/submission_manifest.json` |
| `submission_manifest.not_final` | PASS | `INCOMPLETE` |
| `submission_manifest.has_files` | PASS | `407` |
| `contest_report_pdf.exists` | PASS | `G:/UESTC/feitengspan1/W8A12_3lane/output/github_upload/robot-berry_W8A12_upload_tree/W8A12_3lane/output/pdf/W8A12_3lane_contest_submission_report.pdf` |
| `contest_report_docx.exists` | PASS | `G:/UESTC/feitengspan1/W8A12_3lane/output/github_upload/robot-berry_W8A12_upload_tree/W8A12_3lane/output/docx/W8A12_3lane_contest_submission_report.docx` |
| `draft_archive_summary.exists` | PASS | `G:/UESTC/feitengspan1/W8A12_3lane/output/github_upload/robot-berry_W8A12_upload_tree/W8A12_3lane/evidence/submission_package/archive/summary.md` |

This preflight permits an INCOMPLETE draft package, but blocks upload if the target remote is not configured or if staged files include paths outside the documented upload scope.
