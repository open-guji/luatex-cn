#!/usr/bin/env python3
"""选项取值的中文写法自校验（issue #85）。

键名早有简繁中文别名，取值却多数只认英文：`对齐=顶`、`显示=是`、
`页码位置=内侧` 都会报错。tex/shared/luatex-cn-zh-values.sty 用一张
对照表 + 每个模块一行启用列表统一兜底。本测试检查三件事：

1. 覆盖：源码里每个 choice / 布尔 key 都在所属模块的
   \\luatexcn_zh_values_enable:nn 列表里（新增 key 忘了登记会在这里失败）。
2. 生效：编译小文档，用中文值设 key，从日志读回内部变量，断言等于对应英文值；
   英文值照常可用。
3. 报错：不在对照表里的值给出「不接受值」的错误，而不是被静默吞掉。

用法：
    python3 test/zh_value_test.py
"""

import glob
import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

DEFINE_RE = re.compile(r"\\keys_define:nn\s*\{\s*([^}]*?)\s*\}")
KEY_RE = re.compile(r"^\s*(\S+)\s+\.(bool_g?set(_inverse)?:N|choices?:(nn)?)")
ENABLE_RE = re.compile(
    r"\\luatexcn_zh_values_enable:nn\s*\{\s*([^}]*?)\s*\}\s*\{([^}]*)\}", re.S
)


def check_coverage():
    """每个 choice/布尔 key 都要登记到 zh-values 启用列表。"""
    files = glob.glob(os.path.join(REPO_ROOT, "tex", "**", "*.sty"), recursive=True)
    files += glob.glob(os.path.join(REPO_ROOT, "tex", "*.cls"))
    missing = []
    for path in sorted(files):
        with open(path, encoding="utf8") as f:
            text = f.read()
        enabled = set()
        for m in ENABLE_RE.finditer(text):
            for k in m.group(2).split(","):
                enabled.add((m.group(1), k.strip()))
        module = None
        for line in text.splitlines():
            m = DEFINE_RE.search(line)
            if m:
                module = m.group(1)
            m = KEY_RE.match(line)
            if m and (module, m.group(1)) not in enabled:
                missing.append(f"{os.path.relpath(path, REPO_ROOT)}: {module} / {m.group(1)}")
    return sorted(set(missing))


# (模块, 设置, 读回的表达式, 期望值)
# 读回表达式在 expl3 下展开；布尔用 \bool_if:NTF ... {true}{false}
def b(var):
    return r"\bool_if:NTF " + var + " {true}{false}"


VBOOK_CASES = [
    ("luatexcn / column", "对齐=底", r"\int_use:N \l_tmpa_int", "1"),
    ("luatexcn / column", "對齊=居中", r"\int_use:N \l_tmpa_int", "2"),
    ("luatexcn / column", "align=stretch", r"\int_use:N \l_tmpa_int", "3"),
    ("luatexcn / column", "末行=是", b(r"\l__luatexcn_column_last_bool"), "true"),
    ("luatexcn / column", "末行=否", b(r"\l__luatexcn_column_last_bool"), "false"),
    ("luatexcn / content", "横对齐=居中", r"\l__luatexcn_content_halign_tl", "center"),
    ("luatexcn / content", "边框=开", b(r"\l__luatexcn_content_border_bool"), "true"),
    ("luatexcn / content", "border=关", b(r"\l__luatexcn_content_border_bool"), "false"),
    ("luatexcn / banxin / book-ear", "位置=两侧", r"\l__luatexcn_banxin_book_ear_position_tl", "both"),
    ("luatexcn / banxin / book-ear", "显示=是", b(r"\l__luatexcn_banxin_book_ear_show_bool"), "true"),
    ("luatexcn / inverted", "断口=八角", r"\l__luatexcn_inverted_break_tl", "octagon"),
    ("luatexcn / inverted", "斷口=直角", r"\l__luatexcn_inverted_break_tl", "square"),
    ("luatexcn / punct", "标点风格=大陆", r"\l__luatexcn_punct_style_tl", "mainland"),
    ("luatexcn / punct", "標點風格=臺灣", r"\l__luatexcn_punct_style_tl", "taiwan"),
    ("luatexcn / punct", "宽度调整=上下文", r"\l__luatexcn_punct_squeezemode_tl", "context"),
    ("luatexcn / punct", "行末点号=自然", r"\l__luatexcn_punct_lineendpunct_tl", "natural"),
    ("luatexcn / punct", "禁则=否", b(r"\l__luatexcn_punct_kinsoku_bool"), "false"),
    ("luatexcn / page", "页码位置=外侧", r"\l_cn_vbook_page_number_position_tl", "outer"),
    ("luatexcn / page", "页码位置=中", r"\l_cn_vbook_page_number_position_tl", "center"),
    ("luatexcn / page", "页眉锚点=纸张", r"\l_cn_vbook_header_anchor_tl", "paper"),
    ("luatexcn / page", "页眉位置=内侧", r"\l_cn_vbook_header_position_tl", "inner"),
]

# 夹注（textflow）与线装封面只在 ltc-guji 里加载
GUJI_CASES = [
    ("luatexcn / textflow", "单列=左", r"\l_tmpa_tl", "2"),
    ("luatexcn / textflow", "單列=無", r"\l_tmpa_tl", "0"),
    ("luatexcn / textflow", "自动均衡=否", b(r"\l__luatexcn_textflow_auto_balance_bool"), "false"),
    ("luatexcn / threadcover", "小字位置=随后", r"\l__luatexcn_tcover_small_pos_tl", "follow"),
    ("luatexcn / threadcover", "小字位置=底部", r"\l__luatexcn_tcover_small_pos_tl", "bottom"),
]

HORI_CASES = [
    ("luatexcn / hori", "标点风格=台湾", r"\l__luatexcn_hori_style_tl", "taiwan"),
    ("luatexcn / hori", "禁则级别=严格", r"\l__luatexcn_hori_level_tl", "strict"),
    ("luatexcn / hori", "引号体例=直角引号", r"\l__luatexcn_hori_quotestyle_tl", "corner"),
    ("luatexcn / hori", "末行对齐=两端对齐", r"\l__luatexcn_hori_lastline_tl", "justify"),
    ("luatexcn / hori", "行首夹注符号=缩减", r"\l__luatexcn_hori_linestartbracket_tl", "trim"),
    ("luatexcn / hori", "中西间距=否", b(r"\l__luatexcn_hori_cjkspace_bool"), "false"),
    ("luatexcn / hori", "hanging-punct=是", b(r"\l__luatexcn_hori_hanging_bool"), "true"),
]

# 不在对照表里的值必须报错
BAD_CASES = [
    ("luatexcn / column", "对齐=乱写"),
    ("luatexcn / column", "末行=也许"),
]


def make_doc(preamble, cases, bad):
    lines = [preamble, r"\ExplSyntaxOn"]
    for i, (module, setting, expr, _) in enumerate(cases):
        lines.append(
            r"\keys_set:nn {%s} {%s} \iow_term:e { ZHV|%d|%s| }" % (module, setting, i, expr)
        )
    for module, setting in bad:
        lines.append(r"\keys_set:nn {%s} {%s}" % (module, setting))
    lines += [r"\ExplSyntaxOff", r"\begin{document}", "x", r"\end{document}", ""]
    return "\n".join(lines)


def run(name, tex, cases, bad):
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, name + ".tex")
        with open(path, "w", encoding="utf8") as f:
            f.write(tex)
        env = dict(os.environ, OSFONTDIR=FONTS_DIR)
        proc = subprocess.run(
            ["lualatex", "-interaction=nonstopmode", path],
            cwd=tmp, env=env, capture_output=True,
        )
        with open(os.path.join(tmp, name + ".log"), encoding="utf8", errors="replace") as f:
            log = f.read()
    got = dict(re.findall(r"ZHV\|(\d+)\|([^|]*)\|", log))
    for i, (module, setting, _, want) in enumerate(cases):
        val = got.get(str(i), "<未输出>").strip()
        status = "PASS" if val == want else "FAIL"
        print(f"  {status}  {module:30s} {setting:22s} -> {val}  (期望 {want})")
        if val != want:
            failures.append(f"{module} {setting}: {val} != {want}")
    errors = re.findall(r"! Package luatex-cn Error: 选项 '([^']*)' 不接受值 '([^']*)'", log)
    for module, setting in bad:
        key, value = setting.split("=")
        ok = (key_target(key), value) in [(k, v) for k, v in errors]
        print(f"  {'PASS' if ok else 'FAIL'}  {module:30s} {setting:22s} -> {'报错' if ok else '未报错'}")
        if not ok:
            failures.append(f"{module} {setting}: 未报「不接受值」错误")
    other = [l for l in log.splitlines() if l.startswith("! ") and "不接受值" not in l]
    if other:
        failures.append(f"{name}: 其他 TeX 错误: {other[:3]}")
    return failures


def key_target(zh_key):
    # 中文键名经 .meta:n 转发到英文 key，报错里出现的是英文 key 名
    return {"对齐": "align"}.get(zh_key, zh_key)


def main():
    failures = []
    print("== 覆盖：choice / 布尔 key 都已登记 zh-values")
    missing = check_coverage()
    for m in missing:
        print("  FAIL  未登记", m)
    if not missing:
        print("  PASS")
    failures += missing

    print("== 竖排（ltc-cn-vbook）")
    failures += run(
        "zhv-vbook",
        make_doc("\\documentclass{ltc-cn-vbook}\n\\setmainfont{TW-Kai}", VBOOK_CASES, BAD_CASES),
        VBOOK_CASES, BAD_CASES,
    )
    print("== 古籍（ltc-guji）")
    failures += run(
        "zhv-guji",
        make_doc("\\documentclass{ltc-guji}\n\\setmainfont{TW-Kai}", GUJI_CASES, []),
        GUJI_CASES, [],
    )
    print("== 横排（luatex-cn-hori）")
    failures += run(
        "zhv-hori",
        make_doc("\\documentclass{article}\n\\usepackage{luatex-cn-hori}", HORI_CASES, []),
        HORI_CASES, [],
    )
    if failures:
        print(f"\n{len(failures)} 项失败")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("\n全部通过")


if __name__ == "__main__":
    main()
