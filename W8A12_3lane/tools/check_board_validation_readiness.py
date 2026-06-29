#!/usr/bin/env python3
"""Check readiness of the remaining real board validation reports."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
OUT = BASE / "evidence" / "board_reports" / "validation_readiness"

EXPECTED = {
    "a5_32x32": {
        "audit_name": "a5.board_32x32",
        "scale": 4,
        "lr_size": [32, 32],
        "hr_size": [128, 128],
        "tile_count": [1, 1],
        "target_psnr_db": 28.0,
        "target_fps": 15.0,
    },
    "a6_64x64": {
        "audit_name": "a6.board_64x64",
        "scale": 4,
        "lr_size": [64, 64],
        "hr_size": [256, 256],
        "tile_count": [2, 2],
        "target_psnr_db": 28.0,
        "target_fps": 15.0,
    },
    "a7_720p_x4": {
        "audit_name": "a7.board_720p_x4",
        "scale": 4,
        "lr_size": [320, 180],
        "hr_size": [1280, 720],
        "tile_count": [10, 6],
        "target_psnr_db": 28.0,
        "target_fps": 15.0,
    },
    "x2_720p": {
        "audit_name": "x2.board",
        "scale": 2,
        "lr_size": [640, 360],
        "hr_size": [1280, 720],
        "tile_count": [20, 12],
        "target_psnr_db": 30.0,
        "target_fps": 15.0,
    },
}

TOOLS = [
    "tools/create_board_report.py",
    "tools/update_board_report.py",
    "tools/validate_board_report.py",
    "tools/summarize_jtag_precondition.py",
]


def add(checks: list[dict], name: str, passed: bool, detail: object) -> None:
    checks.append({"name": name, "pass": bool(passed), "detail": detail})


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validation_status(path: Path) -> str:
    if not path.exists():
        return "PENDING_NO_VALIDATION"
    text = path.read_text(encoding="utf-8", errors="ignore")
    if "Status: PASS" in text:
        return "PASS"
    return "PRESENT_NOT_PASS"


def main() -> int:
    checks: list[dict] = []
    plan = BASE / "evidence" / "delivery_audit" / "missing_evidence_plan.md"
    precondition = BASE / "evidence" / "board_probe" / "jtag_precondition_current" / "summary.md"
    validator = BASE / "tools" / "validate_board_report.py"
    plan_text = plan.read_text(encoding="utf-8", errors="ignore") if plan.exists() else ""
    precondition_text = precondition.read_text(encoding="utf-8", errors="ignore") if precondition.exists() else ""
    validator_text = validator.read_text(encoding="utf-8", errors="ignore") if validator.exists() else ""

    for rel in TOOLS:
        add(checks, f"tool:{rel}", (BASE / rel).exists(), rel)
    add(checks, "file:missing_evidence_plan", plan.exists(), plan.relative_to(ROOT).as_posix())
    add(checks, "file:jtag_precondition_current", precondition.exists(), precondition.relative_to(ROOT).as_posix())
    add(checks, "file:validate_board_report", validator.exists(), validator.relative_to(ROOT).as_posix())
    add(
        checks,
        "precondition_declares_status",
        "Status:" in precondition_text and "USB known JTAG candidate count" in precondition_text,
        "current board/JTAG precondition is explicit",
    )

    entries = []
    for tag, expected in EXPECTED.items():
        report_dir = BASE / "evidence" / "board_reports" / tag
        summary_json = report_dir / "summary.json"
        summary_md = report_dir / "summary.md"
        validation_md = report_dir / "validation.md"
        add(checks, f"{tag}:summary_json", summary_json.exists(), summary_json.relative_to(ROOT).as_posix())
        add(checks, f"{tag}:summary_md", summary_md.exists(), summary_md.relative_to(ROOT).as_posix())
        data = read_json(summary_json) if summary_json.exists() else {}
        pipeline = data.get("input_pipeline", {})
        performance = data.get("performance", {})
        quality = data.get("quality", {})

        add(checks, f"{tag}:status_not_final_without_validation", data.get("status") in ("PENDING", "PASS"), data.get("status"))
        add(checks, f"{tag}:scale", data.get("scale") == expected["scale"], data.get("scale"))
        add(checks, f"{tag}:lr_size", data.get("lr_size") == expected["lr_size"], data.get("lr_size"))
        add(checks, f"{tag}:hr_size", data.get("hr_size") == expected["hr_size"], data.get("hr_size"))
        add(
            checks,
            f"{tag}:tile_count",
            [pipeline.get("tile_count_x"), pipeline.get("tile_count_y")] == expected["tile_count"],
            [pipeline.get("tile_count_x"), pipeline.get("tile_count_y")],
        )
        add(checks, f"{tag}:tile_size_32", pipeline.get("tile_size") == [32, 32], pipeline.get("tile_size"))
        add(checks, f"{tag}:halo_21", pipeline.get("halo") == 21, pipeline.get("halo"))
        add(checks, f"{tag}:target_fps", float(performance.get("target_fps", -1)) == expected["target_fps"], performance.get("target_fps"))
        add(
            checks,
            f"{tag}:target_psnr_declared",
            (
                ("PSNR target: x4 >= 28 dB" in plan_text and expected["scale"] == 4)
                or ("PSNR target: x2 >= 30 dB" in plan_text and expected["scale"] == 2)
            )
            and "30.0 if scale == 2 else 28.0 if scale == 4" in validator_text,
            expected["target_psnr_db"],
        )
        add(
            checks,
            f"{tag}:command_chain",
            all(token in plan_text for token in [
                f"--tag {tag}",
                f"board_reports\\{tag}\\summary.json",
                f"board_reports\\{tag}\\validation.md",
                "validate_board_report.py",
            ]),
            expected["audit_name"],
        )
        status = validation_status(validation_md)
        entries.append(
            {
                "tag": tag,
                "audit_name": expected["audit_name"],
                "report_status": data.get("status"),
                "validation_status": status,
                "scale": expected["scale"],
                "lr_size": expected["lr_size"],
                "hr_size": expected["hr_size"],
                "tile_count": expected["tile_count"],
                "target_psnr_db": expected["target_psnr_db"],
                "target_fps": expected["target_fps"],
                "current_psnr_db": quality.get("psnr_db"),
            }
        )

    ok = all(check["pass"] for check in checks)
    data = {"status": "PASS" if ok else "FAIL", "items": entries, "checks": checks}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"BOARD_VALIDATION_READINESS_STATUS={data['status']}")
    print(f"BOARD_VALIDATION_READINESS_MD={OUT / 'summary.md'}")
    print(f"BOARD_VALIDATION_READINESS_JSON={OUT / 'summary.json'}")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        "# Board Validation Readiness",
        "",
        f"Status: {data['status']}",
        "",
        "This readiness check prepares the four remaining real-board validation reports. It is not a substitute for `validation.md Status: PASS`.",
        "",
        "| Tag | Audit Gate | Report | Validation | LR | HR | Tiles | PSNR Target | FPS Target |",
        "| --- | --- | --- | --- | --- | --- | --- | ---: | ---: |",
    ]
    for item in data["items"]:
        lines.append(
            "| `{tag}` | `{audit_name}` | `{report_status}` | `{validation_status}` | {lr} | {hr} | {tiles} | {psnr:.1f} | {fps:.1f} |".format(
                tag=item["tag"],
                audit_name=item["audit_name"],
                report_status=item["report_status"],
                validation_status=item["validation_status"],
                lr="x".join(map(str, item["lr_size"])),
                hr="x".join(map(str, item["hr_size"])),
                tiles="x".join(map(str, item["tile_count"])),
                psnr=item["target_psnr_db"],
                fps=item["target_fps"],
            )
        )
    lines.extend(["", "## Checks", "", "| Check | Result | Detail |", "| --- | --- | --- |"])
    for check in data["checks"]:
        detail = str(check["detail"]).replace("|", "/")
        lines.append(f"| `{check['name']}` | {'PASS' if check['pass'] else 'FAIL'} | `{detail}` |")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
