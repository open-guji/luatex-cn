# LuaTeX-CN

[中文版](README.md)

LuaTeX package for Chinese charactor typesetting, covering horizontal/vertical, tranditional/mordern layout. Currently focus on Ancient Book replication. Implemented core logic of vertical typesetting, decorative elements of traditional Chinese books, and interlinear notes.

CTAN: [v0.1.1](https://ctan.org/pkg/luatex-cn) | GitHub Release: [v0.1.3](https://github.com/open-guji/luatex-cn/releases)

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
1. Published to CTAN/TeXLive, you can install it directly via your TeX distribution's package manager.
2. Download the latest `luatex-cn-tex-v*.zip` from [GitHub Releases](https://github.com/open-guji/luatex-cn/releases). Extract it to `texmf/tex/latex/luatex-cn/` and run `texhash`.
3. Download the latest version, extract it into your current project folder, and compile directly.

## Usage

The recommended way to use the package is through the `ltc-guji` document class:

```latex
\documentclass[红楼梦甲戌本]{ltc-guji}

% Set book title (appears in the right-side banxin)
\title{脂硯齋重評石頭記}

\begin{document}
\begin{正文}
    % Set chapter (updates banxin and resets page number)
    \chapter{Chapter 1}
    
    % SideNote: Annotations between grid columns
    \侧批{Side annotation example}
    甄士隱夢幻識通靈\夹注{Interlinear notes}\空格[1]賈雨村風塵懷閨秀。
    
    % Paragraph control: Precise grid-based indentation
    \begin{Paragraph}[indent=2]
        This is a paragraph with grid indentation.
    \end{Paragraph}
    
    % Floating Annotation: Absolute positioning on the page
    \批注[x=2cm, y=4cm, height=6, color={1 0 0}]{Floating annotation\\supports multiple lines}

    % Seal/Stamp: Background image with absolute positioning
    % \印章[page=1, xshift=-2cm, yshift=-5cm]{seal.png}
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
