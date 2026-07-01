#!/usr/bin/env python3
"""Collect a deterministic manifest for W8A12_3lane delivery files."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "delivery_manifest"

INCLUDE_DIRS = [
    "docs",
    "rtl",
    "sim",
    "scripts",
    "tools",
]

INCLUDE_FILES = [
    ".gitignore",
    "README.md",
    "WORKFLOW.md",
    "STATUS.md",
    "DELIVERY_INDEX.md",
    "evidence/delivery_audit/contest_delivery_audit.md",
    "evidence/delivery_audit/contest_delivery_audit.json",
    "evidence/delivery_audit/missing_evidence_plan.md",
    "evidence/delivery_audit/missing_evidence_plan.json",
    "evidence/delivery_matrix/summary.md",
    "evidence/delivery_matrix/summary.json",
    "evidence/github_upload_preflight/summary.md",
    "evidence/github_upload_preflight/summary.json",
    "evidence/github_upload_export/summary.md",
    "evidence/github_upload_export/summary.json",
    "evidence/github_upload_push/summary.md",
    "evidence/github_upload_push/summary.json",
    "evidence/github_pr_attempt/summary.md",
    "evidence/github_pr_attempt/summary.json",
    "evidence/submission_package/submission_manifest.md",
    "evidence/submission_package/submission_manifest.json",
    "evidence/submission_package/archive/summary.md",
    "evidence/submission_package/archive/summary.json",
    "evidence/x2/reference_readiness/readiness.md",
    "evidence/x2/reference_readiness/readiness.json",
    "evidence/x2/asset_search/x2_asset_search.md",
    "evidence/x2/asset_search/x2_asset_search.json",
    "evidence/resource/A4_ooc_summary_flow.md",
]

EVIDENCE_PATTERNS = [
    "evidence/reference/A0_single_conv/*summary*",
    "evidence/reference/A0_single_conv/*hash*",
    "evidence/reference/A1_single_block/*summary*",
    "evidence/reference/A1_single_block/*hash*",
    "evidence/reference/A2_six_blocks/*summary*",
    "evidence/reference/A2_six_blocks/*hash*",
    "evidence/reference/A2_tile_pipeline_shell/*check*",
    "evidence/top/*/*summary*",
    "evidence/top/accel_top_flow_static/*",
    "evidence/reference/A3_tail_rgb/*summary*",
    "evidence/reference/A3_tail_rgb/*hash*",
    "evidence/resource/A4_lane_mac_core_ooc/*summary*",
    "evidence/resource/A4_lane_mac_core_ooc/*gate*.json",
    "evidence/resource/A4_single_out_mac_scheduler/*summary*",
    "evidence/resource/A4_3lane_mac_scheduler/*static_check*",
    "evidence/resource/A4_scheduler_vector_check/*summary*",
    "evidence/resource/A4_scheduler_flow_static/*summary*",
    "evidence/resource/A4_ooc_parser_selfcheck/*summary*",
    "evidence/resource/A4_single_lane_mac_scheduler/*summary*",
    "evidence/resource/A4_3lane_mac_scheduler/*sim_summary*",
    "evidence/top/accel_top_ooc/*_ooc.rpt",
    "evidence/resource/A4_single_lane_mac_scheduler_ooc/*_ooc.rpt",
    "evidence/resource/A4_3lane_mac_scheduler_ooc/*_ooc.rpt",
    "evidence/resource/A4_single_lane_mac_scheduler_ooc/ooc_summary.*",
    "evidence/resource/A4_3lane_mac_scheduler_ooc/ooc_summary.*",
    "evidence/ppa_summary/*",
    "evidence/bitstream_ppa_gate/*",
    "evidence/sim_fps_estimate/*",
    "evidence/sim_fps_design_space/x4_720p15_fps_closure/*",
    "evidence/report_static/*",
    "evidence/report_pdf/*",
    "evidence/report_pdf/rendered/*.png",
    "evidence/report_docx/*",
    "evidence/report_docx_complete_20260701/*",
    "output/pdf/*.pdf",
    "output/docx/*.docx",
    "evidence/delivery_runs/*/summary.*",
    "evidence/x2/w8a12_export/*summary*",
    "evidence/x2/flow_static/*summary*",
    "evidence/x2/reference/*summary*",
    "evidence/x2/reference_validation/*validation*",
    "evidence/quality_baseline/*/*summary*",
    "evidence/quality_comparison/*summary*",
    "evidence/quality_metric_completion/*",
    "evidence/board_probe/*",
    "evidence/board_probe/*/*",
    "evidence/board_probe/*/*/*",
    "evidence/board_reports/*.md",
    "evidence/board_reports/flow_static/*summary*",
    "evidence/board_reports/validation_closure/*",
    "evidence/board_reports/*/summary.*",
    "evidence/board_reports/*/validation.*",
]

SKIP_SUFFIXES = {
    ".dcp",
    ".bit",
    ".xsa",
    ".jou",
    ".log",
    ".npy",
    ".npz",
    ".pth",
    ".pt",
    ".zip",
}

SKIP_DIR_PARTS = {"__pycache__"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def should_include(path: Path) -> bool:
    if not path.is_file():
        return False
    if any(part in SKIP_DIR_PARTS for part in path.relative_to(BASE).parts):
        return False
    if path.name.startswith("~$"):
        return False
    if path.suffix.lower() in SKIP_SUFFIXES:
        return False
    return True


def collect_paths() -> list[Path]:
    paths: set[Path] = set()
    for rel in INCLUDE_FILES:
        path = BASE / rel
        if should_include(path):
            paths.add(path)
    for rel_dir in INCLUDE_DIRS:
        root = BASE / rel_dir
        if root.exists():
            for path in root.rglob("*"):
                if should_include(path):
                    paths.add(path)
    for pattern in EVIDENCE_PATTERNS:
        for path in BASE.glob(pattern):
            if should_include(path):
                paths.add(path)
    return sorted(paths, key=lambda p: p.relative_to(BASE).as_posix())


def main() -> int:
    paths = collect_paths()
    entries = []
    for path in paths:
        rel = path.relative_to(BASE).as_posix()
        entries.append({"path": rel, "bytes": path.stat().st_size, "sha256": sha256(path)})
    status = "INCOMPLETE"
    audit_json = BASE / "evidence" / "delivery_audit" / "contest_delivery_audit.json"
    if audit_json.exists():
        try:
            status = json.loads(audit_json.read_text(encoding="utf-8")).get("status", status)
        except json.JSONDecodeError:
            status = "INCOMPLETE"
    OUT.mkdir(parents=True, exist_ok=True)
    data = {
        "status": status,
        "root": "W8A12_3lane",
        "file_count": len(entries),
        "entries": entries,
        "note": "Manifest records delivery package files. It does not imply contest acceptance PASS.",
    }
    (OUT / "manifest.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "manifest.md").write_text(render_md(data), encoding="utf-8")
    return 0


def render_md(data: dict) -> str:
    lines = [
        "# W8A12_3lane Delivery Manifest",
        "",
        f"Status: {data['status']}",
        "",
        f"File count: {data['file_count']}",
        "",
        "| Path | Bytes | SHA256 |",
        "| --- | ---: | --- |",
    ]
    for item in data["entries"]:
        lines.append(f"| `{item['path']}` | {item['bytes']} | `{item['sha256']}` |")
    lines.extend(["", data["note"], ""])
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
