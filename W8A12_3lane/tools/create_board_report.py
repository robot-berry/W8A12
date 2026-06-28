#!/usr/bin/env python3
"""Create a W8A12_3lane board report skeleton.

The generated report is deliberately PENDING until real board evidence is filled
in. Delivery audit requires PASS, so a skeleton cannot accidentally satisfy a
board gate.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True, help="Report tag, e.g. a5_32x32")
    parser.add_argument("--scale", type=int, required=True, choices=(2, 4))
    parser.add_argument("--lr-width", type=int, required=True)
    parser.add_argument("--lr-height", type=int, required=True)
    parser.add_argument("--tile-width", type=int, default=32)
    parser.add_argument("--tile-height", type=int, default=32)
    parser.add_argument("--halo", type=int, default=21)
    parser.add_argument("--target-fps", type=float, default=15.0)
    parser.add_argument("--input-source", default="SD/DDR frame")
    parser.add_argument("--tiling-mode", default="tile+halo crop-stitch")
    parser.add_argument("--status", default="PENDING", choices=("PENDING", "PASS", "FAIL"))
    args = parser.parse_args()

    out = ROOT / "W8A12_3lane" / "evidence" / "board_reports" / args.tag
    out.mkdir(parents=True, exist_ok=True)
    hr_width = args.lr_width * args.scale
    hr_height = args.lr_height * args.scale
    data = {
        "status": args.status,
        "tag": args.tag,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "scale": args.scale,
        "lr_size": [args.lr_width, args.lr_height],
        "hr_size": [hr_width, hr_height],
        "input_pipeline": {
            "source": args.input_source,
            "downsample_on_ps": True,
            "tiling_mode": args.tiling_mode,
            "tile_size": [args.tile_width, args.tile_height],
            "halo": args.halo,
            "tile_count_x": (args.lr_width + args.tile_width - 1) // args.tile_width,
            "tile_count_y": (args.lr_height + args.tile_height - 1) // args.tile_height,
            "stitch_output": True,
        },
        "board_part": "xczu19eg-ffvc1760-2-i",
        "resource_target": "XC7Z045/ZC706 equivalent",
        "resource_gate": {
            "lut_limit": 218600,
            "ff_limit": 437200,
            "bram_tile_limit": 545,
            "dsp_limit": 900,
            "lut_used": None,
            "ff_used": None,
            "bram_tile_used": None,
            "dsp_used": None,
            "status": "PENDING",
        },
        "timing": {"wns_ns": None, "whs_ns": None, "status": "PENDING"},
        "correctness": {
            "frame_done": None,
            "error": None,
            "output_pixels": hr_width * hr_height,
            "expected_output_pixels": hr_width * hr_height,
            "mismatch": None,
            "bit_exact_to_fixed_reference": None,
        },
        "quality": {"psnr_db": None, "ssim": None},
        "performance": {"clock_mhz": None, "latency_ms": None, "fps": None, "target_fps": args.target_fps, "power_w": None},
        "files": {
            "bitstream": None,
            "utilization_report": None,
            "timing_report": None,
            "power_report": None,
            "resource_gate": None,
            "fixed_reference": None,
            "board_output": None,
            "preview": None,
        },
    }
    (out / "summary.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (out / "summary.md").write_text(render_md(data), encoding="utf-8")
    return 0


def render_md(data: dict) -> str:
    return "\n".join(
        [
            f"# Board Report: {data['tag']}",
            "",
            f"Status: {data['status']}",
            "",
            "| Item | Value |",
            "| --- | --- |",
            f"| scale | x{data['scale']} |",
            f"| LR size | {data['lr_size'][0]}x{data['lr_size'][1]} |",
            f"| HR size | {data['hr_size'][0]}x{data['hr_size'][1]} |",
            f"| input source | {data.get('input_pipeline', {}).get('source')} |",
            f"| tiling mode | {data.get('input_pipeline', {}).get('tiling_mode')} |",
            f"| tile size | {data.get('input_pipeline', {}).get('tile_size')} |",
            f"| halo | {data.get('input_pipeline', {}).get('halo')} |",
            f"| tile count | {data.get('input_pipeline', {}).get('tile_count_x')}x{data.get('input_pipeline', {}).get('tile_count_y')} |",
            f"| board part | {data['board_part']} |",
            f"| resource target | {data['resource_target']} |",
            "",
            "## Correctness",
            "",
            "| Item | Value |",
            "| --- | --- |",
            f"| FRAME_DONE | {data['correctness']['frame_done']} |",
            f"| ERROR | {data['correctness']['error']} |",
            f"| output_pixels | {data['correctness']['output_pixels']} |",
            f"| mismatch | {data['correctness']['mismatch']} |",
            f"| bit_exact_to_fixed_reference | {data['correctness']['bit_exact_to_fixed_reference']} |",
            "",
            "## Resource / Timing / Power",
            "",
            "| Item | Value |",
            "| --- | --- |",
            f"| LUT | {data['resource_gate'].get('lut_used')} / {data['resource_gate']['lut_limit']} |",
            f"| FF/REG | {data['resource_gate'].get('ff_used')} / {data['resource_gate']['ff_limit']} |",
            f"| BRAM Tile | {data['resource_gate'].get('bram_tile_used')} / {data['resource_gate']['bram_tile_limit']} |",
            f"| DSP | {data['resource_gate'].get('dsp_used')} / {data['resource_gate']['dsp_limit']} |",
            f"| resource_gate | {data['resource_gate']['status']} |",
            f"| WNS | {data.get('timing', {}).get('wns_ns')} |",
            f"| WHS | {data.get('timing', {}).get('whs_ns')} |",
            f"| timing | {data.get('timing', {}).get('status')} |",
            f"| clock_mhz | {data['performance']['clock_mhz']} |",
            f"| latency_ms | {data['performance']['latency_ms']} |",
            f"| fps | {data['performance']['fps']} |",
            f"| target_fps | {data['performance'].get('target_fps')} |",
            f"| power_w | {data['performance']['power_w']} |",
            "",
            "## Quality",
            "",
            "| Item | Value |",
            "| --- | --- |",
            f"| psnr_db | {data['quality']['psnr_db']} |",
            f"| ssim | {data['quality']['ssim']} |",
            "",
            "该文件是上板汇报骨架；只有真实跑板并把状态改为 PASS 后，才能满足交付审计。",
            "",
        ]
    )


if __name__ == "__main__":
    raise SystemExit(main())
