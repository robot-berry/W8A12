#!/usr/bin/env python3
"""Create a contest-scope package from the current submission manifest."""

from __future__ import annotations

import hashlib
import json
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "contest_scope_package"
ARCHIVE_DIR = OUT / "archive"
SUBMISSION_MANIFEST = BASE / "evidence" / "submission_package" / "submission_manifest.json"
READINESS = BASE / "evidence" / "contest_scope_readiness" / "summary.json"
ZIP_NAME = "W8A12_3lane_contest_scope_submission.zip"
FIXED_ZIP_DATE = (2024, 1, 1, 0, 0, 0)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(path)
    return json.loads(path.read_text(encoding="utf-8"))


def add_file(zf: zipfile.ZipFile, src: Path, arcname: str) -> None:
    info = zipfile.ZipInfo(arcname)
    info.date_time = FIXED_ZIP_DATE
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    zf.writestr(info, src.read_bytes())


def normalize_paths(paths: list[str]) -> list[str]:
    return sorted(path.replace("\\", "/") for path in paths)


def render_md(data: dict) -> str:
    lines = [
        "# Contest Scope Package",
        "",
        f"Status: {data['status']}",
        "",
        f"Scope: {data['scope']}",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| archive | `{data['archive']}` |",
        f"| bytes | `{data['bytes']}` |",
        f"| sha256 | `{data['sha256']}` |",
        f"| archived file count | `{data['archived_file_count']}` |",
        f"| source submission manifest status | `{data['source_submission_manifest_status']}` |",
        f"| contest readiness status | `{data['contest_readiness_status']}` |",
        f"| source submission manifest sha256 | `{data['source_submission_manifest_sha256']}` |",
        f"| contest readiness sha256 | `{data['contest_readiness_sha256']}` |",
        "",
        "## Non-Blocking Board Validation Gaps",
        "",
    ]
    for item in data["non_blocking_missing_final_evidence"]:
        lines.append(f"- `{item}`")
    lines.extend(
        [
            "",
            "## Claims",
            "",
            "| Claim | Status |",
            "| --- | --- |",
        ]
    )
    for name, status in data["claims"].items():
        lines.append(f"| `{name}` | `{status}` |")
    lines.extend(
        [
            "",
            "This package is for the contest scope where physical board validation is not a hard gate. The stricter board-validation archive remains separate.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    readiness = load_json(READINESS)
    submission = load_json(SUBMISSION_MANIFEST)
    non_blocking = normalize_paths(readiness.get("non_blocking_board_validation_gaps", []))
    missing_final = normalize_paths(submission.get("missing_final_evidence", []))

    checks = [
        readiness.get("status") == "PASS_WITH_SCOPE",
        missing_final == non_blocking,
        bool(submission.get("entries")),
    ]
    status = "PASS_WITH_SCOPE" if all(checks) else "FAIL"

    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    archive = ARCHIVE_DIR / ZIP_NAME
    archived: list[dict] = []
    if status == "PASS_WITH_SCOPE":
        with zipfile.ZipFile(archive, "w") as zf:
            for entry in sorted(submission["entries"], key=lambda item: item["path"]):
                rel = entry["path"]
                src = BASE / rel
                if not src.exists():
                    raise FileNotFoundError(src)
                arcname = f"W8A12_3lane/{rel}"
                add_file(zf, src, arcname)
                archived.append({"path": arcname, "bytes": src.stat().st_size})
    elif archive.exists():
        archive.unlink()

    summary = {
        "status": status,
        "scope": "Contest report / RTL simulation / bitstream-PPA evidence; physical board validation is tracked as a non-blocking engineering follow-up for this package.",
        "archive": str(archive),
        "bytes": archive.stat().st_size if archive.exists() else 0,
        "sha256": sha256(archive) if archive.exists() else "",
        "archived_file_count": len(archived),
        "source_submission_manifest": str(SUBMISSION_MANIFEST),
        "source_submission_manifest_status": submission.get("status", ""),
        "source_submission_manifest_sha256": sha256(SUBMISSION_MANIFEST),
        "contest_readiness": str(READINESS),
        "contest_readiness_status": readiness.get("status", ""),
        "contest_readiness_sha256": sha256(READINESS),
        "source_submission_manifest_digest": sha256_bytes(
            json.dumps(submission, sort_keys=True, ensure_ascii=False).encode("utf-8")
        ),
        "contest_readiness_digest": sha256_bytes(
            json.dumps(readiness, sort_keys=True, ensure_ascii=False).encode("utf-8")
        ),
        "non_blocking_missing_final_evidence": missing_final,
        "claims": readiness.get("claims", {}),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(summary), encoding="utf-8")
    print(f"CONTEST_SCOPE_PACKAGE_STATUS={summary['status']}")
    print(f"CONTEST_SCOPE_PACKAGE_ZIP={archive}")
    print(f"CONTEST_SCOPE_PACKAGE_SHA256={summary['sha256']}")
    print(f"CONTEST_SCOPE_PACKAGE_SUMMARY_MD={OUT / 'summary.md'}")
    return 0 if status == "PASS_WITH_SCOPE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
