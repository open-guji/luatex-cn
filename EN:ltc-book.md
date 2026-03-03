English | [中文版](ltc-book)

# Modern Vertical Book Classes (v0.2.7+)

luatex-cn provides two document classes for modern vertical Chinese book typesetting. Unlike `ltc-guji` (ancient book typesetting), they use a clean, modern design: no banxin, no fishtail, no silk frames — suitable for contemporary publications that need vertical layout.

| Class | Punct Style | Description |
|-------|-------------|-------------|
| **`ltc-cn-vbook`** (v0.2.8+) | Mainland | Simplified Chinese vertical books |
| **`ltc-tw-vbook`** (v0.2.8+) | Taiwan | Traditional Chinese vertical books |
| `ltc-book` | Taiwan | Legacy name, still works |

## Basic Usage

```latex
\documentclass{ltc-cn-vbook}
\setmainfont{Noto Serif SC}

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。
\end{正文}
\end{document}
```

## Template System

| Option | Description | Punct Style |
|--------|-------------|-------------|
| (none) | Default, 16-kai (170x240mm), 12pt font | Taiwan |
| `中华书局` | Zhonghua Shuju style, 15pt font, footnotes enabled | Mainland |

```latex
\documentclass{ltc-cn-vbook}           % Default
\documentclass[中华书局]{ltc-cn-vbook}  % Zhonghua Shuju
```

## Differences from guji

| Feature | cn-vbook / tw-vbook | guji |
|---------|---------|---------|
| Design | Modern, clean | Traditional ancient |
| Banxin/Yuwei | No | Yes |
| Borders/Silk frames | No | Yes |
| Layout mode | Free column width (`n-column=0`) | Fixed grid (`n-column=8`) |
| Default punct | Modern (normal) | Configurable judou/normal |
| Footnotes | Built-in | Manual loading |
| Page numbers | Auto vertical | In banxin center |

## Punctuation Style

`ltc-cn-vbook` / `ltc-tw-vbook` enable the modern punctuation system by default. See [[Punctuation System | EN:Punctuation]].

```latex
\documentclass{ltc-cn-vbook}
\punctSetup{punct-style=mainland}  % Override to mainland style
```

Or use `\documentclass[中华书局]{ltc-cn-vbook}` which automatically sets mainland style.

You can also switch to judou mode: `\开启句读模式`

## Two-side Mirror Margins (v0.3.2+)

vbook enables twoside mode (`twoside=true`) by default, automatically mirroring inner/outer margins on odd/even pages:

- **Inner margin** (`margin-inner`): Binding side (odd pages = right, even pages = left)
- **Outer margin** (`margin-outer`): Reading side

```latex
\pageSetup{
    twoside = true,
    margin-inner = 16mm,   % binding side
    margin-outer = 24mm,   % outer side
}
```

## Running Headers (v0.3.2+)

vbook supports running headers that alternate between chapter name and book title.

```latex
\pageSetup{
    header-enabled = true,
    header-font-size = 9pt,
    header-y = 52mm,
}
```

| Page | Header Content | Position |
|------|---------------|----------|
| Odd (right) | Chapter name (`\chapter{...}`) | Left (binding side) |
| Even (left) | Book title (`\title{...}`) | Right (binding side) |

Use `\skipHeader` to suppress headers on specific pages (e.g., title pages).

## Paragraph Indentation (v0.3.2+)

vbook supports first-line paragraph indentation:

```latex
\contentSetup{
    first-indent = 2,   % indent first line by 2 characters
}
```

The layout engine automatically detects paragraph boundaries and applies indentation.

## Volume & Chapter Title Commands (v0.3.2+)

| Command | Description | Example |
|---------|-------------|---------|
| `\卷名{...}` | Volume title (24pt, 48pt top spacing) | `\卷名{史記卷六}` |
| `\章节名{...}` | Chapter title (20pt, 2-char indent) | `\章节名{秦始皇本紀}` |

`\章节名` automatically calls `\chapter` to update running headers.

## Footnote System

Built-in footnote support with endnote and page-bottom modes.

```latex
\脚注设置{number-style=lujiao, indent=1em}
天地玄黄\脚注{This is a footnote}。
\输出脚注  % Output at paragraph end
```

### Configuration (`\footnoteSetup` / `\脚注设置`)

| Parameter | Description | Default | Values |
|-----------|-------------|---------|--------|
| `mode` | Mode | `endnote` | `endnote`, `page` |
| `number-style` | Style | `lujiao` | `lujiao` (【一】), `circled` (①) |
| `separator` | Separator | `blank` | `blank`, `none` |
| `font-size` | Size | `0.8em` | Any dimension |
| `indent` | Indent | `1em` | Any dimension |

### Commands

| Command | Chinese | Description |
|---------|---------|-------------|
| `\Footnote{...}` | `\脚注{...}` | Add footnote |
| `\FlushFootnote` | `\输出脚注` | Output endnotes |
| `\FootnoteParagraph{...}` | `\脚注段落{...}` | Unnumbered footnote block |
| `\footnoteSetup{...}` | `\脚注设置{...}` | Configure |
| `\ResetFootnoteCounter` | `\重置脚注计数` | Reset counter |

## Page Numbers

Auto vertical page numbers at lower-left. Configure via `\pageSetup`:

| Parameter | Default |
|-----------|---------|
| `page-number-style` | `digits` (also: `chinese`, `arabic`, `none`) |
| `page-number-font-size` | `9pt` |
| `page-number-x` | `3mm` |
| `page-number-y` | `8mm` |

## Custom Templates

Create `configs/luatex-cn-book-<name>.cfg` with `\pageSetup`, `\contentSetup`, `\punctSetup`, then use `\documentclass[name]{ltc-cn-vbook}`.

---

Next: [[Punctuation | EN:Punctuation]] | [[Features | EN:Features]] | [[Templates | EN:Templates]]
