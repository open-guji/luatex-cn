English | [中文版](Features)

# Features Overview

`luatex-cn` provides a rich set of features for ancient Chinese book typesetting, ranging from core vertical engines to various decorative elements.

## 1. Core Typesetting Engine
A grid-based layout system built on LuaTeX for high-precision vertical text flows.
- **RTT Direction**: Native support for top-to-bottom, right-to-left direction.
- **Grid Positioning**: Characters are precisely aligned to a defined grid.
- **Pagination & Column Flow**: Handles complex page splitting and column transitions automatically.

## 2. Document Classes
- **[[guji | EN:Quick-Start]]**: Traditional ancient book typesetting with banxin, fishtail, silk frames.
- **[[cn-vbook / tw-vbook | EN:ltc-book]]** (v0.2.7+): Modern vertical books with clean design, built-in footnotes and punctuation system.

## 3. Punctuation Processing
- **[[Punctuation System | EN:Punctuation]]** (v0.2.7+): Modern punct squeeze, kinsoku, vertical quote replacement with mainland/Taiwan styles.
- **[[Judou | EN:Judou]]**: Traditional punctuation marks with three modes (normal/judou/none) switchable at any time.

## 4. Traditional Book Elements
Full support for visual elements required by traditional binding:
- **[[Banxin & Yuwei | EN:Templates]]**: Support for single/double fishtails, black silk frames, etc.
- **Split Page**: Support for electronic reading and traditional "tube page" binding.
- **Border System**: Double borders, inner borders, and customizable thickness.

## 5. Annotation & Revision System
Multiple ways to add comments to the text:
- **[[Interlinear Notes | EN:Side-Note]]**: Double-line small text within main body with auto-balancing.
- **[[Side Notes | EN:Side-Note]]**: Vertical annotations between text columns.
- **[[Annotations | EN:Annotation]]**: Floating annotation boxes placed anywhere on the page.
- **[[Marginal Notes | EN:Annotation]]** (v0.2.3+): Top-of-page annotations.
- **[[Footnotes | EN:ltc-book]]** (v0.2.7+): Endnotes and page-bottom notes with lujiao/circled numbering.
- **[[TOC Entries | EN:Features]]**: `\条目` (v0.2.5+) with hierarchical indentation.

## 6. Layout Control & Commands
- **Force Column**: `\列` (or `\Column`) forces content to start in a new column.
- **Last Column**: `\末列` (or `\LastColumn`) places content in the last column.
- **Flexible Widths**: `\行[width=2cm]{...}` (v0.2.7+) for variable-width columns.
- **Page Breaks**: Supports standard `\newpage` and `\clearpage`.
- **Natural Layout** (v0.2.7+): `layout-mode=natural` for non-uniform spacing.

## 7. Decorations & Utilities
- **[[Seals | EN:Seal]]**: Add collection or personal seals anywhere with opacity support.
- **[[Fonts | EN:Fonts]]**: Auto-detection, font families, and fallback chains. Supports simplified/traditional Chinese font names since v0.2.2.
- **[[Textbox | EN:Textbox]]**: Grid-based layout with auto-compression and filling.
- **[[Correction & Decoration | EN:Correction]]**: Correction marks and character decoration.
- **[[Elevation | EN:Taitou]]** (v0.2.6+): Honorific elevation formatting (single/double/triple/flat).

## 8. Architecture & Debug Features (v0.2.0+)
- **Style Registry**: Multi-attribute style storage with cross-page preservation.
- **Metadata System**: Centralized book metadata management.
- **[[Debug Mode | EN:Debug]]**: Grid visualization and layout debugging.
- **[[Layout Export | EN:Layout-Export]]**: `\enableLayoutExport` exports layout results to JSON, including precise character coordinates, page/column/row info, jiazhu and sidenote data.
- **Plugin Architecture**: Standardized plugin API with three-phase interfaces.

## 9. Template System
Preset classical styles available out-of-the-box. See [[Templates | EN:Templates]].
- `四库全书` (Siku Quanshu): Qing Dynasty imperial style.
- `四库全书彩色`: Colored version.
- `红楼梦甲戌本`: Manuscript style.
- `中华书局` (v0.2.7+): Modern mainland-style vertical layout.

---

👉 Next Steps: Check [[Templates | EN:Templates]] | [[Debug Mode | EN:Debug]] | [[Examples | EN:Examples]]
