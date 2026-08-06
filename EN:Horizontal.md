English | [中文版](Horizontal)

# Modern Horizontal Typesetting (\usepackage{luatex-cn})

`\usepackage{luatex-cn}` implements **horizontal** Chinese typesetting per the W3C [Requirements for Chinese Text Layout (clreq)](https://www.w3.org/TR/clreq/) — it is the unified entry point of the whole bundle: in package form the default is horizontal, while vertical books use the `ltc-guji` / `ltc-cn-vbook` document classes. It is a *package*, not a document class: load it on top of any horizontal class (`article`, `book`, `report`, …) and it inserts kinsoku penalties and adjustable glue in `pre_linebreak_filter` / `post_linebreak_filter`.

> The internal package name of the horizontal implementation is `luatex-cn-hori`; loading it directly still works, and the unified entry passes its options through verbatim. `\usepackage[vertical]{luatex-cn}` loads the vertical bundle instead (the historical 0.3.x semantics).

The rule kernel lives in `tex/shared/` (the full clreq punctuation table, a one-dimensional priority space allocator, and the four-level kinsoku module) and is shared with the vertical engine — one source of truth for both writing modes.

> **Prerequisites**
> - Requires **LuaTeX** (`lualatex`); other engines abort with an error.
> - **Mutually exclusive with luatexja.** `ctex` loads luatexja under LuaLaTeX; both insert CJK spacing and line-break penalties in the same callbacks, so loading both double-processes every paragraph. The package detects this and errors out. Use one or the other.
> - Declare Chinese fonts through `fontspec` with `Script=CJK` and `Language`. Without them luaotfload starts from `latn/dflt`, whose `locl` substitutes a baseline-hugging Western ellipsis and never upgrades the dash to its full-width Chinese form.

---

## Minimal example

```latex
\documentclass[12pt]{article}
\usepackage[paperwidth=10cm, paperheight=16cm, margin=1.2cm]{geometry}
\usepackage{fontspec}
\setmainfont{Source Han Serif SC}[Script=CJK, Language={Chinese Simplified}]
\usepackage{luatex-cn}
\begin{document}
中文与 Western text 混排时，中西之间会自动插入四分之一字宽的可调间距。
\end{document}
```

Taiwan style (centered punctuation):

```latex
\usepackage[style=taiwan]{luatex-cn}
```

---

## Package options

Options may be given at `\usepackage[...]{luatex-cn}` time, or changed mid-document with `\horiSetup{...}` (CN alias `\横排设置{...}`); changes take effect for subsequent paragraphs.

### Punctuation and spacing

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `style` | `mainland` / `taiwan` / `none` | `mainland` | Punctuation style preset. `mainland` hugs the start edge with the blank at the end; `taiwan` centers the glyph; `none` is the clreq "no adjustment" preset (neither squeezed nor hugging) |
| `cjk-latin-space` | boolean | `true` | 1/4 em space between CJK and Western text (shrinks to 1/8, stretches to 1/2; the three clreq exceptions get none) |
| `inter-cjk-stretch` | em ratio | `0.05` | Inter-CJK stretch of last resort |
| `adjacent-punct` | `1.5` / `1` / `natural` | `1.5` | Consecutive-punctuation reduction. clreq requires adjacent bracket-type marks to go from 2 em to 1.5 em "in any style"; `1` reduces further to 1 em; `natural` squeezes only as line tightness demands |
| `line-start-bracket` | `trim` / `natural` | `trim` | Trim half a character from the start side of an opening bracket at line start (including an indented first line) |
| `line-end-punct` | `compress` / `natural` | `compress` | Half-width line-final punctuation (clreq compression level 1). `compress` always reclaims the blank and redistributes it; `natural` reclaims only as far as the line's tightness demands |
| `hanging-punct` | boolean | `false` | Hang line-final period-type marks outside the text area. Off by default because centered HK/TW marks should not hang |
| `quote-style` | `keep` / `auto` / `curly` / `corner` | `keep` | Quotation-mark convention conversion. `keep` leaves the manuscript untouched; `auto` follows `style`; `curly` (simplified horizontal: double outside, single inside) and `corner` (traditional Taiwan: single outside, double inside) are explicit, with nesting depth preserved by a one-to-one mapping |

### Line breaking and in-line distribution

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `kinsoku-level` | `none` / `basic` / `gb` / `strict` | `basic` | Kinsoku strictness; clreq recommends `basic` |
| `line-adjust` | boolean | `true` | Per-line priority redistribution (clreq: 7 compression levels / 2 stretch levels, with an even-spread fallback) |

### Paragraphs and pages

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `paragraph-indent` | length / `keep` | `2em` | First-line indent; clreq specifies the width of two Han characters. Resolved against the main font at `\begin{document}`; `keep` leaves `\parindent` alone |
| `orphan-char` | boolean | `true` | Avoid a single Han character alone on a paragraph's last line by borrowing from the previous line |
| `last-line` | `left` / `center` / `right` / `justify` | `left` | Last-line alignment. clreq says body paragraphs' last lines are not justified (the `left` default); use `justify` for lists, table captions, and other places where consistency is wanted |
| `widow-penalty` | integer | `10000` | Widow penalty (10000 = forbidden) |
| `club-penalty` | integer | `10000` | Club (orphan line) penalty |

### Interlinear annotations

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `ruby-size` | ratio | `0.5` | Annotation size relative to the base text |
| `ruby-gap` | em ratio | `0.1` | Gap between the annotation row and the base row |

---

## Commands

### Setup

```latex
\horiSetup{last-line=right}      % CN alias: \横排设置
```

### Interlinear indication marks (H3)

Single-sided binding convention: marks are drawn **below** the text.

| Command | Alias | Effect |
|---------|-------|--------|
| `\专名{...}` | — | Proper-name mark (straight underline) |
| `\书名号甲{...}` | `\书名甲` | Book-title mark, form A (wavy underline) |
| `\着重{...}` | — | Emphasis dots (placed below the line level) |

```latex
太史公\专名{司马迁}著\书名号甲{史记}，其文\着重{究天人之际，通古今之变}。
```

- Adjacent proper names are drawn separately, not merged into one rule.
- Emphasis dots are never placed under punctuation.
- clreq requires a line gap of at least 0.5 em for interlinear marks; below that the marks touch the next line's glyphs. The package warns once on the first violation — raise the leading (e.g. `\linespread{1.6}`).

### Interlinear annotations / phonetic guides (H4)

```latex
\ruby{base}{annotation}      % CN aliases: \拼音, \对照
```

```latex
\拼音{中国}{zhōng guó}的\拼音{汉字}{hàn zì}历史悠久；
\对照{印刷}{printing}术的发明意义重大。
```

- The annotation splits on **spaces** into syllables and is word-aligned with the base per clreq.
- The shorter row is spread across the block width (half a slot at each edge); the longer row is set solid.
- Size and gap come from `ruby-size` / `ruby-gap`.

### Even spread

Distributes characters evenly across a given width with both ends flush — for titles, table cells, and the like.

```latex
\均排{目录}                 % defaults to \linewidth; alias \EvenSpread
\均排[6em]{凡例}
```

> Line-level even distribution as a stretch fallback is handled by the `line-adjust` allocator; you do not need `\均排` for that.

### Paragraph styles (H5)

```latex
\begin{凸排}                % optional argument = hanging indent, default 2em
First line flush, subsequent lines indented — dictionary entries, bibliographies.
\end{凸排}

\begin{段落缩排}            % optional arguments: left, right indent (2em / 0pt)
The whole paragraph indented from the text area — quotations and editorial notes.
\end{段落缩排}
```

### Traditional size numbers

The 号数 size system from clreq's "font size" section, shared between horizontal and vertical modes.

```latex
{\字号{三号} A level-3 heading\par}
{\字号{小四}[1.7] Body text with 1.7× leading\par}
```

The optional argument is the leading multiplier; omitted, it takes the shared-layer constant. Available sizes:

| Name | pt | Name | pt | Name | pt |
|------|----|------|----|------|----|
| 初号 | 42 | 二号 | 22 | 五号 | 10.5 |
| 小初 | 36 | 小二 | 18 | 小五 | 9 |
| 一号 | 26 | 三号 | 16 | 六号 | 7.5 |
| 小一 | 24 | 小三 | 15 | 小六 | 6.5 |
| | | 四号 | 14 | 七号 | 5.5 |
| | | 小四 | 12 | 八号 | 5 |

---

## Relationship to vertical mode

Horizontal and vertical share the clreq rule kernel in `tex/shared/`, so punctuation classification, kinsoku levels, and consecutive-punctuation reduction are one implementation. The five keys of `\标点设置` — `style`, `squeeze-mode`, `adjacent-punct`, `line-start-bracket`, `line-end-punct` — use the same names and values as this package, and `\字号` works in both modes.

## Conformance testing

`test/clreq_test.py` parses the horizontal PDF content stream and asserts clreq clauses against measured glyph x-coordinates and advances: CJK–Western spacing bounds, no space beside period-type marks or inside bracket marks, line-start/line-end kinsoku, symbol-separation prohibition, two-em punctuation units, half-width line-final punctuation, interlinear annotation word alignment, and more. Every assertion cites its clreq clause, and the suite runs in CI.

```bash
python3 test/clreq_test.py                 # check the regression-test hori.tex
python3 test/clreq_test.py yourfile.tex    # check your own horizontal document
```

## Example

**[論辯的魂靈 by Lu Xun](https://github.com/open-guji/luatex-cn/tree/main/示例/论辩的魂灵)** — the same essay set twice: traditional with `style=taiwan` (centered punctuation), simplified with `style=mainland` + `quote-style=curly` (corner quotes converted to curly ones). Demonstrates consecutive-punctuation reduction, line-start/end compression, orphan-character avoidance, and `last-line=right` for the colophon.

---

👉 See also: [[Punctuation | EN:Punctuation]] ｜ [[Fonts | EN:Fonts]] ｜ [[cn-vbook / tw-vbook | EN:ltc-book]]
