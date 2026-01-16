# Quick Start Guide

## Prerequisites

1. Install LuaTeX (comes with TeX Live or MiKTeX)
2. Install required packages:
   ```bash
   tlmgr install luatexja luatexja-fontspec luatexja-otf
   ```
3. Install Chinese fonts (e.g., Noto Serif CJK SC)

## Development Setup

1. Clone or download this repository
2. For local development, place files in your project directory
3. For system-wide installation:
   ```bash
   make install
   ```

## Basic Usage

The `guji` class is the standard entry point for ancient book typesetting.

```latex
\documentclass{guji}

\gujiSetup{
  font-size = 12pt,
  line-limit = 20,
  page-columns = 10,
  banxin = true
}

\begin{document}
\chapter{正文标题}
这是竖排的中文文本。
古籍排版通常使用竖排格式。
\jiazhu{双行小注} 同样受到支持。
\end{document}
```

## Compile

```bash
lualatex your-document.tex
```

## Package Options

- `vertical` - Enable vertical typesetting support
- `traditional` - Use traditional Chinese characters
- `simplified` - Use simplified Chinese characters (default)

## Testing

Test the package with the included example:

```bash
lualatex example.tex
```
