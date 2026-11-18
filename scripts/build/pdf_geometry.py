"""从 luatex-cn 编译出的 PDF 里取出画出来的线框与字形位置（issue #195）。

只做本项目输出用得到的那一小部分 PDF 解释：q/Q/cm 变换栈、w 线宽、RG/rg 颜色、
re/m/l/h 路径、S/f 绘制，以及 BT…ET 里的 Tm/Tf 字形定位。坐标一律换算成 pt，
原点在页面左上角，y 向下（与 \\pageSetup 的边距方向一致）。

只用标准库（zlib/re）。
"""

import re
import zlib
from dataclasses import dataclass, field

BP_TO_PT = 72.27 / 72.0
STREAM_RE = re.compile(rb"stream\r?\n(.*?)endstream", re.DOTALL)
MEDIABOX_RE = re.compile(rb"/MediaBox\s*\[\s*([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)\s*\]")
TOKEN_RE = re.compile(rb"\[(?:[^\]\\]|\\.)*\]|\((?:[^)\\]|\\.)*\)|<[0-9A-Fa-f\s]*>|/[^\s/\[\]()<>]+|[^\s/\[\]()<>]+")


@dataclass
class Shape:
    """一次 S（描边）或 f（填充）画出的路径。"""
    op: str                      # "S" 或 "f"
    width: float                 # 线宽（pt，按变换缩放后）
    color: tuple                 # 描边色（S）或填充色（f），0–1
    rects: list = field(default_factory=list)     # [(x0, y0, x1, y1)]，pt，y 向下
    points: list = field(default_factory=list)    # 折线各点 [(x, y)]

    @property
    def bbox(self):
        xs, ys = [], []
        for x0, y0, x1, y1 in self.rects:
            xs += [x0, x1]
            ys += [y0, y1]
        for x, y in self.points:
            xs.append(x)
            ys.append(y)
        return (min(xs), min(ys), max(xs), max(ys)) if xs else None


@dataclass
class Glyph:
    x: float        # 基线起点 x（pt）
    y: float        # 基线 y（pt，向下）
    size: float     # 字号（pt）


@dataclass
class PageGeometry:
    width: float
    height: float
    shapes: list
    glyphs: list

    def strokes(self, width=None, tol=0.05):
        return [s for s in self.shapes
                if s.op == "S" and (width is None or abs(s.width - width) <= tol)]

    def stroke_rects(self, width=None, tol=0.05):
        out = []
        for s in self.strokes(width, tol):
            out += s.rects
        return out


def _mul(a, b):
    """仿射矩阵相乘：先 a 后 b（PDF 约定 CTM' = M × CTM）。"""
    a0, a1, a2, a3, a4, a5 = a
    b0, b1, b2, b3, b4, b5 = b
    return (a0 * b0 + a1 * b2, a0 * b1 + a1 * b3,
            a2 * b0 + a3 * b2, a2 * b1 + a3 * b3,
            a4 * b0 + a5 * b2 + b4, a4 * b1 + a5 * b3 + b5)


def _apply(m, x, y):
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])


def _page_streams(pdf):
    for m in STREAM_RE.finditer(pdf):
        data = m.group(1)
        try:
            data = zlib.decompress(data)
        except zlib.error:
            pass
        if b" cm" in data or b" re" in data or b"Tm" in data:
            yield data


def parse(pdf_path, page_index=0):
    """解析第 page_index 页（按内容流出现顺序，适用于本项目单流页面）。"""
    with open(pdf_path, "rb") as f:
        pdf = f.read()
    mb = MEDIABOX_RE.search(pdf)
    if mb is None:  # 页面对象在压缩的对象流里
        for m in STREAM_RE.finditer(pdf):
            try:
                mb = MEDIABOX_RE.search(zlib.decompress(m.group(1)))
            except zlib.error:
                continue
            if mb:
                break
    w_bp, h_bp = float(mb.group(3)), float(mb.group(4))
    streams = list(_page_streams(pdf))
    data = streams[page_index]
    shapes, glyphs = _interpret(data, h_bp)
    return PageGeometry(w_bp * BP_TO_PT, h_bp * BP_TO_PT, shapes, glyphs)


def _interpret(data, h_bp):
    def to_pt(x, y):
        return (x * BP_TO_PT, (h_bp - y) * BP_TO_PT)

    ctm = (1, 0, 0, 1, 0, 0)
    stack = []
    lw = 1.0
    stroke_rgb = (0, 0, 0)
    fill_rgb = (0, 0, 0)
    path_rects, path_points = [], []
    shapes, glyphs = [], []
    operands = []
    in_text = False
    font_size = 0.0

    for tok in TOKEN_RE.findall(data):
        try:
            operands.append(float(tok))
            continue
        except ValueError:
            pass
        op = tok.decode("latin1")
        if op[0] in "[(</":
            operands.append(op)
            continue
        if in_text:
            if op == "Tf" and len(operands) >= 2:
                font_size = float(operands[-1])
            elif op == "Tm" and len(operands) >= 6:
                a, b, c, d, e, f = operands[-6:]
                tm = _mul((a, b, c, d, e, f), ctm)
                x, y = to_pt(tm[4], tm[5])
                scale = (tm[0] ** 2 + tm[1] ** 2) ** 0.5
                glyphs.append(Glyph(x, y, font_size * scale * BP_TO_PT))
            elif op == "ET":
                in_text = False
            operands = []
            continue
        if op == "BT":
            in_text = True
        elif op == "q":
            stack.append((ctm, lw, stroke_rgb, fill_rgb))
        elif op == "Q":
            if stack:
                ctm, lw, stroke_rgb, fill_rgb = stack.pop()
        elif op == "cm" and len(operands) >= 6:
            ctm = _mul(tuple(operands[-6:]), ctm)
        elif op == "w" and operands:
            lw = operands[-1]
        elif op == "RG" and len(operands) >= 3:
            stroke_rgb = tuple(operands[-3:])
        elif op == "rg" and len(operands) >= 3:
            fill_rgb = tuple(operands[-3:])
        elif op == "re" and len(operands) >= 4:
            x, y, w, h = operands[-4:]
            p0 = to_pt(*_apply(ctm, x, y))
            p1 = to_pt(*_apply(ctm, x + w, y + h))
            path_rects.append((min(p0[0], p1[0]), min(p0[1], p1[1]),
                               max(p0[0], p1[0]), max(p0[1], p1[1])))
        elif op in ("m", "l") and len(operands) >= 2:
            path_points.append(to_pt(*_apply(ctm, operands[-2], operands[-1])))
        elif op in ("S", "s", "f", "f*", "F", "B", "b"):
            if path_rects or path_points:
                scale = (abs(ctm[0] * ctm[3] - ctm[1] * ctm[2])) ** 0.5
                kind = "S" if op in ("S", "s") else "f"
                shapes.append(Shape(kind, lw * scale * BP_TO_PT,
                                    stroke_rgb if kind == "S" else fill_rgb,
                                    path_rects, path_points))
            path_rects, path_points = [], []
        elif op == "n":
            path_rects, path_points = [], []
        operands = []
    return shapes, glyphs
