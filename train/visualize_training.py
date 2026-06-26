"""Generate a lightweight HTML dashboard from TinySPAN training logs."""

from __future__ import annotations

import argparse
import csv
import html
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path


PROGRESS_RE = re.compile(
    r"epoch\s+(\d+)/(\d+):\s+(\d+)%\|.*?\|\s+(\d+)/(\d+)\s+\[(.*?)<([^,\]]+).*?loss=([0-9.]+),\s+lr=([0-9.eE+-]+)"
)
VAL_RE = re.compile(r"epoch=(\d+)\s+val_psnr=([0-9.]+)dB")


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    raw = path.read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff") or raw[:200].count(b"\x00") > 20:
        return raw.decode("utf-16", errors="ignore")
    return raw.decode("utf-8", errors="ignore")


def parse_log(text: str) -> tuple[list[dict], list[dict]]:
    progress = []
    vals = []
    for match in PROGRESS_RE.finditer(text.replace("\r", "\n")):
        progress.append(
            {
                "epoch": int(match.group(1)),
                "total_epochs": int(match.group(2)),
                "percent": int(match.group(3)),
                "step": int(match.group(4)),
                "total_steps": int(match.group(5)),
                "elapsed": match.group(6),
                "eta": match.group(7),
                "loss": float(match.group(8)),
                "lr": match.group(9),
            }
        )
    for match in VAL_RE.finditer(text):
        vals.append({"epoch": int(match.group(1)), "psnr": float(match.group(2))})
    return progress, vals


def python_training_pids() -> list[int]:
    try:
        result = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "Get-CimInstance Win32_Process | "
                "Where-Object { $_.Name -eq 'python.exe' -and $_.CommandLine -match 'train_reds_span.py' } | "
                "ForEach-Object { $_.ProcessId }",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception:
        return []
    pids = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.isdigit():
            pids.append(int(line))
    return pids


def checkpoints(run_dir: Path) -> list[dict]:
    rows = []
    for path in sorted(run_dir.glob("*.pt")):
        stat = path.stat()
        rows.append(
            {
                "name": path.name,
                "size_mb": stat.st_size / (1024 * 1024),
                "modified": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
    return rows


def read_metrics(run_dir: Path) -> list[dict]:
    path = run_dir / "metrics.csv"
    if not path.exists():
        return []
    rows = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            parsed = dict(row)
            for key in ["epoch", "train_loss", "val_psnr", "epoch_seconds", "steps_per_second", "gpu_max_mem_mb", "best_psnr"]:
                value = parsed.get(key, "")
                if value == "":
                    parsed[key] = None
                else:
                    parsed[key] = float(value)
            rows.append(parsed)
    return rows


def line_chart(points: list[tuple[float, float]], width: int = 900, height: int = 220) -> str:
    if not points:
        return '<div class="empty">暂无曲线数据</div>'
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    if max_x == min_x:
        max_x += 1
    if max_y == min_y:
        max_y += 1
    pad = 24

    def px(x: float) -> float:
        return pad + (x - min_x) / (max_x - min_x) * (width - 2 * pad)

    def py(y: float) -> float:
        return height - pad - (y - min_y) / (max_y - min_y) * (height - 2 * pad)

    path = " ".join(f"{px(x):.1f},{py(y):.1f}" for x, y in points)
    return f"""
<svg viewBox="0 0 {width} {height}" class="chart" role="img">
  <polyline points="{path}" fill="none" stroke="#2563eb" stroke-width="2.4" />
  <text x="{pad}" y="18" class="axis">min {min_y:.4f}</text>
  <text x="{width - 120}" y="18" class="axis">max {max_y:.4f}</text>
</svg>
"""


def render_dashboard(run_dir: Path, log_path: Path, output: Path) -> None:
    text = read_text(log_path)
    progress, vals = parse_log(text)
    metrics = read_metrics(run_dir)
    latest = progress[-1] if progress else None
    pids = python_training_pids()
    ckpts = checkpoints(run_dir)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if metrics:
        loss_points = [(m["epoch"], m["train_loss"]) for m in metrics if m.get("train_loss") is not None]
        psnr_points = [(m["epoch"], m["val_psnr"]) for m in metrics if m.get("val_psnr") is not None]
    else:
        loss_points = [(i + 1, p["loss"]) for i, p in enumerate(progress[-500:])]
        psnr_points = [(v["epoch"], v["psnr"]) for v in vals]

    if latest:
        epoch_text = f'{latest["epoch"]}/{latest["total_epochs"]}'
        step_text = f'{latest["step"]}/{latest["total_steps"]}'
        pct = latest["percent"]
        eta = latest["eta"]
        loss = f'{latest["loss"]:.5f}'
        lr = latest["lr"]
    else:
        epoch_text = step_text = eta = loss = lr = "暂无"
        pct = 0

    ckpt_rows = "\n".join(
        f"<tr><td>{html.escape(c['name'])}</td><td>{c['size_mb']:.2f}</td><td>{c['modified']}</td></tr>"
        for c in ckpts
    ) or '<tr><td colspan="3">暂无 checkpoint</td></tr>'

    if metrics:
        val_rows = "\n".join(
            "<tr>"
            f"<td>{int(m['epoch'])}</td>"
            f"<td>{'' if m.get('train_loss') is None else f'{m['train_loss']:.6f}'}</td>"
            f"<td>{'' if m.get('val_psnr') is None else f'{m['val_psnr']:.3f} dB'}</td>"
            f"<td>{'' if m.get('epoch_seconds') is None else f'{m['epoch_seconds']:.1f}s'}</td>"
            f"<td>{'' if m.get('steps_per_second') is None else f'{m['steps_per_second']:.3f}'}</td>"
            f"<td>{'' if m.get('gpu_max_mem_mb') is None else f'{m['gpu_max_mem_mb']:.1f}'}</td>"
            "</tr>"
            for m in metrics[-20:]
        ) or '<tr><td colspan="6">暂无结构化性能记录</td></tr>'
    else:
        val_rows = "\n".join(
        f"<tr><td>{v['epoch']}</td><td>{v['psnr']:.3f} dB</td></tr>" for v in vals[-20:]
        ) or '<tr><td colspan="2">暂无验证结果</td></tr>'
    metric_header = (
        "<tr><th>Epoch</th><th>Train Loss</th><th>Val PSNR</th><th>Epoch Time</th><th>Step/s</th><th>GPU MB</th></tr>"
        if metrics
        else "<tr><th>Epoch</th><th>PSNR</th></tr>"
    )

    status = "运行中" if pids else "未检测到训练进程"
    status_class = "ok" if pids else "bad"
    pids_text = ", ".join(str(pid) for pid in pids) if pids else "-"

    data_json = html.escape(json.dumps({"latest": latest, "val": vals[-20:], "pids": pids}, ensure_ascii=False))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="30" />
  <title>TinySPAN 训练仪表盘</title>
  <style>
    body {{ font-family: Segoe UI, Microsoft YaHei, Arial, sans-serif; margin: 28px; background: #f8fafc; color: #172033; }}
    h1 {{ margin: 0 0 8px; font-size: 28px; }}
    .sub {{ color: #64748b; margin-bottom: 22px; }}
    .grid {{ display: grid; grid-template-columns: repeat(4, minmax(160px, 1fr)); gap: 12px; margin-bottom: 18px; }}
    .card {{ background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px; box-shadow: 0 1px 2px rgba(15,23,42,0.05); }}
    .label {{ color: #64748b; font-size: 13px; margin-bottom: 6px; }}
    .value {{ font-size: 22px; font-weight: 650; }}
    .ok {{ color: #15803d; }}
    .bad {{ color: #b91c1c; }}
    .bar {{ height: 14px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }}
    .bar > div {{ height: 100%; background: #2563eb; width: {pct}%; }}
    .section {{ margin-top: 18px; }}
    .chart {{ width: 100%; height: 220px; background: white; border: 1px solid #e2e8f0; border-radius: 8px; }}
    .axis {{ fill: #64748b; font-size: 12px; }}
    table {{ width: 100%; border-collapse: collapse; background: white; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; }}
    th, td {{ padding: 10px 12px; border-bottom: 1px solid #e2e8f0; text-align: left; }}
    th {{ background: #f1f5f9; }}
    .empty {{ padding: 28px; background: white; border: 1px solid #e2e8f0; border-radius: 8px; color: #64748b; }}
    code {{ background: #e2e8f0; padding: 2px 5px; border-radius: 4px; }}
  </style>
</head>
<body>
  <h1>TinySPAN 训练仪表盘</h1>
  <div class="sub">自动每 30 秒刷新。生成时间：{now}。日志：<code>{html.escape(str(log_path))}</code></div>
  <div class="grid">
    <div class="card"><div class="label">训练状态</div><div class="value {status_class}">{status}</div></div>
    <div class="card"><div class="label">PID</div><div class="value">{html.escape(pids_text)}</div></div>
    <div class="card"><div class="label">Epoch</div><div class="value">{epoch_text}</div></div>
    <div class="card"><div class="label">Step</div><div class="value">{step_text}</div></div>
    <div class="card"><div class="label">当前 Loss</div><div class="value">{loss}</div></div>
    <div class="card"><div class="label">Learning Rate</div><div class="value">{lr}</div></div>
    <div class="card"><div class="label">ETA</div><div class="value">{html.escape(eta)}</div></div>
    <div class="card"><div class="label">当前 Epoch 进度</div><div class="value">{pct}%</div></div>
  </div>
  <div class="bar"><div></div></div>

  <div class="section">
    <h2>Loss 曲线（最近 500 个记录点）</h2>
    {line_chart(loss_points)}
  </div>
  <div class="section">
    <h2>性能记录</h2>
    {line_chart(psnr_points)}
    <table><thead>{metric_header}</thead><tbody>{val_rows}</tbody></table>
  </div>
  <div class="section">
    <h2>Checkpoint</h2>
    <table><thead><tr><th>文件</th><th>大小 MB</th><th>更新时间</th></tr></thead><tbody>{ckpt_rows}</tbody></table>
  </div>
  <script id="training-data" type="application/json">{data_json}</script>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", default="runs/tinyspan_reds_x4_full")
    parser.add_argument("--log", default=None)
    parser.add_argument("--output", default=None)
    args = parser.parse_args()

    run_dir = Path(args.run_dir)
    log_path = Path(args.log) if args.log else run_dir / "train_stdout.log"
    output = Path(args.output) if args.output else run_dir / "dashboard.html"
    render_dashboard(run_dir, log_path, output)
    print(output)


if __name__ == "__main__":
    main()
