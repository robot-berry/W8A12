#!/usr/bin/env python3
"""Generate an ordered execution queue for remaining hard delivery gates."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
MISSING_PLAN = BASE / "evidence" / "delivery_audit" / "missing_evidence_plan.json"
OUT = BASE / "evidence" / "delivery_audit"

ORDER = [
    "top.accel_shell_sim",
    "top.accel_shell_ooc",
    "top.accel_shell_ooc_summary",
    "a4.single_lane_sim",
    "a4.3lane_sim",
    "a4.single_lane_ooc",
    "a4.single_lane_ooc_summary",
    "a4.3lane_ooc",
    "a4.3lane_ooc_summary",
    "x2.w8a12_export",
    "x2.fixed_reference",
    "x2.fixed_reference_validation",
    "quality.x4_interpolation_baseline",
    "quality.x2_interpolation_baseline",
    "quality.comparison_report",
    "quality.metric_completion_static",
    "board.vivado_hw_probe",
    "a5.board_32x32",
    "a6.board_64x64",
    "a7.board_720p_x4",
    "x2.board",
]

CATEGORY = {
    "top.": "accelerator_top_vivado",
    "a4.": "a4_scheduler_vivado",
    "board.": "board_probe",
    "quality.": "quality_baseline",
    "x2.": "x2_export_reference_board",
    "a5.": "board_x4",
    "a6.": "board_x4",
    "a7.": "board_x4",
}


def category(name: str) -> str:
    for prefix, value in CATEGORY.items():
        if name.startswith(prefix):
            return value
    return "other"


def main() -> int:
    if not MISSING_PLAN.exists():
        raise SystemExit(f"Missing plan not found: {MISSING_PLAN}")
    plan = json.loads(MISSING_PLAN.read_text(encoding="utf-8"))
    items = {item["name"]: item for item in plan.get("items", [])}
    unknown = sorted(set(items) - set(ORDER))
    ordered_names = [name for name in ORDER if name in items] + unknown

    queue: list[dict] = []
    for index, name in enumerate(ordered_names, start=1):
        item = items[name]
        commands = item.get("commands", [])
        queue.append(
            {
                "order": index,
                "name": name,
                "category": category(name),
                "required_path": item.get("path"),
                "required_text": item.get("required_text"),
                "commands": commands,
                "requires_external_process": True,
                "ready_to_run": bool(commands),
            }
        )

    status = "PASS" if queue and all(step["ready_to_run"] for step in queue) else "FAIL"
    data = {
        "status": status,
        "source": MISSING_PLAN.relative_to(ROOT).as_posix(),
        "count": len(queue),
        "queue": queue,
        "note": "This queue is an execution plan for remaining hard gates; it is not a substitute for Vivado, x2 export, or board PASS evidence.",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "hard_gate_execution_queue.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (OUT / "hard_gate_execution_queue.md").write_text(render_md(data), encoding="utf-8")
    return 0 if status == "PASS" else 1


def render_md(data: dict) -> str:
    lines = [
        "# Hard Gate Execution Queue",
        "",
        f"Status: {data['status']}",
        "",
        f"Remaining hard gate count: {data['count']}",
        "",
        "该文件只给出剩余硬门槛的执行顺序和命令，不替代 Vivado/x2/上板 PASS 证据。",
        "",
    ]
    for step in data["queue"]:
        lines.extend(
            [
                f"## {step['order']}. {step['name']}",
                "",
                f"- category: `{step['category']}`",
                f"- required path: `{step['required_path']}`",
                f"- required text: `{step['required_text']}`",
                f"- requires external process: `{step['requires_external_process']}`",
                "",
                "```powershell",
            ]
        )
        lines.extend(step["commands"])
        lines.extend(["```", ""])
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
