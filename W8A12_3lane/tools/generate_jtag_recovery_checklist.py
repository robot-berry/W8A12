#!/usr/bin/env python3
"""Generate current JTAG recovery checklist evidence from USB/precondition JSON."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
DEFAULT_USB_JSON = BASE / "evidence" / "board_probe" / "recovery_preflight_current" / "usb" / "usb_jtag_devices.json"
DEFAULT_PRECONDITION_JSON = BASE / "evidence" / "board_probe" / "jtag_precondition_current" / "summary.json"
DEFAULT_OUT = BASE / "evidence" / "board_probe" / "jtag_recovery_checklist"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--usb-json", type=Path, default=DEFAULT_USB_JSON)
    parser.add_argument("--precondition-json", type=Path, default=DEFAULT_PRECONDITION_JSON)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_absolute():
        path = ROOT / path
    return json.loads(path.read_text(encoding="utf-8-sig"))


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def status_from(precondition: dict[str, Any], usb: dict[str, Any]) -> str:
    known = as_int(precondition.get("usb_known_jtag_candidate_count", usb.get("KnownJtagCandidateCount", 0)))
    vivado = precondition.get("vivado_target_count", "not_checked")
    vivado_ready = isinstance(vivado, int) and vivado >= 1
    return "READY" if known >= 1 and vivado_ready else "BLOCKED"


def current_devices(usb: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "name": item.get("Name", ""),
            "class": item.get("PNPClass", ""),
            "status": item.get("Status", ""),
            "known": bool(item.get("IsKnownJtagCandidate")),
            "id": item.get("DeviceID", ""),
        }
        for item in usb.get("Devices", [])
    ]


def historical_known(usb: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for item in usb.get("PnpHistoryDevices", []):
        if item.get("IsKnownJtagCandidate"):
            out.append(
                {
                    "name": item.get("FriendlyName", ""),
                    "class": item.get("Class", ""),
                    "status": item.get("Status", ""),
                    "id": item.get("InstanceId", ""),
                }
            )
    return out


def make_payload(precondition: dict[str, Any], usb: dict[str, Any]) -> dict[str, Any]:
    status = status_from(precondition, usb)
    known = as_int(precondition.get("usb_known_jtag_candidate_count", usb.get("KnownJtagCandidateCount", 0)))
    vivado = precondition.get("vivado_target_count", "not_checked")
    actions = [
        "确认板卡电源打开且电源指示稳定。",
        "确认 USB 线接到板卡 JTAG/USB-UART 对应接口，而不是普通 USB 外设接口。",
        "重新插拔 JTAG USB 线，优先主机直连 USB 口，暂时避免 USB hub。",
        "在 Windows 设备管理器确认在线设备出现 Xilinx/Digilent/FTDI/USB Serial 相关项。",
        "若历史中有 VID_0403&PID_6010 但当前在线列表没有，继续检查线缆、接口、板卡模式和 FTDI/JTAG 驱动。",
        "恢复后重新运行 recovery preflight；只有 USB known candidate 非零且 Vivado target 非零时继续 stage-hash。",
    ]
    return {
        "status": status,
        "generated_at": precondition.get("generated_at", usb.get("GeneratedAt", "")),
        "usb_match_count": as_int(precondition.get("usb_match_count", usb.get("MatchCount", 0))),
        "usb_known_jtag_candidate_count": known,
        "pnp_history_known_jtag_candidate_count": as_int(
            precondition.get("pnp_history_known_jtag_candidate_count", usb.get("PnpHistoryKnownJtagCandidateCount", 0))
        ),
        "pnp_history_known_vidpid_count": as_int(
            precondition.get("pnp_history_known_vidpid_count", usb.get("PnpHistoryKnownVidPidCount", 0))
        ),
        "vivado_target_count": vivado,
        "known_vidpid_pattern": usb.get("KnownVidPidPattern", ""),
        "current_devices": current_devices(usb),
        "historical_known_candidates": historical_known(usb),
        "required_pass_criteria": [
            "USB known JTAG candidate count >= 1",
            "VIVADO_HW_TARGET_COUNT >= 1",
        ],
        "next_command_after_recovery": (
            "powershell -NoProfile -ExecutionPolicy Bypass -File "
            "W8A12_3lane\\scripts\\run_w8a12_board_recovery_preflight.ps1 -RunStageHashAcceptance"
        ),
        "recovery_actions": actions,
        "note": "This checklist records physical/JTAG recovery state only; it is not a board validation PASS.",
    }


def render_md(data: dict[str, Any]) -> str:
    lines = [
        "# JTAG Recovery Checklist Evidence",
        "",
        f"Status: {data['status']}",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| generated_at | `{data['generated_at']}` |",
        f"| USB match count | `{data['usb_match_count']}` |",
        f"| USB known JTAG candidate count | `{data['usb_known_jtag_candidate_count']}` |",
        f"| PnP history known JTAG candidate count | `{data['pnp_history_known_jtag_candidate_count']}` |",
        f"| PnP history known VID/PID count | `{data['pnp_history_known_vidpid_count']}` |",
        f"| Vivado target count | `{data['vivado_target_count']}` |",
        f"| known VID/PID pattern | `{data['known_vidpid_pattern']}` |",
        "",
        "## Current Online USB Matches",
        "",
    ]
    if data["current_devices"]:
        lines.extend(["| Name | Class | Status | Known JTAG | Device ID |", "| --- | --- | --- | --- | --- |"])
        for item in data["current_devices"]:
            device_id = str(item["id"]).replace("|", "/")
            lines.append(f"| `{item['name']}` | `{item['class']}` | `{item['status']}` | `{item['known']}` | `{device_id}` |")
    else:
        lines.append("None")
    lines.extend(["", "## Historical Known JTAG Candidates", ""])
    if data["historical_known_candidates"]:
        lines.extend(["| Name | Class | Status | Instance ID |", "| --- | --- | --- | --- |"])
        for item in data["historical_known_candidates"]:
            instance_id = str(item["id"]).replace("|", "/")
            lines.append(f"| `{item['name']}` | `{item['class']}` | `{item['status']}` | `{instance_id}` |")
    else:
        lines.append("None")
    lines.extend(["", "## Required Pass Criteria", ""])
    lines.extend(f"- `{item}`" for item in data["required_pass_criteria"])
    lines.extend(["", "## Recovery Actions", ""])
    lines.extend(f"{idx}. {item}" for idx, item in enumerate(data["recovery_actions"], start=1))
    lines.extend(
        [
            "",
            "## Continue Command",
            "",
            "```powershell",
            data["next_command_after_recovery"],
            "```",
            "",
            data["note"],
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    usb_json = args.usb_json if args.usb_json.is_absolute() else ROOT / args.usb_json
    precondition_json = args.precondition_json if args.precondition_json.is_absolute() else ROOT / args.precondition_json
    out_dir = args.out_dir if args.out_dir.is_absolute() else ROOT / args.out_dir
    usb = load_json(usb_json)
    precondition = load_json(precondition_json)
    data = make_payload(precondition, usb)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_md(data), encoding="utf-8")
    print(f"JTAG_RECOVERY_CHECKLIST_STATUS={data['status']}")
    print(f"JTAG_RECOVERY_CHECKLIST_MD={out_dir / 'summary.md'}")
    print(f"JTAG_RECOVERY_CHECKLIST_JSON={out_dir / 'summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
