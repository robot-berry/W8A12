#!/usr/bin/env python3
"""Export the contest submission Markdown report to a DOCX artifact.

The DOCX is intentionally monochrome: all text styles and direct run colors are
set to black. Table fills and borders may remain light neutral colors, but font
color is forced to black through both python-docx formatting and OOXML patching.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET

from docx import Document
from docx.enum.section import WD_SECTION_START
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "W8A12_3lane"
SOURCE = BASE / "docs" / "contest_submission_report.md"
DOCX_OUT = BASE / "output" / "docx" / "W8A12_3lane_contest_submission_report.docx"
EVIDENCE_OUT = BASE / "evidence" / "report_docx"

BODY_FONT = "Microsoft YaHei"
MONO_FONT = "Consolas"
BLACK = RGBColor(0, 0, 0)
BLACK_HEX = "000000"
PAGE_WIDTH_DXA = 9360


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--docx-out", type=Path, default=DOCX_OUT)
    parser.add_argument("--evidence-out", type=Path, default=EVIDENCE_OUT)
    return parser.parse_args()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def set_run_font(run: Any, *, size: float | None = None, bold: bool | None = None, mono: bool = False) -> None:
    font_name = MONO_FONT if mono else BODY_FONT
    run.font.name = font_name
    run.font.color.rgb = BLACK
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.rFonts
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:ascii"), font_name)
    rfonts.set(qn("w:hAnsi"), font_name)
    rfonts.set(qn("w:eastAsia"), BODY_FONT)
    rfonts.set(qn("w:cs"), font_name)


def set_style_font(style: Any, *, size: float, bold: bool = False) -> None:
    style.font.name = BODY_FONT
    style.font.size = Pt(size)
    style.font.bold = bold
    style.font.color.rgb = BLACK
    rpr = style._element.get_or_add_rPr()
    rfonts = rpr.rFonts
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:ascii"), BODY_FONT)
    rfonts.set(qn("w:hAnsi"), BODY_FONT)
    rfonts.set(qn("w:eastAsia"), BODY_FONT)
    rfonts.set(qn("w:cs"), BODY_FONT)


def add_inline_runs(paragraph: Any, text: str, *, size: float | None = None, default_bold: bool = False) -> None:
    parts = re.split(r"(`[^`]*`|\*\*[^*]+\*\*)", text)
    for part in parts:
        if not part:
            continue
        if part.startswith("`") and part.endswith("`"):
            run = paragraph.add_run(part[1:-1])
            set_run_font(run, size=size, mono=True)
        elif part.startswith("**") and part.endswith("**"):
            run = paragraph.add_run(part[2:-2])
            set_run_font(run, size=size, bold=True)
        else:
            run = paragraph.add_run(part)
            set_run_font(run, size=size, bold=default_bold)


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator_row(line: str) -> bool:
    cells = split_table_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def set_cell_shading(cell: Any, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_width(cell: Any, width_dxa: int) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_w = tc_pr.find(qn("w:tcW"))
    if tc_w is None:
        tc_w = OxmlElement("w:tcW")
        tc_pr.append(tc_w)
    tc_w.set(qn("w:w"), str(width_dxa))
    tc_w.set(qn("w:type"), "dxa")


def set_cell_margins(cell: Any, margin_dxa: int = 120) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.find(qn("w:tcMar"))
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for side in ("top", "bottom", "start", "end"):
        node = tc_mar.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            tc_mar.append(node)
        node.set(qn("w:w"), "80" if side in {"top", "bottom"} else str(margin_dxa))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row: Any) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def apply_table_geometry(table: Any, col_widths: list[int]) -> None:
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    table.autofit = False
    tbl_pr = table._tbl.tblPr
    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), str(sum(col_widths)))
    tbl_w.set(qn("w:type"), "dxa")
    tbl_ind = tbl_pr.find(qn("w:tblInd"))
    if tbl_ind is None:
        tbl_ind = OxmlElement("w:tblInd")
        tbl_pr.append(tbl_ind)
    tbl_ind.set(qn("w:w"), "120")
    tbl_ind.set(qn("w:type"), "dxa")

    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in col_widths:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(width))
        grid.append(col)

    for row in table.rows:
        for idx, cell in enumerate(row.cells):
            set_cell_width(cell, col_widths[min(idx, len(col_widths) - 1)])
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def table_widths(rows: list[list[str]]) -> list[int]:
    col_count = max(len(row) for row in rows)
    weights: list[int] = []
    for idx in range(col_count):
        max_len = 4
        for row in rows:
            if idx < len(row):
                text = row[idx]
                score = sum(2 if ord(ch) > 127 else 1 for ch in text)
                max_len = max(max_len, min(score, 36))
        weights.append(max_len)
    total = sum(weights) or 1
    raw = [max(900, round(PAGE_WIDTH_DXA * weight / total)) for weight in weights]
    delta = PAGE_WIDTH_DXA - sum(raw)
    raw[-1] += delta
    return raw


def add_table(doc: Document, rows: list[list[str]]) -> None:
    col_count = max(len(row) for row in rows)
    normalized = [row + [""] * (col_count - len(row)) for row in rows]
    table = doc.add_table(rows=len(normalized), cols=col_count)
    table.style = "Table Grid"
    widths = table_widths(normalized)
    apply_table_geometry(table, widths)
    for r_idx, row in enumerate(normalized):
        for c_idx, text in enumerate(row):
            cell = table.cell(r_idx, c_idx)
            para = cell.paragraphs[0]
            para.paragraph_format.space_after = Pt(0)
            add_inline_runs(para, text, size=8.2, default_bold=(r_idx == 0))
            if r_idx == 0:
                set_cell_shading(cell, "F2F2F2")
    set_repeat_table_header(table.rows[0])


def add_code_block(doc: Document, lines: list[str]) -> None:
    para = doc.add_paragraph(style="CodeBlock")
    add_inline_runs(para, "\n".join(lines), size=8.5)


def setup_document() -> Document:
    doc = Document()
    section = doc.sections[0]
    section.start_type = WD_SECTION_START.NEW_PAGE
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)

    styles = doc.styles
    set_style_font(styles["Normal"], size=10.5)
    styles["Normal"].paragraph_format.space_after = Pt(6)
    styles["Normal"].paragraph_format.line_spacing = 1.10
    set_style_font(styles["Title"], size=18, bold=True)
    styles["Title"].paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    styles["Title"].paragraph_format.space_after = Pt(12)
    for name, size, before, after in [
        ("Heading 1", 15, 14, 7),
        ("Heading 2", 12.5, 10, 5),
        ("Heading 3", 11.5, 8, 4),
        ("List Bullet", 10.2, 0, 4),
        ("List Number", 10.2, 0, 4),
    ]:
        set_style_font(styles[name], size=size, bold=name.startswith("Heading"))
        styles[name].paragraph_format.space_before = Pt(before)
        styles[name].paragraph_format.space_after = Pt(after)
        styles[name].paragraph_format.line_spacing = 1.10

    code_style = styles.add_style("CodeBlock", 1)
    set_style_font(code_style, size=8.5)
    code_style.font.name = MONO_FONT
    code_style.paragraph_format.left_indent = Inches(0.18)
    code_style.paragraph_format.right_indent = Inches(0.18)
    code_style.paragraph_format.space_before = Pt(4)
    code_style.paragraph_format.space_after = Pt(6)

    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    add_inline_runs(footer, "W8A12_3lane Contest Submission Report", size=8)
    return doc


def markdown_to_docx(markdown: str) -> Document:
    doc = setup_document()
    para_buf: list[str] = []
    lines = markdown.splitlines()
    i = 0

    def flush_para() -> None:
        if not para_buf:
            return
        text = " ".join(part.strip() for part in para_buf if part.strip())
        para_buf.clear()
        if text:
            paragraph = doc.add_paragraph()
            add_inline_runs(paragraph, text)

    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("```"):
            flush_para()
            i += 1
            code_lines: list[str] = []
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i].rstrip())
                i += 1
            add_code_block(doc, code_lines)
        elif line.startswith("# "):
            flush_para()
            paragraph = doc.add_paragraph(style="Title")
            add_inline_runs(paragraph, line[2:].strip(), size=18, default_bold=True)
        elif line.startswith("## "):
            flush_para()
            paragraph = doc.add_paragraph(style="Heading 1")
            add_inline_runs(paragraph, line[3:].strip(), size=15, default_bold=True)
        elif line.startswith("### "):
            flush_para()
            paragraph = doc.add_paragraph(style="Heading 2")
            add_inline_runs(paragraph, line[4:].strip(), size=12.5, default_bold=True)
        elif line.startswith("|") and i + 1 < len(lines) and is_separator_row(lines[i + 1]):
            flush_para()
            rows = [split_table_row(line)]
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(split_table_row(lines[i]))
                i += 1
            i -= 1
            add_table(doc, rows)
        elif line.startswith("- "):
            flush_para()
            paragraph = doc.add_paragraph(style="List Bullet")
            add_inline_runs(paragraph, line[2:].strip(), size=10.2)
        elif re.fullmatch(r"\d+\. .*", line):
            flush_para()
            paragraph = doc.add_paragraph(style="List Number")
            add_inline_runs(paragraph, re.sub(r"^\d+\.\s*", "", line), size=10.2)
        elif not line.strip():
            flush_para()
        else:
            para_buf.append(line)
        i += 1
    flush_para()
    return doc


def force_ooxml_text_black(docx_path: Path) -> None:
    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    tmp = docx_path.with_suffix(".tmp.docx")
    with zipfile.ZipFile(docx_path, "r") as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as dst:
        for info in src.infolist():
            data = src.read(info.filename)
            if info.filename.startswith("word/") and info.filename.endswith(".xml"):
                try:
                    root = ET.fromstring(data)
                except ET.ParseError:
                    dst.writestr(info, data)
                    continue
                changed = False
                for rpr in root.findall(".//w:rPr", ns):
                    color = rpr.find("w:color", ns)
                    if color is None:
                        continue
                    if color.get(qn("w:val")) != BLACK_HEX:
                        color.set(qn("w:val"), BLACK_HEX)
                        changed = True
                data = ET.tostring(root, encoding="utf-8", xml_declaration=True) if changed else data
            dst.writestr(info, data)
    tmp.replace(docx_path)


def audit_text_color(docx_path: Path) -> dict[str, Any]:
    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    non_black: list[dict[str, str]] = []
    text_color_count = 0
    with zipfile.ZipFile(docx_path, "r") as zf:
        for name in zf.namelist():
            visible_part = (
                name == "word/document.xml"
                or re.fullmatch(r"word/(header|footer)\d+\.xml", name)
            )
            if not visible_part:
                continue
            try:
                root = ET.fromstring(zf.read(name))
            except ET.ParseError:
                continue
            for rpr in root.findall(".//w:rPr", ns):
                color = rpr.find("w:color", ns)
                if color is None:
                    continue
                text_color_count += 1
                val = (color.get(qn("w:val")) or "").upper()
                if val not in {BLACK_HEX, "AUTO"}:
                    non_black.append({"part": name, "color": val})
    return {
        "status": "PASS" if not non_black else "FAIL",
        "text_color_count": text_color_count,
        "non_black_text_colors": non_black[:50],
        "non_black_text_color_count": len(non_black),
    }


def render_summary(data: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Contest Report DOCX Export",
            "",
            f"Status: {data['status']}",
            "",
            "| Field | Value |",
            "| --- | --- |",
            f"| source | `{data['source']}` |",
            f"| docx | `{data['docx']}` |",
            f"| bytes | `{data['bytes']}` |",
            f"| sha256 | `{data['sha256']}` |",
            f"| text color audit | `{data['text_color_audit']['status']}` |",
            f"| text color entries | `{data['text_color_audit']['text_color_count']}` |",
            f"| non-black text colors | `{data['text_color_audit']['non_black_text_color_count']}` |",
            "",
            "All generated run/style text color entries are forced to black (`000000`).",
            "",
        ]
    )


def main() -> int:
    args = parse_args()
    source = args.source if args.source.is_absolute() else ROOT / args.source
    docx_out = args.docx_out if args.docx_out.is_absolute() else ROOT / args.docx_out
    evidence_out = args.evidence_out if args.evidence_out.is_absolute() else ROOT / args.evidence_out
    docx_out.parent.mkdir(parents=True, exist_ok=True)
    evidence_out.mkdir(parents=True, exist_ok=True)

    doc = markdown_to_docx(source.read_text(encoding="utf-8"))
    doc.core_properties.title = "W8A12 3-lane AI SR accelerator contest report"
    doc.core_properties.author = "W8A12_3lane"
    doc.save(docx_out)
    color_audit = audit_text_color(docx_out)
    data = {
        "status": "PASS" if color_audit["status"] == "PASS" and docx_out.stat().st_size > 0 else "FAIL",
        "source": str(source),
        "docx": str(docx_out),
        "bytes": docx_out.stat().st_size,
        "sha256": sha256(docx_out),
        "text_color_audit": color_audit,
    }
    (evidence_out / "summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    (evidence_out / "summary.md").write_text(render_summary(data), encoding="utf-8")
    print(f"CONTEST_REPORT_DOCX_STATUS={data['status']}")
    print(f"CONTEST_REPORT_DOCX={docx_out}")
    print(f"CONTEST_REPORT_DOCX_SHA256={data['sha256']}")
    print(f"CONTEST_REPORT_DOCX_SUMMARY={evidence_out / 'summary.md'}")
    return 0 if data["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
