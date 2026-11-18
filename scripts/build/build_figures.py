#!/usr/bin/env python3
"""参数标注图：在真实排版结果上画工程图式的尺寸线（issue #195 第二步）。

    python3 scripts/build/build_figures.py          # 生成 资源/wiki-figures/params/*.png
    python3 scripts/build/build_figures.py --check  # 只做自校验，不出图（CI 用）

流程：编译 资源/wiki-figures/params/params.tex → 解析 PDF 里实际画出的线框与字形
（scripts/build/pdf_geometry.py）→ 断言每个尺寸「量出来的值 = 参数设定值」，
以及格宽、格高的推导公式 → 再在 PDF 渲染图上画尺寸线和标签。

所以这些图不会悄悄过期：渲染算法一改，量出来的值和参数对不上，脚本就报错。

依赖：lualatex、pdftoppm、Pillow（--check 不需要 Pillow/pdftoppm）；
字体同回归测试，经 OSFONTDIR 用 test/fonts/（先运行 scripts/download_test_fonts.sh）。
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import pdf_geometry  # noqa: E402

SRC_DIR = ROOT / "资源" / "wiki-figures" / "params"
FONTS = ROOT / "test" / "fonts"
LABEL_FONT = FONTS / "SourceHanSerifSC-Regular.otf"
TOL = 0.05  # pt

# 与 params.tex 一致的参数值（pt）
PARAMS = {
    "paper-width": 1136.0,
    "paper-height": 894.6,
    "margin-top": 190.5,
    "margin-bottom": 91.6,
    "margin-left": 133.2,
    "margin-right": 133.2,
    "n-column": 8,
    "n-char-per-col": 21,
    "border-thickness": 0.4,
    "outer-border-thickness": 4.0,
    "outer-border-sep": 3.0,
    "banxin-ratio": 0.7,
    "banxin-upper-ratio": 0.282,
    "banxin-middle-ratio": 0.563,
    "padding-top": 5.0,
    "padding-bottom": 5.0,
}

NAMES = {  # key -> (中文键, 英文键)
    "paper-width": ("纸宽", "paper-width"),
    "paper-height": ("纸高", "paper-height"),
    "margin-top": ("上边距", "margin-top"),
    "margin-bottom": ("下边距", "margin-bottom"),
    "margin-left": ("左边距", "margin-left"),
    "margin-right": ("右边距", "margin-right"),
    "outer-border-thickness": ("外边框粗细", "outer-border-thickness"),
    "outer-border-sep": ("外边框间距", "outer-border-sep"),
    "padding-top": ("上填充", "padding-top"),
    "grid-width": ("格宽", "grid-width"),
    "grid-height": ("格高", "grid-height"),
    "banxin-width": ("版心宽 = 版心比例 × 格宽", "banxin width = banxin-ratio × grid-width"),
    "banxin-upper": ("版心上比 × 版心高", "banxin-upper-ratio × height"),
    "banxin-middle": ("版心中比 × 版心高", "banxin-middle-ratio × height"),
}


class Geometry:
    """从 PDF 量出的各要素（pt，原点左上，y 向下）。"""

    def __init__(self, page):
        self.page = page
        P = PARAMS
        ob = page.stroke_rects(P["outer-border-thickness"], 0.1)
        if len(ob) != 1:
            raise SystemExit(f"找不到唯一的外边框（线宽 {P['outer-border-thickness']}pt），找到 {len(ob)} 个")
        half_ob = P["outer-border-thickness"] / 2
        x0, y0, x1, y1 = ob[0]
        self.outer_out = (x0 - half_ob, y0 - half_ob, x1 + half_ob, y1 + half_ob)
        self.outer_in = (x0 + half_ob, y0 + half_ob, x1 - half_ob, y1 - half_ob)

        rects = sorted(set(page.stroke_rects(P["border-thickness"], 0.02)))
        # 界栏：与外框同高的列框；版心是其中最窄的那一列
        tall = [r for r in rects if abs((r[3] - r[1]) - (rects[-1][3] - rects[-1][1])) < 0.5]
        widths = sorted(round(r[2] - r[0], 3) for r in tall)
        self.banxin = min(tall, key=lambda r: r[2] - r[0])
        self.columns = sorted((r for r in tall if r != self.banxin), key=lambda r: r[0])
        self.grid_width = self.columns[-1][2] - self.columns[-1][0]
        hb = P["border-thickness"] / 2
        self.rule_top_in = self.columns[-1][1] + hb       # 界栏框上边线内侧
        self.rule_top_out = self.columns[-1][1] - hb
        self.rule_right_out = self.columns[-1][2] + hb    # 最右一列的外侧

        # 版心分隔线：横跨版心宽度的水平线
        bx0, by0, bx1, by1 = self.banxin
        divs = []
        for s in page.shapes:
            if s.op == "S" and len(s.points) == 2:
                (ax, ay), (cx, cy) = s.points
                if abs(ay - cy) < 0.01 and abs(ax - bx0) < 0.1 and abs(cx - bx1) < 0.1:
                    divs.append(ay)
        if len(divs) < 2:
            raise SystemExit(f"版心分隔线应有 2 条，找到 {len(divs)} 条")
        self.dividers = sorted(divs)[:2]
        self.yuwei = [s.bbox for s in page.shapes if s.op == "f"
                      and s.bbox[0] >= bx0 - 0.1 and s.bbox[2] <= bx1 + 0.1]

        # 正文字（最大字号），按列分组求格高
        size = max(g.size for g in page.glyphs)
        cols = {}
        for g in page.glyphs:
            if abs(g.size - size) < 0.1:
                cols.setdefault(round(g.x, 1), []).append(g.y)
        steps = []
        for ys in cols.values():
            ys = sorted(ys)
            steps += [b - a for a, b in zip(ys, ys[1:])]
        # 众数（夹注、句读等会让个别间距不同）
        self.grid_height = max(set(round(s, 3) for s in steps), key=lambda v: sum(abs(s - v) < 0.01 for s in steps))
        self.body_size = size
        # 最右一列（首列）的字
        right_x = max(cols)
        self.first_col_baselines = sorted(cols[right_x])
        self.first_col_x = right_x


def checks(g):
    """返回 [(说明, 量出的值, 期望值)]。"""
    P = PARAMS
    oo, oi = g.outer_out, g.outer_in
    W, H = g.page.width, g.page.height
    pad = P["outer-border-thickness"] + P["outer-border-sep"]
    bt = P["border-thickness"]
    n_cols = 2 * P["n-column"] + P["banxin-ratio"]
    bx0, by0, bx1, by1 = g.banxin
    bh = by1 - by0
    return [
        ("纸宽 paper-width", W, P["paper-width"]),
        ("纸高 paper-height", H, P["paper-height"]),
        ("上边距 margin-top：纸边 → 外框外缘", oo[1], P["margin-top"]),
        ("下边距 margin-bottom", H - oo[3], P["margin-bottom"]),
        ("左边距 margin-left", oo[0], P["margin-left"]),
        ("右边距 margin-right", W - oo[2], P["margin-right"]),
        ("外边框粗细 outer-border-thickness", oi[0] - oo[0], P["outer-border-thickness"]),
        ("外边框间距 outer-border-sep：外框内缘 → 界栏外缘（上）", g.rule_top_out - oi[1], P["outer-border-sep"]),
        ("外边框间距 outer-border-sep（右）", oi[2] - g.rule_right_out, P["outer-border-sep"]),
        ("格宽 = (纸宽 − 左右边距 − 2×(外框粗细+外框间距) − 边框粗细) / (2×行数 + 版心比例)",
         g.grid_width,
         (P["paper-width"] - P["margin-left"] - P["margin-right"] - 2 * pad - bt) / n_cols),
        ("格高 = (纸高 − 上下边距 − 2×(外框粗细+外框间距) − 边框粗细 − 上下填充) / 每行字数",
         g.grid_height,
         (P["paper-height"] - P["margin-top"] - P["margin-bottom"] - 2 * pad - bt
          - P["padding-top"] - P["padding-bottom"]) / P["n-char-per-col"]),
        ("版心宽 = 版心比例 × 格宽", bx1 - bx0, P["banxin-ratio"] * g.grid_width),
        ("版心上段 = 版心上比 × 版心高", g.dividers[0] - by0, P["banxin-upper-ratio"] * bh),
        ("版心中段 = 版心中比 × 版心高", g.dividers[1] - g.dividers[0], P["banxin-middle-ratio"] * bh),
    ]


def compile_pdf(workdir):
    shutil.copy(SRC_DIR / "params.tex", workdir)
    env = dict(os.environ)
    env["OSFONTDIR"] = str(FONTS) + os.pathsep + env.get("OSFONTDIR", "")
    r = subprocess.run(["lualatex", "-interaction=nonstopmode", "params.tex"],
                       cwd=workdir, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    pdf = Path(workdir) / "params.pdf"
    if r.returncode != 0 or not pdf.exists():
        sys.stdout.write(r.stdout.decode("utf-8", "replace")[-3000:])
        raise SystemExit("params.tex 编译失败")
    return pdf


def run_checks(g):
    ok = True
    for desc, got, want in checks(g):
        good = abs(got - want) <= TOL
        ok &= good
        print(f"  {'ok  ' if good else 'FAIL'} {desc}: 量得 {got:.3f}pt，应为 {want:.3f}pt")
    return ok


# ---------------------------------------------------------------------------
# 画图
# ---------------------------------------------------------------------------

BLUE = (20, 80, 190)
FAINT = (120, 160, 230)


class Canvas:
    """把页面某区域（pt）按 scale 放大贴到画布上，并提供尺寸线绘制。"""

    def __init__(self, page_png, dpi, region, scale, pad):
        from PIL import Image, ImageDraw, ImageFont
        self.ImageFont = ImageFont
        x0, y0, x1, y1 = region
        k = dpi / 72.27
        img = Image.open(page_png).convert("RGB")
        crop = img.crop((round(x0 * k), round(y0 * k), round(x1 * k), round(y1 * k)))
        self.s = scale * k / k  # px per pt after resize
        w = round((x1 - x0) * scale)
        h = round((y1 - y0) * scale)
        crop = crop.resize((w, h), Image.LANCZOS)
        self.pad = pad  # (left, top, right, bottom)
        self.img = Image.new("RGB", (w + pad[0] + pad[2], h + pad[1] + pad[3]), "white")
        self.img.paste(crop, (pad[0], pad[1]))
        self.d = ImageDraw.Draw(self.img)
        self.region = region
        self.scale = scale
        self.font = ImageFont.truetype(str(LABEL_FONT), 30)
        self.small = ImageFont.truetype(str(LABEL_FONT), 24)

    def P(self, x, y):
        return (self.pad[0] + (x - self.region[0]) * self.scale,
                self.pad[1] + (y - self.region[1]) * self.scale)

    def outline(self, color=(170, 170, 170)):
        x0, y0 = self.P(self.region[0], self.region[1])
        x1, y1 = self.P(self.region[2], self.region[3])
        self.d.rectangle([x0, y0, x1, y1], outline=color, width=2)

    def _arrow(self, tip, direction):
        x, y = tip
        dx, dy = direction
        L, Wd = 16, 6
        bx, by = x - dx * L, y - dy * L
        px, py = -dy * Wd, dx * Wd
        self.d.polygon([(x, y), (bx + px, by + py), (bx - px, by - py)], fill=BLUE)

    def _label(self, text, mid, default_xy, label_at):
        if label_at is None:
            self.d.text(default_xy, text, font=self.font, fill=BLUE)
            return
        lx, ly = self.P(*label_at)
        tw = self.d.textlength(text, font=self.font)
        end = (lx - 6, ly) if lx >= mid[0] else (lx + tw + 6, ly)
        self.d.line([mid, end], fill=BLUE, width=2)
        self.d.text((lx, ly - 20), text, font=self.font, fill=BLUE)

    def dim_h(self, y, xa, xb, label, side="above", ext_from=None, outside=False, label_at=None):
        """水平尺寸：在页面 y 处量 xa→xb。ext_from: 引出线起点 y；label_at: 标签位置（页面坐标）。"""
        (ax, ay), (bx, _) = self.P(xa, y), self.P(xb, y)
        if ext_from is not None:
            for x in (xa, xb):
                px, py0 = self.P(x, ext_from)
                self.d.line([(px, py0), (px, ay)], fill=FAINT, width=2)
        self._dim_line((ax, ay), (bx, ay), outside)
        tw = self.d.textlength(label, font=self.font)
        cx = (ax + bx) / 2
        if outside:
            xy = (max(ax, bx) + 50, ay - 20)
        else:
            xy = (cx - tw / 2, ay - 44 if side == "above" else ay + 8)
        mid = (max(ax, bx) + (40 if outside else 0), ay)
        self._label(label, mid, xy, label_at)

    def dim_v(self, x, ya, yb, label, side="right", ext_from=None, outside=False, label_at=None):
        (ax, ay), (_, by) = self.P(x, ya), self.P(x, yb)
        if ext_from is not None:
            for y in (ya, yb):
                px0, py = self.P(ext_from, y)
                self.d.line([(px0, py), (ax, py)], fill=FAINT, width=2)
        self._dim_line((ax, ay), (ax, by), outside)
        tw = self.d.textlength(label, font=self.font)
        cy = (ay + by) / 2
        tx = ax + 14 if side == "right" else ax - 14 - tw
        self._label(label, (ax, cy), (tx, cy - 20), label_at)

    def _dim_line(self, a, b, outside):
        (ax, ay), (bx, by) = a, b
        L = ((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 or 1
        ux, uy = (bx - ax) / L, (by - ay) / L
        if outside:  # 尺寸太小：箭头从外面指进来
            self.d.line([(ax - ux * 40, ay - uy * 40), (bx + ux * 40, by + uy * 40)], fill=BLUE, width=3)
            self._arrow((ax, ay), (ux, uy))
            self._arrow((bx, by), (-ux, -uy))
        else:
            self.d.line([a, b], fill=BLUE, width=3)
            self._arrow((ax, ay), (-ux, -uy))
            self._arrow((bx, by), (ux, uy))

    def note(self, xy, text, font=None, fill=(60, 60, 60)):
        self.d.text(xy, text, font=font or self.small, fill=fill)


def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".") + "pt"


def label(key, lang, value=None, derived=False):
    zh, en = NAMES[key]
    name = zh if lang == "zh" else en
    if value is None:
        return name
    return f"{name} {fmt(value)}" if derived else f"{name} = {fmt(value)}"


def fig_page(png, dpi, g, lang):
    P = PARAMS
    W, H = g.page.width, g.page.height
    c = Canvas(png, dpi, (0, 0, W, H), 1.6, (330, 170, 380, 90))
    c.outline()
    oo = g.outer_out
    # 纸宽 / 纸高
    c.dim_h(-60, 0, W, label("paper-width", lang, P["paper-width"]), ext_from=0)
    c.dim_v(-30, 0, H, label("paper-height", lang, P["paper-height"]), side="left", ext_from=0)
    # 四边距
    mx = (oo[0] + oo[2]) / 2 + 150
    c.dim_v(mx, 0, oo[1], label("margin-top", lang, P["margin-top"]))
    c.dim_v(mx, oo[3], H, label("margin-bottom", lang, P["margin-bottom"]))
    my = oo[1] + 100
    c.dim_h(my, 0, oo[0], label("margin-left", lang, P["margin-left"]), side="above")
    c.dim_h(my, oo[2], W, label("margin-right", lang, P["margin-right"]), side="above")
    note = ("边距量到外边框的外缘；内容区 = 纸张 − 四边距" if lang == "zh"
            else "Margins are measured to the outer edge of the frame; content area = paper − margins")
    c.note((c.pad[0], c.img.height - 60), note, font=c.font)
    return c.img


def fig_frame(png, dpi, g, lang):
    P = PARAMS
    oo, oi = g.outer_out, g.outer_in
    right = g.columns[-1]
    region = (right[0] - 60, oo[1] - 22, oo[2] + 24, oo[1] + 110)
    c = Canvas(png, dpi, region, 9, (40, 40, 880, 40))
    c.outline()
    # 格子（最右一列）：虚线标出每格
    top_cell = g.rule_top_in + P["padding-top"]
    for k in range(0, 4):
        yy = top_cell + k * g.grid_height
        a, b = c.P(right[0], yy), c.P(right[2], yy)
        x = a[0]
        while x < b[0]:
            c.d.line([(x, a[1]), (min(x + 14, b[0]), a[1])], fill=FAINT, width=2)
            x += 24
    lx = oo[2] + 8          # 右侧标签栏（页面坐标）
    # 外边框粗细、外边框间距（右侧，水平量；尺寸太小，箭头从外面指进来）
    c.dim_h(oo[1] + 22, oo[2] - P["outer-border-thickness"], oo[2],
            label("outer-border-thickness", lang, P["outer-border-thickness"]), outside=True,
            label_at=(lx, oo[1] + 22))
    c.dim_h(oo[1] + 38, g.rule_right_out, oi[2],
            label("outer-border-sep", lang, P["outer-border-sep"]), outside=True,
            label_at=(lx, oo[1] + 38))
    # 上填充（竖直，最右列内；标签放到天头空白里）
    xC = right[0] + 10
    c.dim_v(xC, g.rule_top_in, top_cell, label("padding-top", lang, P["padding-top"]),
            outside=True, label_at=(right[0] + 20, oo[1] - 12))
    # 格高（最右列第二格）
    xD = right[2] - 6
    c.dim_v(xD, top_cell + g.grid_height, top_cell + 2 * g.grid_height,
            label("grid-height", lang, g.grid_height, derived=True),
            label_at=(lx, top_cell + 1.5 * g.grid_height))
    # 格宽
    yW = top_cell + 2 * g.grid_height + 5
    c.dim_h(yW, right[0], right[2], label("grid-width", lang, g.grid_width, derived=True),
            label_at=(lx, yW))
    lines = (["格宽、格高由版面算出，不必直接设置：",
              "格宽 = (纸宽 − 左右边距 − 2×(外边框粗细+外边框间距) − 边框粗细)",
              "　　　÷ (2×行数 + 版心比例)",
              "格高 = (纸高 − 上下边距 − 2×(外边框粗细+外边框间距) − 边框粗细",
              "　　　− 上填充 − 下填充) ÷ 每行字数"]
             if lang == "zh" else
             ["Grid width and height are derived, not set:",
              "grid-width = (paper-width − left/right margins",
              "  − 2×(outer-border-thickness + outer-border-sep)",
              "  − border-thickness) ÷ (2×n-column + banxin-ratio)",
              "grid-height = (paper-height − top/bottom margins",
              "  − 2×(outer-border-thickness + outer-border-sep)",
              "  − border-thickness − padding-top − padding-bottom) ÷ n-char-per-col"])
    x = c.img.width - c.pad[2] + 30
    y = c.pad[1] + 10
    for i, t in enumerate(lines):
        c.note((x, y + i * 40), t, font=c.small if i else c.font, fill=(40, 40, 40))
    return c.img


def fig_banxin(png, dpi, g, lang):
    P = PARAMS
    bx0, by0, bx1, by1 = g.banxin
    region = (bx0 - 3, by0 - 6, bx1 + 3, by1 + 6)
    c = Canvas(png, dpi, region, 2.2, (60, 150, 600, 40))
    c.outline()
    d1, d2 = g.dividers
    xr = bx1 + 30
    c.dim_v(xr, by0, d1, label("banxin-upper", lang) + f"  ({P['banxin-upper-ratio']})", ext_from=bx1)
    c.dim_v(xr, d1, d2, label("banxin-middle", lang) + f"  ({P['banxin-middle-ratio']})", ext_from=bx1)
    rest = "下段 = 其余" if lang == "zh" else "lower part = the rest"
    c.dim_v(xr, d2, by1, rest, ext_from=bx1)
    c.dim_h(by0 - 14, bx0, bx1, label("banxin-width", lang, bx1 - bx0, derived=True),
            label_at=(bx1 + 30, by0 - 30), ext_from=by0)
    if g.yuwei:
        yx0, yy0, yx1, yy1 = g.yuwei[0]
        name = "鱼尾（上鱼尾）" if lang == "zh" else "fishtail (upper-yuwei)"
        c._label(name, c.P(bx1, (yy0 + yy1) / 2), None, (xr + 40, yy1 + 40))
    hint = ("版心高 = 界栏高；上比、中比是占版心高的比例" if lang == "zh"
            else "Ratios are fractions of the strip height")
    c.note((c.pad[0], 20), hint, font=c.font, fill=(40, 40, 40))
    return c.img


FIGURES = [("page", fig_page, 72.27 * 1.6), ("frame", fig_frame, 72.27 * 9),
           ("banxin", fig_banxin, 72.27 * 2.2)]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="只做自校验，不出图")
    args = ap.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        pdf = compile_pdf(tmp)
        g = Geometry(pdf_geometry.parse(str(pdf)))
        print("参数标注图自校验：")
        if not run_checks(g):
            raise SystemExit("自校验失败：文档里说的参数含义与实际排版不符，先查清再出图")
        if args.check:
            return 0
        from PIL import Image
        for name, fn, dpi in FIGURES:
            png = Path(tmp) / f"{name}.png"
            subprocess.run(["pdftoppm", "-r", f"{dpi:.2f}", "-png", "-singlefile", str(pdf),
                            str(png.with_suffix(""))], check=True)
            for lang in ("zh", "en"):
                out = SRC_DIR / f"{name}-{lang}.png"
                img = fn(png, dpi, g, lang)
                img.quantize(colors=64, method=Image.Quantize.MEDIANCUT).save(out, optimize=True)
                print("wrote", out.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
