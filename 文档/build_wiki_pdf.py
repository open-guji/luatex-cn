#!/usr/bin/env python3
"""
Consolidate luatex-cn.wiki markdown files into two PDF documents:
  - luatex-cn-wiki-zh.pdf  (Chinese documentation)
  - luatex-cn-wiki-en.pdf  (English documentation)

Requirements:
  pip install markdown-it-py weasyprint

Usage:
  python3 文档/build_wiki_pdf.py
"""

import re
import sys
from pathlib import Path

from markdown_it import MarkdownIt
from weasyprint import HTML

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

WIKI_DIR = Path(__file__).resolve().parent.parent.parent / "luatex-cn.wiki"
OUT_DIR = Path(__file__).resolve().parent  # 文档/

# Chapter ordering – mirrors _Sidebar.md structure
ZH_CHAPTERS = [
    # (filename without .md, display title)
    # -- 入门 --
    ("Home", "LuaTeX-CN Wiki"),
    ("Installation", "安装指南"),
    ("Quick-Start", "快速入门"),
    ("Examples", "示例"),
    # -- 排版功能 --
    ("Templates", "模板使用与自定义"),
    ("Fonts", "字体设置"),
    ("Features", "功能详解"),
    ("ltc-book", "现代竖排"),
    # -- 标点与句读 --
    ("Punctuation", "标点系统"),
    ("Judou", "句读"),
    # -- 注释系统 --
    ("Side-Note", "夹注与侧批"),
    ("Annotation", "批注与眉批"),
    # -- 装饰与辅助 --
    ("Correction", "改字与装饰"),
    ("Taitou", "抬头"),
    ("Textbox", "文本框"),
    ("Seal", "印章"),
    # -- 参考 --
    ("Debug", "调试模式"),
    ("Command-Reference", "命令索引"),
    ("Changelog", "更新日志"),
    # -- 开发者 --
    ("Development", "开发文档"),
    ("Release", "发布流程"),
]

EN_CHAPTERS = [
    # -- Getting Started --
    ("EN:Home", "LuaTeX-CN Wiki"),
    ("EN:Installation", "Installation Guide"),
    ("EN:Quick-Start", "Quick Start"),
    ("EN:Examples", "Examples"),
    # -- Typesetting --
    ("EN:Templates", "Templates and Customization"),
    ("EN:Fonts", "Fonts"),
    ("EN:Features", "Features Overview"),
    ("EN:ltc-book", "Modern Vertical Books"),
    # -- Punctuation --
    ("EN:Punctuation", "Punctuation System"),
    ("EN:Judou", "Judou (Punctuation Modes)"),
    # -- Annotations --
    ("EN:Side-Note", "Interlinear & Side Notes"),
    ("EN:Annotation", "Annotations & Marginal Notes"),
    # -- Decorations --
    ("EN:Correction", "Correction & Decoration"),
    ("EN:Taitou", "Elevation (Taitou)"),
    ("EN:Textbox", "Textbox"),
    ("EN:Seal", "Seals"),
    # -- Reference --
    ("EN:Debug", "Debug Mode"),
    ("EN:Changelog", "Changelog"),
    # -- Developer --
    ("EN:Development", "Development Documentation"),
    ("EN:Release", "Release Process"),
]

# ---------------------------------------------------------------------------
# Markdown processing helpers
# ---------------------------------------------------------------------------


def slugify(name: str) -> str:
    """Create an anchor slug from a wiki page name."""
    return re.sub(r"[^a-zA-Z0-9-]", "", name.lower().replace(" ", "-").replace(":", "-"))


def read_wiki_page(name: str) -> str:
    """Read a wiki markdown file, return its content."""
    path = WIKI_DIR / f"{name}.md"
    if not path.exists():
        print(f"  WARNING: {path} not found, skipping.", file=sys.stderr)
        return ""
    return path.read_text(encoding="utf-8")


def strip_language_toggle(md: str) -> str:
    """Remove the first line if it's a language toggle (e.g. 'English | [中文版](Home)')."""
    lines = md.split("\n", 1)
    if lines and re.match(r"^(\[.*\].*\|.*|.*\|\s*\[.*\])", lines[0]):
        return lines[1] if len(lines) > 1 else ""
    return md


def convert_wiki_links(md: str, valid_slugs: set[str]) -> str:
    """Convert [[display | Page-Name]] wiki links to internal PDF anchors."""
    def _replace(m):
        display = m.group(1).strip()
        target = m.group(2).strip() if m.group(2) else display
        slug = slugify(target)
        if slug in valid_slugs:
            return f"[{display}](#{slug})"
        return display

    # [[display | target]] or [[target]]
    md = re.sub(r"\[\[([^|\]]+?)(?:\s*\|\s*([^\]]+?))?\]\]", _replace, md)
    return md


# ---------------------------------------------------------------------------
# HTML / CSS generation
# ---------------------------------------------------------------------------

CSS_COMMON = """
@page {
    size: A4;
    margin: 2cm 2.5cm;
    @bottom-center {
        content: counter(page);
        font-size: 9pt;
        color: #888;
    }
}

body {
    font-size: 11pt;
    line-height: 1.7;
    color: #222;
}

h1 {
    font-size: 20pt;
    border-bottom: 2px solid #333;
    padding-bottom: 6pt;
    margin-top: 40pt;
    page-break-before: always;
}

/* Don't page-break before the very first h1 (cover title) */
body > h1:first-child,
.chapter:first-child h1 {
    page-break-before: avoid;
}

h2 {
    font-size: 15pt;
    color: #333;
    margin-top: 24pt;
    border-bottom: 1px solid #ccc;
    padding-bottom: 4pt;
}

h3 { font-size: 13pt; color: #444; margin-top: 18pt; }
h4 { font-size: 11.5pt; color: #555; }

code {
    font-family: "Cascadia Code", "Fira Code", "Source Code Pro", "Noto Sans Mono CJK SC", monospace;
    background: #f4f4f4;
    padding: 1px 4px;
    border-radius: 3px;
    font-size: 0.9em;
}

pre {
    background: #f6f6f6;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 10px 14px;
    overflow-x: auto;
    font-size: 9pt;
    line-height: 1.4;
}

pre code {
    background: none;
    padding: 0;
}

blockquote {
    border-left: 3px solid #bbb;
    margin-left: 0;
    padding: 4px 14px;
    color: #555;
    background: #fafafa;
}

table {
    border-collapse: collapse;
    width: 100%;
    margin: 12px 0;
    font-size: 10pt;
}

th, td {
    border: 1px solid #ccc;
    padding: 6px 10px;
    text-align: left;
}

th {
    background: #f0f0f0;
    font-weight: bold;
}

a {
    color: #1a5dad;
    text-decoration: none;
}

img {
    max-width: 45%;
    height: auto;
}

hr {
    border: none;
    border-top: 1px solid #ddd;
    margin: 20px 0;
}

.cover {
    text-align: center;
    padding-top: 200px;
}

.cover h1 {
    font-size: 28pt;
    border: none;
    page-break-before: avoid;
}

.cover p {
    font-size: 12pt;
    color: #666;
}

.toc {
    page-break-after: always;
}

.toc h1 {
    page-break-before: avoid;
}

.toc ul {
    list-style: none;
    padding-left: 0;
}

.toc li {
    margin: 4px 0;
    font-size: 11pt;
}

.toc li.sub {
    padding-left: 20px;
    font-size: 10.5pt;
}

.chapter {
    page-break-before: always;
}

.chapter:first-of-type {
    page-break-before: avoid;
}
"""

CSS_ZH = CSS_COMMON + """
body {
    font-family: "Noto Serif CJK SC", "Source Han Serif SC", "SimSun", "AR PL UMing CN", serif;
}
"""

CSS_EN = CSS_COMMON + """
body {
    font-family: "Noto Serif", "Georgia", "Times New Roman", serif;
}
"""


def build_toc_html(chapters: list[tuple[str, str]], is_zh: bool) -> str:
    """Build a table-of-contents HTML block."""
    title = "目录" if is_zh else "Table of Contents"
    feature_pages = {
        "Punctuation", "Judou",
        "Side-Note", "Annotation",
        "Correction", "Taitou", "Textbox", "Seal",
        "EN:Punctuation", "EN:Judou",
        "EN:Side-Note", "EN:Annotation",
        "EN:Correction", "EN:Taitou", "EN:Textbox", "EN:Seal",
    }

    items = []
    for name, display in chapters:
        slug = slugify(name)
        cls = ' class="sub"' if name in feature_pages else ""
        items.append(f'<li{cls}><a href="#{slug}">{display}</a></li>')

    return f"""
<div class="toc">
<h1>{title}</h1>
<ul>
{"".join(items)}
</ul>
</div>
"""


def build_cover_html(is_zh: bool) -> str:
    """Build cover page HTML."""
    if is_zh:
        return """
<div class="cover">
<h1>LuaTeX-CN 文档</h1>
<p>— 高质量古籍排版宏包 —</p>
<p>从 GitHub Wiki 自动生成</p>
</div>
"""
    else:
        return """
<div class="cover">
<h1>LuaTeX-CN Documentation</h1>
<p>— High-Quality Classical Chinese Typesetting —</p>
<p>Auto-generated from GitHub Wiki</p>
</div>
"""


def build_pdf(chapters: list[tuple[str, str]], css: str, out_path: Path, is_zh: bool):
    """Build a single consolidated PDF from a list of wiki chapters."""
    md_parser = MarkdownIt("commonmark", {"html": True}).enable("table").enable("strikethrough")

    # Collect valid slugs for cross-referencing
    valid_slugs = {slugify(name) for name, _ in chapters}

    # Build HTML body
    html_parts = [build_cover_html(is_zh), build_toc_html(chapters, is_zh)]

    for i, (name, _display) in enumerate(chapters):
        slug = slugify(name)
        raw_md = read_wiki_page(name)
        if not raw_md:
            continue

        # Clean up
        raw_md = strip_language_toggle(raw_md)
        raw_md = convert_wiki_links(raw_md, valid_slugs)

        # Render markdown to HTML
        body_html = md_parser.render(raw_md)

        # Wrap in a chapter div with anchor
        html_parts.append(f'<div class="chapter" id="{slug}">\n{body_html}\n</div>')

    full_html = f"""<!DOCTYPE html>
<html lang="{"zh" if is_zh else "en"}">
<head>
<meta charset="utf-8">
<style>{css}</style>
</head>
<body>
{"".join(html_parts)}
</body>
</html>
"""

    # Write intermediate HTML for debugging (optional)
    html_path = out_path.with_suffix(".html")
    html_path.write_text(full_html, encoding="utf-8")

    # Generate PDF
    print(f"  Generating {out_path.name} ...")
    HTML(string=full_html, base_url=str(WIKI_DIR)).write_pdf(str(out_path))
    size_kb = out_path.stat().st_size / 1024
    print(f"  -> {out_path.name} ({size_kb:.0f} KB)")

    # Clean up intermediate HTML
    html_path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if not WIKI_DIR.exists():
        print(f"ERROR: Wiki directory not found: {WIKI_DIR}", file=sys.stderr)
        print("  Make sure the luatex-cn.wiki repo is cloned next to luatex-cn.", file=sys.stderr)
        sys.exit(1)

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Building Chinese PDF ...")
    build_pdf(ZH_CHAPTERS, CSS_ZH, OUT_DIR / "luatex-cn-wiki-zh.pdf", is_zh=True)

    print("Building English PDF ...")
    build_pdf(EN_CHAPTERS, CSS_EN, OUT_DIR / "luatex-cn-wiki-en.pdf", is_zh=False)

    print("\nDone! PDFs are in:", OUT_DIR)


if __name__ == "__main__":
    main()
