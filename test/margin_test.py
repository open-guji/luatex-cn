#!/usr/bin/env python3
"""对页固定内容区 / 装订边距 / 书眉锚定 自校验测试（issue #198）。

像素回归只能保证"和上次一样"。本测试不依赖基线图像，用 pdftotext -bbox
读出每个字的位置，直接对边距做度量断言：

1. 固定内容区（twoside=true, 镜像边距=false）：每页正文都落在
   上下左右边距围成的矩形里；奇偶页正文首列 x 坐标完全相同。
2. 书眉锚定内容区（页眉锚点=内容区）：书眉与页码在内容区外侧（奇数页=左、
   偶数页=右，竖排书右侧装订）header-sep 处，内侧没有任何字。
3. 装订边距：加在书脊一侧（奇数页右、偶数页左），内容区宽度不变。
4. 镜像边距（默认模式）方向：margin-inner 在书脊一侧。
5. 默认 ltc-cn-vbook：书眉/页码仍在外侧（与 0.4.3 输出一致）。
6. 自由列宽模式不再让最后一列越过左边距（#198 一并修复）。

用法：
    python3 test/margin_test.py

仅用标准库 + poppler 的 pdftotext（CI 已安装）。
"""

import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

PT_TO_MM = 25.4 / 72
PAPER_W, PAPER_H = 170.0, 240.0  # vbook 默认 16 开
TOL = 0.6  # mm：字形包围盒与网格边界之间的容差

BODY = "天地玄黃宇宙洪荒日月盈昃辰宿列張寒來暑往秋收冬藏閏餘成歲律呂調陽" * 30

failures = []


def expect(cond, msg):
    if not cond:
        failures.append(msg)


def compile_tex(source, workdir, name):
    tex = os.path.join(workdir, name + ".tex")
    with open(tex, "w", encoding="utf-8") as f:
        f.write(source)
    env = dict(os.environ, OSFONTDIR=FONTS_DIR)
    r = subprocess.run(
        ["lualatex", "-interaction=nonstopmode", "-output-directory=" + workdir, tex],
        cwd=workdir, env=env, capture_output=True,
    )
    pdf = os.path.join(workdir, name + ".pdf")
    log = r.stdout.decode(errors="replace")
    if r.returncode != 0 or not os.path.exists(pdf):
        sys.stderr.write(log[-3000:])
        raise SystemExit("FAIL: 编译失败 %s" % name)
    return pdf


def pages_words(pdf):
    """[[(x0, y0, x1, y1, text), ...] per page], mm, y 自上而下。"""
    out = subprocess.run(["pdftotext", "-bbox", pdf, "-"],
                         capture_output=True, check=True).stdout.decode()
    pages = []
    for chunk in re.split(r"<page ", out)[1:]:
        words = []
        for a, b, c, d, t in re.findall(
                r'xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)<',
                chunk):
            words.append((float(a) * PT_TO_MM, float(b) * PT_TO_MM,
                          float(c) * PT_TO_MM, float(d) * PT_TO_MM, t))
        pages.append(words)
    return pages


def document(page_setup, cls="ltc-tw-vbook"):
    return r"""\documentclass{%s}
\setmainfont{TW-Kai}
\pageSetup{%s}
\title{書名}
\chapter{章名}
\begin{document}
\begin{正文}
%s

%s
\end{正文}
\end{document}
""" % (cls, page_setup, BODY, BODY)


def split_running(words, left, right):
    """把字分成 正文（内容区内）与 书眉页码列（内容区左右两侧）。"""
    body, outside_left, outside_right = [], [], []
    for w in words:
        cx = (w[0] + w[2]) / 2
        if cx < left:
            outside_left.append(w)
        elif cx > right:
            outside_right.append(w)
        else:
            body.append(w)
    return body, outside_left, outside_right


def check_box(tag, pno, body, left, right, top, bottom):
    expect(body, "%s 第 %d 页没有正文" % (tag, pno))
    if not body:
        return
    x0 = min(w[0] for w in body)
    x1 = max(w[2] for w in body)
    y0 = min(w[1] for w in body)
    y1 = max(w[3] for w in body)
    expect(x0 >= left - TOL, "%s 第 %d 页正文越过左边界：%.2f < %.2f" % (tag, pno, x0, left))
    expect(x1 <= right + TOL, "%s 第 %d 页正文越过右边界：%.2f > %.2f" % (tag, pno, x1, right))
    expect(y0 >= top - TOL, "%s 第 %d 页正文越过上边界：%.2f < %.2f" % (tag, pno, y0, top))
    expect(y1 <= bottom + TOL, "%s 第 %d 页正文越过下边界：%.2f > %.2f" % (tag, pno, y1, bottom))


def first_column_x(body):
    return max(w[2] for w in body)


def check_fixed(workdir):
    tag = "固定内容区"
    L, R, T, B, SEP = 22.0, 22.0, 25.0, 25.0, 6.0
    pdf = compile_tex(document(
        "twoside = true, 鏡像邊距 = false, 上邊距 = 25mm, 下邊距 = 25mm, "
        "左邊距 = 22mm, 右邊距 = 22mm, 頁眉錨點 = 內容區"), workdir, "fixed")
    pages = pages_words(pdf)
    expect(len(pages) >= 4, "%s：至少要排 4 页才能比较奇偶页（实际 %d 页）" % (tag, len(pages)))
    firsts = {}
    for pno, words in enumerate(pages, 1):
        left, right = L, PAPER_W - R
        body, out_l, out_r = split_running(words, left, right)
        check_box(tag, pno, body, left, right, T, PAPER_H - B)
        odd = pno % 2 == 1
        outer, inner = (out_l, out_r) if odd else (out_r, out_l)
        expect(outer, "%s 第 %d 页外侧没有书眉/页码" % (tag, pno))
        expect(not inner, "%s 第 %d 页内侧（书脊侧）出现了字：%s" % (tag, pno, [w[4] for w in inner]))
        if outer:
            cx = sum((w[0] + w[2]) / 2 for w in outer) / len(outer)
            want = left - SEP if odd else right + SEP
            expect(abs(cx - want) < 1.0,
                   "%s 第 %d 页书眉列中线 %.2f，应在 %.2f" % (tag, pno, cx, want))
            top = min(w[1] for w in outer)
            expect(abs(top - T) < 1.0, "%s 第 %d 页书眉顶端 %.2f，应与内容区上边 %.2f 对齐" % (tag, pno, top, T))
        if body:
            firsts.setdefault(pno % 2, round(first_column_x(body), 2))
    if len(firsts) == 2:
        expect(firsts[0] == firsts[1],
               "%s：奇偶页正文首列不重合（奇 %.2f，偶 %.2f）" % (tag, firsts[1], firsts[0]))


def check_binding_offset(workdir):
    tag = "装订边距"
    L, R, G = 20.0, 20.0, 8.0
    pdf = compile_tex(document(
        "twoside = true, mirror-margins = false, margin-left = 20mm, margin-right = 20mm, "
        "binding-offset = 8mm, header-anchor = content"), workdir, "gutter")
    pages = pages_words(pdf)
    firsts = {}
    for pno, words in enumerate(pages[:4], 1):
        odd = pno % 2 == 1
        left = L if odd else L + G
        right = PAPER_W - R - G if odd else PAPER_W - R
        body, _, _ = split_running(words, left, right)
        check_box(tag, pno, body, left, right, 30.0, PAPER_H - 20.0)
        if body:
            firsts.setdefault(pno % 2, first_column_x(body))
    if len(firsts) == 2:
        expect(abs((firsts[0] - firsts[1]) - G) < 0.05,
               "%s：偶数页内容区应比奇数页整体右移 %.1fmm（实际 %.2f）" % (tag, G, firsts[0] - firsts[1]))


def check_mirror_direction(workdir):
    tag = "镜像边距方向"
    INNER, OUTER = 30.0, 10.0
    pdf = compile_tex(document(
        "twoside = true, margin-inner = 30mm, margin-outer = 10mm"), workdir, "mirror")
    pages = pages_words(pdf)
    for pno, words in enumerate(pages[:4], 1):
        odd = pno % 2 == 1
        # 奇数页（左页）书脊在右：右边距 = inner
        left, right = (OUTER, PAPER_W - INNER) if odd else (INNER, PAPER_W - OUTER)
        # 纸边锚定的书眉在纸边 3mm 处，排除最外 9mm
        body = [w for w in words if 9.0 < (w[0] + w[2]) / 2 < PAPER_W - 9.0]
        check_box(tag, pno, body, left, right, 30.0, PAPER_H - 20.0)


def check_default_vbook(workdir):
    tag = "默认 vbook"
    pdf = compile_tex(document("", cls="ltc-cn-vbook").replace("\\pageSetup{}\n", ""),
                      workdir, "default")
    pages = pages_words(pdf)
    for pno, words in enumerate(pages[:2], 1):
        edge = [w for w in words if (w[0] + w[2]) / 2 < 12.0 or (w[0] + w[2]) / 2 > PAPER_W - 12.0]
        expect(edge, "%s 第 %d 页没有书眉/页码" % (tag, pno))
        on_left = all((w[0] + w[2]) / 2 < 12.0 for w in edge)
        on_right = all((w[0] + w[2]) / 2 > PAPER_W - 12.0 for w in edge)
        if pno % 2 == 1:
            expect(on_left, "%s 第 %d 页（左页）书眉页码应在左侧外缘" % (tag, pno))
        else:
            expect(on_right, "%s 第 %d 页（右页）书眉页码应在右侧外缘" % (tag, pno))


def main():
    with tempfile.TemporaryDirectory() as workdir:
        check_fixed(workdir)
        check_binding_offset(workdir)
        check_mirror_direction(workdir)
        check_default_vbook(workdir)
    if failures:
        print("FAIL: %d 条断言失败" % len(failures))
        print("\n".join("  " + f for f in failures))
        return 1
    print("PASS: 固定内容区 / 装订边距 / 镜像方向 / 书眉锚定 断言全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
