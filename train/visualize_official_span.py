"""Generate an HTML dashboard for official SPAN/BasicSR training logs."""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path


TRAIN_RE = re.compile(
    r"\[epoch:\s*(?P<epoch>\d+), iter:\s*(?P<iter>[\d,]+), lr:\((?P<lr>[^,\)]+)"
    r".*?\[eta:\s*(?P<eta>[^\]]+)\].*?l_pix:\s*(?P<loss>[0-9.eE+-]+)",
    re.S,
)
PSNR_RE = re.compile(r"#\s*psnr:\s*(?P<psnr>[0-9.]+)[^\n]*(?:@\s*(?P<iter>[\d,]+)\s*iter)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", nargs="+", default=["runs/official_span_logs/train_stdout.log"])
    parser.add_argument("--output", default="runs/official_span/dashboard.html")
    parser.add_argument("--title", default="Official SPAN x4 Training")
    parser.add_argument("--total-iter", type=int, default=300000)
    parser.add_argument("--refresh", type=int, default=30)
    return parser.parse_args()


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    data = path.read_bytes()
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        return data.decode("utf-16", errors="ignore")
    if data.startswith(b"\xef\xbb\xbf"):
        return data.decode("utf-8-sig", errors="ignore")
    for encoding in ("utf-8", "utf-16", "gbk"):
        try:
            return data.decode(encoding, errors="strict")
        except UnicodeError:
            continue
    return data.decode(errors="ignore")


def parse_log(text: str) -> tuple[list[dict], list[dict]]:
    train_rows: list[dict] = []
    psnr_rows: list[dict] = []
    for match in TRAIN_RE.finditer(text.replace("\r", "")):
        train_rows.append(
            {
                "epoch": int(match.group("epoch")),
                "iter": int(match.group("iter").replace(",", "")),
                "lr": float(match.group("lr")),
                "eta": match.group("eta").strip(),
                "loss": float(match.group("loss")),
            }
        )
    for match in PSNR_RE.finditer(text):
        psnr_rows.append(
            {
                "iter": int(match.group("iter").replace(",", "")) if match.group("iter") else None,
                "psnr": float(match.group("psnr")),
            }
        )
    return train_rows, psnr_rows


def line_points(rows: list[dict], x_key: str, y_key: str) -> str:
    if not rows:
        return ""
    max_x = max(float(row[x_key] or 0) for row in rows) or 1.0
    vals = [float(row[y_key]) for row in rows]
    min_y = min(vals)
    max_y = max(vals)
    span_y = max(max_y - min_y, 1e-12)
    points = []
    for row in rows:
        x = float(row[x_key] or 0) / max_x * 1000
        y = 260 - ((float(row[y_key]) - min_y) / span_y * 220 + 20)
        points.append(f"{x:.2f},{y:.2f}")
    return " ".join(points)


def render(
    output: Path,
    title: str,
    log_paths: list[Path],
    train_rows: list[dict],
    psnr_rows: list[dict],
    total_iter: int,
    refresh: int,
) -> None:
    latest = train_rows[-1] if train_rows else {}
    progress = (latest.get("iter", 0) / total_iter * 100.0) if latest else 0.0
    best_psnr = max((row["psnr"] for row in psnr_rows), default=None)
    loss_points = line_points(train_rows[-300:], "iter", "loss")
    psnr_plot_rows = [row for row in psnr_rows if row["iter"] is not None]
    psnr_points = line_points(psnr_plot_rows[-100:], "iter", "psnr")
    rows_json = html.escape(json.dumps(train_rows[-20:], ensure_ascii=False, indent=2))
    psnr_json = html.escape(json.dumps(psnr_rows[-20:], ensure_ascii=False, indent=2))

    html_text = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="{refresh}">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <style>
    :root {{ color-scheme: light; --ink:#1b2430; --muted:#667085; --line:#d7dde8; --panel:#f7f9fc; --accent:#1f7a8c; --warm:#a45c40; }}
    body {{ margin:0; font-family:"Segoe UI", Arial, sans-serif; color:var(--ink); background:#eef2f7; }}
    main {{ max-width:1180px; margin:0 auto; padding:28px; }}
    h1 {{ margin:0 0 8px; font-size:28px; font-weight:700; }}
    h2 {{ margin:20px 0 10px; font-size:18px; }}
    .sub {{ color:var(--muted); margin-bottom:22px; }}
    .grid {{ display:grid; grid-template-columns:repeat(4, minmax(0, 1fr)); gap:14px; }}
    .card {{ background:white; border:1px solid var(--line); border-radius:8px; padding:16px; box-shadow:0 1px 2px rgba(16,24,40,.04); }}
    .label {{ color:var(--muted); font-size:13px; }}
    .value {{ font-size:25px; font-weight:700; margin-top:8px; }}
    .bar {{ height:12px; background:#dfe6ef; border-radius:999px; overflow:hidden; margin-top:12px; }}
    .fill {{ height:100%; width:{progress:.4f}%; background:var(--accent); }}
    .charts {{ display:grid; grid-template-columns:1fr 1fr; gap:14px; margin-top:14px; }}
    svg {{ width:100%; height:280px; background:white; border:1px solid var(--line); border-radius:8px; }}
    polyline {{ fill:none; stroke-width:3; stroke-linejoin:round; stroke-linecap:round; }}
    .loss {{ stroke:var(--accent); }}
    .psnr {{ stroke:var(--warm); }}
    pre {{ white-space:pre-wrap; overflow:auto; background:#111827; color:#e5e7eb; padding:14px; border-radius:8px; max-height:260px; }}
    @media (max-width:820px) {{ .grid, .charts {{ grid-template-columns:1fr; }} main {{ padding:18px; }} }}
  </style>
</head>
<body>
<main>
  <h1>{html.escape(title)}</h1>
  <div class="sub">日志：{html.escape(", ".join(str(p) for p in log_paths))}，页面每 {refresh} 秒自动刷新。</div>
  <section class="grid">
    <div class="card"><div class="label">当前 Iter</div><div class="value">{latest.get("iter", "NA")}</div><div class="bar"><div class="fill"></div></div><div class="label">{progress:.2f}% / {total_iter}</div></div>
    <div class="card"><div class="label">Epoch</div><div class="value">{latest.get("epoch", "NA")}</div></div>
    <div class="card"><div class="label">L1 Loss</div><div class="value">{latest.get("loss", "NA")}</div></div>
    <div class="card"><div class="label">Best PSNR</div><div class="value">{f"{best_psnr:.4f} dB" if best_psnr is not None else "等待验证"}</div></div>
  </section>
  <section class="charts">
    <svg viewBox="0 0 1000 280" role="img" aria-label="loss curve"><polyline class="loss" points="{loss_points}"/></svg>
    <svg viewBox="0 0 1000 280" role="img" aria-label="psnr curve"><polyline class="psnr" points="{psnr_points}"/></svg>
  </section>
  <h2>最近训练记录</h2>
  <pre id="rows">{rows_json}</pre>
  <h2>最近 PSNR 记录</h2>
  <pre id="psnr">{psnr_json}</pre>
</main>
</body>
</html>
"""
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html_text, encoding="utf-8")
    print(output)


def main() -> None:
    args = parse_args()
    log_paths = [Path(path) for path in args.log]
    text = "\n".join(read_text(path) for path in log_paths)
    train_rows, psnr_rows = parse_log(text)
    render(Path(args.output), args.title, log_paths, train_rows, psnr_rows, args.total_iter, args.refresh)


if __name__ == "__main__":
    main()
