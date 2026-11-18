#!/usr/bin/env python3
"""\\gujiSetup / \\defineGujiTemplate 自校验测试。

1. \\defineGujiTemplate{名}{...} 里可以直接写版式 key（n-column、字号、margin-top、
   不带值的布尔 key……），它们被转给 \\pageSetup / \\contentSetup / \\banxinSetup。
   以前 \\gujiSetup 的 keyspace 只有 template 一个 key，写版式 key 直接报错。
2. \\gujiSetup{template=红楼梦甲戌本} 认中文模板名（与文档类选项共用对照表）。
3. ltc-guji-digital 的 \\gujiSetup（= \\digitalSetup）同样两条都成立；
   找不到的模板给出「模板不存在」警告而不是未定义消息的错误。
4. 不属于任何模块的 key 发「未知选项」警告，不被静默吞掉。

用法：
    python3 test/template_setup_test.py
"""

import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

PROBE = r"""
\ExplSyntaxOn
\iow_term:e { TPL|%(n)s|ncol|\int_use:N \l__luatexcn_content_n_column_int| }
\iow_term:e { TPL|%(n)s|mt|\l__luatexcn_page_margin_top_tl| }
\iow_term:e { TPL|%(n)s|border|\bool_if:NTF \l__luatexcn_content_border_bool {true}{false}| }
\ExplSyntaxOff
"""

GUJI = r"""\documentclass{ltc-guji}
\setmainfont{TW-Kai}
\contentSetup{border=false}
\defineGujiTemplate{窄版}{n-column=5, 字号=20pt, margin-top=100pt, border}
\gujiSetup{template=窄版}
""" + PROBE % {"n": "custom"} + r"""
\gujiSetup{template=红楼梦甲戌本}
""" + PROBE % {"n": "zhname"} + r"""
\gujiSetup{bogus-key=1}
\begin{document}
\begin{正文}
天地玄黃宇宙洪荒
\end{正文}
\end{document}
"""

DIGITAL = r"""\documentclass{ltc-guji-digital}
\setmainfont{TW-Kai}
\gujiSetup{template=红楼梦甲戌本, 行数=7}
""" + PROBE % {"n": "digital"} + r"""
\gujiSetup{template=不存在的模板}
\begin{document}
x
\end{document}
"""

failures = []


def expect(cond, msg):
    print(("  PASS  " if cond else "  FAIL  ") + msg)
    if not cond:
        failures.append(msg)


def compile_doc(name, tex):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, name + ".tex")
        with open(path, "w", encoding="utf8") as f:
            f.write(tex)
        env = dict(os.environ, OSFONTDIR=FONTS_DIR)
        subprocess.run(["lualatex", "-interaction=nonstopmode", path],
                       cwd=tmp, env=env, capture_output=True)
        with open(os.path.join(tmp, name + ".log"), encoding="utf8", errors="replace") as f:
            log = f.read()
    # 日志按 79 列折行，先拼回去再匹配
    flat = log.replace("\n", "")
    probes = {}
    for name, key, val in re.findall(r"TPL\|(\w+)\|(\w+)\|([^|]*)\|", log):
        probes.setdefault(name, {})[key] = val.strip()
    errors = [l for l in log.splitlines() if l.startswith("! ")]
    return flat, probes, errors


def main():
    print("== ltc-guji")
    flat, p, errors = compile_doc("tpl-guji", GUJI)
    c = p.get("custom", {})
    expect(c.get("ncol") == "5", f"\\defineGujiTemplate 里的 n-column 生效 (ncol={c.get('ncol')})")
    expect(c.get("mt") == "100pt", f"margin-top 转给 \\pageSetup (mt={c.get('mt')})")
    expect(c.get("border") == "true", f"不带值的布尔 key 取默认值 true (border={c.get('border')})")
    z = p.get("zhname", {})
    expect(z.get("ncol") == "12", f"template=红楼梦甲戌本 载入甲戌本模板 (ncol={z.get('ncol')})")
    expect("bogus-key" in flat and "未知选项" in flat, "未知 key 发出警告")
    expect(not errors, f"无 TeX 错误 {errors[:2]}")

    print("== ltc-guji-digital")
    flat, p, errors = compile_doc("tpl-digital", DIGITAL)
    d = p.get("digital", {})
    expect(d.get("ncol") == "7", f"中文模板名 + 版式 key (ncol={d.get('ncol')})")
    expect("不存在的模板" in flat and "模板" in flat, "找不到的模板给出警告")
    expect(not errors, f"无 TeX 错误 {errors[:2]}")

    if failures:
        print(f"\n{len(failures)} 项失败")
        sys.exit(1)
    print("\n全部通过")


if __name__ == "__main__":
    main()
