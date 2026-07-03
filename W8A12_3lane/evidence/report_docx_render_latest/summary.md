# Contest Report DOCX Render Attempt

Status: SKIPPED_SOFT_DEPENDENCY

| Field | Value |
| --- | --- |
| docx | `G:\UESTC\feitengspan1\W8A12_3lane\output\docx\W8A12_3lane_contest_submission_report.docx` |
| docx_sha256 | `c1cec510db5071843079e7f0f53dfed9e9b1d52c1206692e77df6f05a5c701fb` |
| render_tool | `documents/render_docx.py` |
| result | `FileNotFoundError [WinError 2]` |
| missing_dependency | `soffice / LibreOffice command not found in PATH` |
| fallback_evidence | `W8A12_3lane/evidence/report_docx/summary.md` |

DOCX export itself is still `PASS` and the generated OOXML text-color audit reports `non-black text colors = 0`.
Visual DOCX page rendering is not claimed because the local LibreOffice converter is unavailable.
