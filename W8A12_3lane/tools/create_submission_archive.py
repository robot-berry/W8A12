#!/usr/bin/env python3
"""Create a deterministic ZIP archive from submission_manifest.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
DEFAULT_MANIFEST = BASE / "evidence" / "submission_package" / "submission_manifest.json"
DEFAULT_OUT = BASE / "evidence" / "submission_package" / "archive"
FIXED_ZIP_DATE = (2024, 1, 1, 0, 0, 0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--zip-name", default="W8A12_3lane_submission_current.zip")
    parser.add_argument("--allow-incomplete", action="store_true", help="Allow archive creation when manifest status is INCOMPLETE")
    return parser.parse_args()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def add_file(zf: zipfile.ZipFile, src: Path, arcname: str) -> None:
    info = zipfile.ZipInfo(arcname)
    info.date_time = FIXED_ZIP_DATE
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    zf.writestr(info, src.read_bytes())


def render_md(data: dict) -> str:
    lines = [
        "# Submission Archive Summary",
        "",
        f"Status: {data['status']}",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| archive | `{data['archive']}` |",
        f"| bytes | `{data['bytes']}` |",
        f"| sha256 | `{data['sha256']}` |",
        f"| manifest | `{data['manifest']}` |",
        f"| manifest status | `{data['manifest_status']}` |",
        f"| archived file count | `{data['archived_file_count']}` |",
        f"| missing final evidence count | `{len(data['missing_final_evidence'])}` |",
        "",
    ]
    if data["missing_final_evidence"]:
        lines.extend(["## Missing Final Evidence", ""])
        lines.extend(f"- `{item}`" for item in data["missing_final_evidence"])
        lines.append("")
    lines.append("This archive is deterministic and generated from `submission_manifest.json`. If status is `INCOMPLETE`, it is a draft package, not final contest delivery.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    manifest = args.manifest
    out_dir = args.out_dir
    if not manifest.is_absolute():
        manifest = ROOT / manifest
    if not out_dir.is_absolute():
        out_dir = ROOT / out_dir
    data = json.loads(manifest.read_text(encoding="utf-8"))
    manifest_status = data.get("status", "INCOMPLETE")
    if manifest_status != "PASS" and not args.allow_incomplete:
        raise SystemExit("submission manifest is INCOMPLETE; rerun with --allow-incomplete for a draft archive")

    out_dir.mkdir(parents=True, exist_ok=True)
    archive = out_dir / args.zip_name
    entries = data.get("entries", [])
    archived = []
    with zipfile.ZipFile(archive, "w") as zf:
        for entry in sorted(entries, key=lambda item: item["path"]):
            rel = entry["path"]
            src = BASE / rel
            if not src.exists():
                raise FileNotFoundError(src)
            arcname = f"W8A12_3lane/{rel}"
            add_file(zf, src, arcname)
            archived.append({"path": arcname, "bytes": src.stat().st_size})

    summary = {
        "status": manifest_status,
        "archive": str(archive),
        "bytes": archive.stat().st_size,
        "sha256": sha256(archive),
        "manifest": str(manifest),
        "manifest_status": manifest_status,
        "archived_file_count": len(archived),
        "missing_final_evidence": data.get("missing_final_evidence", []),
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_md(summary), encoding="utf-8")
    print(f"SUBMISSION_ARCHIVE_STATUS={summary['status']}")
    print(f"SUBMISSION_ARCHIVE_ZIP={archive}")
    print(f"SUBMISSION_ARCHIVE_SHA256={summary['sha256']}")
    print(f"SUBMISSION_ARCHIVE_SUMMARY_MD={out_dir / 'summary.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
