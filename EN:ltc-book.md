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

Vertical books bind on the right: **an odd page is the left page of a spread**, with the spine on its right; an even page is the right page, spine on its left. vbook enables twoside mode (`twoside=true`) by default, mirroring inner/outer margins on odd/even pages:

- **Inner margin** (`margin-inner`): spine side (odd pages = right, even pages = left), default `24mm`
- **Outer margin** (`margin-outer`): fore-edge side (odd pages = left, even pages = right), default `16mm`

```latex
\pageSetup{
    twoside = true,
    margin-inner = 24mm,   % spine side
    margin-outer = 16mm,   % fore-edge side
}
```

> Which pair is read is decided by `twoside` (v0.4.3+): `twoside=true` reads only `margin-inner` / `margin-outer`, `twoside=false` reads only `margin-left` / `margin-right`; setting the ignored pair emits a warning. With `twoside=false` the running-header page number is fixed on the left instead of alternating.

> **v0.4.4 direction fix**: `margin-inner` used to be placed on the left of odd pages (the horizontal-book convention), which is actually the fore-edge of a vertical book. It now follows the spine, and the vbook defaults were swapped to inner 24mm / outer 16mm, so the default layout is unchanged. Documents that set `margin-inner ≠ margin-outer` will flip left/right: swap the two values. guji templates use equal inner/outer and are unaffected.

### Fixed content area on facing pages (v0.4.4+)

To keep the text block in the same place on odd and even pages (like fixed margins in InDesign / Word), set `mirror-margins = false`:

```latex
\pageSetup{
    twoside = true,
    mirror-margins = false,
    margin-left = 22mm, margin-right = 22mm,
    binding-offset = 8mm,       % gutter, when the copy will be bound
    header-anchor = content,
}
```

| Parameter | Chinese key | Default | Description |
|-----------|-------------|---------|-------------|
| `mirror-margins` | `镜像边距` / `鏡像邊距` | `true` | `false`: with `twoside = true`, read `margin-left` / `margin-right` on every page so the content area does not move; running header and page number still alternate |
| `binding-offset` | `装订边距` / `裝訂邊距` | `0pt` | Added on the spine side: right of odd pages, left of even pages; right of every page when `twoside = false`. Works in all three margin modes |

| `twoside` | `mirror-margins` | Margins read | Use |
|-----------|------------------|--------------|-----|
| `true` | `true` (default) | `margin-inner` / `margin-outer`, mirrored | Bound facing-page books |
| `true` | `false` | `margin-left` / `margin-right`, same on every page | Fixed content area, alternating header |
| `false` | — | `margin-left` / `margin-right`, same on every page | Unbound print, screen reading |

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
| Odd (left page) | Chapter name (`\chapter{...}`) | Left (fore-edge) |
| Even (right page) | Book title (`\title{...}`) | Right (fore-edge) |

The running header sits at the outer (fore-edge) top corner and the page number at the outer bottom corner. `header-position = inner` moves the header to the spine side (v0.4.4+).

`header-anchor = paper` (default) measures the header and page number from the paper edge with `header-y` / `page-number-x` / `page-number-y`. `header-anchor = content` (v0.4.4+) makes them follow the content area: placed `header-sep` (default `6mm`) outside its outer edge, header top aligned with the content top, page-number foot aligned with the content bottom; `header-y` / `page-number-y`, if given, become offsets from those edges.

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

Auto vertical page numbers at the outer (fore-edge) bottom corner, alternating on odd/even pages. Configure via `\pageSetup`:

| Parameter | Default |
|-----------|---------|
| `page-number-style` | `digits` (also: `chinese`, `arabic`, `none`) |
| `page-number-font-size` | `9pt` |
| `page-number-position` | `outer` (fore-edge; also `inner` = spine side, `center` = centred at the foot of the page; v0.4.4+) |
| `header-position` | `outer` (also `inner`; v0.4.4+) |
| `header-anchor` | `paper` (also `content`; v0.4.4+) |
| `header-sep` | `6mm` (gap to the content area when `header-anchor = content`; v0.4.4+) |
| `page-number-x` | `3mm` (distance from the page edge) |
| `page-number-y` | `52mm` (distance from the page bottom) |
| `header-y` | `52mm` (running header, distance from the page top) |

`page-number-position` moves only the page number and `header-position` only the header. Since v0.4.4 inner/outer follow the real spine and the default is `outer`, which gives the same layout as before; a document that wrote `page-number-position = inner` must now write `outer` to keep its old position.

## Custom Templates

Create `configs/luatex-cn-book-<name>.cfg` with `\pageSetup`, `\contentSetup`, `\punctSetup`, then use `\documentclass[name]{ltc-cn-vbook}`.

---

Next: [[Punctuation | EN:Punctuation]] | [[Features | EN:Features]] | [[Templates | EN:Templates]]
