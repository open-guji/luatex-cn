#!/usr/bin/env python3
"""参数相互覆盖提醒的自校验测试（issue #195 第三步）。

很多「几个参数一起用页面就变形」其实是一个参数静默覆盖了另一个。
core/luatex-cn-core-param-check.lua 在排版时检查这些组合并各发一次警告。
本测试编译小文档，对每个组合断言两件事：

1. 用户设的值确实没生效（读排版后的 Lua 状态），警告说的是实情；
2. 警告出现，且只在「用户设了」时出现：类文件与模板 .cfg 设的值不算，
   所以只用模板（含全部内置模板）的文档一条都不应有。

用法：
    python3 test/param_check_test.py
"""

import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

# 排版后读 Lua 状态：格宽、格高、每页列数（单位 pt）
PROBE_LUA = r"""
local c = _G.content
texio.write_nl("term and log", string.format("PROBE|gw=%.2f|gh=%.2f|cols=%s|",
    (c.grid_width or 0) / 65536, (c.grid_height or 0) / 65536, tostring(c.page_columns)))
"""

BODY = r"""
\begin{document}
\begin{正文}
黃帝者，少典之子，姓公孫，名曰軒轅。生而神靈，弱而能言，幼而徇齊，長而敦敏，成而聰明。
\end{正文}
\end{document}
"""

WARN = "luatex-cn Warning:"

# (名字, 文档类选项, 导言区设置, 应出现的警告片段 或 None, 对 Lua 状态的断言)
CASES = [
    ("template-only", "", "", None,
     lambda s: s["gh"] > 27 and s["cols"] == "17"),
    ("grid-height", "", r"\contentSetup{grid-height=40pt}", "grid-height is ignored",
     lambda s: abs(s["gh"] - 40) > 1),
    ("grid-height-zh", "", r"\内容设置{格高=40pt}", "grid-height is ignored",
     lambda s: abs(s["gh"] - 40) > 1),
    ("grid-height-honoured", "", r"\contentSetup{n-char-per-col=0, grid-height=40pt}", None,
     lambda s: abs(s["gh"] - 40) < 0.01),
    ("grid-height-gujisetup", "", r"\gujiSetup{grid-height=40pt}", "grid-height is ignored",
     lambda s: abs(s["gh"] - 40) > 1),
    ("grid-width", "", r"\contentSetup{grid-width=40pt}", "grid-width is ignored",
     lambda s: abs(s["gw"] - 40) > 1),
    ("page-columns-banxin", "", r"\contentSetup{page-columns=10}", "does not reserve the banxin",
     lambda s: s["cols"] == "10"),
    ("page-columns-n-column", "", r"\banxinSetup{banxin=false}\contentSetup{n-column=6, page-columns=10}",
     "page-columns overrides n-column", lambda s: s["cols"] == "10"),
    ("font-size", "", r"\contentSetup{font-size=40pt}", "larger than the grid height",
     lambda s: s["gh"] < 40),
    ("banxin-ratios", "", r"\banxinSetup{banxin-upper-ratio=0.6, banxin-middle-ratio=0.6}",
     "must not exceed 1", lambda s: True),
    ("template-switch", "", r"\gujiSetup{template=红楼梦甲戌本}", None, lambda s: True),
    # 只改纸张、不碰字号与每行字数（如只排封面）：格高变小也不提醒
    ("paper-only", "", r"\pageSetup{paper-height=260mm}", None, lambda s: s["gh"] < 28),
    ("n-char-per-col", "", r"\contentSetup{n-char-per-col=30}", "larger than the grid height",
     lambda s: s["gh"] < 28),
]

# 内置模板（文档类选项）单独使用时不应有任何参数提醒
TEMPLATES = ["四库全书", "四库全书彩色", "红楼梦甲戌本", "欧式族谱", "四库全书文渊阁简明目录"]

failures = []


def expect(cond, msg):
    print(("  PASS  " if cond else "  FAIL  ") + msg)
    if not cond:
        failures.append(msg)


def compile_doc(name, options, preamble):
    tex = (r"\documentclass[%s]{ltc-guji}" % options + "\n" + r"\setmainfont{TW-Kai}" + "\n"
           + preamble + "\n"
           + r"\AddToHook{enddocument/end}{\directlua{dofile('probe.lua')}}" + BODY)
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "probe.lua"), "w", encoding="utf8") as f:
            f.write(PROBE_LUA)
        path = os.path.join(tmp, name + ".tex")
        with open(path, "w", encoding="utf8") as f:
            f.write(tex)
        env = dict(os.environ, OSFONTDIR=FONTS_DIR)
        subprocess.run(["lualatex", "-interaction=nonstopmode", path],
                       cwd=tmp, env=env, capture_output=True)
        with open(os.path.join(tmp, name + ".log"), encoding="utf8", errors="replace") as f:
            log = f.read()
    # 日志按 79 列折行，拼回去再匹配
    flat = log.replace("\n", "")
    state = {}
    m = re.search(r"PROBE\|gw=([\d.]+)\|gh=([\d.]+)\|cols=(\w+)\|", flat)
    if m:
        state = {"gw": float(m.group(1)), "gh": float(m.group(2)), "cols": m.group(3)}
    # 本模块的提醒都带中文全角括号里的 key 名；只数这些，别的模块的警告不管
    warnings = [w for w in re.findall(r"luatex-cn Warning: (.*?)\)\.", flat)
                if "（" in w and any(k in w for k in
                    ("grid-", "page-columns", "font-size", "banxin-upper-ratio"))]
    errors = [l for l in log.splitlines() if l.startswith("! ")]
    return state, warnings, errors


def main():
    for name, options, preamble, want, state_ok in CASES:
        print(f"== {name}")
        state, warnings, errors = compile_doc(name, options, preamble)
        expect(not errors, f"无 TeX 错误 {errors[:2]}")
        expect(bool(state) and state_ok(state), f"排版结果符合预期 {state}")
        if want is None:
            expect(not warnings, f"没有参数提醒 {warnings[:1]}")
        else:
            hits = [w for w in warnings if want in w]
            expect(len(hits) == 1, f"出现且只出现一次「{want}」(共 {len(hits)} 条)")
            expect(len(warnings) == len(hits), f"没有别的参数提醒 {[w for w in warnings if want not in w][:1]}")

    for tpl in TEMPLATES:
        print(f"== 模板 {tpl}")
        state, warnings, errors = compile_doc("tpl", tpl, "")
        expect(not errors, f"无 TeX 错误 {errors[:2]}")
        expect(not warnings, f"模板自带的值不触发提醒 {warnings[:1]}")

    if failures:
        print(f"\n{len(failures)} 项失败")
        sys.exit(1)
    print("\n全部通过")


if __name__ == "__main__":
    main()
