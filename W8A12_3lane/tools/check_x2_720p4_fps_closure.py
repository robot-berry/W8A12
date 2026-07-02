#!/usr/bin/env python3
"""Build and check the x2 720p4 FPS closure evidence."""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
SRC = BASE / "evidence" / "sim_fps_design_space" / "packed2d_x2_720p20_perf_scheduler" / "summary.json"
OUT = BASE / "evidence" / "sim_fps_design_space" / "x2_720p4_fps_closure"

LR_W = 640
LR_H = 360
SCALE = 2
SR_W = LR_W * SCALE
SR_H = LR_H * SCALE
TARGET_FPS = 4.0
TARGET_FPS_X1000 = int(TARGET_FPS * 1000)
CLOCK_MHZ = 250.0
DSP_GATE = 900
BOUNDARY_CANDIDATE = "24x64"
RECOMMENDED_CANDIDATE = "24x72"
NON_GATED_CANDIDATE = "48x144"
RECOMMENDED_SLACK_MIN_PCT = 10.0


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def candidate_map(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(item.get("candidate", "")): item for item in data.get("candidates", [])}


def frame_cycle_budget(clock_mhz: float = CLOCK_MHZ, target_fps: float = TARGET_FPS) -> float:
    return clock_mhz * 1_000_000.0 / target_fps


def slack_pct(frame_cycles: int, budget_cycles: float) -> float:
    return (budget_cycles - float(frame_cycles)) * 100.0 / budget_cycles


def summarize_candidate(candidate: dict[str, Any], budget_cycles: float) -> dict[str, Any]:
    frame_cycles = int(candidate.get("frame_cycles", 0))
    fps_x1000 = int(candidate.get("fps_x1000", 0))
    estimated_dsp = int(candidate.get("estimated_dsp", 0))
    return {
        "candidate": candidate.get("candidate", ""),
        "output_lanes": int(candidate.get("output_lanes", 0)),
        "tap_lanes": int(candidate.get("tap_lanes", 0)),
        "estimated_dsp": estimated_dsp,
        "resource_gate": bool(candidate.get("resource_gate", estimated_dsp <= DSP_GATE)),
        "cycles_per_lr_pixel": int(candidate.get("cycles_per_lr_pixel", 0)),
        "frame_cycles": frame_cycles,
        "fps": float(candidate.get("fps", 0.0)),
        "fps_x1000": fps_x1000,
        "frame_cycle_slack_pct_of_4fps_budget": round(slack_pct(frame_cycles, budget_cycles), 3),
        "passes_4fps": fps_x1000 >= TARGET_FPS_X1000,
        "passes_15fps": bool(candidate.get("pass15", False)),
        "passes_20fps": bool(candidate.get("pass20", False)),
        "passes_30fps": bool(candidate.get("pass30", False)),
    }


def add_check(checks: list[dict[str, Any]], candidate: str, check: str, passed: bool, detail: Any) -> None:
    checks.append({"candidate": candidate, "check": check, "pass": bool(passed), "detail": detail})


def build_closure(data: dict[str, Any]) -> dict[str, Any]:
    candidates = candidate_map(data)
    checks: list[dict[str, Any]] = []
    budget_cycles = frame_cycle_budget()

    add_check(checks, "global", "source_status_pass", data.get("status") == "PASS", data.get("status"))
    add_check(checks, "global", "source_stage", data.get("stage") == "packed2d_x2_720p20_perf_scheduler", data.get("stage"))
    add_check(checks, "global", "source_frame_720p_x2", "640x360" in str(data.get("frame", "")) and "1280x720" in str(data.get("frame", "")), data.get("frame"))
    add_check(checks, "global", "source_clock_250mhz", float(data.get("clock_mhz", 0.0)) == CLOCK_MHZ, data.get("clock_mhz"))
    add_check(checks, "global", "source_20fps_still_fails", data.get("target_status") == "FAIL", data.get("target_status"))
    add_check(checks, "global", "has_boundary_candidate_24x64", BOUNDARY_CANDIDATE in candidates, sorted(candidates))
    add_check(checks, "global", "has_recommended_candidate_24x72", RECOMMENDED_CANDIDATE in candidates, sorted(candidates))
    add_check(checks, "global", "scope_scheduler_level", True, "scheduler/performance-model only; not board-measured FPS")

    boundary = candidates.get(BOUNDARY_CANDIDATE, {})
    recommended = candidates.get(RECOMMENDED_CANDIDATE, {})
    non_gated = candidates.get(NON_GATED_CANDIDATE, {})

    if boundary:
        boundary_summary = summarize_candidate(boundary, budget_cycles)
        add_check(checks, BOUNDARY_CANDIDATE, "dsp_le_900", boundary_summary["estimated_dsp"] <= DSP_GATE, boundary_summary["estimated_dsp"])
        add_check(checks, BOUNDARY_CANDIDATE, "documents_4fps_fail", not boundary_summary["passes_4fps"], boundary_summary["fps_x1000"])
        add_check(checks, BOUNDARY_CANDIDATE, "lr_frame_pixels", int(boundary.get("frame_pixels", 0)) == LR_W * LR_H, boundary.get("frame_pixels"))
    else:
        boundary_summary = None

    if recommended:
        rec_summary = summarize_candidate(recommended, budget_cycles)
        add_check(checks, RECOMMENDED_CANDIDATE, "fps_ge_4", rec_summary["fps_x1000"] >= TARGET_FPS_X1000, rec_summary["fps_x1000"])
        add_check(checks, RECOMMENDED_CANDIDATE, "dsp_le_900", rec_summary["estimated_dsp"] <= DSP_GATE, rec_summary["estimated_dsp"])
        add_check(checks, RECOMMENDED_CANDIDATE, "resource_gate_true", rec_summary["resource_gate"], rec_summary["resource_gate"])
        add_check(checks, RECOMMENDED_CANDIDATE, "lr_frame_pixels", int(recommended.get("frame_pixels", 0)) == LR_W * LR_H, recommended.get("frame_pixels"))
        add_check(checks, RECOMMENDED_CANDIDATE, "recommended_slack_ge_min", rec_summary["frame_cycle_slack_pct_of_4fps_budget"] >= RECOMMENDED_SLACK_MIN_PCT, rec_summary["frame_cycle_slack_pct_of_4fps_budget"])
        add_check(checks, RECOMMENDED_CANDIDATE, "does_not_claim_20fps", not rec_summary["passes_20fps"], rec_summary["passes_20fps"])
    else:
        rec_summary = None

    if non_gated:
        non_gated_summary = summarize_candidate(non_gated, budget_cycles)
        add_check(checks, NON_GATED_CANDIDATE, "documents_resource_gate_fail", not non_gated_summary["resource_gate"], non_gated_summary["estimated_dsp"])
    else:
        non_gated_summary = None

    ok = all(check["pass"] for check in checks)
    return {
        "status": "PASS" if ok else "FAIL",
        "closure_level": "scheduler/performance-model",
        "scope_boundary": "Not board-measured FPS and not full packed 2-D pixel RTL bit-exact closure. x2 720p20 remains FAIL under the 900-DSP gate.",
        "model": "REDS SPAN x2 F48 W8A12",
        "scale": "x2",
        "lr_input": {"width": LR_W, "height": LR_H, "pixels": LR_W * LR_H},
        "sr_output": {"width": SR_W, "height": SR_H, "pixels": SR_W * SR_H},
        "clock_mhz": CLOCK_MHZ,
        "target_fps": TARGET_FPS,
        "target_frame_cycle_budget": budget_cycles,
        "dsp_gate": DSP_GATE,
        "resource_boundary_candidate": boundary_summary,
        "recommended_closure_candidate": rec_summary,
        "non_gated_reference_candidate": non_gated_summary,
        "checks": checks,
        "source_summary": str(SRC),
        "source_simulate_log": data.get("simulate_log", ""),
    }


def render_md(data: dict[str, Any]) -> str:
    boundary = data["resource_boundary_candidate"] or {}
    rec = data["recommended_closure_candidate"] or {}
    non_gated = data["non_gated_reference_candidate"] or {}
    lines = [
        "# X2 720p4 FPS Closure",
        "",
        f"Status: {data['status']}",
        "",
        "This evidence closes the lowered x2 720p 4fps target at scheduler/performance-model level.",
        "It does not claim board-measured FPS, full packed 2-D pixel RTL bit-exact completion, or x2 720p20 completion.",
        "",
        "| Item | Value |",
        "| --- | --- |",
        f"| model | {data['model']} |",
        f"| scale | {data['scale']} |",
        f"| LR input | {data['lr_input']['width']}x{data['lr_input']['height']} |",
        f"| SR output | {data['sr_output']['width']}x{data['sr_output']['height']} |",
        f"| clock | {data['clock_mhz']:.0f} MHz |",
        f"| lowered target | {data['target_fps']:.1f} fps |",
        f"| DSP gate | {data['dsp_gate']} |",
        f"| closure level | {data['closure_level']} |",
        "",
        "## Candidates",
        "",
        "| Role | Candidate | DSP | Resource gate | Cycles/LR pixel | Frame cycles | FPS @250MHz | 4fps slack |",
        "| --- | --- | ---: | --- | ---: | ---: | ---: | ---: |",
        (
            f"| resource boundary | {boundary.get('candidate', '')} | {boundary.get('estimated_dsp', 0)} | "
            f"{boundary.get('resource_gate', False)} | {boundary.get('cycles_per_lr_pixel', 0)} | "
            f"{boundary.get('frame_cycles', 0)} | {boundary.get('fps', 0.0):.3f} | "
            f"{boundary.get('frame_cycle_slack_pct_of_4fps_budget', 0.0):.3f}% |"
        ),
        (
            f"| recommended closure | {rec.get('candidate', '')} | {rec.get('estimated_dsp', 0)} | "
            f"{rec.get('resource_gate', False)} | {rec.get('cycles_per_lr_pixel', 0)} | "
            f"{rec.get('frame_cycles', 0)} | {rec.get('fps', 0.0):.3f} | "
            f"{rec.get('frame_cycle_slack_pct_of_4fps_budget', 0.0):.3f}% |"
        ),
        (
            f"| non-gated reference | {non_gated.get('candidate', '')} | {non_gated.get('estimated_dsp', 0)} | "
            f"{non_gated.get('resource_gate', False)} | {non_gated.get('cycles_per_lr_pixel', 0)} | "
            f"{non_gated.get('frame_cycles', 0)} | {non_gated.get('fps', 0.0):.3f} | "
            f"{non_gated.get('frame_cycle_slack_pct_of_4fps_budget', 0.0):.3f}% |"
        ),
        "",
        "## Checks",
        "",
        "| Candidate | Check | Result | Detail |",
        "| --- | --- | --- | --- |",
    ]
    for check in data["checks"]:
        detail = json.dumps(check["detail"], ensure_ascii=False) if isinstance(check["detail"], (dict, list)) else str(check["detail"])
        detail = detail.replace("|", "/")
        lines.append(f"| {check['candidate']} | `{check['check']}` | {'PASS' if check['pass'] else 'FAIL'} | `{detail}` |")
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- `24x64` remains under 900 DSP but reaches only 3.861fps, so it is documented as a boundary point rather than a 4fps closure point.",
            "- `24x72` is the recommended x2 lowered-target closure point: 4.483fps @250MHz, 888 DSP, and 10.789% frame-cycle slack against the 4fps budget.",
            "- `48x144` reaches higher FPS but uses 3504 DSP, so it is not valid under the ZC706/XC7Z045 900-DSP planning gate.",
            "- x2 720p20, x4 20fps, and x4 30fps are not claimed by this gate.",
            "",
        ]
    )
    return "\n".join(lines)


def write_outputs(data: dict[str, Any], out_dir: Path = OUT) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (out_dir / "summary.md").write_text(render_md(data), encoding="utf-8")


def sample_source() -> dict[str, Any]:
    return {
        "status": "PASS",
        "target_status": "FAIL",
        "stage": "packed2d_x2_720p20_perf_scheduler",
        "frame": "640x360 LR -> 1280x720 SR",
        "clock_mhz": 250,
        "candidates": [
            {
                "candidate": "24x64",
                "output_lanes": 24,
                "tap_lanes": 64,
                "estimated_dsp": 792,
                "cycles_per_lr_pixel": 281,
                "frame_pixels": 230400,
                "frame_cycles": 64742400,
                "fps_x1000": 3861,
                "fps": 3.861,
                "pass15": False,
                "pass20": False,
                "pass30": False,
                "resource_gate": True,
            },
            {
                "candidate": "24x72",
                "output_lanes": 24,
                "tap_lanes": 72,
                "estimated_dsp": 888,
                "cycles_per_lr_pixel": 242,
                "frame_pixels": 230400,
                "frame_cycles": 55756800,
                "fps_x1000": 4483,
                "fps": 4.483,
                "pass15": False,
                "pass20": False,
                "pass30": False,
                "resource_gate": True,
            },
            {
                "candidate": "48x144",
                "output_lanes": 48,
                "tap_lanes": 144,
                "estimated_dsp": 3504,
                "cycles_per_lr_pixel": 63,
                "frame_pixels": 230400,
                "frame_cycles": 14515200,
                "fps_x1000": 17223,
                "fps": 17.223,
                "pass15": True,
                "pass20": False,
                "pass30": False,
                "resource_gate": False,
            },
        ],
    }


def self_test() -> int:
    good = build_closure(sample_source())
    if good["status"] != "PASS":
        print(json.dumps(good, indent=2, ensure_ascii=False))
        print("X2_720P4_FPS_CLOSURE_SELF_TEST=FAIL")
        return 1

    bad_source = sample_source()
    for candidate in bad_source["candidates"]:
        if candidate["candidate"] == RECOMMENDED_CANDIDATE:
            candidate["frame_cycles"] = 63_000_000
            candidate["fps_x1000"] = 3968
            candidate["fps"] = 3.968
    bad = build_closure(bad_source)
    if bad["status"] != "FAIL":
        print(json.dumps(bad, indent=2, ensure_ascii=False))
        print("X2_720P4_FPS_CLOSURE_SELF_TEST=FAIL")
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        write_outputs(good, out)
        if not (out / "summary.json").exists() or not (out / "summary.md").exists():
            print("X2_720P4_FPS_CLOSURE_SELF_TEST=FAIL")
            return 1
        bom_json = out / "bom_summary.json"
        bom_json.write_text(json.dumps(sample_source()), encoding="utf-8-sig")
        loaded = load_json(bom_json)
        if loaded.get("stage") != "packed2d_x2_720p20_perf_scheduler":
            print("X2_720P4_FPS_CLOSURE_SELF_TEST=FAIL")
            return 1

    print("X2_720P4_FPS_CLOSURE_SELF_TEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run built-in tests")
    parser.add_argument("--source", type=Path, default=SRC, help="x2 packed2d scheduler summary JSON")
    parser.add_argument("--out-dir", type=Path, default=OUT, help="closure evidence output directory")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if not args.source.exists():
        print("X2_720P4_FPS_CLOSURE_STATUS=FAIL")
        print(f"missing_source={args.source}")
        return 1

    data = load_json(args.source)
    closure = build_closure(data)
    write_outputs(closure, args.out_dir)
    print(f"X2_720P4_FPS_CLOSURE_STATUS={closure['status']}")
    print(f"X2_720P4_FPS_CLOSURE_MD={args.out_dir / 'summary.md'}")
    print(f"X2_720P4_FPS_CLOSURE_JSON={args.out_dir / 'summary.json'}")
    return 0 if closure["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
