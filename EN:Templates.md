[中文版](Templates) | English Version

# Templates and Customization

In `luatex-cn` a "template" is a configuration file (`.cfg`) containing setup commands such as `\pageSetup`, `\contentSetup` and `\banxinSetup`. Give the template name as a document class option to load it.

## Built-in Templates

| Template Name | Document Class | Description |
|--------------|----------------|-------------|
| `四库全书` (`default`) | `ltc-guji` | Classic official book style (B&W); the `ltc-guji` default |
| `四库全书彩色` (`SiKuQuanShu-colored`) | `ltc-guji` | Classic official book style (color) |
| `红楼梦甲戌本` (`HongLouMengJiaXuBen`) | `ltc-guji` | Manuscript style with side/top notes |
| `欧式族谱` (`oushizupu`) | `ltc-guji` | Genealogy style |
| (default config) | `ltc-cn-vbook` | Modern vertical, mainland punctuation |
| (default config) | `ltc-tw-vbook` | Modern vertical, Taiwan punctuation |

The two modern vertical classes have no named templates; each loads its default configuration. See [[ltc-book | EN:ltc-book]].

## Using Templates

Specify the template name in the document class options:

```latex
\documentclass[四库全书彩色]{ltc-guji}
\documentclass[红楼梦甲戌本]{ltc-guji}

% Or switch in the preamble (use the English name here)
\gujiSetup{ template = HongLouMengJiaXuBen }
```

## Custom Templates

### Method 1: Create a Configuration File (recommended)

For a template named `<name>`, the class first looks for `<name>.cfg` in the document folder, then in `configs/` on the TeX path.

| Class | File name |
|-------|-----------|
| `ltc-guji` | `<name>.cfg` or `configs/luatex-cn-guji-<name>.cfg` |
| `ltc-cn-vbook` / `ltc-tw-vbook` | `<name>.cfg` or `configs/luatex-cn-vbook-<name>.cfg` |

Then load it with `\documentclass[<name>]{ltc-guji}`.

#### guji Template

```latex
% MyTemplate.cfg (in the document folder)

\gujiSetup{ template = default }   % start from Siku Quanshu, then change below

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

#### cn-vbook / tw-vbook Template

The template is loaded after the default configuration, so only list what you change:

```latex
% mytemplate.cfg

\pageSetup{
    paper-width = 148mm,
    paper-height = 210mm,
    margin-inner = 18mm,
    margin-outer = 15mm,
    page-number-style = digits,
}

\contentSetup{
    font-size = 11pt,
    line-spacing = 13pt,
}

\punctSetup{punct-style=taiwan}

\endinput
```

### Method 2: Direct Configuration in the Document

Write the setup commands in the preamble; set the book and chapter titles with `\title` and `\chapter`:

```latex
\documentclass{ltc-guji}

\contentSetup{
    n-column = 10,
    font-size = 24pt,
    border = true,
}

\title{My Book Title}

\begin{document}
\begin{正文}
\chapter{Chapter One}
% ...
\end{正文}
\end{document}
```

> `\gujiSetup` currently accepts only the `template` key. The `\gujiSetup{book-name=…}` form shown in older versions of this wiki, and packing layout keys into `\defineGujiTemplate`, both fail with an unknown-key error.

## Common Settings

Defaults below are the code defaults with no template loaded; templates override some of them. For every key see [[Command Reference | Command-Reference]].

| Command | Parameter | Description | Default |
|---------|-----------|-------------|---------|
| `\gujiSetup` | `template` | Template name (English) | — |
| `\contentSetup` | `n-column` | Columns per half page (0 = free width) | 8 |
| | `n-char-per-col` | Characters per column (0 = auto) | 0 |
| | `font-size` | Font size | 12pt |
| | `grid-width` / `grid-height` | Cell width / height | 1.5em / 1.2em |
| | `line-spacing` | Line spacing (natural mode) | `\baselineskip` |
| | `border` | Show column rules | false |
| | `border-color` | Rule color | black |
| | `font-color` | Text color | _(empty)_ |
| | `layout-mode` | `grid` / `natural` | `grid` |
| | `horizontal-align` | Horizontal position of the column block: `right` / `center` / `left` (v0.4.5+) | `right` |
| `\pageSetup` | `paper-width` / `paper-height` | Paper size | 210mm / 297mm |
| | `margin-*` | Margins | 0pt |
| | `twoside` | Facing pages (mirrored margins) | false |
| | `page-number-style` | Page number style | _(empty)_ |
| `\banxinSetup` | `banxin-upper-ratio` | Upper section ratio | 0.28 |
| | `upper-yuwei` / `lower-yuwei` | Upper / lower fishtail | true |
| | `book-ear` | Book ear (v0.4.5+) | false |
| `\punctSetup` | `punct-style` | Punctuation style | `taiwan` |
| | `punct-squeeze` | Squeeze | `true` |
| | `kinsoku` | Line-breaking rules | `true` |

---

👉 Next: See [[Debug Mode | EN:Debug]] or [[Features | EN:Features]]
