English | [中文版](Installation)

# Installation Guide

This page describes how to install the `luatex-cn` package.

## Method 1: Via CTAN/Package Manager (Recommended)

Install using your TeX distribution's package manager:

```bash
# TeX Live (Windows/Linux)
tlmgr install luatex-cn

# MiKTeX
# Open MiKTeX Console → Packages → Search for luatex-cn
```

> ⚠️ **Note**: The CTAN version may lag behind GitHub. We recommend using GitHub Release.

## Method 2: Manual Installation from GitHub Release

1. **Download**: Go to [GitHub Releases](https://github.com/open-guji/luatex-cn/releases) and download the latest `luatex-cn-tex-v*.zip`

2. **Locate texmf directory**:
   - **Windows**: `C:\Users\<username>\texmf`
   - **macOS/Linux**: `~/texmf`

3. **Place files**: Put the contents of `tex/` into:
   ```
   texmf/tex/latex/luatex-cn/
   ```

4. **Refresh database**:
   ```bash
   texhash
   ```

## Method 3: Direct Usage

Place the contents of `tex/` in the same directory as your `.tex` file and compile directly.

## Verify Installation

Create a test file `test.tex`:

```latex
\documentclass[四库全书]{guji}
\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。
\end{正文}
\end{document}
```

Run:
```bash
lualatex test.tex
```

If compilation succeeds, installation is complete.

## System Requirements

- LuaTeX (TeX Live 2024+ recommended)
- `luaotfload` and `fontspec`

## Font Requirements

We recommend installing these fonts for best results:
- Noto Serif CJK SC (Source Han Serif)
- FangSong or KaiTi (for traditional book effects)
