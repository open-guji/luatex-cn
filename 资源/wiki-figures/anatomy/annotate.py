#!/usr/bin/env python3
"""古籍版式要素标注图（issue #195 第一步）。

    python3 资源/wiki-figures/anatomy/annotate.py

编译同目录的 anatomy.tex（整版不拆筒子页），150 dpi 栅格化，再加编号标记、版心放大图和图例，
输出 anatomy-zh.png / anatomy-en.png。编号标记的位置目前是在 150 dpi 图上量的像素坐标，
改了 anatomy.tex 或渲染算法后要重新核对（issue #195 第二步会改为从 layout JSON 自动取）。

依赖：lualatex、pdftoppm、Pillow；字体同回归测试，经 OSFONTDIR 用 test/fonts/
（先运行 scripts/download_test_fonts.sh）。
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FONTS = ROOT / "test" / "fonts"
LABEL_FONT = FONTS / "SourceHanSerifSC-Regular.otf"
SEAL = ROOT / "示例" / "史记五帝本纪" / "文渊阁宝印.png"

DPI = 150
LEFT = 330             # 左栏（版心放大图）宽度（px）
RIGHT = 900            # 右栏（图例）宽度（px）
RED = (190, 30, 30)
GRAY = (95, 95, 95)
R = 21                 # 编号圆半径

# 版心放大图：从整页裁出的范围（px, 150 dpi），放在左栏里的位置
BANXIN_CROP = (1139, 400, 1218, 1480)
INSET_SCALE = 1.5
INSET_X = 60
INSET_Y = 150

# 编号标记：键 -> (标记圆心, 引线终点 or None)。坐标是 150 dpi 页面像素；
# ("inset", x, y) 表示版心裁图内的像素（未放大前）。
MARKS = {
    "tiantou":  ((1650, 250), None),
    "dijiao":   ((1650, 1762), None),
    "waikuang": ((2135, 1350), (2081, 1350)),
    "jielan":   ((1905, 1300), (1958, 1300)),
    "banxin":   ((1178, 1560), None),
    "yuwei":    (("inset", 110, 385), ("inset", 75, 385)),
    "banxin_title": (("inset", 110, 175), ("inset", 62, 175)),
    "banxin_juan":  (("inset", 110, 580), ("inset", 52, 580)),
    "banxin_page":  (("inset", 110, 1040), ("inset", 70, 1040)),
    "shuer":    ((236, 700), (236, 640)),
    "zhengwen": ((1800, 1530), (1722, 1530)),
    "jiazhu":   ((1800, 1340), (1738, 1340)),
    "judou":    ((1795, 585), (1740, 585)),
    "cepi":     ((1322, 345), (1322, 418)),
    "meipi":    ((1925, 120), (1962, 150)),
    "yinzhang": ((440, 1570), (440, 1520)),
}

# 图例分组与顺序（编号按此顺序生成）
GROUPS = [
    ("frame",  ["tiantou", "dijiao", "waikuang", "jielan"]),
    ("banxin", ["banxin", "yuwei", "banxin_title", "banxin_juan", "banxin_page", "shuer"]),
    ("text",   ["zhengwen", "jiazhu", "judou", "cepi", "meipi"]),
    ("other",  ["yinzhang"]),
]

GROUP_TITLES = {
    "zh": {"frame": "版面", "banxin": "版心（左侧为放大图）", "text": "正文与注释", "other": "其他"},
    "en": {"frame": "Page frame", "banxin": "Centre strip (enlarged at left)",
           "text": "Text and notes", "other": "Other"},
}

LABELS = {
    "zh": {
        "tiantou":  ("天头", r"\页面设置{上边距}"),
        "dijiao":   ("地脚", r"\页面设置{下边距}"),
        "waikuang": ("版框（边栏）", r"\内容设置{外边框}"),
        "jielan":   ("界栏（行线）", r"\内容设置{边框}"),
        "banxin":   ("版心", r"\版心设置{版心}"),
        "yuwei":    ("鱼尾", r"\版心设置{上鱼尾, 下鱼尾}"),
        "banxin_title": ("版心书名", r"\title"),
        "banxin_juan":  ("版心篇名／卷次", r"\chapter"),
        "banxin_page":  ("页码", r"\版心设置{页码}"),
        "shuer":    ("书耳", r"\版心设置{书耳}"),
        "zhengwen": ("正文大字（半叶 8 行，行 21 字）", r"正文 环境；\内容设置{行数, 每行字数}"),
        "jiazhu":   ("夹注（双行小字）", r"\夹注"),
        "judou":    ("句读", r"\开启句读模式"),
        "cepi":     ("侧批", r"\侧批"),
        "meipi":    ("眉批", r"\眉批"),
        "yinzhang": ("钤印", r"\印章"),
    },
    "en": {
        "tiantou":  ("Head margin (tiantou)", r"\pageSetup{margin-top}"),
        "dijiao":   ("Foot margin (dijiao)", r"\pageSetup{margin-bottom}"),
        "waikuang": ("Frame (bianlan)", r"\contentSetup{outer-border}"),
        "jielan":   ("Column rules (jielan)", r"\contentSetup{border}"),
        "banxin":   ("Centre strip (banxin)", r"\banxinSetup{banxin}"),
        "yuwei":    ("Fishtail (yuwei)", r"\banxinSetup{upper-yuwei, lower-yuwei}"),
        "banxin_title": ("Book title in banxin", r"\title"),
        "banxin_juan":  ("Chapter in banxin", r"\chapter"),
        "banxin_page":  ("Leaf number", r"\banxinSetup{page-number}"),
        "shuer":    ("Book ear (shu'er)", r"\banxinSetup{book-ear}"),
        "zhengwen": ("Main text (8 columns x 21 chars)", r"BodyText; \contentSetup{n-column, n-char-per-col}"),
        "jiazhu":   ("Interlinear note (jiazhu)", r"\JiaZhu"),
        "judou":    ("Judou marks", r"\JudouPunctuationMode"),
        "cepi":     ("Side note (cepi)", r"\Sidenote"),
        "meipi":    ("Head note (meipi)", r"\MeiPi"),
        "yinzhang": ("Seal", r"\YinZhang"),
    },
}


def render_page(workdir: Path) -> Image.Image:
    shutil.copy(HERE / "anatomy.tex", workdir)
    shutil.copy(SEAL, workdir)
    env = dict(os.environ)
    env["OSFONTDIR"] = str(FONTS) + os.pathsep + env.get("OSFONTDIR", "")
    subprocess.run(["lualatex", "-interaction=nonstopmode", "anatomy.tex"],
                   cwd=workdir, env=env, check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["pdftoppm", "-r", str(DPI), "-png", "-singlefile",
                    "anatomy.pdf", "page"], cwd=workdir, check=True)
    return Image.open(workdir / "page.png").convert("RGB")


def draw_figure(page: Image.Image, lang: str) -> Image.Image:
    W, H = page.size
    canvas = Image.new("RGB", (LEFT + W + RIGHT, H), "white")
    canvas.paste(page, (LEFT, 0))
    d = ImageDraw.Draw(canvas)
    num_font = ImageFont.truetype(str(LABEL_FONT), 26)
    group_font = ImageFont.truetype(str(LABEL_FONT), 30)
    name_font = ImageFont.truetype(str(LABEL_FONT), 32)
    cmd_font = ImageFont.truetype(str(LABEL_FONT), 24)

    # 版心放大图 + 原位置的虚线框
    inset = page.crop(BANXIN_CROP)
    inset = inset.resize((round(inset.width * INSET_SCALE), round(inset.height * INSET_SCALE)),
                         Image.LANCZOS)
    canvas.paste(inset, (INSET_X, INSET_Y))
    d.rectangle([INSET_X - 2, INSET_Y - 2, INSET_X + inset.width + 1, INSET_Y + inset.height + 1],
                outline=RED, width=3)
    x0, y0, x1, y1 = BANXIN_CROP
    dashed_rect(d, (x0 + LEFT, y0, x1 + LEFT, y1), RED)

    def to_canvas(p):
        if p[0] == "inset":
            return INSET_X + p[1] * INSET_SCALE, INSET_Y + p[2] * INSET_SCALE
        return p[0] + LEFT, p[1]

    def marker(cx, cy, n):
        d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=RED, outline="white", width=3)
        d.text((cx, cy), str(n), font=num_font, fill="white", anchor="mm")

    order = [k for _, keys in GROUPS for k in keys]
    for n, key in enumerate(order, 1):
        centre, end = MARKS[key]
        cx, cy = to_canvas(centre)
        if end is not None:
            ex, ey = to_canvas(end)
            d.line([(cx, cy), (ex, ey)], fill=RED, width=4)
            d.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=RED)
        marker(cx, cy, n)

    # 图例
    lx = LEFT + W + 40
    y = 40
    n = 1
    for group, keys in GROUPS:
        d.text((lx, y), GROUP_TITLES[lang][group], font=group_font, fill=RED)
        y += 56
        for key in keys:
            name, cmd = LABELS[lang][key]
            marker(lx + R, y + 18, n)
            d.text((lx + 2 * R + 18, y), name, font=name_font, fill="black")
            d.text((lx + 2 * R + 18, y + 44), cmd, font=cmd_font, fill=GRAY)
            y += 88
            n += 1
        y += 14
    return canvas


def dashed_rect(d, box, fill, dash=14, gap=8, width=3):
    x0, y0, x1, y1 = box
    for (a, b) in [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]:
        (ax, ay), (bx, by) = a, b
        length = max(abs(bx - ax), abs(by - ay))
        steps = int(length // (dash + gap)) + 1
        for i in range(steps):
            s = i * (dash + gap) / length
            e = min((i * (dash + gap) + dash) / length, 1)
            d.line([(ax + (bx - ax) * s, ay + (by - ay) * s), (ax + (bx - ax) * e, ay + (by - ay) * e)],
                   fill=fill, width=width)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        page = render_page(Path(tmp))
    for lang in ("zh", "en"):
        out = HERE / f"anatomy-{lang}.png"
        # 64 色调色板：约 0.3 MB，肉眼无差别（原 RGB 约 0.85 MB）
        img = draw_figure(page, lang).quantize(colors=64, method=Image.Quantize.MEDIANCUT)
        img.save(out, optimize=True)
        print("wrote", out.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
