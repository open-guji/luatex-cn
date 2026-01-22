# LuaTeX-CN

[中文版](README.md)

CTAN: [v0.1.1](https://ctan.org/pkg/luatex-cn)

GitHub Release: [v0.1.2](https://github.com/open-guji/luatex-cn/releases)
LuaTeX package for Chinese charactor typesetting, covering horizontal/vertical, tranditional/mordern layout. Currently focus on Ancient Book replication. Implemented core logic of vertical typesetting, decorative elements of traditional Chinese books, and interlinear notes.

## Features

- **Vertical Typesetting (竖排)**: Robust core engine for classical vertical layouts
- **Ancient Book Layout (古籍版式)**: Integrated support for "Banxin" (版心), "Yuwei" (鱼尾), and borders
- **Interlinear Notes (夹注)**: Automatic balancing and breaking for dual-column small notes
- **Floating Annotations (批注/PiZhu)**: Supports floating annotation boxes with absolute positioning anywhere on the page
- **Grid-based Positioning**: Precise control over character placements via Lua-calculated layout
- **Modern Architecture**: Built on `expl3` and Lua code separation for maximum maintainability

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

Quick install:
1. **Coming soon to CTAN**, you can install it directly via your TeX distribution's package manager.
2. Download the latest `luatex-cn-src-v*.zip` from [GitHub Releases](https://github.com/open-guji/luatex-cn/releases). Extract it to `texmf/tex/latex/luatex-cn/` and run `texhash`.
3. Download the latest version, extract it into your current project folder, and compile directly.

## Usage

The recommended way to use the package is through the `ltc-guji` document class:

```latex
\documentclass[四库全书]{ltc-guji}

\begin{document}
\begin{正文}
\chapter{五帝本紀第一}
這是竖排的中文文本示例，包含夹注\夹注{双行小注}的功能演示。

\begin{列表}
    \item Part 1
    \item Volume 1
\end{列表}

\印章[page=1]{seal.png}
\end{正文}
\end{document}
```

## Requirements

- LuaTeX (TeX Live 2024+ recommended)
- `luaotfload` and `fontspec`
- Quality Chinese fonts (e.g., Noto Serif CJK, Source Han Serif, or specialized Kaiti fonts)

## Documentation

[documentation](文档/README.md) | [example](示例/README.md)

Maintainer: Sheldon Li

Email: sheldonli.dev@gmail.com

## License

Apache License 2.0
