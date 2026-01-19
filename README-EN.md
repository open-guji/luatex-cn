# LuaTeX-CN

[中文版](README.md)

**Version: 0.1.0** | [CTAN](https://ctan.org/pkg/luatex-cn) | [GitHub](https://github.com/open-guji/luatex-cn)

LuaTeX package for sophisticated traditional Chinese vertical typesetting and ancient book layout, with long-term vision to support full Chinese typography.

Dedicated to implementing the purest, highest quality Chinese ancient book typesetting support based on the LuaTeX engine, fully covering vertical typesetting core logic, banxin (版心) decoration, and interlinear notes (jiazhu/夹注) processing.

## Features

- **Vertical Typesetting (竖排)**: Robust core engine for classical vertical layouts
- **Ancient Book Layout (古籍版式)**: Integrated support for "Banxin" (版心), "Yuwei" (鱼尾), and borders
- **Interlinear Notes (夹注)**: Automatic balancing and breaking for dual-column small notes
- **Grid-based Positioning**: Precise control over character placements via Lua-calculated layout
- **Modern Architecture**: Built on `expl3` and Lua code separation for maximum maintainability

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

Quick install:
```bash
l3build install
```

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

See `example.tex` for usage examples.

Maintainer: Sheldon Li
Email: sheldonli.dev@gmail.com

## License

Apache License 2.0