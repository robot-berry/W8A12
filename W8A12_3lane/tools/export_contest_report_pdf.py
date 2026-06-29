#!/usr/bin/env python3
"""Export the contest submission Markdown report to a verified PDF artifact."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import textwrap
from pathlib import Path
from typing import Any
from xml.sax.saxutils import escape

from PIL import Image, ImageStat
from pypdf import PdfReader
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
SOURCE = BASE / "docs" / "contest_submission_report.md"
PDF_OUT = BASE / "output" / "pdf" / "W8A12_3lane_contest_submission_report.pdf"
EVIDENCE_OUT = BASE / "evidence" / "report_pdf"
RENDER_OUT = EVIDENCE_OUT / "rendered"
POPPLER_DIR = Path.home() / ".cache" / "codex-runtimes" / "codex-primary-runtime" / "dependencies" / "native" / "poppler" / "Library" / "bin"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--pdf-out", type=Path, default=PDF_OUT)
    parser.add_argument("--evidence-out", type=Path, default=EVIDENCE_OUT)
    parser.add_argument("--render-pages", type=int, default=99)
    return parser.parse_args()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def register_fonts() -> dict[str, str]:
    candidates = [
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("C:/Windows/Fonts/NotoSansSC-VF.ttf"),
        Path("C:/Windows/Fonts/Deng.ttf"),
    ]
    font_path = next((path for path in candidates if path.exists()), None)
    if font_path is None:
        return {"regular": "Helvetica", "bold": "Helvetica-Bold", "font_path": ""}
    pdfmetrics.registerFont(TTFont("ContestCJK", str(font_path)))
    return {"regular": "ContestCJK", "bold": "ContestCJK", "font_path": str(font_path)}


def inline(text: str, regular_font: str = "ContestCJK") -> str:
    chunks = re.split(r"(`[^`]+`)", text)
    out: list[str] = []
    for chunk in chunks:
        if not chunk:
            continue
        if chunk.startswith("`") and chunk.endswith("`"):
            out.append(f'<font name="Courier">{escape(chunk[1:-1])}</font>')
        else:
            out.append(escape(chunk))
    return "".join(out).replace("  ", " ")


def split_table_row(line: str) -> list[str]:
    text = line.strip().strip("|")
    return [cell.strip() for cell in text.split("|")]


def is_separator_row(line: str) -> bool:
    cells = split_table_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell.strip()) for cell in cells)


def flush_paragraph(buffer: list[str], story: list[Any], style: ParagraphStyle) -> None:
    if not buffer:
        return
    text = " ".join(part.strip() for part in buffer if part.strip())
    if text:
        story.append(Paragraph(inline(text), style))
        story.append(Spacer(1, 3 * mm))
    buffer.clear()


def build_styles(fonts: dict[str, str]) -> dict[str, ParagraphStyle]:
    sample = getSampleStyleSheet()
    regular = fonts["regular"]
    bold = fonts["bold"]
    return {
        "title": ParagraphStyle(
            "TitleCN",
            parent=sample["Title"],
            fontName=bold,
            fontSize=20,
            leading=26,
            alignment=TA_CENTER,
            spaceAfter=8 * mm,
        ),
        "h2": ParagraphStyle(
            "H2CN",
            parent=sample["Heading2"],
            fontName=bold,
            fontSize=13.5,
            leading=18,
            textColor=colors.HexColor("#1f4e79"),
            spaceBefore=4 * mm,
            spaceAfter=2 * mm,
        ),
        "h3": ParagraphStyle(
            "H3CN",
            parent=sample["Heading3"],
            fontName=bold,
            fontSize=11.5,
            leading=15,
            textColor=colors.HexColor("#333333"),
            spaceBefore=3 * mm,
            spaceAfter=1.5 * mm,
        ),
        "body": ParagraphStyle(
            "BodyCN",
            parent=sample["BodyText"],
            fontName=regular,
            fontSize=9.2,
            leading=14.2,
            alignment=TA_LEFT,
            spaceAfter=2 * mm,
        ),
        "bullet": ParagraphStyle(
            "BulletCN",
            parent=sample["BodyText"],
            fontName=regular,
            fontSize=9,
            leading=13.5,
            leftIndent=6 * mm,
            firstLineIndent=-3.5 * mm,
            spaceAfter=1.2 * mm,
        ),
        "table": ParagraphStyle(
            "TableCN",
            parent=sample["BodyText"],
            fontName=regular,
            fontSize=7.2,
            leading=9.2,
        ),
        "code": ParagraphStyle(
            "CodeCN",
            parent=sample["Code"],
            fontName="Courier",
            fontSize=7.4,
            leading=9,
            backColor=colors.HexColor("#f5f5f5"),
            borderColor=colors.HexColor("#dddddd"),
            borderWidth=0.25,
            borderPadding=3,
        ),
        "footer": ParagraphStyle(
            "FooterCN",
            parent=sample["BodyText"],
            fontName=regular,
            fontSize=7.5,
            leading=9,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#666666"),
        ),
    }


def add_table(rows: list[list[str]], story: list[Any], styles: dict[str, ParagraphStyle], doc_width: float) -> None:
    if not rows:
        return
    col_count = max(len(row) for row in rows)
    normalized = [row + [""] * (col_count - len(row)) for row in rows]
    table_data = [
        [Paragraph(inline(cell), styles["table"]) for cell in row]
        for row in normalized
    ]
    col_width = doc_width / col_count
    table = Table(table_data, colWidths=[col_width] * col_count, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eaf2f8")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#17365d")),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#b7c9d6")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 3 * mm))


def add_code_block(lines: list[str], story: list[Any], styles: dict[str, ParagraphStyle]) -> None:
    wrapped: list[str] = []
    for line in lines:
        parts = textwrap.wrap(line, width=96, replace_whitespace=False, drop_whitespace=False) or [""]
        wrapped.extend(parts)
    story.append(Preformatted("\n".join(wrapped), styles["code"], maxLineLength=96))
    story.append(Spacer(1, 3 * mm))


def markdown_to_story(markdown: str, styles: dict[str, ParagraphStyle], doc_width: float) -> list[Any]:
    story: list[Any] = []
    para: list[str] = []
    lines = markdown.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("```"):
            flush_paragraph(para, story, styles["body"])
            i += 1
            code_lines: list[str] = []
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i].rstrip())
                i += 1
            add_code_block(code_lines, story, styles)
        elif line.startswith("# "):
            flush_paragraph(para, story, styles["body"])
            story.append(Paragraph(inline(line[2:].strip()), styles["title"]))
        elif line.startswith("## "):
            flush_paragraph(para, story, styles["body"])
            if story:
                story.append(Spacer(1, 1 * mm))
            story.append(Paragraph(inline(line[3:].strip()), styles["h2"]))
        elif line.startswith("### "):
            flush_paragraph(para, story, styles["body"])
            story.append(Paragraph(inline(line[4:].strip()), styles["h3"]))
        elif line.startswith("|") and i + 1 < len(lines) and is_separator_row(lines[i + 1]):
            flush_paragraph(para, story, styles["body"])
            rows = [split_table_row(line)]
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(split_table_row(lines[i]))
                i += 1
            i -= 1
            add_table(rows, story, styles, doc_width)
        elif line.startswith("- "):
            flush_paragraph(para, story, styles["body"])
            story.append(Paragraph("- " + inline(line[2:].strip()), styles["bullet"]))
        elif re.fullmatch(r"\d+\. .*", line):
            flush_paragraph(para, story, styles["body"])
            story.append(Paragraph(inline(line.strip()), styles["bullet"]))
        elif line.strip() == "":
            flush_paragraph(para, story, styles["body"])
        else:
            para.append(line)
        i += 1
    flush_paragraph(para, story, styles["body"])
    return story


def on_page(canvas, doc, fonts: dict[str, str]) -> None:  # type: ignore[no-untyped-def]
    canvas.saveState()
    canvas.setFont(fonts["regular"], 7.5)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawString(18 * mm, 12 * mm, "W8A12_3lane AI SR Accelerator Contest Report")
    canvas.drawRightString(A4[0] - 18 * mm, 12 * mm, f"Page {doc.page}")
    canvas.restoreState()


def render_pdf(pdf_path: Path, render_dir: Path, pages: int) -> list[Path]:
    pdftoppm = POPPLER_DIR / "pdftoppm.exe"
    if not pdftoppm.exists():
        return []
    render_dir.mkdir(parents=True, exist_ok=True)
    for old in render_dir.glob("page-*.png"):
        old.unlink()
    prefix = render_dir / "page"
    subprocess.run(
        [str(pdftoppm), "-png", "-f", "1", "-l", str(max(1, pages)), str(pdf_path), str(prefix)],
        check=True,
        capture_output=True,
        text=True,
    )
    return sorted(render_dir.glob("page-*.png"))


def image_nonblank(path: Path) -> dict[str, Any]:
    image = Image.open(path).convert("L")
    stat = ImageStat.Stat(image)
    extrema = image.getextrema()
    return {
        "path": str(path),
        "width": image.width,
        "height": image.height,
        "mean": stat.mean[0],
        "extrema": list(extrema),
        "nonblank": extrema[0] < extrema[1] and stat.mean[0] < 254.5,
    }


def verify_pdf(pdf_path: Path, render_dir: Path, render_pages: int) -> dict[str, Any]:
    reader = PdfReader(str(pdf_path))
    page_count = len(reader.pages)
    extracted = "\n".join(page.extract_text() or "" for page in reader.pages)
    required_tokens = [
        "W8A12",
        "三路并行",
        "REDS",
        "28.3118",
        "34.4297",
        "72 / 76",
    ]
    rendered = render_pdf(pdf_path, render_dir, min(page_count, render_pages))
    render_checks = [image_nonblank(path) for path in rendered]
    status = (
        page_count >= 5
        and all(token in extracted for token in required_tokens)
        and bool(render_checks)
        and all(item["nonblank"] for item in render_checks)
    )
    return {
        "status": "PASS" if status else "FAIL",
        "page_count": page_count,
        "required_tokens": {token: token in extracted for token in required_tokens},
        "rendered_pages": [str(path) for path in rendered],
        "render_checks": render_checks,
    }


def render_summary(data: dict[str, Any]) -> str:
    lines = [
        "# Contest Report PDF Export",
        "",
        f"Status: {data['status']}",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| source | `{data['source']}` |",
        f"| pdf | `{data['pdf']}` |",
        f"| bytes | `{data['bytes']}` |",
        f"| sha256 | `{data['sha256']}` |",
        f"| page_count | `{data['page_count']}` |",
        f"| font | `{data['font_path']}` |",
        "",
        "## Render Checks",
        "",
        "| Image | Size | Mean | Extrema | Nonblank |",
        "| --- | --- | ---: | --- | --- |",
    ]
    for item in data["render_checks"]:
        lines.append(
            f"| `{item['path']}` | `{item['width']}x{item['height']}` | "
            f"{item['mean']:.2f} | `{item['extrema']}` | `{item['nonblank']}` |"
        )
    lines.extend(["", "## Required Text Tokens", "", "| Token | Present |", "| --- | --- |"])
    for token, present in data["required_tokens"].items():
        lines.append(f"| `{token}` | `{present}` |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    source = args.source if args.source.is_absolute() else ROOT / args.source
    pdf_out = args.pdf_out if args.pdf_out.is_absolute() else ROOT / args.pdf_out
    evidence_out = args.evidence_out if args.evidence_out.is_absolute() else ROOT / args.evidence_out
    render_out = evidence_out / "rendered"
    pdf_out.parent.mkdir(parents=True, exist_ok=True)
    evidence_out.mkdir(parents=True, exist_ok=True)

    fonts = register_fonts()
    styles = build_styles(fonts)
    doc = SimpleDocTemplate(
        str(pdf_out),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title="W8A12 三路并行 AI 超分硬件加速器赛题报告",
        author="W8A12_3lane",
    )
    story = markdown_to_story(source.read_text(encoding="utf-8"), styles, doc.width)
    story.append(Paragraph("附录：交付状态声明", styles["h2"]))
    story.append(
        Paragraph(
            "本 PDF 由工具自动生成，当前仍为阶段性交付报告。最终赛题交付必须以 contest_delivery_audit.md 状态 PASS 为准。",
            styles["body"],
        )
    )
    doc.build(story, onFirstPage=lambda c, d: on_page(c, d, fonts), onLaterPages=lambda c, d: on_page(c, d, fonts))

    verification = verify_pdf(pdf_out, render_out, args.render_pages)
    data = {
        "status": verification["status"],
        "source": str(source),
        "pdf": str(pdf_out),
        "bytes": pdf_out.stat().st_size,
        "sha256": sha256(pdf_out),
        "font_path": fonts["font_path"],
        **verification,
    }
    (evidence_out / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (evidence_out / "summary.md").write_text(render_summary(data), encoding="utf-8")
    print(f"CONTEST_REPORT_PDF_STATUS={data['status']}")
    print(f"CONTEST_REPORT_PDF={pdf_out}")
    print(f"CONTEST_REPORT_PDF_SHA256={data['sha256']}")
    print(f"CONTEST_REPORT_PDF_SUMMARY={evidence_out / 'summary.md'}")
    return 0 if data["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
