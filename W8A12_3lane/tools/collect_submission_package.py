#!/usr/bin/env python3
"""Build a submission-package manifest for robot-berry/W8A12 upload."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "submission_package"

INCLUDE_ROOT_FILES = [
    ".gitignore",
    "README.md",
    "WORKFLOW.md",
    "STATUS.md",
    "DELIVERY_INDEX.md",
]

INCLUDE_DIRS = [
    "docs",
    "rtl",
    "sim",
    "scripts",
    "tools",
]

EVIDENCE_INCLUDE_GLOBS = [
    "evidence/delivery_audit/*.md",
    "evidence/delivery_audit/*.json",
    "evidence/delivery_matrix/*",
    "evidence/delivery_manifest/manifest.md",
    "evidence/submission_package/*.md",
    "evidence/github_upload_preflight/*",
    "evidence/github_upload_export/*",
    "evidence/github_upload_push/*",
    "evidence/reference/*/*summary*",
    "evidence/reference/*/*hash*",
    "evidence/reference/A2_tile_pipeline_shell/*check*",
    "evidence/top/*/*summary*",
    "evidence/top/accel_top_flow_static/*",
    "evidence/resource/*/*summary*",
    "evidence/resource/*/*check*",
    "evidence/top/accel_top_ooc/*_ooc.rpt",
    "evidence/resource/A4_single_lane_mac_scheduler_ooc/*_ooc.rpt",
    "evidence/resource/A4_3lane_mac_scheduler_ooc/*_ooc.rpt",
    "evidence/resource/A4_scheduler_flow_static/*",
    "evidence/ppa_summary/*",
    "evidence/report_static/*",
    "evidence/report_pdf/*",
    "evidence/report_pdf/rendered/*.png",
    "output/pdf/*.pdf",
    "evidence/delivery_runs/*/summary.*",
    "evidence/x2/reference_readiness/*",
    "evidence/x2/asset_search/*",
    "evidence/x2/flow_static/*",
    "evidence/quality_baseline/*/*summary*",
    "evidence/quality_comparison/*summary*",
    "evidence/quality_metric_completion/*",
    "evidence/board_probe/*",
    "evidence/board_probe/*/*",
    "evidence/board_probe/*/*/*",
    "evidence/board_reports/*.md",
    "evidence/board_reports/flow_static/*",
    "evidence/board_reports/*/summary.*",
]

SKIP_SUFFIXES = {".dcp", ".bit", ".xsa", ".jou", ".log", ".npy", ".npz", ".pth", ".pt", ".zip"}
SKIP_DIR_PARTS = {"build", ".Xil", "__pycache__"}

REQUIRED_FOR_FINAL = [
    "evidence/delivery_audit/contest_delivery_audit.md",
    "evidence/delivery_audit/missing_evidence_plan.md",
    "evidence/top/accel_top_sim/summary.md",
    "evidence/top/accel_top_ooc/utilization_ooc.rpt",
    "evidence/top/accel_top_ooc/timing_ooc.rpt",
    "evidence/top/accel_top_ooc/ooc_summary.md",
    "evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md",
    "evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md",
    "evidence/resource/A4_single_lane_mac_scheduler_ooc/utilization_ooc.rpt",
    "evidence/resource/A4_single_lane_mac_scheduler_ooc/timing_ooc.rpt",
    "evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.md",
    "evidence/resource/A4_3lane_mac_scheduler_ooc/utilization_ooc.rpt",
    "evidence/resource/A4_3lane_mac_scheduler_ooc/timing_ooc.rpt",
    "evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.md",
    "evidence/ppa_summary/summary.md",
    "evidence/report_static/summary.md",
    "evidence/report_pdf/summary.md",
    "evidence/board_reports/a5_32x32/validation.md",
    "evidence/board_reports/a6_64x64/validation.md",
    "evidence/board_reports/a7_720p_x4/validation.md",
    "evidence/x2/w8a12_export/summary.md",
    "evidence/x2/reference/summary.md",
    "evidence/x2/reference_validation/validation.md",
    "evidence/quality_baseline/x4_interpolation/summary.md",
    "evidence/quality_baseline/x2_interpolation/summary.md",
    "evidence/quality_comparison/summary.md",
    "evidence/quality_metric_completion/summary.md",
    "evidence/board_reports/x2_720p/validation.md",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def should_include(path: Path) -> bool:
    if not path.is_file():
        return False
    rel_parts = path.relative_to(BASE).parts
    if any(part in SKIP_DIR_PARTS for part in rel_parts):
        return False
    if path.suffix.lower() in SKIP_SUFFIXES:
        return False
    return True


def collect() -> list[Path]:
    paths: set[Path] = set()
    for rel in INCLUDE_ROOT_FILES:
        p = BASE / rel
        if should_include(p):
            paths.add(p)
    for rel_dir in INCLUDE_DIRS:
        root = BASE / rel_dir
        if root.exists():
            for p in root.rglob("*"):
                if should_include(p):
                    paths.add(p)
    for pattern in EVIDENCE_INCLUDE_GLOBS:
        for p in BASE.glob(pattern):
            if should_include(p):
                paths.add(p)
    return sorted(paths, key=lambda p: p.relative_to(BASE).as_posix())


def main() -> int:
    paths = collect()
    entries = [
        {
            "path": path.relative_to(BASE).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
        for path in paths
    ]
    missing_final = [rel for rel in REQUIRED_FOR_FINAL if not (BASE / rel).exists()]
    status = "PASS" if not missing_final else "INCOMPLETE"
    data = {
        "status": status,
        "root": "W8A12_3lane",
        "file_count": len(entries),
        "entries": entries,
        "missing_final_evidence": missing_final,
        "note": "This is an upload/package manifest; final contest readiness still depends on delivery audit PASS.",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "submission_manifest.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "submission_manifest.md").write_text(render_md(data), encoding="utf-8")
    return 0 if status == "PASS" else 1


def render_md(data: dict) -> str:
    lines = [
        "# Submission Package Manifest",
        "",
        f"Status: {data['status']}",
        "",
        f"File count: {data['file_count']}",
        "",
        "## Missing Final Evidence",
        "",
    ]
    if data["missing_final_evidence"]:
        lines.extend(f"- `{item}`" for item in data["missing_final_evidence"])
    else:
        lines.append("None")
    lines.extend(["", "## Files", "", "| Path | Bytes | SHA256 |", "| --- | ---: | --- |"])
    for item in data["entries"]:
        lines.append(f"| `{item['path']}` | {item['bytes']} | `{item['sha256']}` |")
    lines.extend(["", data["note"], ""])
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
