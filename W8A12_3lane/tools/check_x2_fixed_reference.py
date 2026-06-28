#!/usr/bin/env python3
"""Validate x2 W8A12 fixed-reference summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "evidence" / "x2" / "reference_validation"


def resolve(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def add(checks: list[dict], name: str, passed: bool, detail: object) -> None:
    checks.append({"name": name, "pass": bool(passed), "detail": detail})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=Path("W8A12_3lane/evidence/x2/reference/summary.json"))
    args = parser.parse_args()

    summary_path = resolve(args.summary)
    checks: list[dict] = []
    add(checks, "summary_exists", summary_path.exists(), str(summary_path))
    summary: dict = {}
    if summary_path.exists():
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        add(checks, "status_pass", summary.get("status") == "PASS", summary.get("status"))
        add(checks, "stage_a3_tail_rgb", summary.get("stage") == "A3_tail_rgb", summary.get("stage"))
        add(checks, "scale_is_x2", int(summary.get("scale", -1)) == 2, summary.get("scale"))
        add(checks, "channels_f48", int(summary.get("channels", -1)) == 48, summary.get("channels"))
        add(checks, "activation_bits_12", int(summary.get("activation_bits", -1)) == 12, summary.get("activation_bits"))
        add(checks, "out_channels_rgb", int(summary.get("out_channels", -1)) == 3, summary.get("out_channels"))
        expected_h = int(summary.get("height", -1)) * 2
        expected_w = int(summary.get("width", -1)) * 2
        add(checks, "out_height_matches_x2", summary.get("out_height") == expected_h, summary.get("out_height"))
        add(checks, "out_width_matches_x2", summary.get("out_width") == expected_w, summary.get("out_width"))
        hashes = summary.get("hashes", {})
        add(checks, "rgb_hash_present", bool(hashes.get("rgb_q_hash")), hashes.get("rgb_q_hash"))

    ok = all(check["pass"] for check in checks)
    OUT.mkdir(parents=True, exist_ok=True)
    data = {"status": "PASS" if ok else "FAIL", "summary": str(summary_path), "checks": checks}
    (OUT / "validation.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "validation.md").write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# x2 Fixed Reference Validation",
        "",
        f"Status: {data['status']}",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in data["checks"]:
        detail = str(check["detail"]).replace("|", "/")
        lines.append(f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | `{detail}` |")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
