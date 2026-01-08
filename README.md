# luatex-cn

LuaTeX package for Chinese character and vertical typesetting support.

支持中文古籍竖排，长期愿景希望基于LuaTeX完整支持中文排版。

## Features

- Chinese character typesetting support
- Vertical typesetting (竖排) for classical Chinese texts
- Lua-based advanced typesetting features
- Support for both simplified and traditional Chinese
- Built on expl3 (LaTeX3 programming layer) for modern, robust code

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

Quick install:
```bash
make install
```

## Usage

```latex
\documentclass{ctexart}
\usepackage[vertical,simplified]{luatex-cn}

\begin{document}
\begin{tate}
这是竖排的中文文本示例。
\end{tate}
\end{document}
```

## Requirements

- LuaTeX
- expl3 (LaTeX3 programming layer) - included in modern LaTeX distributions
- luatexja package
- Chinese fonts (e.g., Noto Serif CJK SC/TC)

## Documentation

See `example.tex` for usage examples.

## License

LPPL 1.3
