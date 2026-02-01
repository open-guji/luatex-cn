[中文版](Templates) | English Version

# Templates and Customization

`luatex-cn` provides a flexible template system with built-in and custom templates.

## Built-in Templates

| Template Name | Document Class | Description |
|--------------|----------------|-------------|
| `四库全书` | `ltc-guji` | Classic official book style (B&W) |
| `四库全书彩色` | `ltc-guji` | Classic official book style (Color) |
| `红楼梦甲戌本` | `ltc-guji` | Manuscript style with side/top notes |
| `default` | `ltc-book` | Default modern vertical style |

## Using Templates

Specify the template name in document class options:

```latex
% Use colored Siku Quanshu template
\documentclass[四库全书彩色]{ltc-guji}

% Use Hong Lou Meng Jiaxu edition template
\documentclass[红楼梦甲戌本]{ltc-guji}
```

## Custom Templates

### Method 1: Create Configuration File

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

### Method 2: Direct Configuration in Document

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

### Method 3: Define Template with defineGujiTemplate

```latex
\defineGujiTemplate{MyTemplate}{
    book-name = Default Title,
    n-column = 10,
    border = true,
}

% Use custom template
\gujiSetup{ template = MyTemplate }
```

## Configuration Reference Table

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

---

👉 Next: See [[Debug Mode | EN:Debug]] or [[Features | EN:Features]]
