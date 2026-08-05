English | [中文版](Features)

# Features Overview

`luatex-cn` provides a rich set of features for Chinese typesetting, from the core vertical engine and traditional book elements to a clreq-conformant horizontal pipeline.

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
> ⚠️ Not yet in a release (latest is v0.3.8) — get it from the main branch.

## 4. Punctuation Processing
- **[[Punctuation System | EN:Punctuation]]** (v0.2.7+): Modern punct squeeze, kinsoku, vertical quote replacement with mainland/Taiwan styles. Vertical punctuation width adjustment is context-sensitive per clreq, and glyph placement is anchored by measured ink extents rather than the font's own design. On the main branch additionally: hanging punctuation at column end (`punct-hanging`), CJK-Western spacing (1/4 em, `western-space`), sideways Western text (`\Sideways`), and the extended connector/interpunct/solidus classes (mainland interpunct at half width).
- **[[Judou | EN:Judou]]**: Traditional punctuation marks with three modes (normal/judou/none) switchable at any time.

## 5. Traditional Book Elements
Full support for visual elements required by traditional binding:
- **[[Banxin & Yuwei | EN:Templates]]**: Support for single/double fishtails, black silk frames, etc.
- **Split Page**: Support for electronic reading and traditional "tube page" binding.
- **Border System**: Double borders, inner borders, and customizable thickness.

## 6. Annotation & Revision System
Multiple ways to add comments to the text:
- **[[Interlinear Notes | EN:Side-Note]]**: Double-line small text within main body with auto-balancing.
- **[[Side Notes | EN:Side-Note]]**: Vertical annotations between text columns.
- **[[Annotations | EN:Annotation]]**: Floating annotation boxes placed anywhere on the page.
- **[[Marginal Notes | EN:Annotation]]** (v0.2.3+): Top-of-page annotations.
- **[[Footnotes | EN:ltc-book]]** (v0.2.7+): Endnotes and page-bottom notes with lujiao/circled numbering.
- **[[TOC Entries | EN:Features]]**: `\条目` (v0.2.5+) with hierarchical indentation.

## 7. Layout Control & Commands
- **Force Column**: `\列` (or `\Column`) forces content to start in a new column.
- **Last Column**: `\末列` (or `\LastColumn`) places content in the last column.
- **Flexible Widths**: `\行[width=2cm]{...}` (v0.2.7+) for variable-width columns.
- **Page Breaks**: Supports standard `\newpage` and `\clearpage`.
- **Half-Page Break** (v0.3.6+): `\NewHalfPage` / `\换半页` jumps to the next half-page in split-page mode.
- **Illustration Page** (v0.3.6+): `\IllustrationPage` / `\插图页` hides silk frames while keeping borders, for full-page illustrations (fix #29).
- **Natural Layout** (v0.2.7+): `layout-mode=natural` for non-uniform spacing.

## 8. Decorations & Utilities
- **[[Seals | EN:Seal]]**: Add collection or personal seals anywhere with opacity support.
- **[[Fonts | EN:Fonts]]**: Auto-detection, font families, and fallback chains. Supports simplified/traditional Chinese font names since v0.2.2.
- **[[Textbox | EN:Textbox]]**: Grid-based layout with auto-compression and filling. Transparency control (v0.3.6+).
- **Colophon** (v0.3.6+): `\colophon` / `\牌记` — opaque double-border floating text box.
- **[[Correction & Decoration | EN:Correction]]**: Correction marks and character decoration.
- **[[Elevation | EN:Taitou]]** (v0.2.6+): Honorific elevation formatting (single/double/triple/flat).

## 9. Architecture & Debug Features (v0.2.0+)
- **Style Registry**: Multi-attribute style storage with cross-page preservation.
- **Metadata System**: Centralized book metadata management.
- **[[Debug Mode | EN:Debug]]**: Grid visualization and layout debugging.
- **[[Layout Export | EN:Layout-Export]]**: `\enableLayoutExport` exports layout results to JSON, including precise character coordinates, page/column/row info, jiazhu and sidenote data.
- **Plugin Architecture**: Standardized plugin API with three-phase interfaces.

## 10. Template System
Preset classical styles available out-of-the-box. See [[Templates | EN:Templates]].
- `四库全书` (Siku Quanshu): Qing Dynasty imperial style.
- `四库全书彩色`: Colored version.
- `红楼梦甲戌本`: Manuscript style.
- `中华书局` (v0.2.7+): Modern mainland-style vertical layout.

---

👉 Next Steps: Check [[Templates | EN:Templates]] | [[Debug Mode | EN:Debug]] | [[Examples | EN:Examples]]
