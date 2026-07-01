#!/usr/bin/env python3
"""Build and check the x4 720p15 FPS closure evidence."""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
SRC = BASE / "evidence" / "sim_fps_design_space" / "packed2d_perf_scheduler" / "summary.json"
OUT = BASE / "evidence" / "sim_fps_design_space" / "x4_720p15_fps_closure"

LR_W = 320
LR_H = 180
SCALE = 4
SR_W = LR_W * SCALE
SR_H = LR_H * SCALE
TARGET_FPS = 15.0
TARGET_FPS_X1000 = int(TARGET_FPS * 1000)
CLOCK_MHZ = 250.0
DSP_GATE = 900
MIN_CANDIDATE = "24x64"
RECOMMENDED_CANDIDATE = "24x72"
RECOMMENDED_SLACK_MIN_PCT = 10.0


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def candidate_map(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for item in data.get("candidates", []):
        result[str(item.get("candidate", ""))] = item
    return result


def frame_cycle_budget(clock_mhz: float = CLOCK_MHZ, target_fps: float = TARGET_FPS) -> float:
    return clock_mhz * 1_000_000.0 / target_fps


def slack_pct(frame_cycles: int, budget_cycles: float) -> float:
    return (budget_cycles - float(frame_cycles)) * 100.0 / budget_cycles


def check_candidate(
    candidate: dict[str, Any],
    name: str,
    budget_cycles: float,
    require_slack_pct: float | None = None,
) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []

    def add(check: str, passed: bool, detail: Any) -> None:
        checks.append(
            {
                "candidate": name,
                "check": check,
                "pass": bool(passed),
                "detail": detail,
            }
        )

    fps_x1000 = int(candidate.get("fps_x1000", 0))
    estimated_dsp = int(candidate.get("estimated_dsp", 0))
    frame_pixels = int(candidate.get("frame_pixels", 0))
    frame_cycles = int(candidate.get("frame_cycles", 0))
    candidate_slack = slack_pct(frame_cycles, budget_cycles)

    add("fps_ge_15", fps_x1000 >= TARGET_FPS_X1000, fps_x1000)
    add("dsp_le_900", estimated_dsp <= DSP_GATE, estimated_dsp)
    add("lr_frame_pixels", frame_pixels == LR_W * LR_H, frame_pixels)
    add("declares_pass15", bool(candidate.get("pass15", False)), candidate.get("pass15"))
    add("not_claiming_20_or_30", not candidate.get("pass20", False) and not candidate.get("pass30", False), {
        "pass20": candidate.get("pass20", False),
        "pass30": candidate.get("pass30", False),
    })
    add("positive_frame_cycles", frame_cycles > 0, frame_cycles)
    add("positive_slack_to_15fps_budget", candidate_slack > 0.0, round(candidate_slack, 3))
    if require_slack_pct is not None:
        add("recommended_slack_ge_min", candidate_slack >= require_slack_pct, round(candidate_slack, 3))
    return checks


def build_closure(data: dict[str, Any]) -> dict[str, Any]:
    candidates = candidate_map(data)
    checks: list[dict[str, Any]] = []

    def add(check: str, passed: bool, detail: Any) -> None:
        checks.append({"candidate": "global", "check": check, "pass": bool(passed), "detail": detail})

    budget_cycles = frame_cycle_budget()
    add("source_status_pass", data.get("status") == "PASS", data.get("status"))
    add("source_stage", data.get("stage") == "packed2d_perf_scheduler", data.get("stage"))
    add("source_frame_720p_x4", "320x180" in str(data.get("frame", "")) and "1280x720" in str(data.get("frame", "")), data.get("frame"))
    add("source_clock_250mhz", float(data.get("clock_mhz", 0.0)) == CLOCK_MHZ, data.get("clock_mhz"))
    add("has_minimum_candidate_24x64", MIN_CANDIDATE in candidates, sorted(candidates))
    add("has_recommended_candidate_24x72", RECOMMENDED_CANDIDATE in candidates, sorted(candidates))
    add("scope_scheduler_level", True, "scheduler/performance-model only; not board-measured FPS")

    minimum: dict[str, Any] = {}
    recommended: dict[str, Any] = {}
    if MIN_CANDIDATE in candidates:
        minimum = candidates[MIN_CANDIDATE]
        checks.extend(check_candidate(minimum, MIN_CANDIDATE, budget_cycles))
    if RECOMMENDED_CANDIDATE in candidates:
        recommended = candidates[RECOMMENDED_CANDIDATE]
        checks.extend(check_candidate(recommended, RECOMMENDED_CANDIDATE, budget_cycles, RECOMMENDED_SLACK_MIN_PCT))

    ok = all(item["pass"] for item in checks)
    return {
        "status": "PASS" if ok else "FAIL",
        "closure_level": "scheduler/performance-model",
        "scope_boundary": "Not board-measured FPS and not full packed 2-D pixel RTL bit-exact closure.",
        "model": "REDS SPAN x4 F48 W8A12",
        "scale": "x4",
        "lr_input": {"width": LR_W, "height": LR_H, "pixels": LR_W * LR_H},
        "sr_output": {"width": SR_W, "height": SR_H, "pixels": SR_W * SR_H},
        "clock_mhz": CLOCK_MHZ,
        "target_fps": TARGET_FPS,
        "target_frame_cycle_budget": budget_cycles,
        "dsp_gate": DSP_GATE,
        "minimum_resource_candidate": summarize_candidate(minimum, budget_cycles) if minimum else None,
        "recommended_closure_candidate": summarize_candidate(recommended, budget_cycles) if recommended else None,
        "checks": checks,
        "source_summary": str(SRC),
        "source_simulate_log": data.get("simulate_log", ""),
    }


def summarize_candidate(candidate: dict[str, Any], budget_cycles: float) -> dict[str, Any]:
    frame_cycles = int(candidate.get("frame_cycles", 0))
    return {
        "candidate": candidate.get("candidate", ""),
        "output_lanes": int(candidate.get("output_lanes", 0)),
        "tap_lanes": int(candidate.get("tap_lanes", 0)),
        "estimated_dsp": int(candidate.get("estimated_dsp", 0)),
        "cycles_per_lr_pixel": int(candidate.get("cycles_per_lr_pixel", 0)),
        "frame_cycles": frame_cycles,
        "fps": float(candidate.get("fps", 0.0)),
        "fps_x1000": int(candidate.get("fps_x1000", 0)),
        "frame_cycle_slack_pct_of_15fps_budget": round(slack_pct(frame_cycles, budget_cycles), 3),
        "passes_15fps": bool(candidate.get("pass15", False)),
        "passes_20fps": bool(candidate.get("pass20", False)),
        "passes_30fps": bool(candidate.get("pass30", False)),
    }


def render_md(data: dict[str, Any]) -> str:
    min_c = data["minimum_resource_candidate"] or {}
    rec_c = data["recommended_closure_candidate"] or {}
    lines = [
        "# X4 720p15 FPS Closure",
        "",
        f"Status: {data['status']}",
        "",
        "This evidence closes the x4 720p 15fps target at scheduler/performance-model level.",
        "It does not claim board-measured FPS or full packed 2-D pixel RTL bit-exact completion.",
        "",
        "| Item | Value |",
        "| --- | --- |",
        f"| model | {data['model']} |",
        f"| scale | {data['scale']} |",
        f"| LR input | {data['lr_input']['width']}x{data['lr_input']['height']} |",
        f"| SR output | {data['sr_output']['width']}x{data['sr_output']['height']} |",
        f"| clock | {data['clock_mhz']:.0f} MHz |",
        f"| target | {data['target_fps']:.1f} fps |",
        f"| DSP gate | {data['dsp_gate']} |",
        f"| closure level | {data['closure_level']} |",
        "",
        "## Candidates",
        "",
        "| Role | Candidate | DSP | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps slack |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
        (
            f"| minimum resource | {min_c.get('candidate', '')} | {min_c.get('estimated_dsp', 0)} | "
            f"{min_c.get('cycles_per_lr_pixel', 0)} | {min_c.get('frame_cycles', 0)} | "
            f"{min_c.get('fps', 0.0):.3f} | {min_c.get('frame_cycle_slack_pct_of_15fps_budget', 0.0):.3f}% |"
        ),
        (
            f"| recommended closure | {rec_c.get('candidate', '')} | {rec_c.get('estimated_dsp', 0)} | "
            f"{rec_c.get('cycles_per_lr_pixel', 0)} | {rec_c.get('frame_cycles', 0)} | "
            f"{rec_c.get('fps', 0.0):.3f} | {rec_c.get('frame_cycle_slack_pct_of_15fps_budget', 0.0):.3f}% |"
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
            "- `24x64` is retained as the minimum-resource 15fps point. Its slack is small, so it is not the recommended implementation point.",
            "- `24x72` is the recommended closure point because it remains under 900 DSP and has more than 10% frame-cycle slack against the 15fps budget.",
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
        "stage": "packed2d_perf_scheduler",
        "frame": "320x180 LR -> 1280x720 SR",
        "clock_mhz": 250,
        "candidates": [
            {
                "candidate": "24x64",
                "output_lanes": 24,
                "tap_lanes": 64,
                "estimated_dsp": 792,
                "cycles_per_lr_pixel": 288,
                "frame_pixels": 57600,
                "frame_cycles": 16588800,
                "fps_x1000": 15070,
                "fps": 15.07,
                "pass15": True,
                "pass20": False,
                "pass30": False,
            },
            {
                "candidate": "24x72",
                "output_lanes": 24,
                "tap_lanes": 72,
                "estimated_dsp": 888,
                "cycles_per_lr_pixel": 248,
                "frame_pixels": 57600,
                "frame_cycles": 14284800,
                "fps_x1000": 17501,
                "fps": 17.501,
                "pass15": True,
                "pass20": False,
                "pass30": False,
            },
        ],
    }


def self_test() -> int:
    good = build_closure(sample_source())
    if good["status"] != "PASS":
        print(json.dumps(good, indent=2, ensure_ascii=False))
        print("X4_720P15_FPS_CLOSURE_SELF_TEST=FAIL")
        return 1

    bad_source = sample_source()
    for candidate in bad_source["candidates"]:
        if candidate["candidate"] == RECOMMENDED_CANDIDATE:
            candidate["frame_cycles"] = 16_000_000
            candidate["fps_x1000"] = 15625
            candidate["fps"] = 15.625
    bad = build_closure(bad_source)
    if bad["status"] != "FAIL":
        print(json.dumps(bad, indent=2, ensure_ascii=False))
        print("X4_720P15_FPS_CLOSURE_SELF_TEST=FAIL")
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        write_outputs(good, out)
        if not (out / "summary.json").exists() or not (out / "summary.md").exists():
            print("X4_720P15_FPS_CLOSURE_SELF_TEST=FAIL")
            return 1
        bom_json = out / "bom_summary.json"
        bom_json.write_text(json.dumps(sample_source()), encoding="utf-8-sig")
        loaded = load_json(bom_json)
        if loaded.get("stage") != "packed2d_perf_scheduler":
            print("X4_720P15_FPS_CLOSURE_SELF_TEST=FAIL")
            return 1

    print("X4_720P15_FPS_CLOSURE_SELF_TEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run built-in tests")
    parser.add_argument("--source", type=Path, default=SRC, help="packed2d scheduler summary JSON")
    parser.add_argument("--out-dir", type=Path, default=OUT, help="closure evidence output directory")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if not args.source.exists():
        print(f"X4_720P15_FPS_CLOSURE_STATUS=FAIL")
        print(f"missing_source={args.source}")
        return 1

    data = load_json(args.source)
    closure = build_closure(data)
    write_outputs(closure, args.out_dir)
    print(f"X4_720P15_FPS_CLOSURE_STATUS={closure['status']}")
    print(f"X4_720P15_FPS_CLOSURE_MD={args.out_dir / 'summary.md'}")
    print(f"X4_720P15_FPS_CLOSURE_JSON={args.out_dir / 'summary.json'}")
    return 0 if closure["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
