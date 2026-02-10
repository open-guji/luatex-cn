[中文版](Templates) | English Version

# Templates and Customization

`luatex-cn` provides a flexible template system with built-in and custom templates.

## Built-in Templates

| Template Name | Document Class | Description |
|--------------|----------------|-------------|
| `四库全书` | `ltc-guji` | Classic official book style (B&W) |
| `四库全书彩色` | `ltc-guji` | Classic official book style (Color) |
| `红楼梦甲戌本` | `ltc-guji` | Manuscript style with side/top notes |
| `default` | `ltc-book` | Default modern vertical style (Taiwan punct) |
| `中华书局` | `ltc-book` | Zhonghua Shuju modern style (Mainland punct) |

## Using Templates

Specify the template name in document class options:

```latex
% ltc-guji templates
\documentclass[四库全书彩色]{ltc-guji}
\documentclass[红楼梦甲戌本]{ltc-guji}

% ltc-book templates (v0.2.7+)
\documentclass{ltc-book}              % Default template
\documentclass[中华书局]{ltc-book}     % Zhonghua Shuju template
```

## Custom Templates

### Method 1: Create Configuration File

#### ltc-guji Template

Create a `luatex-cn-guji-<template-name>.cfg` file in the `configs/` directory:

```latex
\gujiSetup{ template = default }

\pageSetup{
    paper-width = 1077.2pt,
    paper-height = 1077.2pt,
}

\contentSetup{
    n-column = 12,
    font-size = 30pt,
    border = true,
}

\banxinSetup{
    upper-yuwei = true,
    lower-yuwei = true,
}

\endinput
```

#### ltc-book Template (v0.2.7+)

Create a `luatex-cn-book-<template-name>.cfg` file in the `configs/` directory:

```latex
\pageSetup{
    paper-width = 148mm,
    paper-height = 210mm,
    page-number-style = digits,
}

\contentSetup{
    font-size = 11pt,
    line-spacing = 13pt,
    n-column = 0,
    border = false,
}

\punctSetup{punct-style=taiwan}

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
| | `layout-mode` | Layout mode (v0.2.7+) | `grid` |
| `\pageSetup` | `paper-width` | Paper width | - |
| | `paper-height` | Paper height | - |
| | `margin-*` | Margins | - |
| | `page-number-style` | Number style (v0.2.7+) | `none` |
| `\banxinSetup` | `banxin-upper-ratio` | Upper section ratio | 0.18 |
| | `upper-yuwei` | Upper fish tail | true |
| `\punctSetup` | `punct-style` | Punct style (v0.2.7+) | `taiwan` |
| | `punct-squeeze` | Squeeze (v0.2.7+) | `true` |
| | `kinsoku` | Line-breaking rules (v0.2.7+) | `true` |

---

👉 Next: See [[Debug Mode | EN:Debug]] or [[Features | EN:Features]]
