#!/usr/bin/env python3
"""几何自校验测试：竖排格内字形基线必须等距。

与像素回归测试不同，本测试不依赖基线图像——它直接解析编译产物
PDF 的内容流，取出每个字形的 Tm 定位矩阵，按列（相同 x 坐标）分组，
断言同一列内相邻字形的基线间距严格相等（即每字一格、共享基线）。

这样能抓住"「一」「丶」等墨迹不跨基线的字被按墨迹框居中而整字偏移"
一类的 bug（LEARNING.md 3.6）：那类 bug 会使列内基线间距抖动，
而基线型像素对比测试会把错误渲染原样锁进基线,无法发现。

第二项检查（句读，issue #216）：句读标记相对所附的字的竖向偏移，以所附字的
字号为单位，全文必须一致——无论字在正文还是夹注、夹注格高是否与正文相同。
夹注 n-char-per-col 曾让夹注里的句读按正文格高定位而偏离所附的字，
像素基线会把这种偏移原样锁住，这里直接量出来。
横向同理（issue #232）：同一种标记（、或 。）相对所附字的横向偏移也必须
一致——夹注五种 align 下的各小列、侧批（issue #233）都一样。

用法：
    python3 test/geometry_test.py            # 编译并检查默认测试文件
    python3 test/geometry_test.py file.pdf   # 直接检查已有 PDF（基线等距）
    python3 test/geometry_test.py --judou file.pdf|file.tex  # 只做句读检查

仅用标准库（zlib/re），无第三方依赖。
"""

import os
import re
import subprocess
import sys
import tempfile
import zlib

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_TEX = os.path.join(
    REPO_ROOT, "test", "regression_test", "basic", "tex", "baseline-align.tex"
)
JUDOU_TEX = os.path.join(
    REPO_ROOT, "test", "regression_test", "basic", "tex", "jiazhu-combo.tex"
)
_PAST = os.path.join(REPO_ROOT, "test", "regression_test", "past_issue", "tex")
# (文件, 至少应找到的句读标记数)
JUDOU_TEXES = [
    (JUDOU_TEX, 8),
    (os.path.join(_PAST, "judou_jiazhu_align_issue232.tex"), 35),  # 五种夹注对齐
    # 侧批里的 4 个句读修复前画成 ?，找不到标记就少 4 个（issue #233）
    (os.path.join(_PAST, "judou_sidenote_issue233.tex"), 12),
]
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

# 基线间距允许的抖动（pt）。渲染只受 sp 取整影响，远小于 0.01pt；
# 墨迹框居中类 bug 造成的抖动在 1pt 以上。
TOLERANCE_PT = 0.01
# 每列至少要有这么多字形才检查（太短的列谈不上"间距序列"）
MIN_GLYPHS_PER_COLUMN = 4
# 全文档至少要找到这么多列，防止解析失败时测试空转通过
MIN_COLUMNS = 3

TM_RE = re.compile(rb"1 0 0 1 (-?[\d.]+) (-?[\d.]+) Tm\s*\[<[0-9A-Fa-f]+>\]TJ")
STREAM_RE = re.compile(rb"stream\r?\n(.*?)endstream", re.DOTALL)


def iter_content_streams(pdf_bytes):
    """遍历 PDF 里所有能解出文本的流（明文或 Flate 压缩）。"""
    for m in STREAM_RE.finditer(pdf_bytes):
        data = m.group(1)
        if b" Tm" not in data:
            try:
                data = zlib.decompress(data)
            except zlib.error:
                continue
        if b" Tm" in data:
            yield data


def collect_columns(pdf_path):
    """返回 {x坐标: [y坐标...]}，x/y 单位为 pt。"""
    with open(pdf_path, "rb") as f:
        pdf = f.read()
    columns = {}
    for stream in iter_content_streams(pdf):
        for m in TM_RE.finditer(stream):
            x, y = float(m.group(1)), float(m.group(2))
            columns.setdefault(round(x, 3), []).append(y)
    return columns


def check(pdf_path):
    columns = collect_columns(pdf_path)
    checked = 0
    failures = []
    for x, ys in sorted(columns.items(), reverse=True):
        ys = sorted(ys, reverse=True)  # 竖排自上而下
        all_gaps = [a - b for a, b in zip(ys, ys[1:])]
        if not all_gaps:
            continue
        # 同一 x 可能落着多段互不相干的列（如另一半叶的列恰好同 x）。
        # 以中位间距的 1.5 倍为界切段，段内才要求等距。
        median = sorted(all_gaps)[len(all_gaps) // 2]
        segments = [[ys[0]]]
        for prev, cur in zip(ys, ys[1:]):
            if prev - cur > median * 1.5 + TOLERANCE_PT:
                segments.append([cur])
            else:
                segments[-1].append(cur)
        for seg in segments:
            if len(seg) < MIN_GLYPHS_PER_COLUMN:
                continue
            gaps = [round(a - b, 3) for a, b in zip(seg, seg[1:])]
            ref = gaps[0]
            bad = [g for g in gaps if abs(g - ref) > TOLERANCE_PT]
            checked += 1
            if bad:
                failures.append(
                    "  x=%.3f y=%.3f..%.3f: 基线间距不一致 %s"
                    % (x, seg[0], seg[-1], gaps)
                )
    if checked < MIN_COLUMNS:
        print("FAIL: 只解析到 %d 列（最少要求 %d），PDF 解析可能失效" % (checked, MIN_COLUMNS))
        return 1
    if failures:
        print("FAIL: %d/%d 列基线间距不等距：" % (len(failures), checked))
        print("\n".join(failures))
        return 1
    print("PASS: %d 列基线间距全部等距（容差 %gpt）" % (checked, TOLERANCE_PT))
    return 0


# ---------------------------------------------------------------------------
# 句读标记相对所附字的位置（issue #216）
# ---------------------------------------------------------------------------

# 句读颜色：jiazhu-combo.tex 用 \句读设置{句读颜色=red}，文中别无红色字形
JUDOU_RGB = (1.0, 0.0, 0.0)
# 偏移（以字号计）允许的差异。正常只有取整误差（<0.002）；
# #216 那类 bug 造成的差异在 0.2 以上。
JUDOU_TOLERANCE_EM = 0.01
# 至少要找到这么多句读标记，防止解析失败时空转通过
MIN_JUDOU_MARKS = 8
# 句读标记按所附字字号的 1.2 倍绘制（judou.lua register_decorate 的 scale）。
# 只认这个比例的红字为「紧跟所附字的句读」：连续的红字（彩色正文）、
# 以及夹注收尾后正文标点挂在夹注末字上的大号句读（字号不同）不在本检查范围。
JUDOU_SCALE = 1.2

GLYPH_TOKEN_RE = re.compile(
    rb"(?P<cm>(?:-?[\d.]+\s+){5}-?[\d.]+)\s+cm"
    rb"|(?P<tm>(?:-?[\d.]+\s+){5}-?[\d.]+)\s+Tm\s*\[<(?P<gid>[0-9A-Fa-f]+)>\]TJ"
    rb"|/\S+\s+(?P<tf>-?[\d.]+)\s+Tf"
    rb"|(?P<rg>-?[\d.]+\s+-?[\d.]+\s+-?[\d.]+)\s+rg"
    rb"|(?<![\w.])(?P<q>[qQ])(?![\w.])"
)


def collect_glyphs(pdf_path):
    """按绘制顺序返回字形 [(x, y, 字号, 填充色, 字形码)]，坐标已乘上 cm 矩阵。

    句读标记由 decorate 用 `q 颜色 s 0 0 s x y cm ... Q` 包着画，
    所以要跟踪 q/Q 与 cm，不能只看 Tm。
    """
    with open(pdf_path, "rb") as f:
        pdf = f.read()
    out = []
    for stream in iter_content_streams(pdf):
        ctm = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
        stack = []
        size = 0.0
        rgb = (0.0, 0.0, 0.0)
        for t in GLYPH_TOKEN_RE.finditer(stream):
            if t.group("cm"):
                a, b, c, d, e, f = map(float, t.group("cm").split())
                A, B, C, D, E, F = ctm
                ctm = [a * A + b * C, a * B + b * D, c * A + d * C,
                       c * B + d * D, e * A + f * C + E, e * B + f * D + F]
            elif t.group("tm"):
                _, _, _, _, e, f = map(float, t.group("tm").split())
                A, B, C, D, E, F = ctm
                out.append((e * A + f * C + E, e * B + f * D + F, size * D, rgb,
                            t.group("gid")))
            elif t.group("tf"):
                size = float(t.group("tf"))
            elif t.group("rg"):
                rgb = tuple(round(float(v), 3) for v in t.group("rg").split())
            elif t.group("q") == b"q":
                stack.append((ctm[:], rgb))
            elif stack:
                ctm, rgb = stack.pop()
    return out


def check_judou(pdf_path, min_marks=MIN_JUDOU_MARKS):
    """每个句读标记紧跟在所附的字之后绘制；量出两者基线之差（以所附字字号计）。"""
    offsets = []
    h_offsets = []  # 横向偏移：夹注 align 移动了字，句读要跟着走（issue #232）
    anchor = None
    for x, y, size, rgb, gid in collect_glyphs(pdf_path):
        if rgb != JUDOU_RGB:
            anchor = (x, y, size)
            continue
        if anchor and anchor[2] > 0 and abs(size / anchor[2] - JUDOU_SCALE) < 0.05:
            offsets.append(((anchor[1] - y) / anchor[2], anchor, (x, y)))
            h_offsets.append(((x - anchor[0]) / anchor[2], anchor, (x, y), gid))
        anchor = None  # 一个字只配一个句读
    if len(offsets) < min_marks:
        print("FAIL: 只找到 %d 个句读标记（最少要求 %d），PDF 解析可能失效"
              % (len(offsets), min_marks))
        return 1
    rc = 0
    # 横向按标记字形分组比较：、与 。墨迹中心离字形原点不一样远，
    # 原点之差本来就不同；同一种标记则无论正文、夹注各小列与各种 align、
    # 侧批，都应在所附字右侧同样的位置（issue #232 / #233）。
    groups = [("竖向", offsets)]
    for g in sorted({t[3] for t in h_offsets}):
        groups.append(("横向（标记 <%s>）" % g.decode(),
                       [t[:3] for t in h_offsets if t[3] == g]))
    for name, offs in groups:
        ref = sorted(o for o, _, _ in offs)[len(offs) // 2]
        bad = [(o, a, m) for o, a, m in offs if abs(o - ref) > JUDOU_TOLERANCE_EM]
        if bad:
            print("FAIL: %d/%d 个句读标记%s偏离所附的字（应为 %.3f 字高）："
                  % (len(bad), len(offs), name, ref))
            for o, a, m in bad:
                print("  字 (%.2f, %.2f) %.2fpt → 句读 (%.2f, %.2f)：%.3f 字高"
                      % (a[0], a[1], a[2], m[0], m[1], o))
            rc = 1
        else:
            print("PASS: %d 个句读标记相对所附字的%s偏移一致（%.3f 字高，容差 %g）"
                  % (len(offs), name, ref, JUDOU_TOLERANCE_EM))
    return rc


def compile_tex(tex_path, workdir):
    env = dict(os.environ, OSFONTDIR=FONTS_DIR)
    r = subprocess.run(
        [
            "lualatex",
            "-interaction=nonstopmode",
            "-output-directory=" + workdir,
            os.path.abspath(tex_path),
        ],
        cwd=os.path.dirname(os.path.abspath(tex_path)),
        env=env,
        capture_output=True,
    )
    base = os.path.splitext(os.path.basename(tex_path))[0]
    pdf = os.path.join(workdir, base + ".pdf")
    if r.returncode != 0 and not os.path.exists(pdf):
        sys.stderr.write(r.stdout.decode(errors="replace")[-3000:])
        raise SystemExit("FAIL: 编译失败 " + tex_path)
    return pdf


def run(fn, target):
    if target.endswith(".pdf"):
        return fn(target)
    with tempfile.TemporaryDirectory() as workdir:
        return fn(compile_tex(target, workdir))


def main():
    args = sys.argv[1:]
    if args and args[0] == "--judou":
        return run(check_judou, args[1] if len(args) > 1 else JUDOU_TEX)
    if args:
        return run(check, args[0])
    rc = run(check, DEFAULT_TEX)
    for tex, min_marks in JUDOU_TEXES:
        print("[句读] " + os.path.relpath(tex, REPO_ROOT))
        rc = run(lambda pdf: check_judou(pdf, min_marks), tex) or rc
    return rc


if __name__ == "__main__":
    sys.exit(main())
