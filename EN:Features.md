English | [中文版](Features)

# Features Overview

`luatex-cn` provides a rich set of features for Chinese typesetting, from the core vertical engine and traditional book elements to a clreq-conformant horizontal pipeline. Per-clause conformance status and intentional deviations are documented in the [clreq conformance matrix](https://github.com/open-guji/luatex-cn/blob/main/docs/CLREQ-CONFORMANCE.md), verified by 119 PDF metric assertions.

## 1. Core Typesetting Engine
A grid-based layout system built on LuaTeX for high-precision vertical text flows.
- **RTT Direction**: Native support for top-to-bottom, right-to-left direction.
- **Grid Positioning**: Characters are precisely aligned to a defined grid.
- **Pagination & Column Flow**: Handles complex page splitting and column transitions automatically.

## 2. Vertical: Four Document Classes
- **[[guji | EN:Quick-Start]]**: Traditional ancient book typesetting with banxin, fishtail, silk frames.
- **[guji-digital](https://github.com/open-guji/luatex-cn/tree/main/test/digital_test)**: Digitization mode — one source line is one vertical column, with `\双列{\右小列{…}\左小列{…}}` for manual interlinear splitting, to reproduce a source edition's page layout exactly.
- **[[cn-vbook / tw-vbook | EN:ltc-book]]** (v0.2.7+): Modern vertical books with clean design, built-in footnotes and punctuation system.

## 3. Horizontal: `\usepackage{luatex-cn}`

A modern horizontal Chinese pipeline implementing W3C clreq. It is a package, not a class: load it on top of `article` or any other horizontal class. Its rule kernel in `tex/shared/` is the same implementation the vertical engine uses.

```latex
\usepackage{fontspec}
\setmainfont{Source Han Serif SC}[Script=CJK, Language={Chinese Simplified}]
\usepackage[style=taiwan]{luatex-cn}
```

- **CJK–Western spacing**: 1/4 em, shrinkable to 1/8 and stretchable to 1/2, with the three clreq exceptions.
- **Punctuation width adjustment**: mainland / Taiwan / no-adjustment presets, consecutive-punctuation reduction, half-width line-final punctuation, optional hanging punctuation.
- **Line breaking**: four kinsoku levels (none/basic/gb/strict) plus the symbol-separation prohibition; per-line redistribution in clreq priority order (7 compression levels / 2 stretch levels with an even-spread fallback).
- **Interlinear marks and annotations**: `\专名`, `\书名号甲`, `\着重`; `\拼音` / `\对照` word-aligned phonetic guides.
- **Paragraphs and pages**: two-character first-line indent, orphan-character avoidance, widow/club line control, hanging-indent and indented-paragraph environments, four last-line alignments, and the `\字号` traditional size system.
- **Quotation-mark conversion**: off by default; convertible to curly or corner style automatically or explicitly.

The implementation is verified clause by clause by `test/clreq_test.py`, which measures the PDF content stream and runs in CI. See **[[Horizontal | EN:Horizontal]]**.

> ⚠️ Requires LuaTeX and is mutually exclusive with `luatexja` (which `ctex` loads under LuaLaTeX).
>
## 4. Punctuation Processing
- **[[Punctuation System | EN:Punctuation]]** (v0.2.7+): Modern punct squeeze, kinsoku, vertical quote replacement with mainland/Taiwan styles. Vertical punctuation width adjustment is context-sensitive per clreq, and glyph placement is anchored by measured ink extents rather than the font's own design. Since v0.4.0 additionally: hanging punctuation at column end (`punct-hanging`), CJK-Western spacing (1/4 em, `western-space`), sideways Western text (`\Sideways`), short runs set horizontally in one slot (`\CombineUpright`, tate-chū-yoko), and the extended connector/interpunct/solidus classes (mainland interpunct at half width).
- **[[Judou | EN:Judou]]**: Traditional punctuation marks with three modes (normal/judou/none) switchable at any time.

## 5. Traditional Book Elements
Full support for visual elements required by traditional binding:
- **[[Banxin & Yuwei | EN:Templates]]**: Support for single/double fishtails, black silk frames, etc.
- **Split Page**: Support for electronic reading and traditional "tube page" binding.
- **Border System**: Double borders, inner borders, and customizable thickness.
- **Book Ear** (v0.4.5+): `\banxinSetup{book-ear=true}` (`书耳`) draws a small box outside the top corner of the frame recording the chapter title, taken from the current `\chapter` by default; position (left / right / both), size and font size are configurable. Keys in the Banxin section of [[Command Reference | Command-Reference]] (#87).
- **Thread-bound Cover** (v0.4.3+): `\线装书封面[keys]{title}` renders the modern blue thread-bound cover; see §8 below.

## 6. Annotation & Revision System
Multiple ways to add comments to the text:
- **[[Interlinear Notes | EN:Side-Note]]**: Double-line small text within main body with auto-balancing.
- **[[Side Notes | EN:Side-Note]]**: Vertical annotations between text columns.
- **[[Annotations | EN:Annotation]]**: Floating annotation boxes placed anywhere on the page.
- **[[Marginal Notes | EN:Annotation]]** (v0.2.3+): Top-of-page annotations.
- **[[Footnotes | EN:ltc-book]]** (v0.2.7+): Endnotes and page-bottom notes with lujiao/circled numbering.
- **[[TOC Entries | EN:Features]]**: `\条目` (v0.2.5+) with hierarchical indentation.

## 7. Style Control (v0.2.8+)

`\Style` (or `\样式`) temporarily overrides font size, font, text color, cell height and spacing inside the body text without changing the layout mode.

```latex
% Inline
\样式[字号=16pt, 字体颜色=red]{important text}

% Environment (for several lines)
\begin{样式设置}[字号=14pt, 间距=0.5em]
  several lines of styled text…
\end{样式设置}
```

| Key | Chinese | Description |
|-----|---------|-------------|
| `font-size` | `字号` | Font size |
| `font` | `字体` | Font |
| `font-color` | `字体颜色` | Text color |
| `grid-height` | `格高` | Cell height |
| `spacing-top` | `上间距` | Extra space above |
| `spacing-bottom` | `下间距` | Extra space below |
| `spacing` | `间距` | Both of the above |

Styles live in an internal registry, survive page breaks and nest. See [[Command Reference | Command-Reference]].

## 8. Covers (v0.2.8+)

The `Cover` environment (`\begin{封面}`) sets a cover page. It turns off the borders and banxin and can set a page background color.

```latex
\begin{封面}[底色=200,200,200]
  \行[对齐=center, 字号=24pt]{Title}
  \行[对齐=center, 字号=14pt]{Author}
\end{封面}
```

| Key | Chinese | Description |
|-----|---------|-------------|
| `background-color` | `底色` | Cover background (color name or RGB) |

The environment wraps `SinglePage` + `BodyText`, so no manual page handling is needed. The background color applies to the cover page only.

### Thread-bound Cover (v0.4.3+)

`\ThreadBoundCover[keys]{title}` (`\线装书封面` / `\線裝書封面`) outputs one page of the modern blue thread-bound cover seen on facsimile editions by Zhonghua Book Company, Guangling Press and others (after CY/T 247—2021, figures 1 and 2): a navy cover with a cream title label at the top left, a thick-thin double frame inside the label, and the title in large type from top to bottom. The label has a minimum height (50% of the page height by default) and grows with a long title; if it would overflow the page, the title and small type shrink proportionally. Only the label is printed: no author or publisher.

```latex
\线装书封面[册次=第一冊]{史記}
\线装书封面[卷次=卷一]{李白詩集}
\线装书封面[册次=第九冊, 卷次=卷二十一至二十三]{欽定四庫全書簡明目錄}
\线装书封面[册次=第一冊, 小字位置=随后]{四書章句集注}
\线装书封面[册次=第一冊, 订线]{史記}   % preview: draw the binding thread
```

| Key (EN / ZH) | Default | Description |
|---|---|---|
| `volume` / `册次` | empty | e.g. 第一冊 |
| `juan` / `卷次` | empty | e.g. 卷一; with `volume`, set side by side (volume on the right) |
| `small-position` / `小字位置` | `bottom` (`底部`) | `follow` (`随后`): right after the title |
| `binding-thread` / `订线` | off | Draw the binding thread, for preview only |
| `thread-holes` / `订线眼数` | 4 | 6 for six-hole binding |
| `thread-distance` / `订线距` | page width × 0.08 | Distance of the thread from the right edge |
| `thread-color` / `订线颜色` | `236, 236, 230` | |
| `background-color` / `底色` | `30, 50, 90` | Cover color (RGB 0–255 or color name) |
| `label-color` / `签条底色` | `232, 228, 212` | Label paper color |
| `ink-color` / `墨色` | `25, 25, 25` | Title, small type and frame color |
| `label-width` / `签条宽` | page width × 0.23 | |
| `label-left` / `签条左距` | page width × 0.05 | Label left edge from the page left |
| `label-top` / `签条上距` | page height × 0.04 | Label top from the page top |
| `label-min-height` / `签条最小高` | page height × 0.5 | |
| `title-font-size` / `书名字号` | label width × 0.56 | |
| `small-font-size` / `小字字号` | title size × 0.3 | |

Length keys left out (or `0pt`) are derived from the page size; the page size follows the document (half the sheet width in split-page mode). Full example: [`示例/线装书封面/`](https://github.com/open-guji/luatex-cn/tree/main/示例/线装书封面).

## 9. Line Marks: Proper-name and Book-title Marks (v0.2.8+)

`\LineMark` (or `\线标`) draws a straight or wavy line beside the characters, used for **proper-name marks** and **book-title marks**. The lines are drawn with PDF graphics, not Unicode characters, so they are precise and flexible.

```latex
% Proper-name mark (straight)
\专名号{孔子}

% Book-title mark (wavy)
\书名号{红楼梦}

% Custom
\线标[类型=wavy, 颜色=blue, 振幅=large]{emphasis}
```

| Command | Chinese | Effect |
|---------|---------|--------|
| `\ProperNameMark` | `\专名号` `\下划线` | Straight line |
| `\BookTitleMark` | `\书名号` `\波浪线` | Wavy line |

| Key | Chinese | Description | Default |
|-----|---------|-------------|---------|
| `type` | `类型` | `straight` or `wavy` | `straight` |
| `color` | `颜色` | Line color | `black` |
| `offset` | `偏移` | Distance from the text | `0.6em` |
| `amplitude` | `振幅` | Wave amplitude: `small` `medium` `large` | `medium` |
| `line-width` | `线宽` | Line width | `0.8pt` |
| `style` | `风格` | `standard` (compact) or `cursive` (hand-drawn feel) | `standard` |

Line marks scale automatically inside jiazhu, side notes and other small-type contexts.

## 10. Layout Control & Commands
- **Force Column**: `\Column` (or `\行`) sets its content as a column of its own.
- **Last Column**: `\LastColumn` (or `\末行`) places content in the last column.
- **Flexible Widths**: `\行[width=2cm]{...}` (v0.2.7+) for variable-width columns.
- **Page Breaks**: Supports standard `\newpage` and `\clearpage`.
- **Half-Page Break** (v0.3.6+): `\NewHalfPage` / `\换半页` jumps to the next half-page in split-page mode.
- **Illustration Page** (v0.3.6+): `\IllustrationPage` / `\插图页` hides silk frames while keeping borders, for full-page illustrations (fix #29).
- **Natural Layout** (v0.2.7+): `layout-mode=natural` for non-uniform spacing.
- **Free Column Width** (v0.2.8+): with `n-column=0` column widths follow the content (default in `ltc-cn-vbook` / `ltc-tw-vbook`).
- **Facing-page Padding** (v0.4.4+): `\pageSetup{facing-pages=true}` (`对页补页`) makes every chapter start on an odd (right-hand) page: when a `\chapter` lands at the top of an even page, a page is inserted before it. Off by default; only `\chapter` inside a `正文` block counts; not applied in split-page mode. `\InsertBlankPage` (`\补空白页`) forces a page anywhere; two in a row give two pages. Inserted pages keep the frame, banxin or header and page number by default; `blank-page-style=blank` (`补页样式=空白`) makes them fully blank, both in `\pageSetup` and as `\InsertBlankPage[blank-page-style=blank]` (#176).
- **Centered Page** (v0.4.5+): `\begin{CenteredPage} … \end{CenteredPage}` (`居中页`) sets a block of text on a new page with the columns centred horizontally in the content area, for title and volume pages; place each column vertically with `\行[align=center]`. In ordinary body text use `\contentSetup{horizontal-align=center}` (`right` / `center` / `left`, default `right`) (#175).

```latex
\begin{居中页}
  \行[align=center]{王又朴集}
  \行[align=center]{上}
\end{居中页}
```

## 11. Decorations & Utilities
- **[[Seals | EN:Seal]]**: Add collection or personal seals anywhere with opacity support.
- **[[Fonts | EN:Fonts]]**: Auto-detection, font families, and fallback chains. Supports simplified/traditional Chinese font names since v0.2.2.
- **[[Textbox | EN:Textbox]]**: Grid-based layout with auto-compression and filling. Transparency control (v0.3.6+).
- **Colophon** (v0.3.6+): `\colophon` / `\牌记` — opaque double-border floating text box.
- **Missing Characters**: `\MissingChar` (`\缺字`) inserts a white square □ as a placeholder; `\缺字[3]` for three.
- **[[Correction & Decoration | EN:Correction]]**: Correction marks and character decoration.
- **[[Elevation | EN:Taitou]]** (v0.2.6+): Honorific elevation formatting (single/double/triple/flat).

## 12. Architecture & Debug Features (v0.2.0+)
- **Style Registry**: Multi-attribute style storage with cross-page preservation.
- **Metadata System**: Centralized book metadata management.
- **[[Debug Mode | EN:Debug]]**: Grid visualization and layout debugging.
- **[[Layout Export | EN:Layout-Export]]**: `\enableLayoutExport` exports layout results to JSON, including precise character coordinates, page/column/row info, jiazhu and sidenote data.
- **Plugin Architecture**: Standardized plugin API with three-phase interfaces.

## 13. Template System
Preset classical styles available out-of-the-box. See [[Templates | EN:Templates]].
- `四库全书` (Siku Quanshu): Qing Dynasty imperial style.
- `四库全书彩色`: Colored version.
- `红楼梦甲戌本`: Manuscript style.
- `欧式族谱`: Genealogy style.
- `ltc-cn-vbook` / `ltc-tw-vbook` default configs: modern vertical layout with mainland / Taiwan punctuation.

---

👉 Next Steps: Check [[Templates | EN:Templates]] | [[Debug Mode | EN:Debug]] | [[Examples | EN:Examples]]
