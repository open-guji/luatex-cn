#!/usr/bin/env python3
"""对页补页 / 补空白页 自校验测试（issue #176）。

像素回归只能保证"和上次一样"。本测试不依赖基线图像，直接数 PDF 页数、
读每页的文字，断言：

1. 开关关闭（默认）：页数与不写该选项时完全一致，不多出任何空白页。
2. 开启 对页补页：章末落在奇数页就补一页（下一章落在奇数页起），
   章末在偶数页不补；多个 正文 块之间奇偶页按实体页序累计。
3. 补页样式：默认补页带版心/页眉页码；补页样式=空白 则整页无任何字。
4. 手动命令 \\补空白页 / \\InsertBlankPage：块内、块外、连写两次都各补一页。

用法：
    python3 test/blank_page_test.py

仅用标准库 + poppler 的 pdftotext/pdfinfo（CI 已安装）。
"""

import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")


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
    return pdf, log


def page_count(pdf):
    out = subprocess.run(["pdfinfo", pdf], capture_output=True, check=True).stdout.decode()
    return int(re.search(r"^Pages:\s+(\d+)", out, re.M).group(1))


def page_text(pdf, n):
    """第 n 页（从 1 数）的文字，去掉所有空白。"""
    out = subprocess.run(
        ["pdftotext", "-f", str(n), "-l", str(n), pdf, "-"], capture_output=True, check=True
    ).stdout.decode()
    return re.sub(r"\s+", "", out)


# ----------------------------------------------------------------------------
# 文档模板：古籍（带版心）与竖排书（页眉页码由 shipout 钩子画）
# ----------------------------------------------------------------------------

GUJI = r"""\documentclass{ltc-guji}
\setmainfont{TW-Kai}
\关闭分页
%(setup)s
\title{測試書}
\chapter{甲卷}
\begin{document}
%(body)s
\end{document}
"""

VBOOK = r"""\documentclass{ltc-cn-vbook}
\setmainfont{TW-Kai}
\pageSetup{page-number-style=arabic, header-enabled=true%(setup)s}
\begin{document}
%(body)s
\end{document}
"""

# 甲 1 页 → 乙 2 页 → 丙 1 页 → 丁 1 页。
# 默认 5 页：甲=1，乙=2-3，丙=4，丁=5。
# 开启对页补页：甲(1)后补 → 乙=3-4，丙=5（乙在偶数页 4 收尾，丙不补），
# 丁本该是 6 → 补 → 丁=7，共 7 页，空白页是第 2 与第 6 页。
CHAPTERS = r"""\begin{正文}
甲卷第一页\clearpage
\chapter{乙卷}
乙卷第一页\clearpage
乙卷第二页\clearpage
\chapter{丙卷}
丙卷第一页\clearpage
\chapter{丁卷}
丁卷第一页
\end{正文}"""


def body_pages(pdf, n):
    """页 n 是否印了正文（正文里都带「卷第」二字）。"""
    return "卷第" in page_text(pdf, n)


def check_switch_off(workdir):
    """默认关：页数不变，没有空白页。"""
    pdf, _ = compile_tex(GUJI % {"setup": "", "body": CHAPTERS}, workdir, "off")
    n = page_count(pdf)
    bad = [i for i in range(1, n + 1) if not body_pages(pdf, i)]
    fails = []
    if n != 5:
        fails.append("默认应为 5 页，实际 %d 页" % n)
    if bad:
        fails.append("默认不该有空白页，空白页: %s" % bad)
    # 显式写 false 与不写等价
    pdf2, _ = compile_tex(
        GUJI % {"setup": r"\pageSetup{对页补页=false}", "body": CHAPTERS}, workdir, "off2"
    )
    if page_count(pdf2) != 5:
        fails.append("对页补页=false 应为 5 页，实际 %d 页" % page_count(pdf2))
    return fails


def check_facing_on(workdir):
    """开启：奇数页收尾补一页，偶数页收尾不补；补页带版心。"""
    pdf, _ = compile_tex(
        GUJI % {"setup": r"\pageSetup{对页补页=true}", "body": CHAPTERS}, workdir, "on"
    )
    n = page_count(pdf)
    fails = []
    if n != 7:
        fails.append("开启后应为 7 页，实际 %d 页" % n)
        return fails
    blanks = [i for i in range(1, n + 1) if not body_pages(pdf, i)]
    if blanks != [2, 6]:
        fails.append("空白页应在第 2、6 页，实际 %s" % blanks)
    for i in blanks:
        if "測試書" not in page_text(pdf, i):
            fails.append("默认补页样式第 %d 页应带版心（書名），实际无" % i)
    # 每一章都在奇数页起
    for page, label in ((1, "甲"), (3, "乙"), (5, "丙"), (7, "丁")):
        # 竖排文字的提取顺序不定（章题与正文列会交错），只认「首字出现在该页」
        if label not in page_text(pdf, page):
            fails.append("%s卷应从第 %d 页起" % (label, page))
    return fails


def check_plain_style(workdir):
    """补页样式=空白：补出来的页什么都没有。"""
    pdf, _ = compile_tex(
        GUJI % {"setup": r"\pageSetup{对页补页=true, 补页样式=空白}", "body": CHAPTERS},
        workdir, "plain",
    )
    fails = []
    if page_count(pdf) != 7:
        fails.append("补页样式=空白 仍应为 7 页，实际 %d 页" % page_count(pdf))
        return fails
    for i in (2, 6):
        t = page_text(pdf, i)
        if t:
            fails.append("补页样式=空白 的第 %d 页应无任何文字，实际 %r" % (i, t))
    if "測試書" not in page_text(pdf, 1):
        fails.append("正文页的版心不应受影响")
    return fails


MANUAL = r"""\begin{正文}
第一页\clearpage
第二页\补空白页
第三页\InsertBlankPage\补空白页[补页样式=空白]
第四页
\end{正文}
\补空白页
\begin{正文}
第五页
\end{正文}"""


def check_manual(workdir):
    """强制补页：块内每处一页，连写两次是两页，块外也补一页。"""
    pdf, _ = compile_tex(GUJI % {"setup": "", "body": MANUAL}, workdir, "manual")
    n = page_count(pdf)
    fails = []
    # 第一页 | 第二页 | 空白 | 第三页 | 空白 空白(空白样式) | 第四页 | 空白(块外) | 第五页
    expect = ["第一页", "第二页", None, "第三页", None, None, "第四页", None, "第五页"]
    if n != len(expect):
        fails.append("手动补页后应为 %d 页，实际 %d 页" % (len(expect), n))
        return fails
    for i, want in enumerate(expect, start=1):
        t = page_text(pdf, i)
        if want is None:
            if "页" in t:
                fails.append("第 %d 页应为空白页，实际 %r" % (i, t))
        elif want not in t:
            fails.append("第 %d 页应是 %s，实际 %r" % (i, want, t))
    # 块内第二个 \补空白页[补页样式=空白]：第 6 页无版心；第 3、5 页（默认样式）有
    if page_text(pdf, 6):
        fails.append("第 6 页（补页样式=空白）应无任何文字，实际 %r" % page_text(pdf, 6))
    for i in (3, 5, 8):
        if "測試書" not in page_text(pdf, i):
            fails.append("第 %d 页（默认补页样式）应带版心" % i)
    return fails


def check_multiblock(workdir):
    """多个 正文 块：奇偶页按实体页序累计，而不是按块内页号。"""
    body = r"""\begin{正文}
\chapter*{甲}甲卷末
\end{正文}
\begin{正文}
\chapter*{乙}乙卷首\clearpage 乙卷二
\end{正文}
\newpage
\begin{正文}
\chapter*{丙}丙卷首
\end{正文}"""
    pdf, _ = compile_tex(
        VBOOK % {"setup": ", facing-pages=true", "body": body}, workdir, "multi"
    )
    fails = []
    # 甲=1；乙若紧接则在第 2 页（偶）→ 补空白页 2；乙=3-4；丙=5（奇）不补
    n = page_count(pdf)
    if n != 5:
        fails.append("多块文档应为 5 页，实际 %d 页" % n)
        return fails
    got = [page_text(pdf, i) for i in range(1, 6)]
    want = ["甲卷末1", "2", "乙卷首3", "乙卷二4", "丙卷首5"]
    if got != want:
        fails.append("多块文档各页应为 %s，实际 %s" % (want, got))
    return fails


def check_vbook_styles(workdir):
    """竖排书：默认补页带页码，补页样式=空白 则页码也没有。"""
    body = r"""\begin{正文}
甲\补空白页 乙\补空白页[补页样式=空白] 丙
\end{正文}"""
    pdf, _ = compile_tex(VBOOK % {"setup": "", "body": body}, workdir, "vbook")
    fails = []
    n = page_count(pdf)
    if n != 5:
        fails.append("应为 5 页，实际 %d 页" % n)
        return fails
    got = [page_text(pdf, i) for i in range(1, 6)]
    want = ["甲1", "2", "乙3", "", "丙5"]
    if got != want:
        fails.append("各页应为 %s，实际 %s" % (want, got))
    return fails


def check_unknown_style_warns(workdir):
    """不认识的补页样式要警告，而不是悄悄吞掉。"""
    body = r"\begin{正文}甲\补空白页[补页样式=红色]乙\end{正文}"
    _, log = compile_tex(VBOOK % {"setup": "", "body": body}, workdir, "unknown")
    if "unknown 补页样式" not in log:
        return ["未知补页样式没有警告"]
    return []


CHECKS = [
    ("开关关闭时页数不变", check_switch_off),
    ("开启后奇数页收尾补一页、偶数页收尾不补", check_facing_on),
    ("补页样式=空白 整页无字", check_plain_style),
    ("手动命令 \\补空白页 / \\InsertBlankPage", check_manual),
    ("多个 正文 块按实体页序判奇偶", check_multiblock),
    ("竖排书：带页码 / 无页码 两种补页样式", check_vbook_styles),
    ("未知补页样式发警告", check_unknown_style_warns),
]


def main():
    failed = 0
    with tempfile.TemporaryDirectory() as workdir:
        for title, fn in CHECKS:
            fails = fn(workdir)
            if fails:
                failed += 1
                print("FAIL: " + title)
                for f in fails:
                    print("  " + f)
            else:
                print("PASS: " + title)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
