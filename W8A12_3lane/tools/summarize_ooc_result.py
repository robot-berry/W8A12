#!/usr/bin/env python3
"""Summarize an OOC synthesis result and enforce XC7Z045 limits."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

DEFAULT_LIMITS = {
    "lut": 218600,
    "ff": 437200,
    "bram": 545,
    "dsp": 900,
    "uram": 0,
}

METRIC_PATTERNS = {
    "lut": (r"\b(?:Slice\s+)?LUTs?\b", r"\bCLB\s+LUTs\b"),
    "ff": (r"\b(?:Slice\s+)?Registers\b", r"\bCLB\s+Registers\b", r"\bFFs?\b"),
    "bram": (r"\bBlock\s+RAM\s+Tile\b", r"\bBRAM(?:_18K|_36K)?\b"),
    "dsp": (r"\bDSPs?\b", r"\bDSP48E[12]?\b"),
    "uram": (r"\bURAM\b", r"\bUltraRAM\b"),
}


def parse_timing_pass(path: Path) -> dict:
    if not path.exists():
        return {"exists": False, "pass": False, "wns_ns": None, "whs_ns": None}
    text = path.read_text(encoding="utf-8", errors="ignore")
    summary = parse_design_timing_summary(text)
    wns = summary.get("wns_ns")
    whs = summary.get("whs_ns")
    if wns is None:
        wns = parse_first_float(text, r"\bWNS\b.*?(-?\d+(?:\.\d+)?)")
    if whs is None:
        whs = parse_first_float(text, r"\bWHS\b.*?(-?\d+(?:\.\d+)?)")
    return {
        "exists": True,
        "pass": (wns is not None and whs is not None and wns >= 0 and whs >= 0),
        "wns_ns": wns,
        "whs_ns": whs,
    }


def parse_design_timing_summary(text: str) -> dict[str, float | None]:
    """Parse the first numeric row in Vivado's Design Timing Summary table."""
    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if "WNS(ns)" not in line or "WHS(ns)" not in line:
            continue
        for candidate in lines[idx + 1 : idx + 8]:
            stripped = candidate.strip()
            if not stripped or set(stripped) <= {"-", " "}:
                continue
            fields = stripped.split()
            if len(fields) < 5:
                continue
            return {
                "wns_ns": float(fields[0]) if fields[0] != "NA" else None,
                "whs_ns": float(fields[4]) if fields[4] != "NA" else None,
            }
    return {"wns_ns": None, "whs_ns": None}


def parse_first_float(text: str, pattern: str) -> float | None:
    match = re.search(pattern, text, re.S)
    if not match:
        return None
    return float(match.group(1))


def parse_vivado_table_rows(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not (stripped.startswith("|") and stripped.endswith("|")):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) >= 2 and not all(set(cell) <= {"-", " "} for cell in cells):
            rows.append(cells)
    return rows


def first_number(cells: list[str]) -> float | None:
    for cell in cells[1:]:
        normalized = cell.replace(",", "")
        match = re.search(r"-?\d+(?:\.\d+)?", normalized)
        if match:
            return float(match.group(0))
    return None


def row_matches_metric(row_name: str, metric: str) -> bool:
    return any(re.search(pattern, row_name, re.I) for pattern in METRIC_PATTERNS[metric])


def parse_resource_metrics(text: str) -> dict[str, float | None]:
    metrics: dict[str, float | None] = {name: None for name in DEFAULT_LIMITS}
    rows = parse_vivado_table_rows(text)
    header: list[str] | None = None
    for metric in DEFAULT_LIMITS:
        for row in rows:
            if row_matches_metric(row[0], metric):
                value = first_number(row)
                if value is not None:
                    metrics[metric] = value
                    break

    # Hierarchical utilization reports usually use:
    # | Instance | Module | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs |
    # | RAMB36 | RAMB18 | URAM | DSP Blocks |
    for row in rows:
        lowered = [cell.lower() for cell in row]
        if "instance" in lowered and "module" in lowered:
            header = row
            continue
        if header is None:
            continue
        joined = " ".join(row[:2]).lower()
        if "top" not in joined and "w8a12" not in joined and "span" not in joined:
            continue

        by_name: dict[str, float] = {}
        for name, cell in zip(header, row):
            match = re.search(r"-?\d+(?:\.\d+)?", cell.replace(",", ""))
            if match:
                by_name[name.strip().lower()] = float(match.group(0))

        if metrics.get("lut") is None:
            metrics["lut"] = first_present(by_name, "total luts", "clb luts")
        if metrics.get("ff") is None:
            metrics["ff"] = first_present(by_name, "ffs", "clb registers")
        if metrics.get("bram") is None:
            ramb36 = by_name.get("ramb36", 0.0)
            ramb18 = by_name.get("ramb18", 0.0)
            bram_tile = by_name.get("block ram tile")
            metrics["bram"] = bram_tile if bram_tile is not None else ramb36 + (ramb18 * 0.5)
        if metrics.get("dsp") is None:
            metrics["dsp"] = first_present(by_name, "dsp blocks", "dsps")
        if metrics.get("uram") is None:
            metrics["uram"] = by_name.get("uram")
        if any(metrics.get(key) is not None for key in ("lut", "ff", "bram", "dsp")):
            break

    if metrics["uram"] is None:
        metrics["uram"] = 0.0
    return metrics


def first_present(values: dict[str, float], *names: str) -> float | None:
    for name in names:
        if name in values:
            return values[name]
    return None


def resource_summary(util: Path) -> dict:
    text = util.read_text(encoding="utf-8", errors="ignore")
    limits = dict(DEFAULT_LIMITS)
    metrics = parse_resource_metrics(text)
    checks = []
    ok = True
    for name, limit in limits.items():
        value = metrics[name]
        passed = value is not None and value <= limit
        checks.append({"metric": name, "value": value, "limit": limit, "pass": passed})
        ok = ok and passed
    return {"pass": ok, "metrics": metrics, "limits": limits, "checks": checks}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--report-dir", required=True, type=Path)
    parser.add_argument("--utilization", default="utilization_ooc.rpt")
    parser.add_argument("--timing", default="timing_ooc.rpt")
    args = parser.parse_args()

    report_dir = args.report_dir
    util = report_dir / args.utilization
    timing = report_dir / args.timing
    out_json = report_dir / "ooc_summary.json"
    out_md = report_dir / "ooc_summary.md"

    if not util.exists():
        data = {"status": "MISSING", "tag": args.tag, "error": f"missing {util}"}
        report_dir.mkdir(parents=True, exist_ok=True)
        out_json.write_text(json.dumps(data, indent=2), encoding="utf-8")
        out_md.write_text(f"# OOC Summary: {args.tag}\n\nStatus: MISSING\n\nMissing `{util}`.\n", encoding="utf-8")
        return 1

    resources = resource_summary(util)
    timing_summary = parse_timing_pass(timing)
    ok = resources["pass"] and timing_summary["pass"]
    data = {
        "status": "PASS" if ok else "FAIL",
        "tag": args.tag,
        "utilization_report": str(util),
        "timing_report": str(timing),
        "resource_gate": resources,
        "timing": timing_summary,
    }
    out_json.write_text(json.dumps(data, indent=2), encoding="utf-8")
    out_md.write_text(render_md(data), encoding="utf-8")
    return 0 if ok else 1


def render_md(data: dict) -> str:
    lines = [
        f"# OOC Summary: {data['tag']}",
        "",
        f"Status: {data['status']}",
        "",
        "| Resource | Used | Limit | Result |",
        "| --- | ---: | ---: | --- |",
    ]
    for check in data["resource_gate"]["checks"]:
        used = "MISSING" if check["value"] is None else check["value"]
        lines.append(f"| {check['metric']} | {used} | {check['limit']} | {'PASS' if check['pass'] else 'FAIL'} |")
    timing = data["timing"]
    lines.extend(
        [
            "",
            "## Timing",
            "",
            f"- WNS ns: {timing['wns_ns']}",
            f"- WHS ns: {timing['whs_ns']}",
            f"- timing pass: {timing['pass']}",
            "",
        ]
    )
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
