#!/usr/bin/env python3
"""Export a clean upload tree for robot-berry/W8A12 without pushing this repo history."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "github_upload_export"
DEFAULT_EXPORT_ROOT = BASE / "output" / "github_upload" / "robot-berry_W8A12_upload_tree"
TARGET_REPO = "https://github.com/robot-berry/W8A12.git"
SKIP_PREFIXES = ("W8A12_3lane/evidence/github_upload_export/",)

FORBIDDEN_RE = re.compile(
    r"(\.(npy|npz|pth|pt|pid|zip|dcp|bit|xsa|jou|log|wdb)$|"
    r"(^|/)(stdout|stderr)\.txt$|"
    r"_(stdout|stderr)\.txt$)",
    re.IGNORECASE,
)


def run_git(args: list[str]) -> tuple[int, str]:
    proc = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return proc.returncode, proc.stdout.strip()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_clean_dir(path: Path) -> None:
    resolved = path.resolve()
    allowed = (BASE / "output" / "github_upload").resolve()
    if not str(resolved).startswith(str(allowed)):
        raise RuntimeError(f"refusing to delete outside {allowed}: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True, exist_ok=True)


def collect_candidates() -> list[str]:
    code, output = run_git(["ls-files", "--others", "--cached", "--exclude-standard", "W8A12_3lane"])
    if code != 0:
        raise RuntimeError(output)
    paths = []
    for line in output.splitlines():
        rel = line.strip().replace("\\", "/")
        if not rel or not rel.startswith("W8A12_3lane/"):
            continue
        if rel.startswith(SKIP_PREFIXES):
            continue
        if FORBIDDEN_RE.search(rel):
            continue
        src = ROOT / rel
        if src.is_file():
            paths.append(rel)
    return sorted(set(paths))


def main() -> int:
    export_root = DEFAULT_EXPORT_ROOT
    safe_clean_dir(export_root)

    candidates = collect_candidates()
    entries = []
    total_bytes = 0
    for rel in candidates:
        src = ROOT / rel
        dst = export_root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        size = dst.stat().st_size
        total_bytes += size
        entries.append({"path": rel, "bytes": size, "sha256": sha256_file(dst)})

    forbidden_after_copy = [entry["path"] for entry in entries if FORBIDDEN_RE.search(entry["path"])]
    status = "PASS" if entries and not forbidden_after_copy else "FAIL"
    data = {
        "status": status,
        "target_repo": TARGET_REPO,
        "export_root": str(export_root),
        "file_count": len(entries),
        "total_bytes": total_bytes,
        "forbidden_after_copy": forbidden_after_copy,
        "entries": entries,
        "note": "This clean tree is for creating a separate upload commit without pushing the current repository history.",
    }

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"GITHUB_UPLOAD_EXPORT_STATUS={status}")
    print(f"GITHUB_UPLOAD_EXPORT_ROOT={export_root}")
    print(f"GITHUB_UPLOAD_EXPORT_FILE_COUNT={len(entries)}")
    print(f"GITHUB_UPLOAD_EXPORT_SUMMARY={OUT / 'summary.md'}")
    return 0 if status == "PASS" else 1


def render_md(data: dict) -> str:
    lines = [
        "# GitHub Upload Clean Tree Export",
        "",
        f"Status: {data['status']}",
        "",
        f"Target repository: `{data['target_repo']}`",
        "",
        f"Export root: `{data['export_root']}`",
        "",
        f"File count: `{data['file_count']}`",
        "",
        f"Total bytes: `{data['total_bytes']}`",
        "",
        f"Forbidden copied files: `{len(data['forbidden_after_copy'])}`",
        "",
        "## Upload Command Sketch",
        "",
        "```powershell",
        f"Set-Location \"{data['export_root']}\"",
        "git init",
        "git remote add origin https://github.com/robot-berry/W8A12.git",
        "git add W8A12_3lane",
        'git commit -m "Add W8A12 3-lane contest delivery draft"',
        "git push origin HEAD:training-software",
        "```",
        "",
        "This export intentionally keeps the `W8A12_3lane/` directory as the upload root and does not include forbidden generated artifacts.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
