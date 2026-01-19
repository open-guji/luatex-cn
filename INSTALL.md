# Installation Guide

## Requirements

- LuaTeX (part of TeX Live or MiKTeX)
- Required packages:
  - `luatexja`
  - `luatexja-fontspec`
  - `luatexja-otf`

## Installation Methods

### Method 1: Manual Installation

1. Copy the package files to your local texmf tree:
   ```bash
   # Create directory
   mkdir -p ~/texmf/tex/latex/luatex-cn
   
   # Copy source files (recursive)
   cp -r src/* ~/texmf/tex/latex/luatex-cn/
   ```

2. Update the TeX database:
   ```bash
   texhash
   ```

### Method 2: Using l3build (Recommended)

```bash
l3build install
```

This will automatically place all files into your local `TEXMFHOME` directory.

### Method 3: Development Mode

For development, you can place the package files in the same directory as your `.tex` files.

## Verification

Test the installation by compiling the example:

```bash
lualatex example.tex
```

## Font Setup

Make sure you have Chinese fonts installed. Recommended fonts:
- Noto Serif CJK SC/TC
- Source Han Serif SC/TC
- FandolSong

Set fonts in your document:
```latex
\setCJKmainfont{Noto Serif CJK SC}
```
