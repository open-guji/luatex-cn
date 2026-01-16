# LuaTeX-CN

**Version: 1.0.0** | [CTAN](https://ctan.org/pkg/luatex-cn) | [GitHub](https://github.com/open-guji/luatex-cn)

LuaTeX package for sophisticated traditional Chinese vertical typesetting and ancient book layout.

> **Note**: The package version is maintained in the [`VERSION`](VERSION) file.

致力于基于 LuaTeX 引擎实现最纯粹、最高质量的中文古籍排版支持，完整覆盖竖排核心逻辑、版心装饰及夹注处理。

## Features

- **Vertical Typesetting (竖排)**: Robust core engine for classical vertical layouts.
- **Ancient Book Layout (古籍版式)**: Integrated support for "Banxin" (版心), "Yuwei" (鱼尾), and borders.
- **Interlinear Notes (夹注)**: Automatic balancing and breaking for dual-column small notes.
- **Grid-based Positioning**: Precise control over character placements via Lua-calculated layout.
- **Modern Architecture**: Built on `expl3` and Lua code separation for maximum maintainability.

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

Quick install:
```bash
make install
```

## Usage

The recommended way to use the package is through the `guji` document class:

```latex
\documentclass{guji}

% Configure layout and fonts
\gujiSetup{
  font-size = 12pt,
  line-limit = 20,
  page-columns = 10,
  banxin = true,
  book-name = {史記}
}

\begin{document}
\chapter{五帝本紀第一}
這是竖排的中文文本示例，包含夹注\jiazhu{双行小注}的功能演示。
\end{document}
```

## Requirements

- LuaTeX (TeX Live 2024+ recommended)
- `luaotfload` and `fontspec`
- Quality Chinese fonts (e.g., Noto Serif CJK, Source Han Serif, or specialized Kaiti fonts)

## Documentation

See `example.tex` for usage examples.

## License

Apache License 2.0
