English | [中文版](Features)

# Features Overview

`luatex-cn` provides a rich set of features for ancient Chinese book typesetting, ranging from core vertical engines to various decorative elements.

## 1. Core Typesetting Engine
A grid-based layout system built on LuaTeX for high-precision vertical text flows.
- **RTT Direction**: Native support for top-to-bottom, right-to-left direction.
- **Grid Positioning**: Characters are precisely aligned to a defined grid.
- **Pagination & Column Flow**: Handles complex page splitting and column transitions automatically.

## 2. Traditional Book Elements
Full support for visual elements required by traditional binding:
- **[[Banxin & Yuwei | EN:Side-Note]]**: Support for single/double fishtails, black silk frames, etc.
- **[[Split Page | EN:Release]]**: Support for electronic reading and traditional "tube page" binding.
- **Border System**: Double borders, inner borders, and customizable thickness.

## 3. Annotation & Revision System
Multiple ways to add comments to the text:
- **[[Interlinear Notes | EN:Side-Note]]**: Double-line small text within main body with auto-balancing.
- **[[Side Notes | EN:Side-Note]]**: Vertical annotations between text columns.
- **[[Annotations | EN:Annotation]]**: Floating annotation boxes placed anywhere on the page.

## 4. Decorations & Utilities
- **[[Seals | EN:Seal]]**: Add collection or personal seals anywhere with opacity support.
- **[[Judou | EN:Judou]]**: Traditional punctuation marks (circles and dots). Enhanced support for more Chinese punctuation since v0.2.1.
- **[[Fonts | EN:Fonts]]**: Auto-detection, font families, and fallback chains for rare characters. Supports simplified/traditional Chinese font names since v0.2.2.
- **[[Textbox | EN:Textbox]]**: Grid-based layout with auto-compression and filling.
- **[[Correction & Decoration | EN:Correction]]**: Correction marks (\fix) and character decoration (\decorate).

## 5. Architecture & Debug Features (v0.2.0+)
- **Style Registry**: Phase 2 multi-attribute style storage (color, font_size, grid_height), supports cross-page style preservation.
- **Metadata System**: Centralized book metadata management (`\title`, `\publisher`, `\ChapterMarker`).
- **[[Debug Mode | EN:Debug]]**: `\LtcDebugOn` displays page grid coordinates, `\LtcShowGrid` shows coordinate grid for layout debugging.
- **Plugin Architecture**: Standardized plugin API with unified initialize/layout/render three-phase interfaces.

## 6. Template System
Preset classical styles available out-of-the-box. See [[Templates | EN:Templates]] for details.
- `四库全书` (Siku Quanshu): Qing Dynasty imperial style.
- `四库全书彩色`: Colored version of Siku Quanshu style.
- `红楼梦甲戌本`: Manuscript style with extensive annotations.

---

👉 Next Steps: Check [[Templates | EN:Templates]] | [[Debug Mode | EN:Debug]] | [[Examples | EN:Examples]]
