#!/usr/bin/env python3
"""生成回归测试用的极小字体 PuaVertTest.ttf（自绘方块字形，无第三方字体版权问题）。

模拟 Windows 宋体等字体的行为：vert GSUB 把 ，。 换成没有 Unicode 的竖排字形
（cmap 里没有），luaotfload 会给它们分配 PUA 码位，用来复现句读模式识别不出标点。
需要 fonttools：  pip install fonttools
用法：python3 scripts/make_pua_vert_test_font.py <输出路径>
"""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString

CHARS = "天地玄黄宇宙洪荒日月盈昃辰宿列张"
PUNCT = {"，": "commaV", "。": "periodV"}
UPM = 1000


def box(x0, y0, x1, y1, hollow=True):
    pen = TTGlyphPen(None)
    pen.moveTo((x0, y0)); pen.lineTo((x0, y1)); pen.lineTo((x1, y1)); pen.lineTo((x1, y0)); pen.closePath()
    if hollow:
        pen.moveTo((x0 + 60, y0 + 60)); pen.lineTo((x1 - 60, y0 + 60)); pen.lineTo((x1 - 60, y1 - 60)); pen.lineTo((x0 + 60, y1 - 60)); pen.closePath()
    return pen.glyph()


def main(out):
    names = [".notdef"] + [f"g{ord(c):04X}" for c in CHARS]
    cmap = {ord(c): f"g{ord(c):04X}" for c in CHARS}
    glyphs = {".notdef": box(100, 0, 900, 800)}
    for c in CHARS:
        glyphs[f"g{ord(c):04X}"] = box(100, 0, 900, 800)
    # 横排标点（有 Unicode）+ 竖排替换字形（无 Unicode，名字不是 uniXXXX）
    for ch, vname in PUNCT.items():
        hname = f"g{ord(ch):04X}"
        names += [hname, vname]
        cmap[ord(ch)] = hname
        glyphs[hname] = box(100, 0, 300, 200, hollow=False)   # 横排：左下
        glyphs[vname] = box(700, 600, 900, 800, hollow=False)  # 竖排：右上
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({n: (UPM, 0) for n in names})
    fb.setupHorizontalHeader(ascent=880, descent=-120)
    fb.setupNameTable({"familyName": "PuaVertTest", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=880, sTypoDescender=-120, usWinAscent=880, usWinDescent=120)
    fb.setupPost(keepGlyphNames=False)  # format 3：不带字形名 → 无法由名字推出 Unicode
    fea = "languagesystem DFLT dflt;\nlanguagesystem hani dflt;\nfeature vert {\n"
    fea += "".join(f"sub g{ord(ch):04X} by {v};\n" for ch, v in PUNCT.items()) + "} vert;\n"
    addOpenTypeFeaturesFromString(fb.font, fea)
    fb.save(out)


if __name__ == "__main__":
    main(sys.argv[1])
