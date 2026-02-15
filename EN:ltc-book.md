English | [中文版](ltc-book)

# Modern Vertical Book Classes (v0.2.7+)

luatex-cn provides two document classes for modern vertical Chinese book typesetting. Unlike `guji` (ancient book typesetting), they use a clean, modern design: no banxin, no fishtail, no silk frames — suitable for contemporary publications that need vertical layout.

| Class | Punct Style | Description |
|-------|-------------|-------------|
| **`cn-vbook`** (v0.2.8+) | Mainland | Simplified Chinese vertical books |
| **`tw-vbook`** (v0.2.8+) | Taiwan | Traditional Chinese vertical books |
| `ltc-book` | Taiwan | Legacy name, still works |

## Basic Usage

```latex
\documentclass{cn-vbook}
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
\documentclass{cn-vbook}           % Default
\documentclass[中华书局]{cn-vbook}  % Zhonghua Shuju
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

`cn-vbook` / `tw-vbook` enable the modern punctuation system by default. See [[Punctuation System | EN:Punctuation]].

```latex
\documentclass{cn-vbook}
\punctSetup{punct-style=mainland}  % Override to mainland style
```

Or use `\documentclass[中华书局]{cn-vbook}` which automatically sets mainland style.

You can also switch to judou mode: `\开启句读模式`

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

Create `configs/luatex-cn-book-<name>.cfg` with `\pageSetup`, `\contentSetup`, `\punctSetup`, then use `\documentclass[name]{cn-vbook}`.

---

Next: [[Punctuation | EN:Punctuation]] | [[Features | EN:Features]] | [[Templates | EN:Templates]]
