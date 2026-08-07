# LuaTeX-CN

[中文版](README.md)

A LuaTeX package for Chinese typesetting with two goals: **faithful replication of classical (古籍) page layouts**, and **modern Chinese typesetting that follows the W3C *Requirements for Chinese Text Layout* (clreq)**.

- **Classical vertical layout**: Banxin (版心), interlinear notes (夹注), side/top annotations (侧批/眉批), footnotes, seals, judou punctuation, character corrections and ruled borders — the bundled examples reproduce the page layout of sources such as the Wenyuange Siku Quanshu and the Jiaxu manuscript of *Dream of the Red Chamber*.
- **Modern vertical layout**: vertical books in traditional Chinese, with Mainland China or Taiwan punctuation conventions. The details that make vertical text look right are handled automatically per clreq: how wide each punctuation mark should be, what gets compressed first when a column runs out of space, which characters must not start or end a line, and how much space separates Chinese from Western words and numbers. Vertical conventions such as emphasis dots, letting a line-final comma or period hang outside the column, and fitting short numbers like "12" upright into a single character slot are also supported.
- **Modern horizontal layout**: one line — `\usepackage{luatex-cn}` — gives you the same rule set in horizontal writing, plus interlinear marks (proper-name and book-title underlines, emphasis dots), pinyin ruby, and paragraph-level control of widows and orphans.
- **Customisable templates**: layout parameters and templates can be overridden.

"Follows clreq" is not a slogan: the test suite measures the coordinates of every glyph in the output PDF and checks them against the specification clause by clause (currently 119 automated checks). Per-clause status and the few intentional deviations are documented in the **[clreq conformance matrix](doc/CLREQ-CONFORMANCE.md)**.

CTAN: [v0.4.1](https://ctan.org/pkg/luatex-cn) | GitHub Release: [v0.4.1](https://github.com/open-guji/luatex-cn/releases)

> **[Wiki user manual](https://github.com/open-guji/luatex-cn/wiki/EN:Home)** ｜ **[Quick start](https://github.com/open-guji/luatex-cn/wiki/EN:Quick-Start)** ｜ **[Changelog](https://github.com/open-guji/luatex-cn/wiki/EN:Changelog)**

## Showcase

### Classical layout — Siku Quanshu (Wenyuange edition)

| *Siku Quanshu Concise Catalogue* — raised heads, interlinear notes, indentation | *Records of the Grand Historian* — seals, interlinear notes, ruled borders |
| :---: | :---: |
| ![Siku catalogue](示例/首页展示/mulu-color.png) | ![Shiji](示例/首页展示/shiji-bw.png) |
| [source](示例/四库全书简明目录/目录.tex) ｜ [PDF](示例/四库全书简明目录/目录.pdf) | [source](示例/史记五帝本纪/史记-黑白.tex) ｜ [PDF](示例/史记五帝本纪/史记-黑白.pdf) |

### Manuscript — *Dream of the Red Chamber*, Jiaxu edition

| Page 2 (punctuation) | Page 1 (top annotations) |
| :---: | :---: |
| ![Honglou 2](示例/首页展示/honglou-p2.png) | ![Honglou 1](示例/首页展示/honglou-p1.png) |

> [source](示例/红楼梦甲戌本/石头记.tex) | [PDF](示例/红楼梦甲戌本/石头记.pdf)

### Modern vertical book — *Records of the Grand Historian*, chapter 16

| Page 2 | Page 1 |
| :---: | :---: |
| ![Juan 16 p2](示例/首页展示/juan16-p2.png) | ![Juan 16 p1](示例/首页展示/juan16-p1.png) |

> [source](示例/史记卷十六·现代/卷十六.tex) | [PDF](示例/史记卷十六·现代/卷十六.pdf)

More in the [examples directory](示例/README.md) and the [Wiki examples page](https://github.com/open-guji/luatex-cn/wiki/EN:Examples).

## Quick start

1. Install a TeX distribution — **TeX Live 2024+** recommended (see the [Wiki installation guide](https://github.com/open-guji/luatex-cn/wiki/EN:Installation)).
2. Install luatex-cn: download `luatex-cn-v*.zip` from [GitHub Releases](https://github.com/open-guji/luatex-cn/releases), extract the contents of `luatex-cn/tex/` into `~/texmf/tex/latex/luatex-cn/` and run `texhash` — or install from CTAN (`tlmgr install luatex-cn`; the CTAN version may lag behind).
3. Compile with **`lualatex`** (not `pdflatex` or `xelatex`).

A first classical page:

```latex
\documentclass[四库全书]{ltc-guji}
\句读模式
%\setmainfont{TW-Kai}

\title{钦定四库全书}
\chapter{史记\\卷一}

\begin{document}
\begin{正文}
黄帝者，少典之子，姓公孫，名曰軒轅。\夹注{生而神靈，弱而能言，幼而徇齊，長而敦敏，成而聰明。}
\end{正文}
\end{document}
```

Horizontal text is one line away:

```latex
\documentclass{article}
\usepackage{fontspec}
\setmainfont{TW-Kai}
\usepackage[style=taiwan]{luatex-cn}
\begin{document}
子曰：「學而時習之，不亦說乎？」本文以 LuaTeX 引擎排版，版本 1.18。
\end{document}
```

Punctuation widths, line-breaking rules and Chinese-Western spacing take effect immediately; see the [Wiki horizontal page](https://github.com/open-guji/luatex-cn/wiki/EN:Horizontal).

## Features

| Feature | Description | Wiki |
|---------|-------------|------|
| **Vertical engine** | Grid-based vertical text flow with automatic column and page breaking | [Quick start](https://github.com/open-guji/luatex-cn/wiki/EN:Quick-Start) |
| **Banxin & fishtails** | Single/double fishtails, ruled borders, double frames | [Templates](https://github.com/open-guji/luatex-cn/wiki/EN:Templates) |
| **Interlinear notes** | Dual-column small notes with automatic balancing, across columns and pages | [Side notes](https://github.com/open-guji/luatex-cn/wiki/EN:Side-Note) |
| **Side / top annotations** | Annotations between columns and above the text frame | [Annotations](https://github.com/open-guji/luatex-cn/wiki/EN:Annotation) |
| **Judou** | Traditional judou, modern punctuation, or bare-text mode | [Judou](https://github.com/open-guji/luatex-cn/wiki/EN:Judou) |
| **Seals** | Seal images with absolute positioning and transparency | [Seals](https://github.com/open-guji/luatex-cn/wiki/EN:Seal) |
| **Corrections & marks** | Textual corrections, proper-name marks, book-title marks, emphasis dots | [Corrections](https://github.com/open-guji/luatex-cn/wiki/EN:Correction) |
| **Raised heads (抬头)** | Single/double/triple raising with automatic frame wrapping | [Taitou](https://github.com/open-guji/luatex-cn/wiki/EN:Taitou) |
| **Modern punctuation** | Punctuation compression, line-breaking rules, Mainland/Taiwan styles | [Punctuation](https://github.com/open-guji/luatex-cn/wiki/EN:Punctuation) |
| **Horizontal clreq mode** | Unified entry `\usepackage{luatex-cn}`: punctuation widths, line-breaking rules, Chinese-Western spacing, interlinear marks, pinyin ruby | [Horizontal](https://github.com/open-guji/luatex-cn/wiki/EN:Horizontal) |
| **Footnotes** | End-of-block or bottom-of-page notes with bracket or circled numbering | [Footnotes](https://github.com/open-guji/luatex-cn/wiki/EN:ltc-book) |
| **Templates** | Built-in presets: Siku Quanshu, Honglou Jiaxu manuscript, Zhonghua Book Company, … | [Templates](https://github.com/open-guji/luatex-cn/wiki/EN:Templates) |
| **Font management** | Cross-platform detection and font-family fallback | [Fonts](https://github.com/open-guji/luatex-cn/wiki/EN:Fonts) |
| **Debug tools** | Grid visualisation, coordinate rulers, per-module logging | [Debug](https://github.com/open-guji/luatex-cn/wiki/EN:Debug) |

## One package, four document classes

| Entry point | Purpose |
|-------------|---------|
| **`\usepackage{luatex-cn}`** | Modern horizontal text — use with any standard class such as article |
| **`\documentclass{ltc-guji}`** | Classical books (banxin, fishtails, ruled borders): write semantic commands, the engine does the layout |
| **`\documentclass{ltc-guji-digital}`** | Digitisation of classical books: one source line per column, replicating the original page exactly |
| **`\documentclass{ltc-cn-vbook}`** | Modern vertical books, Mainland China punctuation |
| **`\documentclass{ltc-tw-vbook}`** | Modern vertical books, Taiwan punctuation |

> Every command has both simplified- and traditional-Chinese names, e.g. `\夹注{...}`, `\侧批{...}`, `\begin{正文}`.

## Requirements

- LuaTeX (TeX Live 2024+ recommended)
- `luaotfload` and `fontspec` (bundled with TeX Live)
- Chinese fonts — Source Han Serif or a Kai typeface works well; `scripts/download_fonts.py` can fetch openly licensed fonts without installing them system-wide

## Documentation & community

- **[Wiki user manual](https://github.com/open-guji/luatex-cn/wiki/EN:Home)** — full usage guide
- **[Examples](示例/README.md)** — complete typeset sources
- **[Issues](https://github.com/open-guji/luatex-cn/issues)** — bug reports and suggestions

Maintainer: Sheldon Li | Email: sheldonli.dev@gmail.com  
Maintainer: Frank Lin | Email: ctan@linshuang.info

## Development

To work on the source or run the test suite locally, see the [developer guide](文档/developer_guide.md) or the [Wiki development page](https://github.com/open-guji/luatex-cn/wiki/EN:Development).

## License

Apache License 2.0
