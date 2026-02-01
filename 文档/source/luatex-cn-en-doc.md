# LuaTeX-cn User Manual

[中文版](luatex-cn-zh-doc.md)

`luatex-cn` is a macro package specifically designed for LuaTeX, with enhanced support for traditional Chinese vertical layout (Guji) and modern vertical typesetting.

---

## 1. Home

### Project Overview

The `luatex-cn` package aims to provide professional solutions for Chinese vertical typesetting. Key features include:

- **Ancient Book Layout**: Full support for traditional Guji format, including black vertical lines (Wusilan), Banxin (center fold), and fish tail decorations
- **Modern Vertical**: Support for clean modern vertical style, suitable for novels and reports
- **Annotation System**: Multiple annotation methods including interlinear notes (Jiazhu), side notes, and top annotations
- **Template System**: Built-in preset templates with support for custom extensions

### System Requirements

- **Compiler**: Must use `LuaLaTeX` (version 1.10+). pdfLaTeX or XeLaTeX are not supported.
- **Distribution**: TeX Live 2024 or higher is recommended.

---

## 2. Quick Start

### 2.1 Installation Guide

#### Method 1: Install via CTAN/Package Manager (Recommended)

- **TeX Live (Windows/Linux)**: Open terminal and run `tlmgr install luatex-cn`
- **MacTeX (macOS)**: Use **TeX Live Utility** to search and install `luatex-cn`
- **MiKTeX**: Open **MiKTeX Console**, go to "Packages", search and install `luatex-cn`

#### Method 2: Manual Installation from GitHub Release

1. **Download**: Go to [GitHub Releases](https://github.com/open-guji/luatex-cn/releases) and download the latest `luatex-cn-src-v*.zip`
2. **Locate texmf directory**:
   - **Windows**: Usually at `C:\Users\<username>\texmf`
   - **macOS/Linux**: Usually at `~/texmf`
3. **Place files**: Extract the archive and place all files into `texmf/tex/latex/luatex-cn/`
4. **Refresh database**: Run `texhash`

#### Method 3: Install with l3build

If you have cloned the project source code, you can use `l3build` to install:

```bash
l3build install
```

#### Verify Installation

Create a simple `.tex` file and run `lualatex test.tex`. If compilation succeeds, the installation is complete.

### 2.2 Quick Start Guide

#### Basic Ancient Book (Guji) Template

Create a `.tex` file:

```latex
\documentclass[四库全书彩色]{ltc-guji}

\usepackage{enumitem}
\usepackage{tikz}

% Strongly recommended to set a specific font
\setmainfont{TW-Kai}

\title{欽定四庫全書}
\chapter{史記\\卷一}

\begin{document}
\begin{正文}
欽定四庫全書

\begin{列表}
    \item 史記卷一
    \item \填充文本框[12]{漢太史令}司馬遷\空格 撰
    \item 五帝本紀第一
\end{列表}

\begin{段落}[indent=3]
Main text content goes here...
\夹注{This is interlinear small text. The package handles alignment automatically.}
\end{段落}

\end{正文}
\end{document}
```

Compile with `lualatex` to obtain a colorful Guji page with automatic Banxin.

#### Modern Vertical Template

```latex
\documentclass{ltc-book}

\setmainfont{Source Han Serif SC}

\begin{document}
\begin{正文}
This is modern vertical text.
\end{正文}
\end{document}
```

### 2.3 Templates and Customization

#### Built-in Templates

The project provides the following built-in templates:

| Template Name | Document Class | Description |
|--------------|----------------|-------------|
| `四库全书` | `ltc-guji` | Classic official book style (B&W) |
| `四库全书彩色` | `ltc-guji` | Classic official book style (Color) |
| `红楼梦甲戌本` | `ltc-guji` | Manuscript style with side/top notes |
| `default` | `ltc-book` | Default modern vertical style |

#### Using Templates

Specify the template name in document class options:

```latex
% Use colored Siku Quanshu template
\documentclass[四库全书彩色]{ltc-guji}

% Use Hong Lou Meng Jiaxu edition template
\documentclass[红楼梦甲戌本]{ltc-guji}
```

#### Custom Templates

##### Method 1: Create Configuration File

Create a `luatex-cn-guji-<template-name>.cfg` file in the `configs/` directory:

```latex
% luatex-cn-guji-MyTemplate.cfg

% Can inherit from existing template
\gujiSetup{ template = default }

% Page setup
\pageSetup{
    paper-width = 1077.2pt,
    paper-height = 1077.2pt,
    margin-top = 226.8pt,
    margin-bottom = 113.4pt,
    margin-left = 25.5pt,
    margin-right = 25.5pt,
}

% Content setup
\contentSetup{
    n-column = 12,
    font-size = 30pt,
    line-spacing = 45pt,
    n-char-per-col = 18,
    border = true,
}

% Banxin setup
\banxinSetup{
    banxin-upper-ratio = 0.18,
    banxin-middle-ratio = 0.38,
    upper-yuwei = true,
    lower-yuwei = true,
}

\endinput
```

##### Method 2: Direct Configuration in Document

```latex
\documentclass{ltc-guji}

\gujiSetup{
    book-name = My Book Title,
    chapter-title = Chapter One,
}

\contentSetup{
    n-column = 10,
    font-size = 24pt,
    border = true,
}

\begin{document}
% ...
\end{document}
```

##### Method 3: Define Template with defineGujiTemplate

```latex
\defineGujiTemplate{MyTemplate}{
    book-name = Default Title,
    n-column = 10,
    border = true,
}

% Use custom template
\gujiSetup{ template = MyTemplate }
```

#### Font Configuration

The package supports flexible font configuration:

```latex
\usepackage{fontspec}

% Set main text font
\setmainfont{JiGu}[
    RawFeature={+vert,+vrt2},  % Enable vertical typesetting
    CharacterWidth=Full         % Full-width characters
]
```

Recommended fonts:
- **TW-Kai** (TW-Kai font): First choice for Guji layout
- **JiGu** (JiGu font): Simulates woodblock print effect
- **STKaiti** (STKaiti): System Kai font

For detailed font configuration, see: [luatex-cn-font-setup.md](./luatex-cn-font-setup.md)

---

## 3. Feature Reference

### 3.1 Document Classes

#### `ltc-guji.cls` (Specialized for Guji)

Includes complex grids, fish-tails, and Banxin control, suitable for reproducing historical documents.

#### `ltc-book.cls` (Modern Vertical Layout)

Suitable for modern novels or reports, no grid, flexible layout.

### 3.2 Core Typesetting Commands

#### Vertical Typesetting

- **`\竖排[params]{content}`** / **`\VerticalRTT`**: Arranges content according to vertical grid

#### Text Box Commands

- **`\TextBox[params]{content}`** / **`\文本框`**: Creates a gridded text box
  - `height`: Number of lines occupied (grid height)
  - `n-cols`: Number of internal columns
  - `box-align`: Content alignment (`top`, `center`, `bottom`, `fill`)

- **`\填充文本框[height]{content}`**: Creates an auto-filling text box

#### Spacing

- **`\Space[length]`** / **`\空格`**: Inserts a grid placeholder

### 3.3 Annotation System

#### Jiazhu (Interlinear Double-column Notes)

- **`\TextFlow{content}`** / **`\文本流`** / **`\夹注`**: Generates traditional "Jiazhu"

```latex
Main text\夹注{This is interlinear annotation}continues here
```

#### Side Notes

- **`\SideNode[params]{content}`** / **`\侧批`** / **`\CePi`**: Adds annotations to margins
  - `yoffset`: Vertical offset
  - `color`: Annotation color (often red in Guji)

```latex
\侧批[yoffset=1em, color=red]{Side note content}
```

#### Floating Annotation Box

- **`\PiZhu[params]{content}`** / **`\批注`**: Creates floating annotation box with absolute positioning
  - `x`, `y`: Absolute coordinates
  - `height`: Box height (in grid lines)
  - `font-size`: Annotation font size
  - `color`: Color (supports RGB format, e.g., `1 0 0` for red)
  - `grid-width`, `grid-height`: Internal grid dimensions

### 3.4 Decoration and Positioning

#### Seal/Stamp

- **`\YinZhang[params]{image_path}`** / **`\印章`**: Inserts an absolutely positioned seal
  - `page`: Target page number
  - `x`, `y`: Coordinate position (relative to page top-left)
  - `width`: Seal width

```latex
\印章[page=1, x=5cm, y=10cm, width=3cm]{seal.png}
```

### 3.5 Paragraph Control

- **`\begin{Paragraph}[params]`** / **`\begin{段落}`**:
  - `indent`: Global indentation
  - `first-indent`: First-line indentation (default 1-2 characters)
  - `bottom-indent`: Bottom (right-side) padding

### 3.6 List Environment

- **`\begin{列表}`**: Creates a vertical list environment

```latex
\begin{列表}
    \item First item
    \item Second item
\end{列表}
```

### 3.7 Global Configuration

#### gujiSetup (Guji Configuration)

```latex
\gujiSetup{
    book-name = Book Title,        % Book name in Banxin
    chapter-title = Chapter Name,  % Chapter title in Banxin
    template = 四库全书彩色,       % Template to use
}
```

#### contentSetup (Content Configuration)

```latex
\contentSetup{
    n-column = 12,              % Columns per half page
    font-size = 30pt,           % Font size
    line-spacing = 45pt,        % Line spacing
    n-char-per-col = 18,        % Characters per column
    border = true,              % Show border
    outer-border = false,       % Show outer border
    font-color = {35, 25, 20},  % Font color (RGB)
    border-color = {180, 95, 75}, % Border color (RGB)
}
```

#### pageSetup (Page Configuration)

```latex
\pageSetup{
    paper-width = 1077.2pt,
    paper-height = 1077.2pt,
    margin-top = 226.8pt,
    margin-bottom = 113.4pt,
    margin-left = 25.5pt,
    margin-right = 25.5pt,
}
```

#### banxinSetup (Banxin Configuration)

```latex
\banxinSetup{
    banxin-upper-ratio = 0.18,  % Upper section ratio
    banxin-middle-ratio = 0.38, % Middle section ratio
    upper-yuwei = true,         % Upper fish tail
    lower-yuwei = true,         % Lower fish tail
    banxin-divider = true,      % Banxin divider line
}
```

### 3.8 Configuration Reference Table

The following table lists main configuration commands and their parameters:

| Command | Parameter | Description | Default |
|---------|-----------|-------------|---------|
| `\gujiSetup` | `book-name` | Book name | - |
| | `chapter-title` | Chapter title | - |
| | `template` | Template name | `default` |
| `\contentSetup` | `n-column` | Columns per half page | 12 |
| | `font-size` | Font size | 30pt |
| | `line-spacing` | Line spacing | 45pt |
| | `n-char-per-col` | Characters per column | 18 |
| | `border` | Show border | true |
| | `font-color` | Font color (RGB) | {0,0,0} |
| | `border-color` | Border color (RGB) | {0,0,0} |
| `\pageSetup` | `paper-width` | Paper width | - |
| | `paper-height` | Paper height | - |
| | `margin-*` | Margins | - |
| `\banxinSetup` | `banxin-upper-ratio` | Upper section ratio | 0.18 |
| | `upper-yuwei` | Upper fish tail | true |
| | `lower-yuwei` | Lower fish tail | true |

### 3.9 Debug Mode

The package provides comprehensive debugging features to help troubleshoot layout issues.

#### Enable/Disable Debug

```latex
\LtcDebugOn    % or \开启调试
\LtcDebugOff   % or \关闭调试
```

#### Module-level Debug

```latex
\LtcDebugModuleOn{vertical}   % or \开启调试模块{vertical}
\LtcDebugModuleOff{vertical}  % or \关闭调试模块{vertical}
```

#### Display Helper Tools

```latex
% Show page frame
\LtcShowFrame   % or \显示边框

% Show grid coordinates
\LtcShowGrid[measure=cm]  % or \显示网格[measure=cm]
\LtcHideGrid              % or \隐藏网格

% Show coordinates (same as show grid)
\显示坐标[measure=pt]
\隐藏坐标
```

Supported units: `cm` (default), `pt`, `mm`

#### Debug Color Settings

```latex
\LtcDebugColor{vertical}{blue}
```

---

## 4. Examples

### 4.1 Shiji Wudi Benji (Records of the Grand Historian)

- **Features**: Demonstrates highly complex Guji layout
- **Functions**:
  - Absolutely positioned red seals (overlaying text)
  - Custom Banxin text with single fish tail
  - Complex Jiazhu typesetting
  - Traditional Wusilan and indentation

See: [示例/史记五帝本纪/](../../示例/史记五帝本纪/)

### 4.2 Shiji Table of Contents

- **Features**: Mimics Qing Dynasty Siku Quanshu Beisige style
- **Functions**:
  - Standard ancient book table of contents layout
  - "Eight lines, twenty-one characters" format constraint
  - Typical white mouth, double border on all sides, single fish tail

See: [示例/史记目录/](../../示例/史记目录/)

### 4.3 Hong Lou Meng Jiaxu Edition

- **Features**: Simulates manuscript/annotated edition style
- **Functions**:
  - Side notes and top annotations
  - Double-column small text
  - No fish tail in Banxin, bottom page numbers

See: [示例/红楼梦甲戌本/](../../示例/红楼梦甲戌本/)

### 4.4 Modern Vertical Book

- **Features**: Clean modern vertical style
- **Functions**:
  - Pure vertical text support without Guji elements
  - Suitable for modern literature or report vertical typesetting

See: [示例/现代竖排书/](../../示例/现代竖排书/)

---

## 5. More Resources

- **Project Homepage**: [GitHub - open-guji/luatex-cn](https://github.com/open-guji/luatex-cn)
- **Issue Reports**: [GitHub Issues](https://github.com/open-guji/luatex-cn/issues)
- **Developer Guide**: [developer_guide.md](./developer_guide.md)
