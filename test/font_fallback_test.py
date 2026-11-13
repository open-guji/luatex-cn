#!/usr/bin/env python3
"""字体回退链自校验测试（issue #197）。

\\设置字体族 的回退链原先用 luaotfload 原生 fallback：每出现一个新字号，
就把整条链上每支字体按该字号全部载入（六支链约 90 MB/字号），长书 OOM。
现改为按需回退（tex/fonts/luatex-cn-font-fallback.lua）。本测试不依赖基线图像，
直接编译小文档断言两件事：

1. 回退仍然生效——主字体 TW-Kai 没有的扩展 B 字（U+20000 等）在多个字号下
   都由链上的 Jigmo2 补上：日志里没有 "Missing character"，PDF 里嵌入了 Jigmo2。

2. 字号不再乘以回退链的体量——正文只用主字体就有的字时，多出 N 种字号，
   挂三支回退链的文档 Lua 堆增长与只用单支字体的文档相当（容差见 MEM_*）。
   原生 fallback 下每种字号都要把 Jigmo、Jigmo2 整支载一遍，会远超容差——
   测试会用 LUATEXCN_NATIVE_FALLBACK=1 切回原生 fallback 验证这一点，
   保证断言确实能抓到回归。

用法：
    python3 test/font_fallback_test.py

字体同回归测试：经 OSFONTDIR 指向 test/fonts/（scripts/download_test_fonts.sh 下载，
TW-Kai / Jigmo / Jigmo2 均为 regression-test 必需字体）。仅用标准库。
"""

import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(REPO_ROOT, "test", "fonts")

CHAIN = "TW-Kai, Jigmo, Jigmo2"
SINGLE = "TW-Kai"
# 主字体就有的常用字
COMMON = "天地玄黃宇宙洪荒"
# 扩展 B：TW-Kai 没有，Jigmo2 有
EXT_B = "\U00020000\U00020001\U00020002"

SIZES = ["28pt", "24pt", "21pt", "18.5pt", "16.3pt", "14.7pt", "13.1pt"]

# 每多一种字号，挂链文档的 Lua 堆增长不得超过单字体文档增长 × 倍数 + 余量
MEM_RATIO = 1.5
MEM_SLACK_KB = 8 * 1024

TEMPLATE = r"""\documentclass{ltc-guji}
\pdfvariable objcompresslevel=0
\关闭分页
\无标点模式
\设置字体族{%(family)s}
\tracinglostchars=2
\AtEndDocument{\directlua{collectgarbage("collect")
  texio.write_nl("term and log", "LUAMEM_KB " .. math.floor(collectgarbage("count")))}}
\begin{document}
\begin{正文}
%(body)s
\end{正文}
\end{document}
"""


def compile_doc(workdir, name, family, sizes, text, extra_env=None):
    body = "\n".join(
        r"\样式[font-size=%s]{%s}\换行" % (s, text) for s in sizes
    )
    tex = os.path.join(workdir, name + ".tex")
    with open(tex, "w", encoding="utf-8") as f:
        f.write(TEMPLATE % {"family": family, "body": body})
    env = dict(os.environ, OSFONTDIR=FONTS_DIR)
    env.pop("LUATEXCN_NATIVE_FALLBACK", None)
    if extra_env:
        env.update(extra_env)
    r = subprocess.run(
        ["lualatex", "-interaction=nonstopmode", "-output-directory=" + workdir, tex],
        cwd=workdir, env=env, capture_output=True,
    )
    pdf = os.path.join(workdir, name + ".pdf")
    log_path = os.path.join(workdir, name + ".log")
    log = ""
    if os.path.exists(log_path):
        with open(log_path, encoding="utf-8", errors="replace") as f:
            log = f.read()
    if r.returncode != 0 or not os.path.exists(pdf):
        sys.stderr.write(r.stdout.decode(errors="replace")[-3000:])
        raise SystemExit("FAIL: 编译失败 (returncode=%d) %s" % (r.returncode, name))
    m = re.search(r"LUAMEM_KB (\d+)", log)
    if not m:
        raise SystemExit("FAIL: 日志中没有 LUAMEM_KB（%s）" % name)
    with open(pdf, "rb") as f:
        pdf_bytes = f.read()
    return int(m.group(1)), log, pdf_bytes


def check_fallback_works(workdir):
    _, log, pdf = compile_doc(workdir, "fb-extb", CHAIN, SIZES[:3], COMMON + EXT_B)
    missing = [l for l in log.splitlines() if "Missing character" in l]
    if missing:
        raise SystemExit("FAIL: 回退链没有补上扩展 B 字：\n  " + "\n  ".join(missing[:5]))
    if b"Jigmo2" not in pdf:
        raise SystemExit("FAIL: PDF 中没有嵌入回退字体 Jigmo2")
    print("PASS  扩展 B 字在 3 种字号下均由回退字体 Jigmo2 补上")


def check_memory_per_size(workdir):
    one = SIZES[:1]
    many = SIZES
    extra = len(many) - len(one)
    s1, _, _ = compile_doc(workdir, "mem-single-1", SINGLE, one, COMMON)
    sn, _, _ = compile_doc(workdir, "mem-single-n", SINGLE, many, COMMON)
    c1, _, _ = compile_doc(workdir, "mem-chain-1", CHAIN, one, COMMON)
    cn, _, _ = compile_doc(workdir, "mem-chain-n", CHAIN, many, COMMON)
    single_per = (sn - s1) / extra
    chain_per = (cn - c1) / extra
    limit = single_per * MEM_RATIO + MEM_SLACK_KB
    print("      单字体  每多一种字号 Lua 堆 +%.1f MB (%d → %d KB)" % (single_per / 1024, s1, sn))
    print("      三支链  每多一种字号 Lua 堆 +%.1f MB (%d → %d KB)" % (chain_per / 1024, c1, cn))
    if chain_per > limit:
        raise SystemExit(
            "FAIL: 回退链让每种字号多占 %.1f MB（上限 %.1f MB）——"
            "回退字体可能又在每个字号被整支载入（#197）" % (chain_per / 1024, limit / 1024))
    print("PASS  回退链不随字号数目额外占内存（上限 %.1f MB/字号）" % (limit / 1024))

    # 灵敏度自检：换回 luaotfload 原生 fallback，同样的文档必须超过上限，
    # 否则这条断言抓不到 #197 的回归
    native = {"LUATEXCN_NATIVE_FALLBACK": "1"}
    o1, _, _ = compile_doc(workdir, "mem-native-1", CHAIN, one, COMMON, native)
    on, _, _ = compile_doc(workdir, "mem-native-n", CHAIN, many, COMMON, native)
    native_per = (on - o1) / extra
    print("      原生 fallback 每多一种字号 Lua 堆 +%.1f MB (%d → %d KB)" % (native_per / 1024, o1, on))
    if native_per <= limit:
        raise SystemExit(
            "FAIL: 原生 fallback 也没超过上限（%.1f MB ≤ %.1f MB），内存断言不够灵敏"
            % (native_per / 1024, limit / 1024))
    print("PASS  灵敏度自检：原生 fallback 每种字号多占 %.1f MB，超过上限" % (native_per / 1024))


def main():
    with tempfile.TemporaryDirectory(prefix="ltc-fallback-") as workdir:
        check_fallback_works(workdir)
        check_memory_per_size(workdir)
    print("\nAll font fallback tests passed!")


if __name__ == "__main__":
    main()
