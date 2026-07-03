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
MANAGED_EXPORT_ROOTS = ("W8A12_3lane", "tools", "scripts", "rtl", "external")
ROOT_TOOL_FILES = (
    "tools/calibrate_span_activation_scales.py",
    "tools/export_span_w8a12_quant_plan.py",
    "tools/export_span_quant_plan_to_rtl.py",
    "tools/export_span_w8a12_postprocess_to_rtl.py",
    "tools/check_span_w8a12_rtl_export.py",
    "tools/run_span_ptq_reference.py",
)
ROOT_STAGEHASH_SCRIPT_FILES = (
    "scripts/run_w8a12_board_recovery_preflight.ps1",
    "scripts/run_w8a12_stagehash_true2x2_acceptance.ps1",
    "scripts/probe_vivado_hw_targets.ps1",
    "scripts/probe_vivado_hw_targets.tcl",
    "scripts/check_usb_jtag_devices.ps1",
    "scripts/cleanup_vivado_processes.ps1",
    "scripts/run_xsct_psu_init_only.ps1",
    "scripts/run_xsct_psu_init_only.tcl",
    "scripts/run_jtag_w8a12_tile_writer_smoke.ps1",
    "scripts/jtag_rgb_transfer.tcl",
    "scripts/compare_jtag_w8a12_span_output.ps1",
    "scripts/run_read_jtag_w8a12_tile_writer_regs.ps1",
    "scripts/read_jtag_w8a12_tile_writer_regs.tcl",
    "scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.ps1",
    "scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.tcl",
    "scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl",
)
ROOT_RTL_FILES = (
    "rtl/board/sr_tile_scheduler.v",
    "rtl/board/sr_tile_halo_fetch_stream_shell.v",
    "rtl/board/sr_tile_rgb_buffer_streamer.v",
    "rtl/board/sr_stream_cropper.v",
    "rtl/board/sr_tile_output_writer.v",
    "rtl/board/sr_feature_tile_buffer_streamer.v",
    "rtl/board/sr_tile_halo_fetch_w8a12_conv1_shell.v",
    "rtl/board/sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v",
    "rtl/board/sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v",
    "rtl/board/sr_tile_halo_fetch_w8a12_front_tail_writer_shell.v",
    "rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v",
    "rtl/board/sr_w8a12_block_group_single_out_tile_engine.v",
    "rtl/board/sr_w8a12_block_group_single_out_buffered_tile_engine.v",
    "rtl/board/sr_w8a12_block_group_attention_residual_tile_engine.v",
    "rtl/board/sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v",
    "rtl/span/span_w8a12_generated_select.vh",
    "rtl/span/span_rgb_line_window3x3.v",
    "rtl/span/span_w8a12_feature_line_window3x3.v",
    "rtl/span/span_w8a12_rgb_normalize.v",
    "rtl/span/span_w8a12_rgb_window_normalize.v",
    "rtl/span/span_w8a12_weight_group_rom.v",
    "rtl/span/span_w8a12_requant_pipe.v",
    "rtl/span/span_w8a12_parallel_mac_tile.v",
    "rtl/span/span_w8a12_parallel_group_accum_engine.v",
    "rtl/span/span_w8a12_parallel_conv_vector_streamed_weights.v",
    "rtl/span/span_w8a12_conv1_streamed_frontend.v",
    "rtl/span/span_w8a12_requant.v",
    "rtl/span/span_w8a12_block_group_const_bank.v",
    "rtl/span/span_w8a12_block_group_unary_lut.v",
    "rtl/span/span_w8a12_block_group_attention.v",
    "rtl/span/span_w8a12_block_group_single_out_conv_layer.v",
    "rtl/span/span_w8a12_block_group_single_out_conv_act_kernel.v",
    "rtl/span/span_w8a12_feature_conv_streamed_frontend.v",
    "rtl/span/span_w8a12_conv2_streamed_frontend.v",
    "rtl/span/span_w8a12_conv1x1_streamed_frontend.v",
    "rtl/span/span_w8a12_conv_cat_scale_concat.v",
    "rtl/span/span_w8a12_upsampler0_streamed_frontend.v",
    "rtl/span/span_w8a12_pixelshuffle_x4_streamed_rgb.v",
    "rtl/span/span_w8a12_upsampler0_pixelshuffle_streamed_rgb.v",
    "rtl/span/span_w8a12_tail_streamed_rgb.v",
)
ROOT_RTL_DIRS = ("rtl/generated/reds_span_x4_f48_w8a12",)
FILESYSTEM_DIRS = ("external/SPAN/basicsr", *ROOT_RTL_DIRS)
ADDITIONAL_PATHS = (*ROOT_TOOL_FILES, *ROOT_STAGEHASH_SCRIPT_FILES, *ROOT_RTL_FILES, *FILESYSTEM_DIRS)

FORBIDDEN_RE = re.compile(
    r"((^|/)~\$|"
    r"\.(npy|npz|pth|pt|pid|zip|dcp|bit|xsa|jou|log|wdb)$|"
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


def safe_clean_payload_dir(export_root: Path) -> None:
    """Refresh managed upload payload roots and preserve an existing local .git repo."""
    resolved = export_root.resolve()
    allowed = (BASE / "output" / "github_upload").resolve()
    if not str(resolved).startswith(str(allowed)):
        raise RuntimeError(f"refusing to clean outside {allowed}: {resolved}")
    resolved.mkdir(parents=True, exist_ok=True)
    for name in MANAGED_EXPORT_ROOTS:
        payload = (resolved / name).resolve()
        if not str(payload).startswith(str(resolved)):
            raise RuntimeError(f"refusing to clean payload outside {resolved}: {payload}")
        if payload.exists():
            shutil.rmtree(payload)
    (resolved / "W8A12_3lane").mkdir(parents=True, exist_ok=True)


def collect_git_paths(pathspecs: list[str]) -> list[str]:
    code, output = run_git(["ls-files", "--others", "--cached", "--exclude-standard", "--", *pathspecs])
    if code != 0:
        raise RuntimeError(output)
    return output.splitlines()


def collect_candidates() -> list[str]:
    output_lines = collect_git_paths(["W8A12_3lane", *ADDITIONAL_PATHS])
    paths = []
    for line in output_lines:
        rel = line.strip().replace("\\", "/")
        if not rel:
            continue
        if rel.startswith(SKIP_PREFIXES):
            continue
        if FORBIDDEN_RE.search(rel):
            continue
        src = ROOT / rel
        if src.is_file():
            paths.append(rel)
    for directory in FILESYSTEM_DIRS:
        src_dir = ROOT / directory
        if not src_dir.is_dir():
            continue
        for src in src_dir.rglob("*"):
            if not src.is_file():
                continue
            rel = src.relative_to(ROOT).as_posix()
            if FORBIDDEN_RE.search(rel):
                continue
            if "__pycache__" in src.parts:
                continue
            paths.append(rel)
    return sorted(set(paths))


def main() -> int:
    export_root = DEFAULT_EXPORT_ROOT
    safe_clean_payload_dir(export_root)

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
        "included_roots": ["W8A12_3lane/", "tools/*.py required exporters", "scripts/* required JTAG/stage-hash helpers", "explicit W8A12 rtl/board and rtl/span files used by the Vivado Tcl", "rtl/generated/reds_span_x4_f48_w8a12/", "external/SPAN/basicsr/"],
        "note": "This clean tree is for creating or updating a separate upload commit without pushing the current repository history. Existing .git metadata under the export root is preserved.",
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
        "git add W8A12_3lane tools scripts external/SPAN/basicsr",
        'git commit -m "Add W8A12 3-lane contest delivery draft"',
        "git push origin HEAD:training-software",
        "```",
        "",
        "This export includes `W8A12_3lane/` plus the root model/export tools, JTAG/stage-hash helper scripts, explicit W8A12 RTL files needed by the board bitstream/simulation Tcl, and `external/SPAN/basicsr/` source required by the submission scope policy. It preserves any existing local `.git/` metadata under the export root and does not include forbidden generated artifacts.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
