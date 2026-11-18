#!/usr/bin/env python3
"""
Consolidate luatex-cn.wiki markdown files into two PDF documents:
  - luatex-cn-wiki-zh.pdf  (Chinese documentation)
  - luatex-cn-wiki-en.pdf  (English documentation)

Requirements:
  pip install markdown-it-py "weasyprint>=69" pillow pikepdf fonttools

Usage:
  python3 文档/build_wiki_pdf.py
"""

import json
import os
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

from markdown_it import MarkdownIt
from PIL import Image
from weasyprint import HTML
from weasyprint.urls import URLFetcher, URLFetcherResponse

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Wiki checkout 位置：默认在仓库旁边，可用 LUATEX_CN_WIKI_DIR 覆盖（CI 用）
WIKI_DIR = Path(
    os.environ.get(
        "LUATEX_CN_WIKI_DIR",
        Path(__file__).resolve().parent.parent.parent / "luatex-cn.wiki",
    )
)
OUT_DIR = Path(__file__).resolve().parent  # 文档/

# 单色（矢量轮廓）Noto Emoji：让 emoji 以字体子集嵌入 PDF。
# 不加这个的话，Pango 回落到系统彩色 emoji 字体（macOS 的 Apple Color Emoji
# 是 160px 位图），每个 emoji 都会变成一张 ~25 KB 的位图塞进 PDF。
# URL 钉死在 google/fonts 的具体 commit 上，保证可复现；字体不入库，按需下载。
#
# 两个必要的曲折（缺一不可，详见 ensure_emoji_font / force_text_presentation）：
#   1. fontconfig 的 generic 配置把「Noto Emoji」家族别名到 emoji 并 prefer
#      系统彩色字体，@font-face 会被截胡 —— 所以改名成独有家族再注册；
#   2. Pango 对 emoji 呈现形式的字符强制走系统 emoji 字体、无视 CSS 字体栈
#      —— 所以正文里给 emoji 统一加文本呈现选择符 U+FE0E。
EMOJI_FONT_URL = (
    "https://raw.githubusercontent.com/google/fonts/"
    "2d85e20401920891efb7cd6272d6339685df2820/ofl/notoemoji/NotoEmoji%5Bwght%5D.ttf"
)
EMOJI_FONT_DL_PATH = OUT_DIR / "fonts" / "NotoEmoji.ttf"
EMOJI_FONT_PATH = OUT_DIR / "fonts" / "LuaTeXCNEmoji.ttf"
EMOJI_FAMILY = "LuaTeX-CN Emoji"

# 预览图压缩参数：图片显示宽度最多为版面 45%（16cm × 45% ≈ 7.2cm），
# 300 dpi 对应约 850px；截图/线稿类预览图用 64 色调色板肉眼无损。
# 原图以原始分辨率（约 400–780 dpi）8bpc 全彩嵌入，是 PDF 体积的大头。
IMG_MAX_WIDTH_PX = 850
IMG_PALETTE_COLORS = 64


def ensure_emoji_font() -> Path:
    """下载单色 Noto Emoji，实例化并改名为独有家族名。

    改名的原因：fontconfig 自带的 generic 别名把「Noto Emoji」映射到 emoji
    家族并 prefer 系统彩色 emoji 字体（fc-match 'Noto Emoji' 会命中
    Apple Color Emoji），以原名注册 @font-face 会被截胡。换成不在别名表里的
    家族名后，@font-face 才真正生效。
    """
    if EMOJI_FONT_PATH.exists():
        return EMOJI_FONT_PATH
    EMOJI_FONT_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not EMOJI_FONT_DL_PATH.exists():
        print(f"Downloading Noto Emoji -> {EMOJI_FONT_DL_PATH}")
        urllib.request.urlretrieve(EMOJI_FONT_URL, EMOJI_FONT_DL_PATH)

    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont

    font = TTFont(EMOJI_FONT_DL_PATH)
    if "fvar" in font:
        instantiateVariableFont(font, {"wght": 400}, inplace=True)
    for rec in font["name"].names:
        # 1=family 3=unique-id 4=full-name 6=postscript-name 16=typographic-family
        if rec.nameID in (1, 3, 4, 6, 16):
            rec.string = (rec.toUnicode()
                          .replace("Noto Emoji", EMOJI_FAMILY)
                          .replace("NotoEmoji", EMOJI_FAMILY.replace(" ", "")))
    font.save(EMOJI_FONT_PATH)
    print(f"Emoji font ready: {EMOJI_FONT_PATH} (family: {EMOJI_FAMILY})")
    return EMOJI_FONT_PATH


# Emoji_Presentation=Yes 的字符（UTS #51）：Pango 会把它们切成 emoji run
# 并强制使用系统 emoji 字体（无视 CSS 字体栈）。加上 U+FE0E 文本呈现
# 选择符后按普通文本排版，才会用上面注册的矢量 emoji 字体。
_EMOJI_DEFAULT_RE = re.compile(
    "([\u231a\u231b\u23e9-\u23ec\u23f0\u23f3\u25fd\u25fe\u2614\u2615"
    "\u2648-\u2653\u267f\u2693\u26a1\u26aa\u26ab\u26bd\u26be\u26c4\u26c5"
    "\u26ce\u26d4\u26ea\u26f2\u26f3\u26f5\u26fa\u26fd\u2705\u270a\u270b"
    "\u2728\u274c\u274e\u2753-\u2755\u2757\u2795-\u2797\u27b0\u27bf"
    "\u2b1b\u2b1c\u2b50\u2b55\U0001f000-\U0001faff])(?!\ufe0e)"
)


def force_text_presentation(html: str) -> str:
    """把 emoji 统一改为文本呈现：U+FE0F → U+FE0E，默认 emoji 呈现的补 U+FE0E。"""
    html = html.replace("\ufe0f", "\ufe0e")
    return _EMOJI_DEFAULT_RE.sub("\\1\ufe0e", html)


def compress_image_bytes(raw: bytes) -> bytes | None:
    """Downscale to ≤300 dpi at display size and quantize to a palette PNG."""
    try:
        im = Image.open(BytesIO(raw))
        im.load()
    except Exception as exc:
        print(f"  WARNING: cannot decode image ({exc}), keeping original", file=sys.stderr)
        return None
    if im.width > IMG_MAX_WIDTH_PX:
        im = im.resize(
            (IMG_MAX_WIDTH_PX, max(1, round(im.height * IMG_MAX_WIDTH_PX / im.width))),
            Image.LANCZOS,
        )
    if im.mode != "P":
        if "A" in im.getbands():
            # FASTOCTREE 是 Pillow 里唯一支持带 alpha 量化的方法
            im = im.convert("RGBA").quantize(
                colors=IMG_PALETTE_COLORS, method=Image.Quantize.FASTOCTREE)
        else:
            im = im.convert("RGB").quantize(
                colors=IMG_PALETTE_COLORS, method=Image.Quantize.MEDIANCUT)
    buf = BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def palettize_pdf_images(pdf_path: Path) -> None:
    """把 PDF 里的全彩图像流转成 64 色 Indexed 表示。

    WeasyPrint 嵌入图像时一律把调色板 PNG 展开成 8bpc RGB（3 字节/像素），
    fetcher 里做的量化只剩下降采样的作用。这里在 PDF 层面补回来：
    每像素 1 字节索引 + 64×3 字节查找表，Flate 后体积约为 RGB 的 1/3。
    """
    import zlib

    import pikepdf

    before = pdf_path.stat().st_size
    seen = set()
    with pikepdf.open(pdf_path, allow_overwriting_input=True) as pdf:
        for page in pdf.pages:
            xobjects = page.obj.get("/Resources", {}).get("/XObject", {})
            for _name, obj in xobjects.items():
                key = (obj.objgen if hasattr(obj, "objgen") else None)
                if key in seen:
                    continue
                seen.add(key)
                if (obj.get("/Subtype") != "/Image"
                        or obj.get("/ColorSpace") != "/DeviceRGB"
                        or int(obj.get("/BitsPerComponent", 0)) != 8):
                    continue
                pil = pikepdf.PdfImage(obj).as_pil_image().convert("RGB")
                pal = pil.quantize(
                    colors=IMG_PALETTE_COLORS, method=Image.Quantize.MEDIANCUT)
                palette = bytes(pal.getpalette()[:IMG_PALETTE_COLORS * 3])
                n_colors = len(palette) // 3
                obj.write(
                    zlib.compress(pal.tobytes(), 9),
                    filter=pikepdf.Name("/FlateDecode"))
                obj.ColorSpace = pikepdf.Array([
                    pikepdf.Name("/Indexed"), pikepdf.Name("/DeviceRGB"),
                    n_colors - 1, pikepdf.Binary(palette) if hasattr(pikepdf, "Binary")
                    else pikepdf.String(palette),
                ])
                obj.BitsPerComponent = 8
                if "/DecodeParms" in obj:
                    del obj.DecodeParms
        pdf.save(pdf_path)
    after = pdf_path.stat().st_size
    print(f"  Palettized images: {before // 1024} KB -> {after // 1024} KB")


_image_cache: dict[str, bytes] = {}
_fetcher = URLFetcher(allow_redirects=True)


def image_fetcher(url: str) -> URLFetcherResponse:
    """WeasyPrint url_fetcher：位图一律先压缩再交给排版引擎。

    首页展示等预览图在 zh/en 两份 PDF 里重复出现，按 URL 缓存压缩结果，
    避免重复下载与重复量化。（WeasyPrint ≥ 69 的 URLFetcher API）
    """
    if url in _image_cache:
        return URLFetcherResponse(
            url, body=_image_cache[url], headers={"Content-Type": "image/png"})
    resp = _fetcher.fetch(url)
    mime = resp.headers.get_content_type()
    if mime.startswith("image/") and mime != "image/svg+xml":
        raw = resp.read()
        resp.close()
        compressed = compress_image_bytes(raw)
        if compressed is None:
            return URLFetcherResponse(url, body=raw, headers={"Content-Type": mime})
        print(f"  Image {url.rsplit('/', 1)[-1]}: "
              f"{len(raw) // 1024} KB -> {len(compressed) // 1024} KB")
        _image_cache[url] = compressed
        return URLFetcherResponse(
            url, body=compressed, headers={"Content-Type": "image/png"})
    return resp


def git_head(repo_dir: Path) -> str:
    """Return the short HEAD commit of a git checkout, or 'unknown'."""
    try:
        return subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=repo_dir, capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, OSError):
        return "unknown"

# Chapter ordering – mirrors _Sidebar.md structure
ZH_CHAPTERS = [
    # (filename without .md, display title)
    # -- 入门 --
    ("Home", "LuaTeX-CN Wiki"),
    ("Installation", "安装指南"),
    ("Quick-Start", "快速入门"),
    ("Anatomy", "古籍版式要素"),
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
    ("EN:Anatomy", "Page Anatomy"),
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


# TeX 家族词 → 经典 logo 样式。只处理正确大小写的整词
# （lualatex、luatex-cn 等命令/包名是小写，不会命中；LuaTeX-CN 中的
# LuaTeX 部分会被样式化，-CN 原样保留）。长词在前保证优先匹配。
_TEX_E = 'T<span class="tex-e">e</span>X'
_TEX_A = 'L<span class="tex-a">a</span>' + _TEX_E
_LOGO_HTML = {
    "LuaLaTeX": "Lua" + _TEX_A,
    "LuaTeX": "Lua" + _TEX_E,
    "XeLaTeX": "Xe" + _TEX_A,
    "XeTeX": "Xe" + _TEX_E,
    "pdfLaTeX": "pdf" + _TEX_A,
    "pdfTeX": "pdf" + _TEX_E,
    "LaTeX": _TEX_A,
    "TeX": _TEX_E,
}
_LOGO_RE = re.compile(
    r"(?<![A-Za-z])(" + "|".join(_LOGO_HTML) + r")(?![a-zA-Z])"
)
# 标签整体、pre/code 块整体作为分隔符保留，只改纯文本片段
_HTML_TOKEN_RE = re.compile(
    r"(<pre\b.*?</pre>|<code\b.*?</code>|<[^>]+>)", re.S
)


def texify_logos(html: str) -> str:
    """把正文文本中的 TeX/LaTeX/LuaTeX 等换成 logo 样式 span。

    跳过 <pre>/<code> 块与标签内部（属性值），避免命令行、
    源码示例与链接地址被改写。
    """
    parts = _HTML_TOKEN_RE.split(html)
    return "".join(
        p if p.startswith("<") else _LOGO_RE.sub(lambda m: _LOGO_HTML[m.group(1)], p)
        for p in parts
    )


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

    # 表格单元格内的 wiki 链接会把竖线转义成 \|（[[A \| B]]），
    # 先还原为普通分隔符，否则反斜杠残留在链接文本里产生 \]，
    # 使 markdown 链接无法闭合、整段以字面文本渲染
    md = re.sub(r"\[\[[^\]]+?\]\]", lambda m: m.group(0).replace("\\|", "|"), md)

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

/* TeX 家族 logo：E 下沉、LaTeX 的 A 上标缩小（经典排印样式）。
   text-transform 保证复制/书签文本仍是 TeX/LaTeX 原拼写 */
.tex-e {
    text-transform: uppercase;
    vertical-align: -0.45ex;
    margin-left: -0.1667em;
    margin-right: -0.125em;
}
.tex-a {
    text-transform: uppercase;
    font-size: 0.75em;
    vertical-align: 0.27em;
    margin-left: -0.36em;
    margin-right: -0.15em;
}

code {
    font-family: "Cascadia Code", "Fira Code", "Source Code Pro", "Noto Sans Mono CJK SC", "LuaTeX-CN Emoji", monospace;
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

.cover p.stamp {
    font-size: 9pt;
    color: #999;
    margin-top: 40pt;
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

# emoji 字体排在 serif 关键字之前：主字体没有的 emoji 字符落到矢量 emoji
# 字体（随子集嵌入），而不是继续回落到系统彩色 emoji 位图字体
CSS_ZH = CSS_COMMON + f"""
body {{
    font-family: "Noto Serif CJK SC", "Source Han Serif SC", "SimSun", "AR PL UMing CN", "{EMOJI_FAMILY}", serif;
}}
"""

CSS_EN = CSS_COMMON + f"""
body {{
    font-family: "Noto Serif", "Georgia", "Times New Roman", "{EMOJI_FAMILY}", serif;
}}
"""


def build_font_css(emoji_font: Path) -> str:
    return f"""
@font-face {{
    font-family: "{EMOJI_FAMILY}";
    src: url("{emoji_font.resolve().as_uri()}");
}}
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


def build_stamp(is_zh: bool) -> str:
    """Generation stamp: UTC timestamp + repo/wiki commits."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    repo_commit = git_head(Path(__file__).resolve().parent.parent)
    wiki_commit = git_head(WIKI_DIR)
    if is_zh:
        return (f"生成时间 {ts} · 仓库 {repo_commit} · wiki {wiki_commit}")
    return f"Generated {ts} · repo {repo_commit} · wiki {wiki_commit}"


def build_cover_html(is_zh: bool) -> str:
    """Build cover page HTML."""
    stamp = build_stamp(is_zh)
    if is_zh:
        return f"""
<div class="cover">
<h1>LuaTeX-CN 文档</h1>
<p>— 古籍版式复刻 · 遵循 clreq 的现代中文排版 —</p>
<p>从 GitHub Wiki 自动生成</p>
<p class="stamp">{stamp}</p>
</div>
"""
    else:
        return f"""
<div class="cover">
<h1>LuaTeX-CN Documentation</h1>
<p>— Classical Page Replication · clreq-Conformant Modern Chinese —</p>
<p>Auto-generated from GitHub Wiki</p>
<p class="stamp">{stamp}</p>
</div>
"""


def build_pdf(chapters: list[tuple[str, str]], css: str, out_path: Path, is_zh: bool):
    """Build a single consolidated PDF from a list of wiki chapters."""
    md_parser = MarkdownIt("commonmark", {"html": True}).enable("table").enable("strikethrough")

    # Collect valid slugs for cross-referencing
    valid_slugs = {slugify(name) for name, _ in chapters}

    # Build HTML body（封面/目录也做 TeX logo 样式化）
    html_parts = [
        texify_logos(build_cover_html(is_zh)),
        texify_logos(build_toc_html(chapters, is_zh)),
    ]

    for i, (name, _display) in enumerate(chapters):
        slug = slugify(name)
        raw_md = read_wiki_page(name)
        if not raw_md:
            continue

        # Clean up
        raw_md = strip_language_toggle(raw_md)
        raw_md = convert_wiki_links(raw_md, valid_slugs)

        # Render markdown to HTML
        body_html = texify_logos(md_parser.render(raw_md))

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
    full_html = force_text_presentation(full_html)

    # Write intermediate HTML for debugging (optional)
    html_path = out_path.with_suffix(".html")
    html_path.write_text(full_html, encoding="utf-8")

    # Generate PDF
    print(f"  Generating {out_path.name} ...")
    HTML(string=full_html, base_url=str(WIKI_DIR),
         url_fetcher=image_fetcher).write_pdf(str(out_path))
    palettize_pdf_images(out_path)
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
    font_css = build_font_css(ensure_emoji_font())

    print("Building Chinese PDF ...")
    build_pdf(ZH_CHAPTERS, font_css + CSS_ZH, OUT_DIR / "luatex-cn-wiki-zh.pdf", is_zh=True)

    print("Building English PDF ...")
    build_pdf(EN_CHAPTERS, font_css + CSS_EN, OUT_DIR / "luatex-cn-wiki-en.pdf", is_zh=False)

    # 生成 stamp：记录本次构建对应的 wiki/repo commit，
    # CI workflow 据此判断 wiki 是否有更新、需不需要重建
    stamp = {
        "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo_commit": git_head(Path(__file__).resolve().parent.parent),
        "wiki_commit": git_head(WIKI_DIR),
    }
    stamp_path = OUT_DIR / "wiki-pdf-stamp.json"
    stamp_path.write_text(
        json.dumps(stamp, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Stamp:", stamp)

    print("\nDone! PDFs are in:", OUT_DIR)


if __name__ == "__main__":
    main()
