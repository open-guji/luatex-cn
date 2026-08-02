#!/usr/bin/env python3
"""clreq 断言测试：解析横排 PDF 内容流，对字距/禁则做规范符合性断言。

与像素回归测试互补（差距分析 R3）：像素基线只能保证「和上次一样」，
本测试直接度量「行末逗号占多宽」「中西间距是否在 clreq 区间内」等
规范量。每条断言注明对应的 clreq 条款。

原理：
  1. 以未压缩模式（objcompresslevel=0, compresslevel=0）编译测试文档，
     使字体对象与 ToUnicode CMap 可直接用正则解析——零第三方依赖。
  2. 从 /W 数组取每个 CID 的 advance，从 ToUnicode 取 CID→Unicode；
     用小型解释器跟踪 q/Q 栈、cm 级联与 Tm 矩阵，重建每个字形的
     设备坐标（TJ 数字为千分 em 位移，正数向左——挤压即体现为正数）；
     被 cm 缩放的字形（如脚注标号组）也能读到真实位置与有效字号。
  3. 相邻字形的间隙 gap = 下一字 x 起点 − 上一字 x 终点（em）。

用法：
    python3 test/clreq_test.py               # 编译并检查默认测试文件
    python3 test/clreq_test.py file.pdf      # 直接检查已有 PDF（须未压缩）

仅用标准库（re/subprocess/tempfile），无第三方依赖。
"""

import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_TEX = os.path.join(
    REPO_ROOT, "test", "regression_test", "basic", "tex", "hori.tex")
STRESS_TEX = os.path.join(
    REPO_ROOT, "test", "clreq_test", "stress-unbreakable.tex")
TAIWAN_TEX = os.path.join(
    REPO_ROOT, "test", "regression_test", "basic", "tex", "hori-taiwan.tex")
VERTICAL_TEX = os.path.join(
    REPO_ROOT, "test", "clreq_test", "vert-punct.tex")
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

# 坐标/宽度舍入容差（em）。sp 取整与 PDF 三位小数远小于此。
EPS = 0.01


# ============================================================================
# PDF 解析
# ============================================================================

class Glyph:
    __slots__ = ("char", "x0", "x1", "em")

    def __init__(self, char, x0, x1, em):
        self.char = char    # str（可能是多码位，取首字符即可）
        self.x0 = x0        # 行内起点 pt
        self.x1 = x1        # 行内终点（起点+advance）pt
        self.em = em        # 字号 pt

    def __repr__(self):
        return f"{self.char}@{self.x0:.2f}"


class Line:
    def __init__(self, y, page=1):
        self.y = y
        self.page = page
        self.glyphs = []

    @property
    def text(self):
        return "".join(g.char for g in self.glyphs)

    def gap_em(self, i):
        """第 i 与 i+1 个字形之间的间隙（em，可为负=压入前字空白）。"""
        a, b = self.glyphs[i], self.glyphs[i + 1]
        return (b.x0 - a.x1) / a.em


def parse_tounicode(cmap_bytes):
    """解析 ToUnicode CMap，返回 {cid: unicode_str}。"""
    out = {}
    for m in re.finditer(rb"beginbfchar(.*?)endbfchar", cmap_bytes, re.DOTALL):
        for src, dst in re.findall(rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", m.group(1)):
            cid = int(src, 16)
            units = [int(dst[i:i + 4], 16) for i in range(0, len(dst), 4)]
            out[cid] = "".join(_utf16_units_to_str(units))
    for m in re.finditer(rb"beginbfrange(.*?)endbfrange", cmap_bytes, re.DOTALL):
        for lo, hi, dst in re.findall(
                rb"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", m.group(1)):
            lo_i, hi_i, base = int(lo, 16), int(hi, 16), int(dst, 16)
            for k in range(hi_i - lo_i + 1):
                out[lo_i + k] = chr(base + k)
    return out


def _utf16_units_to_str(units):
    i = 0
    while i < len(units):
        u = units[i]
        if 0xD800 <= u <= 0xDBFF and i + 1 < len(units):
            yield chr(0x10000 + ((u - 0xD800) << 10) + (units[i + 1] - 0xDC00))
            i += 2
        else:
            yield chr(u)
            i += 1


def parse_w_array(body):
    """解析 CIDFont /W 数组（含嵌套子数组），返回 {cid: width_per_mille}。"""
    widths = {}
    m = re.search(rb"/W\s*\[", body)
    if not m:
        return widths
    # 括号配平提取完整数组内容（正则的非贪婪匹配会被嵌套 [..] 截断）
    i = m.end()
    depth = 1
    j = i
    while j < len(body) and depth > 0:
        c = body[j:j + 1]
        if c == b"[":
            depth += 1
        elif c == b"]":
            depth -= 1
        j += 1
    data = body[i:j - 1]
    # 两种形态：c [w1 w2 ...] 与 c1 c2 w
    pos = 0
    tokens = re.findall(rb"\[|\]|-?[\d.]+", data)
    i = 0
    while i < len(tokens):
        if tokens[i] in (b"[", b"]"):
            i += 1
            continue
        start = int(float(tokens[i]))
        if i + 1 < len(tokens) and tokens[i + 1] == b"[":
            j = i + 2
            cid = start
            while j < len(tokens) and tokens[j] != b"]":
                widths[cid] = float(tokens[j])
                cid += 1
                j += 1
            i = j + 1
        elif i + 2 < len(tokens):
            end, w = int(float(tokens[i + 1])), float(tokens[i + 2])
            for cid in range(start, end + 1):
                widths[cid] = w
            i += 3
        else:
            break
    return widths


def parse_pdf(path):
    """返回 Line 列表（全文档，按页序/行序）。要求 PDF 未压缩。"""
    pdf = open(path, "rb").read()
    if b"FlateDecode" in pdf and b"beginbfchar" not in pdf:
        raise SystemExit("PDF 是压缩的：请用本脚本编译（objcompresslevel=0）")

    # 对象表：obj_num → body
    objs = {}
    for m in re.finditer(rb"(\d+)\s+0\s+obj(.*?)endobj", pdf, re.DOTALL):
        objs[int(m.group(1))] = m.group(2)

    # 字体资源：/Fnn → (widths, tounicode, default_width)
    # 页面资源字典把名字映射到 Type0 字体对象
    fonts = {}
    for num, body in objs.items():
        if b"/Subtype" in body and b"/Type0" in body and b"/BaseFont" in body:
            # DescendantFonts → CIDFont（含 /W /DW）
            widths, dw = {}, 1000.0
            df = re.search(rb"/DescendantFonts\s*\[\s*(\d+)\s+0\s+R", body)
            if df and int(df.group(1)) in objs:
                cid_body = objs[int(df.group(1))]
                # /W 可能内联，也可能是指向数组对象的间接引用
                wref = re.search(rb"/W\s+(\d+)\s+0\s+R", cid_body)
                if wref and int(wref.group(1)) in objs:
                    widths = parse_w_array(b"/W " + objs[int(wref.group(1))] + b" /")
                else:
                    widths = parse_w_array(cid_body)
                dwm = re.search(rb"/DW\s+([\d.]+)", cid_body)
                if dwm:
                    dw = float(dwm.group(1))
            tounicode = {}
            tu = re.search(rb"/ToUnicode\s+(\d+)\s+0\s+R", body)
            if tu and int(tu.group(1)) in objs:
                sm = re.search(rb"stream\r?\n(.*?)endstream",
                               objs[int(tu.group(1))], re.DOTALL)
                if sm:
                    tounicode = parse_tounicode(sm.group(1))
            fonts[num] = (widths, tounicode, dw)

    # 资源名映射：在页面对象里找 /Fk N 0 R
    name_to_font = {}
    for body in objs.values():
        for name, ref in re.findall(rb"/(F\d+)\s+(\d+)\s+0\s+R", body):
            if int(ref) in fonts:
                name_to_font[name.decode()] = fonts[int(ref)]

    # 内容流：小型解释器——跟踪 q/Q 栈、cm 级联与完整 Tm 矩阵。
    # 引擎对缩放字形（如脚注标号组）的输出模式是：
    #   1 0 0 1 tx ty cm  q  sx 0 0 sy ox oy cm  1 0 0 1 -tx -ty cm
    #   BT … 1 0 0 1 tx ty Tm [<…>]TJ ET … Q …
    # 即 Tm 里只有页面原点常量，真实位置全在 cm 里。只认 `1 0 0 1 x y Tm`
    # 的旧解析会把这类字形读到变换前的原点（页面左上角）。
    lines = {}
    stream_re = re.compile(rb"stream\r?\n(.*?)endstream", re.DOTALL)
    NUM = rb"(-?[\d.]+)"
    op_re = re.compile(
        NUM + rb" " + NUM + rb" " + NUM + rb" " + NUM + rb" " +
        NUM + rb" " + NUM + rb" (cm|Tm)"
        rb"|/(F\d+)\s+([\d.]+)\s+Tf"
        rb"|\[((?:<[0-9A-Fa-f]*>|-?[\d.]+|\s)*)\]TJ"
        rb"|(?<![\w<])(q|Q)(?![\w>])", re.DOTALL)

    def mat_mul(m1, m2):
        """行向量约定 p' = p·M 下的矩阵乘 m1×m2（各为 a,b,c,d,e,f）。"""
        a1, b1, c1, d1, e1, f1 = m1
        a2, b2, c2, d2, e2, f2 = m2
        return (a1 * a2 + b1 * c2, a1 * b2 + b1 * d2,
                c1 * a2 + d1 * c2, c1 * b2 + d1 * d2,
                e1 * a2 + f1 * c2 + e2, e1 * b2 + f1 * d2 + f2)

    IDENT = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    page_no = 0
    for sm in stream_re.finditer(pdf):
        data = sm.group(1)
        if b" Tm" not in data or b"TJ" not in data:
            continue
        page_no += 1
        cur_font = None
        cur_size = 10.0
        ctm = IDENT
        stack = []
        tm = IDENT
        x_txt = 0.0          # 文本空间内沿书写方向累计的位移（pt）
        for m in op_re.finditer(data):
            if m.group(7):                       # cm / Tm
                mat = tuple(float(m.group(k)) for k in range(1, 7))
                if m.group(7) == b"cm":
                    ctm = mat_mul(mat, ctm)      # CTM' = M × CTM
                else:
                    tm = mat
                    x_txt = 0.0
                continue
            if m.group(8):                       # Tf
                cur_font = name_to_font.get(m.group(8).decode())
                cur_size = float(m.group(9))
                continue
            if m.group(11):                      # q / Q
                if m.group(11) == b"q":
                    stack.append(ctm)
                elif stack:
                    ctm = stack.pop()
                continue
            if cur_font is None:                 # TJ
                continue
            widths, tounicode, dw = cur_font
            a, b_, c, d, e, f = mat_mul(tm, ctm)
            # 设备坐标：p_dev = (x_txt·a + e, x_txt·b + f)。
            # 本引擎无旋转（b=c=0），em 取纵向有效字号 size·d——
            # 缩放字形（v_scale）的度量随之正确；未缩放时 d=1 不变。
            em_eff = cur_size * d
            y_dev = x_txt * b_ + f
            key = (page_no, round(y_dev, 2))
            line = lines.get(key)
            if line is None:
                line = lines[key] = Line(y_dev, page_no)
            for tok in re.finditer(rb"<([0-9A-Fa-f]+)>|(-?[\d.]+)", m.group(10)):
                if tok.group(2) is not None:
                    # TJ 数字：千分 em，正数向左
                    x_txt -= float(tok.group(2)) / 1000.0 * cur_size
                    continue
                hexstr = tok.group(1)
                for i in range(0, len(hexstr), 4):
                    cid = int(hexstr[i:i + 4], 16)
                    adv = widths.get(cid, dw) / 1000.0 * cur_size
                    ch = tounicode.get(cid, "�")
                    x_dev = x_txt * a + e
                    line.glyphs.append(Glyph(ch, x_dev, x_dev + adv * a, em_eff))
                    x_txt += adv

    # 行内按 x 排序；按页与 y（自上而下）排序输出
    out = []
    for (page, _y), line in sorted(lines.items(), key=lambda kv: (kv[0][0], -kv[0][1])):
        line.glyphs.sort(key=lambda g: g.x0)
        out.append(line)
    return out


class Column:
    """直排的一列：字形自上而下排列，度量单位是「基线步长」。"""

    def __init__(self, x):
        self.x = x
        self.glyphs = []   # [(char, y, em), ...]

    @property
    def text(self):
        return "".join(g[0] for g in self.glyphs)

    def span_em(self, i, j):
        """第 i 与第 j 个字形基线之间的距离（em）。

        直排的大陆式点号在渲染时另有偏靠位移（字面偏右上），所以「标点占
        几个字幅」要用它**两侧汉字**的基线距离来量，而不是标点自身的位移。
        """
        (_, y0, em) = self.glyphs[i]
        (_, y1, _e) = self.glyphs[j]
        return (y0 - y1) / em

    def index_of(self, sub, occurrence=0):
        """列内文本中第 occurrence 次出现的 sub 的起始下标。"""
        pos, start = -1, 0
        for _ in range(occurrence + 1):
            pos = self.text.find(sub, start)
            if pos < 0:
                raise SystemExit(f"列「{self.text[:16]}…」中找不到「{sub}」")
            start = pos + 1
        return pos

    def step_em(self, i):
        """第 i 个字形占用的纵向步长（em）= 它与下一字基线的距离。

        直排下引擎给每个字形单独定位，字幅（cell）挤压直接体现为步长缩短，
        因此步长比值就是 clreq「标点占几个字幅」的可度量形式。
        """
        (_, y0, em), (_, y1, _e) = self.glyphs[i], self.glyphs[i + 1]
        return (y0 - y1) / em


def parse_pdf_vertical(path, min_len=4):
    """返回 Column 列表（直排）。按 x 分组、组内自上而下。

    横排版本按 y 分行；直排每个字形的 y 都不同，改按 x 分列。
    """
    placements = []
    for line in parse_pdf(path):
        for g in line.glyphs:
            placements.append((line.page, g.x0, line.y, g.char, g.em))
    if not placements:
        return []

    # x 聚类：大陆式点号渲染时向列外侧偏靠（MAINLAND_OFFSETS），x 与同列
    # 汉字相差约 0.2 字宽；脚注标号（缩放小字）也偏出约 0.35 字宽。
    # 容差基准取全文档 em 的中位数——取「第一个字形」会让结果取决于
    # 恰好谁排在最上面（若是小字号的标号，容差缩水导致同列被拆开）。
    ems = sorted(p[4] for p in placements)
    tol = 0.45 * ems[len(ems) // 2]
    out, cur, cur_page = [], None, None
    # 先按页、再按 x（自右向左）；同页同 x 才算一列
    for page, x, y, ch, em in sorted(placements, key=lambda p: (p[0], -p[1])):
        if cur is None or page != cur_page or abs(cur.x - x) > tol:
            cur = Column(x)
            cur.page = page
            cur_page = page
            out.append(cur)
        cur.glyphs.append((ch, y, em))
    for col in out:
        col.glyphs.sort(key=lambda t: -t[1])
    return [c for c in out if len(c.glyphs) >= min_len]


# ============================================================================
# 编译
# ============================================================================

def compile_tex(tex_path, out_dir):
    """以未压缩 PDF 模式编译，返回 PDF 路径。"""
    env = dict(os.environ, OSFONTDIR=FONTS_DIR)
    jobname = "clreq_check"
    preamble = (r"\directlua{pdf.setcompresslevel(0) pdf.setobjcompresslevel(0)}"
                rf"\input{{{os.path.basename(tex_path)}}}")
    cmd = ["lualatex", "-interaction=nonstopmode",
           f"-output-directory={out_dir}", f"-jobname={jobname}", preamble]
    r = subprocess.run(cmd, cwd=os.path.dirname(tex_path),
                       capture_output=True, text=True, env=env)
    pdf = os.path.join(out_dir, jobname + ".pdf")
    if not os.path.exists(pdf):
        print(r.stdout[-3000:])
        raise SystemExit(f"编译失败: {tex_path}")
    return pdf


# ============================================================================
# 断言原语
# ============================================================================

class Reporter:
    def __init__(self):
        self.passed = 0
        self.failed = []

    def check(self, clause, desc, ok, detail=""):
        if ok:
            self.passed += 1
            print(f"  [OK]   {clause}: {desc}")
        else:
            self.failed.append((clause, desc, detail))
            print(f"  [FAIL] {clause}: {desc}  {detail}")


def find_line(lines, substring):
    for line in lines:
        if substring in line.text:
            return line
    raise SystemExit(f"断言无法定位：没有一行包含「{substring}」")


def gap_after(line, substring):
    """substring 最后一个字符与其后一个字形之间的 gap（em）。"""
    idx = line.text.find(substring)
    if idx < 0:
        raise SystemExit(f"行「{line.text[:20]}…」中找不到「{substring}」")
    i = idx + len(substring) - 1
    return line.gap_em(i)


# ============================================================================
# 用例（每条注明 clreq 条款）
# ============================================================================

def run_assertions(lines):
    r = Reporter()

    # ---- 中西混排：汉字与西文字母、数字间不多于 1/4 汉字宽，
    #      行内调整可挤至 1/8、拉至 1/2（clreq: 中、西文混排处理）
    for where, sub in [("有空格源码", "基于"), ("无空格源码", "结果为")]:
        line = find_line(lines, sub)
        g = gap_after(line, sub)
        r.check("中西间距", f"{where}「{sub}|→西文」gap={g:.3f}em ∈ [1/8, 1/2]",
                0.125 - EPS <= g <= 0.5 + EPS)

    line = find_line(lines, "毫米")
    g = -1
    idx = line.text.find("毫米")
    if idx > 0:
        g = line.gap_em(idx - 1)  # 数字 | 毫
    r.check("中西间距", f"「数字|毫米」gap={g:.3f}em ∈ [1/8, 1/2]",
            0.125 - EPS <= g <= 0.5 + EPS)

    # ---- 例外：点号前后不加中西间距（clreq: 在中文点号前后…不调整字距或加入空白）
    line = find_line(lines, "Hello")
    g = gap_after(line, "：")
    r.check("中西间距例外", f"「：|Hello」不加间距 gap={g:.3f}em ≤ 0",
            g <= EPS)

    # ---- 例外：夹注号内侧不加（clreq: 开始夹注符号之后、结束夹注符号之前）
    line = find_line(lines, "English")
    g = gap_after(line, "（")
    r.check("中西间距例外", f"「（|English」内侧无间距 gap={g:.3f}em ≈ 0",
            abs(g) <= EPS)
    idx = line.text.find("）")
    g = line.gap_em(idx - 1)
    r.check("中西间距例外", f"「English|）」内侧无间距 gap={g:.3f}em ≈ 0",
            abs(g) <= EPS)

    # ---- 符号分离禁则：数字串、数字+单位、货币同行不拆（clreq: 符号分离禁则）
    for token in ["1234", "5678", "95%", "37℃", "±3", "¥1280", "¥999"]:
        found = any(token in line.text for line in lines)
        r.check("符号分离禁则", f"「{token}」未被拆行", found)
        if found:
            line = find_line(lines, token)
            idx = line.text.find(token)
            tight = all(abs(line.gap_em(idx + k)) <= EPS
                        for k in range(len(token) - 1))
            r.check("符号分离禁则", f"「{token}」内部零间隙", tight)

    # ---- 行首行尾禁则（clreq: 基本级）
    FORBID_START = set("，。、：；！？」』）》〉】〕……··—～/")
    FORBID_END = set("「『（《〈【〔")
    bad_start = [ln.text[:6] for ln in lines if ln.text and ln.text[0] in FORBID_START]
    bad_end = [ln.text[-6:] for ln in lines if ln.text and ln.text[-1] in FORBID_END]
    r.check("行首禁则", f"无行以点号/结束符/连接号开头（{len(lines)} 行）",
            not bad_start, str(bad_start[:3]))
    r.check("行尾禁则", "无行以开引号/开括号结尾",
            not bad_end, str(bad_end[:3]))

    # ---- 两字宽标点整体（clreq: 破折号/省略号占两字，不可拆）
    line = find_line(lines, "巧克力")
    dash_idx = line.text.find("——")
    twoem_idx = line.text.find("⸺")
    if dash_idx >= 0:
        g = line.gap_em(dash_idx)
        r.check("两字宽标点", f"「——」同行相邻且零间隙 gap={g:.3f}em ≈ 0",
                abs(g) <= EPS)
    elif twoem_idx >= 0:
        # 字体（如思源宋体）经 liga 把 —— 合成单个两字宽字形 ⸺（U+2E3A），
        # 正是 clreq「占两字、形如一线」的理想形态；断言其字幅 ≈ 2em
        gl = line.glyphs[twoem_idx]
        w = (gl.x1 - gl.x0) / gl.em
        r.check("两字宽标点", f"「⸺」liga 合成单字形，字幅={w:.3f}em ≈ 2",
                abs(w - 2.0) <= EPS)
    else:
        r.check("两字宽标点", "破折号（——或⸺）同行出现", False)
    ell = None
    for ln in lines:
        if "……" in ln.text:
            ell = ln
            break
    r.check("两字宽标点", "「……」同行相邻", ell is not None)

    # ---- 标点挤压已发生（clreq: 标点符号的宽度调整——挤压体现为负 gap）
    squeezed = 0
    for ln in lines:
        for i in range(len(ln.glyphs) - 1):
            if ln.glyphs[i].char in "，。、；" and ln.gap_em(i) < -0.1:
                squeezed += 1
    r.check("标点挤压", f"存在被挤压的标点空白（负 gap × {squeezed}）", squeezed > 0)

    # ---- H2：行末标点半字宽（clreq 挤压第 1 级；line-end-punct=compress 默认）。
    #      post_linebreak 用负 kern 回收行末字形内空白：字形 advance 不变，
    #      但其空白伸出文本右缘之外。度量：满行右缘 M 取「非标点结尾行」的
    #      最大 x1；标点结尾的满行须满足 M − x0(末字) ≤ 半字宽，
    #      即标点在行内只占半字，回收的空白已还给行内其他间隙。
    # 行末可挤压字符 = 末端带空白的点号与结束符（clreq: 行末标点/结束夹注号
    # 均调成半字）。集合必须完整——漏掉的字符若真被挤压，其 x1 会超出文本
    # 右缘 0.5em，把 margin 估计值抬高半字，令全部断言失真。
    PUNCT_END = set("，。、；！？」』）》〉】〕")
    # 右缘样本进一步排除所有以标点结尾的行（含不可挤压的冒号等）：
    # 这类行可能因排版特殊（如 overfull 容忍）而略越界，不适合当基准。
    MARGIN_EXCLUDE = PUNCT_END | set("：·—…～／")
    margin = max((ln.glyphs[-1].x1 for ln in lines
                  if ln.glyphs and ln.glyphs[-1].char not in MARGIN_EXCLUDE),
                 default=0.0)
    # 受挤压行的可观测特征：末字空白被负 kern 回收后，其 advance 越出文本
    # 右缘（x1 > M）。数量下限是回归锁——若 H2 失效，标点行全部回到
    # x1 = M，此断言立即失败。段末满行（带 parfillskip、无短缺，clreq 无需
    # 挤压）x1 ≈ M，不计入。
    compressed = [
        ln for ln in lines
        if ln.glyphs and ln.glyphs[-1].char in PUNCT_END
        and ln.glyphs[-1].x1 - margin >= 0.2 * ln.glyphs[-1].em
    ]
    r.check("行末标点挤压", f"存在被挤压的行末标点行（{len(compressed)} 行 ≥ 5）",
            len(compressed) >= 5)
    bad = []
    for ln in compressed:
        g = ln.glyphs[-1]
        occupied = (margin - g.x0) / g.em
        if occupied > 0.5 + EPS:
            bad.append(f"「…{ln.text[-6:]}」占 {occupied:.3f}em")
    r.check("行末标点挤压",
            f"受挤压的 {len(compressed)} 行行末标点在行内均 ≤ 半字宽",
            not bad, str(bad[:3]))

    # ---- 连续标点缩减（clreq: 夹注符号连排「无论何种风格都应该」把
    #      2 字宽缩为 1.5——两符号间隙固定为 −0.5em，行紧时可further）
    for pair in ["》（", "）；"]:
        line = find_line(lines, pair)
        idx = line.text.find(pair)
        g = line.gap_em(idx)
        r.check("连续标点缩减", f"「{pair[0]}|{pair[1]}」固定缩减 gap={g:.3f}em ≤ -0.5",
                g <= -0.5 + EPS)

    # ---- 行首开始夹注符号缩减（clreq: 段首缩进的首行行首出现开始夹注
    #      符号，可以缩减其始侧半字——缩进视觉上保持两字）
    OPEN_SET = set("「『（《〈【〔")
    margin_left = min((ln.glyphs[0].x0 for ln in lines
                       if ln.glyphs and ln.glyphs[0].char not in OPEN_SET),
                      default=0.0)
    line = find_line(lines, "大学之道")
    g0 = line.glyphs[0]
    indent = (g0.x0 - margin_left) / g0.em
    r.check("行首夹注符号缩减",
            f"段首「 缩进 {indent:.3f}em ≈ 1.5（2em 缩进 − 0.5em 始侧空白）",
            abs(indent - 1.5) <= 0.05)
    # 行中折行产生的行首开括号（若有）：始侧空白悬出左缘 0.5em。
    # 段首缩进起始的开括号行（off > 0.5，缩进量随字号换算）由上面的
    # 确定性锚点覆盖，此处只查非缩进行。
    bad = []
    for ln in lines:
        if ln.glyphs and ln.glyphs[0].char in OPEN_SET and ln is not line:
            off = (ln.glyphs[0].x0 - margin_left) / ln.glyphs[0].em
            if off < 0.5 and abs(off + 0.5) > 0.05:
                bad.append(f"「{ln.text[:4]}」off={off:.3f}em")
    r.check("行首夹注符号缩减", "折行行首的开括号均已缩减始侧空白", not bad,
            str(bad[:3]))

    # ---- H4 行间注：注文行（小字号）存在；注文块与基文块居中对齐（clreq 词对齐）
    ann_lines = [ln for ln in lines if ln.glyphs and ln.glyphs[0].em < 8]
    r.check("行间注", f"存在小字号注文行（{len(ann_lines)} 行 ≥ 2）",
            len(ann_lines) >= 2)
    ann = next((ln for ln in ann_lines if "zhōngguó" in ln.text), None)
    r.check("行间注", "注文「zhōngguó」完整可见", ann is not None)
    if ann is not None:
        i = ann.text.find("zhōngguó")
        a0 = ann.glyphs[i].x0
        a1 = ann.glyphs[i + len("zhōngguó") - 1].x1
        base = find_line(lines, "中")
        j = base.text.find("中")
        # 注文比基文宽 → 基文「中 国」被加大字距铺满注文宽（clreq: 长于基文时
        # 加大基文字距），两块中心应重合
        b0 = base.glyphs[j].x0
        b1 = base.glyphs[base.text.find("国", j)].x1
        diff = abs((a0 + a1) / 2 - (b0 + b1) / 2) / base.glyphs[j].em
        r.check("行间注", f"「zhōngguó」与「中国」中心对齐 偏差={diff:.3f}em ≤ 0.1",
                diff <= 0.1)

    return r


# ============================================================================
# 压力用例：符号分离禁则的相位扫描普查
# （test/clreq_test/stress-unbreakable.tex：每种 token 以递增填充重复出现，
#   扫过行内全部断点相位；被拆行则该 token 无法在任何一行凑出完整匹配，
#   完整出现次数普查必然对不上。）
# ============================================================================

# token → (计划出现次数, 至少分布的行数, 保护机制)
# "structural"：半角 token 内部不插断点，不可拆是构造性保证（census 作回归锁，
#               防止将来有人在西文边界插入断点）；
# "kinsoku"：  全角数字字间存在断点 glue，仅靠 penalty 保护——具区分力
#               （关闭禁则的对照组会在此拆行）。
STRESS_TOKENS = {
    "95%": (20, 4, "structural"),
    "37℃": (15, 3, "structural"),
    "±5": (15, 3, "structural"),
    "¥1280": (12, 3, "structural"),
    "0123456789": (10, 3, "structural"),
    "9876543210987654": (1, 1, "structural"),          # 16 位（8em）整体换行
    "246813579024681357902468": (1, 1, "structural"),  # 24 位（12em），近整行宽
    "１２３４５６７８": (12, 4, "kinsoku"),             # 全角 8 位相位扫描
    "８７６５４３２１０９８７６５": (1, 1, "kinsoku"),  # 全角 14 位（14em），降序避免含 8 位 token
}


def run_stress_assertions(lines):
    r = Reporter()
    for token, (expected, min_lines, guard) in STRESS_TOKENS.items():
        count = 0
        line_hits = 0
        gaps_ok = True
        for ln in lines:
            n = ln.text.count(token)
            if n == 0:
                continue
            count += n
            line_hits += 1
            start = 0
            for _ in range(n):
                idx = ln.text.find(token, start)
                for k in range(len(token) - 1):
                    if abs(ln.gap_em(idx + k)) > EPS:
                        gaps_ok = False
                start = idx + len(token)
        tag = "kinsoku保护" if guard == "kinsoku" else "构造性保证"
        r.check("符号分离禁则",
                f"「{token}」完整出现 {count}/{expected} 次（{tag}，拆行即缺失）",
                count == expected)
        r.check("符号分离禁则",
                f"「{token}」分布于 {line_hits} 行（≥{min_lines}，证明经受断行压力）",
                line_hits >= min_lines)
        r.check("符号分离禁则", f"「{token}」所有出现内部零间隙", gaps_ok)

    # 行首行尾禁则在压力文档上同样全行扫描
    FORBID_START = set("，。、：；！？」』）》〉】〕％%℃")
    bad_start = [ln.text[:6] for ln in lines if ln.text and ln.text[0] in FORBID_START]
    r.check("行首禁则", f"压力文档 {len(lines)} 行无行首禁字符", not bad_start,
            str(bad_start[:3]))
    return r


def run_taiwan_assertions(lines):
    """style=taiwan 专属断言（hori-taiwan.tex，TW-Kai 台式居中字面）。"""
    r = Reporter()
    text = "".join(ln.text for ln in lines)

    # ---- 引号体例（clreq: 台湾用传统引号，先单后双）：
    #      quote-style=auto + style=taiwan 把来稿弯引号逐字转换，嵌套保持
    r.check("引号体例", "输出含传统引号「」『』（弯引号已转换）",
            all(c in text for c in "「」『』"))
    r.check("引号体例", "输出不含弯引号",
            not any(c in text for c in "“”‘’"))

    # ---- 台式？！固定一字宽（clreq: 横排台式问号叹号不调整）：
    #      advance = 1em，且其后空隙不为负（未被当作可挤空白）
    seen, fixed_ok = 0, True
    for ln in lines:
        for i, g in enumerate(ln.glyphs):
            if g.char in "？！":
                seen += 1
                if abs((g.x1 - g.x0) / g.em - 1.0) > EPS:
                    fixed_ok = False
                if i + 1 < len(ln.glyphs) and ln.gap_em(i) < -EPS:
                    fixed_ok = False
    r.check("台式固定标点", f"？！共 {seen} 处（≥4），advance=1em 且旁侧无压缩",
            seen >= 4 and fixed_ok)

    # ---- 行首禁则
    FORBID_START = set("，。、：；！？」』）……")
    bad = [ln.text[:6] for ln in lines if ln.text and ln.text[0] in FORBID_START]
    r.check("行首禁则", f"{len(lines)} 行无行首禁字符", not bad, str(bad[:3]))

    # ---- 行末标点挤压：台式点号居中，末端空白仅半侧（0.25em）——
    #      受挤压行的行末标点在行内占 1 − 0.25 = 0.75em
    PUNCT_END = set("，。、；！？」』）")
    margin = max((ln.glyphs[-1].x1 for ln in lines
                  if ln.glyphs and ln.glyphs[-1].char not in PUNCT_END),
                 default=0.0)
    compressed, bad2 = [], []
    for ln in lines:
        if not ln.glyphs or ln.glyphs[-1].char not in "，。、；":
            continue
        g = ln.glyphs[-1]
        if g.x1 - margin >= 0.1 * g.em:
            compressed.append(ln)
            occupied = (margin - g.x0) / g.em
            if occupied > 0.75 + EPS:
                bad2.append(f"「…{ln.text[-4:]}」占 {occupied:.3f}em")
    r.check("行末标点挤压", f"台式受挤压行（{len(compressed)} 行 ≥ 2）占位 ≤ 0.75em",
            len(compressed) >= 2 and not bad2, str(bad2[:3]))
    return r


def find_column(cols, substring):
    for col in cols:
        if substring in col.text:
            return col
    raise SystemExit(f"断言无法定位：没有一列包含「{substring}」")


def run_vertical_assertions(cols):
    """直排标点宽度调整（vert-punct.tex，ltc-cn-vbook + 上下文相关挤压）。

    度量方式：直排字幅的挤压体现为基线步长缩短。大陆式点号在渲染时另有
    偏靠位移，故一律以**两侧汉字**的基线距离（span）度量「这段占几个字
    幅」，标点本身的位移不进入测量。
    """
    r = Reporter()

    base = find_column(cols, "天地玄黄")
    i = base.index_of("天")
    unit = base.span_em(i, i + 1)   # 一个字幅 + 字间距 = 步长基准
    steps = [base.span_em(i + k, i + k + 1) for k in range(3)]
    r.check("字幅基准", f"汉字步长一致 = {unit:.3f}em",
            all(abs(s - unit) < EPS for s in steps), str(steps))

    def span_cells(col, a, b, occ_a=0, occ_b=0):
        return col.span_em(col.index_of(a, occ_a), col.index_of(b, occ_b)) / unit

    # ---- ① 夹在汉字之间的单个标点占满一字幅
    #      （clreq 标点符号的宽度调整：挤压只在连续标点与行首行尾发生）
    n = span_cells(base, "黄", "宇")
    r.check("标点宽度调整", f"汉字间的逗号占满一字幅：黄→宇 = {n:.3f} 字幅（期望 2）",
            abs(n - 2.0) < EPS)

    # ---- ② 直排冒号/分号/问号/叹号固定一字幅（clreq mode 修正规则）
    col = find_column(cols, "子曰")
    for a, b, mark in [("曰", "学", "："), ("之", "不", "；"), ("乎", "有", "？")]:
        n = span_cells(col, a, b)
        r.check("直排固定标点",
                f"「{mark}」固定一字幅：{a}→{b} = {n:.3f} 字幅（期望 2）",
                abs(n - 2.0) < EPS)

    # ---- ③ 连续标点缩减为 1.5 字幅（clreq 连续标点符号的调整）
    col = find_column(cols, "金木水火土")
    n = span_cells(col, "土", "引")
    r.check("连续标点", f"「。」+「「」合计 1.5 字幅：土→引 = {n:.3f}（期望 2.5）",
            abs(n - 2.5) < EPS)

    col = find_column(cols, "连续引号")
    n = span_cells(col, "好", "好", 0, 1)
    r.check("连续标点",
            f"「。」「」」「「」三连合计 2 字幅：好→好 = {n:.3f}（期望 3）",
            abs(n - 3.0) < EPS)
    n = span_cells(col, "说", "好")
    r.check("连续标点",
            f"「：」+「「」合计 1.5 字幅（冒号本身不可挤）：说→好 = {n:.3f}（期望 2.5）",
            abs(n - 2.5) < EPS)

    # ---- ④ 挤压方向（clreq: 收回的是哪一侧的空白，字面就往哪边让）
    #      大陆式点号的空白在末端 → 收回后字面**不动**，让后一个符号上移；
    #      开始夹注符号的空白在始端 → 收回后字面向后贴紧被夹注的内容。
    ref = base.span_em(base.index_of("荒"), base.index_of("。")) / unit
    got = col.span_em(col.index_of("好"), col.index_of("。")) / unit
    r.check("挤压方向",
            f"「。」收回末端空白后字面不移动：前字→。 = {got:.3f}，"
            f"未缩减的同一距离 = {ref:.3f}",
            abs(got - ref) < EPS)

    i = col.index_of("。")
    after = col.span_em(i, i + 1) / unit
    r.check("挤压方向",
            f"收回量落在「。」之后一侧：。→」 = {after:.3f} 字幅（应 < 1）",
            after < 1.0 - EPS)

    j = col.index_of("说")
    bracket = col.span_em(j, j + 2) / unit   # 说 →（：）→「
    r.check("挤压方向",
            f"行内开始夹注符号收回始端空白后向后贴紧：说→「 = {bracket:.3f} 字幅（应 < 2）",
            bracket < 2.0 - EPS)

    # ---- ⑤ 行首禁则（clreq 行首行尾禁则，基本级）
    #      用例用长度递增的数字串扫过列末的各个相位（与列容量无关），
    #      其中必有若干段的逗号恰好越出列末：禁则须把它挤进本列，
    #      而不是让它成为下一列的首字。
    FORBID_START = set("，。、：；！？」』）》〉】〕｝］")
    bad = [c.text[:8] for c in cols if c.text and c.text[0] in FORBID_START]
    r.check("行首禁则", f"{len(cols)} 列均不以禁则字符开头", not bad, str(bad[:3]))

    # 第二条只证明「相位扫描确实扫到了边界」——若禁则真的失效，上一条会先炸。
    squeezed = [c for c in cols if c.text.endswith("，") and "一二三" in c.text]
    r.check("行首禁则",
            f"相位扫描扫到列末边界 {len(squeezed)} 次，逗号均被挤进本列"
            f"（列长 {[len(c.glyphs) for c in squeezed]}）",
            len(squeezed) >= 1)

    # ---- ⑥ 解析器：cm 缩放字形的坐标（锁住解析器对 cm 级联的跟踪）
    #      脚注标号组以 q <sx> 0 0 <sy> <ox> <oy> cm 缩放绘制，Tm 里只有
    #      页面原点常量。若解析器不跟踪 cm，︻一︼ 会读到左上角、脱离本列，
    #      下面两条都会失败。
    col = find_column(cols, "标号位置")
    r.check("cm 缩放解析",
            f"标号组按真实坐标落回本列原位：列文本 = {col.text[:12]}…",
            "丙︻一︼丁" in col.text)
    j = col.index_of("︻")
    hanzi_em = col.glyphs[col.index_of("丙")][2]
    marker_ems = [col.glyphs[k][2] for k in (j, j + 1, j + 2)]
    r.check("cm 缩放解析",
            f"标号字形读到缩放后的有效字号：{['%.2f' % e for e in marker_ems]}pt"
            f"（正文 {hanzi_em:.2f}pt）",
            all(e < hanzi_em - EPS for e in marker_ems))
    return r


def run_vertical_doc(name, tex, min_cols):
    with tempfile.TemporaryDirectory() as tmp:
        pdf = compile_tex(tex, tmp)
        cols = parse_pdf_vertical(pdf)
    if len(cols) < min_cols:
        raise SystemExit(f"{name}: 解析出的列数过少（{len(cols)}），解析可能失败")
    print(f"\n=== {name}：解析到 {len(cols)} 列 ===")
    return run_vertical_assertions(cols)


def run_doc(name, tex, assert_fn, min_lines):
    with tempfile.TemporaryDirectory() as tmp:
        pdf = compile_tex(tex, tmp)
        lines = parse_pdf(pdf)
    if len(lines) < min_lines:
        raise SystemExit(f"{name}: 解析出的行数过少（{len(lines)}），解析可能失败")
    print(f"\n=== {name}：解析到 {len(lines)} 行 ===")
    return assert_fn(lines)


def main():
    if len(sys.argv) > 1 and sys.argv[1].endswith(".pdf"):
        lines = parse_pdf(sys.argv[1])
        print(f"解析到 {len(lines)} 行文本，开始断言：")
        r = run_assertions(lines)
        reporters = [r]
    elif len(sys.argv) > 1:
        r = run_doc(sys.argv[1], sys.argv[1], run_assertions, 5)
        reporters = [r]
    else:
        reporters = [
            run_doc("hori.tex 基础用例", DEFAULT_TEX, run_assertions, 5),
            run_doc("stress-unbreakable.tex 压力用例", STRESS_TEX,
                    run_stress_assertions, 20),
            run_doc("hori-taiwan.tex 台式用例", TAIWAN_TEX,
                    run_taiwan_assertions, 8),
            run_vertical_doc("vert-punct.tex 直排用例", VERTICAL_TEX, 4),
        ]

    passed = sum(r.passed for r in reporters)
    failed = [f for r in reporters for f in r.failed]
    print(f"\nclreq 断言：{passed} 通过，{len(failed)} 失败")
    if failed:
        for clause, desc, detail in failed:
            print(f"  FAIL {clause}: {desc} {detail}")
        sys.exit(1)
    print("ALL CLREQ ASSERTIONS PASSED")


if __name__ == "__main__":
    main()
