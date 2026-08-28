#!/usr/bin/env python3
"""颜色 key 自校验测试（issue #163 及同族问题）。

像素回归测试只能保证"和上次一样"——#163 那类 bug（\\夹注设置{color=red}
被 unknown-key fallback 静默吞掉）如果先于基线存在，基线会把错误原样锁住。
本测试不依赖基线图像：直接解析 PDF 内容流里的 `r g b rg` 填充色算符，
断言每个模块设定的颜色确实落到了页面上。

覆盖两件事：

1. 颜色 key 的两种拼法都生效——core 层写 font-color / 字体颜色，
   批注/眉批/侧批/句读写 color / 颜色，两边互为别名。
   test/regression_test/basic/tex/color-keys.tex 刻意每个模块用错位的那一种拼法，
   只要有一个别名失效，对应颜色就不会出现。

2. 颜色值的两种写法都生效——颜色名（red）与 RGB 三元组（{255, 128, 0}，
   模板里用的就是 0-255 形式）。

另外断言未知 key 会发出警告而不是被静默丢弃（这正是 #163 难以被发现的原因）。

用法：
    python3 test/color_test.py

仅用标准库（zlib/re），无第三方依赖。
"""

import os
import re
import subprocess
import sys
import tempfile
import zlib

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")
COLOR_KEYS_TEX = os.path.join(
    REPO_ROOT, "test", "regression_test", "basic", "tex", "color-keys.tex"
)

STREAM_RE = re.compile(rb"stream\r?\n(.*?)endstream", re.DOTALL)
# 填充色与描边色：`r g b rg` / `r g b RG`
RGB_OP_RE = re.compile(r"([\d.]+) ([\d.]+) ([\d.]+) (?:rg|RG)")

# color-keys.tex 里每个模块用的颜色，以及它用的是哪种拼法。
# 拼法一栏就是这个测试的重点：全部是"错位"的那一种，历史上会被静默丢弃。
EXPECTED = [
    ((255, 0, 0), "夹注全局色", "\\夹注设置{颜色=...}（原生 font-color）"),
    ((0, 0, 255), "夹注局部色", "\\夹注[color=...]（原生 font-color）"),
    ((0, 128, 0), "侧批", "\\侧批设置{font-color=...}（原生 color）"),
    ((255, 0, 255), "批注", "\\批注设置{字体颜色=...}（原生 颜色）"),
    ((0, 128, 128), "眉批", "\\眉批设置{font-color=...}（原生 color）"),
    ((255, 128, 0), "句读", "\\句读设置{颜色=...}（原生 judou-color）"),
    ((128, 0, 128), "文本框", "\\文本框[color=...]（原生 font-color）"),
    ((0, 0, 128), "行(Column)", "\\行[颜色=...]（原生 font-color）"),
]

# 0-255 与 0-1 换算后的比较容差（PDF 里写的是 %.4f）
TOLERANCE = 0.002


def iter_content_streams(pdf_bytes):
    for m in STREAM_RE.finditer(pdf_bytes):
        data = m.group(1)
        try:
            data = zlib.decompress(data)
        except zlib.error:
            pass
        yield data


def collect_colors(pdf_path):
    """返回 PDF 内容流里出现过的所有颜色，元素为 (r, g, b) 浮点三元组。"""
    with open(pdf_path, "rb") as f:
        pdf = f.read()
    colors = set()
    for stream in iter_content_streams(pdf):
        for m in RGB_OP_RE.finditer(stream.decode("latin1")):
            colors.add(tuple(float(x) for x in m.groups()))
    return colors


def has_color(colors, rgb255):
    want = tuple(c / 255 for c in rgb255)
    return any(
        all(abs(a - b) <= TOLERANCE for a, b in zip(got, want)) for got in colors
    )


def compile_tex(tex_path, workdir, extra_env=None):
    env = dict(os.environ, OSFONTDIR=FONTS_DIR)
    if extra_env:
        env.update(extra_env)
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
    # 返回码才是准：nonstopmode 下 TeX 报错后仍会产出一份（内容不全的）PDF，
    # 只判断文件是否存在会把出错的编译当成功，后面的颜色扫描还可能误通过。
    if r.returncode != 0 or not os.path.exists(pdf):
        sys.stderr.write(r.stdout.decode(errors="replace")[-3000:])
        raise SystemExit("FAIL: 编译失败 (returncode=%d) %s" % (r.returncode, tex_path))
    return pdf, r.stdout.decode(errors="replace")


def check_color_keys(workdir):
    """每个模块的颜色都必须真的出现在页面上。"""
    pdf, log = compile_tex(COLOR_KEYS_TEX, workdir)
    colors = collect_colors(pdf)
    failures = []
    for rgb, who, how in EXPECTED:
        if not has_color(colors, rgb):
            failures.append("  %s: %s 设定的 RGB%s 没有出现在 PDF 里" % (who, how, rgb))
    # 顺带确认这份文档自己不该触发任何未知 key 警告
    if "luatex-cn Warning" in log:
        failures.append("  color-keys.tex 触发了未知 key 警告（说明还有别名没接上）")
    if failures:
        print("FAIL: %d/%d 个颜色 key 未生效：" % (len(failures), len(EXPECTED)))
        print("\n".join(failures))
        return 1
    print("PASS: %d 个模块的颜色 key 别名全部生效" % len(EXPECTED))
    return 0


JUDOU_TEMPLATE = r"""\documentclass{ltc-guji}
\setmainfont{TW-Kai}
\关闭分页
\开启句读模式
\句读设置{句读颜色=%s}
\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。
\end{正文}
\end{document}
"""

# 同一个颜色的多种写法都必须渲染成同一个 RGB。
# "255,128,0" 曾被原样写进 PDF literal（非法语法），句读点直接失色。
COLOR_FORMATS = [
    ("orange", (255, 128, 0)),
    ("{255,128,0}", (255, 128, 0)),
    ("{255, 128, 0}", (255, 128, 0)),
    ("{1 0.5 0}", (255, 128, 0)),
    ("red", (255, 0, 0)),
]


def check_color_formats(workdir):
    """颜色名 / 0-255 三元组 / 0-1 三元组三种写法必须等价。"""
    failures = []
    for i, (written, expect) in enumerate(COLOR_FORMATS):
        tex = os.path.join(workdir, "fmt%d.tex" % i)
        with open(tex, "w", encoding="utf-8") as f:
            f.write(JUDOU_TEMPLATE % written)
        pdf, _ = compile_tex(tex, workdir)
        if not has_color(collect_colors(pdf), expect):
            failures.append("  句读颜色=%s 未渲染出 RGB%s" % (written, expect))
    if failures:
        print("FAIL: %d/%d 种颜色写法未生效：" % (len(failures), len(COLOR_FORMATS)))
        print("\n".join(failures))
        return 1
    print("PASS: %d 种颜色值写法（颜色名 / 0-255 / 0-1）全部等价" % len(COLOR_FORMATS))
    return 0


# issue #163 报的就是这一行写法。color-keys.tex 里 \夹注设置 用的是中文
# 「颜色」，它另有一条 .meta 通往 font-color，不经过 jiazhu 的英文 color 键；
# 少了这个用例，英文别名失效也测不出来。
JIAZHU_EN_TEX = r"""\documentclass{ltc-guji}
\setmainfont{TW-Kai}
\关闭分页
\无标点模式
\夹注设置{color=%s}
\begin{document}
\begin{正文}
天地\夹注{夹注内容}玄黄
\end{正文}
\end{document}
"""


def check_jiazhu_english_color(workdir):
    """\夹注设置{color=...}（#163 原文写法）必须生效。"""
    tex = os.path.join(workdir, "jiazhu_en.tex")
    with open(tex, "w", encoding="utf-8") as f:
        f.write(JIAZHU_EN_TEX % "{0, 128, 255}")
    pdf, log = compile_tex(tex, workdir)
    if not has_color(collect_colors(pdf), (0, 128, 255)):
        print("FAIL: \\夹注设置{color=...}（issue #163 原文写法）未生效")
        return 1
    if "luatex-cn Warning" in log:
        print("FAIL: \\夹注设置{color=...} 触发了未知 key 警告")
        return 1
    print("PASS: \\夹注设置{color=...}（issue #163 原文写法）生效")
    return 0


UNKNOWN_KEY_TEX = r"""\documentclass{ltc-guji}
\setmainfont{TW-Kai}
\关闭分页
\begin{document}
\begin{正文}
一二三\夹注[这个键根本不存在=1]{注}四五
\end{正文}
\end{document}
"""


def check_unknown_key_warns(workdir):
    """写错的 key 必须发警告——静默丢弃正是 #163 拖了这么久才被发现的原因。"""
    tex = os.path.join(workdir, "unknown.tex")
    with open(tex, "w", encoding="utf-8") as f:
        f.write(UNKNOWN_KEY_TEX)
    _, log = compile_tex(tex, workdir)
    if "这个键根本不存在" not in log or "luatex-cn Warning" not in log:
        print("FAIL: 未知 key 被静默丢弃，没有发出警告")
        return 1
    print("PASS: 未知 key 会发出警告而不是被静默丢弃")
    return 0


def main():
    rc = 0
    with tempfile.TemporaryDirectory() as workdir:
        rc |= check_color_keys(workdir)
        rc |= check_jiazhu_english_color(workdir)
        rc |= check_color_formats(workdir)
        rc |= check_unknown_key_warns(workdir)
    return rc


if __name__ == "__main__":
    sys.exit(main())
