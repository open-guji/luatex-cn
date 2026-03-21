English | [中文版](Changelog)

# Changelog

All notable changes to this project will be documented here.

## [0.3.6] - 2026-03-20

New illustration page, colophon, annotation toggles, and Banxin TextBox overhaul.

- ✨ **Illustration Page**: New `\IllustrationPage` / `\插图页` command with half-page granularity silk frame suppression, defaults to half-page break first (fix #29)
- ✨ **Colophon**: New `\colophon` / `\牌记` command — opaque double-border floating text box (fix #58)
- ✨ **Annotation Toggles**: Side notes/MeiPi/PiZhu support `sidenote=false`/`meipi=false`/`pizhu=false` on/off switches in Setup or per-call (fix #89)
- ✨ **Half-Page Break**: New `\NewHalfPage` / `\换半页` command
- ✨ **Banxin TextBox**: Banxin upper/lower/middle sections now rendered through TextBox pipeline, supporting compact layout, jiazhu, and fill-padding
- ✨ **TextBox Transparency**: New `transparent` boolean parameter (default: true) to control text box background transparency
- 🐛 **Side Note Punctuation**: Fixed vertical punctuation conversion not applied in normal mode for side notes (fix #89)
- 🐛 **Table Fixes**: Fixed auto-width cell column overlap, fixed-width empty cell ineffective, vertical alignment not accounting for padding
- 🐛 **Illustration Page Silk Frame**: Fixed `\IllustrationPage` causing all pages to lose silk frames due to style stack pollution
- 🐛 **Table Cross-Page**: Fixed parallel mode cross-page table subsequent bands rendering at wrong position
- 🐛 **Underline Position**: Fixed `\Underline` position offset in Free Mode
- ♻️ **Parallel Default**: Table banding now defaults to parallel mode (page break when band full, not band switch)
- ♻️ **Padding Unification**: Unified `padding-top`/`padding-bottom` parameters, replacing multiple naming schemes
- ♻️ **Parameter Rename**: Banxin parameters renamed from content-oriented to position-oriented, `x`/`y` aliases updated

## [0.3.5] - 2026-03-14

Component-level settings system and multi-level heading support.

- ✨ **Setting Stack**: New setting stack module for component-level punctuation mode configuration in side notes, annotations, header notes, and text boxes (fix #84)
- ✨ **Global Settings Command**: New `\GlobalSettings` / `\全局设置` command for unified management of punct-mode, punct-style, and other global parameters; new xshift parameter for side notes (fix #86)
- ✨ **Multi-level Headings**: New `\chapter`/`\section`/`\subsection` commands with `\chapter[banxin title]{body title}` optional parameter to distinguish banxin vs body display; new `\sectionSetup` configuration command (fix #64)
- ✨ **Unified Style Parameters**: All components accept style parameters via .unknown double-forwarding (settings → style)
- 🐛 **Seal Fix**: Fixed multiple `\YinZhang` commands overwriting each other, showing only the last one (fix #80)
- 🐛 **Alias Unification**: Unified Chinese aliases: Column→行, SideNode→Sidenote (fix #83)
- 🐛 **Line Break Spacing**: Fixed source line breaks in BodyText producing extra spaces (fix #86)
- 🐛 **Layout Fixes**: Fixed auto_balance sub-column overflow, textflow band height constraint, banxin font matching, banxin_ratio=1 horizontal line crossing, and table column border edge line issues

## [0.3.4] - 2026-03-12

New table and genealogy typesetting (experimental).

- ✨ **Table Environment**: Table environment with cell grouping, multi-band layout, band height/column parameters, fine-grained border control
- ✨ **Band (Horizontal Section)**: Band feature for horizontal sectioning in vertical pages with border rendering
- ✨ **Ouyang-style Genealogy**: Initial implementation of Ouyang Xiu-style genealogy typesetting, see examples
- ✨ **Jiazhu Shortcut**: New `\夹注捷径{open}{close}` for custom bracket auto-replacement to `\夹注{}` (fix #76)
- 🐛 **Taitou Line Break**: Fixed line break failure after taitou when character count ≤ taitou count (fix #78)
- 🐛 **Jiazhu Key Forwarding**: Fixed jiazhu key system forwarding unknown keys to textflow (fix #81)
- 🐛 **Footnote Marker**: Fixed inconsistent centering of footnote markers like【一】【二】(fix #77)
- 🐛 **Table Fixes**: Fixed table cell vertical alignment, band separator position, column border inheritance, multi-table parameter override
- 🐛 **Layout Fixes**: Fixed extra row in page break/jiazhu/taitou, fixed textflow pending state leak
- ♻️ **Coordinate System Refactor**: pos.x/pos.y use absolute coordinates, render stage applies unified RTL→LTR conversion

## [0.3.3] - 2026-03-04

Multiple typesetting bug fixes.

- 🐛 **Proper Name Underline**: Fixed proper name mark breaking at every character in natural mode (fix #74)
- 🐛 **Decoration Symbol Offset**: Fixed horizontal offset for Noto CJK fonts, compatible with different rawdata.descriptions key formats (fix #73)
- 🐛 **Correction Command**: Fixed `\改` command adding extra spacing and comma position offset in jiazhu (fix #72)
- 🐛 **Punctuation Detection**: Fixed certain font punctuation marks not being recognized (fix #71)

## [0.3.2] - 2026-03-02

Full implementation of modern vertical typesetting (Zhonghua Shuju style).

- ✨ **Paragraph Indentation**: Paragraph detection and vbook first-line indent, indent style merged into StyleEnv
- ✨ **Running Headers**: Alternating odd/even page headers showing chapter/book name, page numbers on inner margin
- ✨ **Two-side Mirror Margins**: Added twoside mirror margin support, enabled by default in vbook
- ✨ **Footnote Enhancement**: Hanging indent for footnote continuation, `\FootnoteParagraph` for unnumbered footnote blocks, footnote numbering alignment
- ✨ **Moquan (Ink Border) Command**: Added `\墨围` command with separate border padding control
- ✨ **Column Spacing**: Free Mode column spacing, near-full column justification in natural mode
- ✨ **Overlay Compare Tool**: Added `overlay_compare.py` red-blue overlay comparison tool
- 🐛 **Kinsoku Rules**: Fixed natural mode kinsoku rules applying across all layout paths
- 🐛 **Footnote Fix**: Fixed footnote paragraph indent loss after cross-column continuation
- 🐛 **vbook Fix**: Fixed Lua number format error and Taiwan traditional Chinese command aliases
- 🐛 **Annotation Color**: Fixed pizhu default color RGB parsing error from expl3 space eating
- 🐛 **Character Spacing**: Unified natural mode spacing strategy, changed to 0.1em proportional spacing
- 🐛 **Column Stretch**: Footnote numbering and moquan excluded from column stretch

## [0.3.1] - 2026-02-26

Focus on optimizing guji-digital document class for facsimile typesetting.

- ✨ **Document-level Style System**: New `\ConfigDocument` command for document-level style presets and attribute passing
- ✨ **Digitization Toolchain**: Bidirectional conversion tools (`semantic_to_digital.py` / `digital_to_semantic.py`)
- ✨ **Layout Export**: Export layout JSON via `ENABLE_EXPORT=1` environment variable for automated validation
- ✨ **PDF Page Mapping**: Simplified spread page semantics, correct single/double page mapping
- 🐛 **Indent System Refactor**: Split taitou and suojin indent types, fixed attribute passing bugs
- 🐛 **Textflow Layout**: Fixed taitou indent being incorrectly cleared in textflow
- 🐛 **Decoration Symbols**: Changed circle dot/emphasis mark character from `。` to `○` for better visuals
- 🐛 **Page Break Fix**: Fixed `\双列` typesetting after `\换页`
- 🐛 **Flat Taitou Fix**: Fixed `\平抬` not working inside jiazhu
- 📦 **Template Updates**: Added Wuliang Quanzhi template, restructured Siku Quanshu template folder

## [0.3.0] - 2026-02-18

Project is now stable for full-book typesetting.

- ✨ **User Experience Improvements**: Organized parameter naming conventions, updated Wiki and README documentation
- ✨ **Template System**: Added templates folder with ready-to-use typesetting templates
- 🐛 **Paragraph Fix**: Fixed `bottom-indent` default value setting (fix #xx)
- 🐛 **Banxin Fix**: Fixed banxin chapter alignment handling

**Note**: Before v1.0, commands and parameters may change. Please keep your installation up to date.

## [0.2.9] - 2026-02-18

Complete typesetting of *Qinding Siku Quanshu Jianming Mulu (Volume 1)*. Added "digitization" mode for classical text OCR and proofreading.

- ✨ **Helper Commands**: Added `\臣`, `\xshift` and other typesetting auxiliary commands
- ✨ **Page Processing**: Added cover page, collation page, and blank page processing
- ✨ **Digital Mode**: New `ltc-guji-digital` document class for OCR-based classical text digitization and proofreading (experimental)
- ✨ **SideNote Enhancement**: `\SideNode` now supports positional parameters and numeric auto-conversion (`\SideNode[5pt]` = `\SideNode[0.5]` auto-converts to em)
- ♻️ **Parameter Renaming**:
  - Renamed: `font-color` Chinese alias `字色` → `字体颜色` (`\Style`, `\Paragraph`, `\SideNode`, etc.)
  - Renamed: `yoffset` → `yshift` (`\SideNode`, Chinese alias `纵偏` → `纵移`)
  - Renamed: `distribute` → `fill` (`\TextBox`, Chinese alias `均分` → `填充`)
  - Renamed: `font-name` → `font` (`\Content`, Chinese alias `字体名` → `字体`)
  - Improved: Paragraph `first-indent`/`bottom-indent` defaults to empty, automatically follows `indent` parameter
- 🐛 **Taitou Fixes**: Fixed numerous taitou indentation and line-breaking issues
- 🐛 **Judou Fix**: Fixed judou mode behavior inside jiazhu (interlinear notes)
- 🐛 **Banxin Fix**: Fixed single-page banxin processing
- 🐛 **Background Color Fix**: Fixed background color inheritance and override logic

## [0.2.8] - 2026-02-14

- ✨ **Free Layout Mode**: New automatic column width and flexible column spacing support
- ✨ **Style Command**: Added `\样式` command and `Style` environment for inline style overrides (font size, color, grid height, etc.)
- ✨ **Cover Feature**: Added `Cover` environment and volume/chapter name commands for ancient book covers
- ✨ **Command Renaming**: Document classes unified to `ltc-guji`, `ltc-cn-vbook`, `ltc-tw-vbook`; commands fully support English/simplified/traditional Chinese names
- 🐛 **Bug Fixes**: Improved modern traditional Chinese vertical typesetting; fixed footnote and heading layout issues
- ♻️ **Refactoring**: Major refactoring of layout-grid module, unified grid/natural engines, rewrote unit tests

## [0.2.7] - 2026-02-09

- ✨ **Modern Punctuation System**: Full modern punctuation support (squeeze, kinsoku line-breaking, vertical quote replacement) with mainland/Taiwan style options
- ✨ **ltc-book Document Class**: New `ltc-book` class for modern vertical Chinese book typesetting with template system (default/zhonghuashuju)
- ✨ **Footnote System**: Added `\Footnote` command with endnote and page-bottom modes, lujiao/circled numbering styles
- ✨ **Natural Layout Mode**: Added `layout-mode=natural` for non-uniform character spacing with half-grid punctuation and bottom-aligned columns
- ✨ **Flexible Column Widths**: `\Column` now supports `width` parameter for variable-width column layouts
- ✨ **Title Page Column Widths**: TitlePage supports `column-widths` parameter for flexible layouts
- 🐛 **Bug Fix**: Fixed content loss when `\newpage` follows auto-pagination at column end (fix #63)
- 🐛 **Bug Fix**: Fixed `\Space` command being skipped at column start (fix #62)
- 🐛 **Bug Fix**: Fixed `\挪抬` command trailing spaces producing extra whitespace
- ♻️ **Refactoring**: Split render-page.lua into two modules, reorganized regression tests into three suites

## [0.2.6] - 2026-02-07

- ✨ **Taitou Support**: Added `\抬头[N]` system (Single/Double/Triple/Flat/Relative Taitou) with automatic border wrapping
- ✨ **Proper Name/Book Title Marks**: Re-implemented using PDF graphics, solving connectivity and font compatibility issues (fix #53, #56, #57)
- ✨ **Jiazhu Balance Control**: Added `auto-balance` option for non-balanced layouts
- 🐛 **Glyph Rotation Fix**: Added automatic 90° rotation for ellipsis and em dash when font lacks vertical forms
- 🐛 **Bug Fix**: Fixed sidenote color leakage across page boundaries (fix #44)
- 🐛 **Bug Fix**: Fixed jiazhu column switching logic


## [0.2.5] - 2026-02-05

- ✨ **Catalog Entry Command**: Added `\条目` command with hierarchical indentation for table of contents
- ✨ **Column Control Commands**: Added `\列` (Column) and `\末列` (LastColumn) commands for better layout control (fix #30)
- 🐛 **Bug Fix**: Fixed decoration underlines (专名号/书名号) not drawn on last character at column end (fix #54)
- 🐛 **Bug Fix**: Fixed character centering offset for some characters (e.g., "漢"), main text now uses width-based centering (fix #55)
- 🐛 **Bug Fix**: Fixed sidenote color leakage to banxin when crossing page boundaries (fix #48)

## [0.2.4] - 2026-02-03

- ✨ **Underline Support**: Added `\Underline` / `\下划线` commands, implemented with the `|` character (fix #5)
- ✨ **Book Title & Proper Name Marks**: Added `\书名号` (wavy line) and `\专名号` (straight line) commands (fix #16)
- 🐛 **Bug Fix**: Fixed sidenote column alignment when switching columns (fix #47)
- 🐛 **Bug Fix**: Fixed sidenote going to second column when crossing pages (fix #49)
- 🐛 **Bug Fix**: Fixed jiazhu alignment issue (fix #51)
- 🐛 **Bug Fix**: Fixed `\newgeometry` not supporting paperwidth/paperheight (fix #52)
- 🐛 **Bug Fix**: Fixed sidenote color leakage causing banxin to turn red when crossing pages

## [0.2.3] - 2026-02-01

- ✨ **MeiPi (Marginal Notes)**: Added `\眉批` command with auto-positioning and manual coordinate support (fix #46)
- ✨ **Special TextBox**: TextBox frame feature with border shape customization (fix #25)
- ✨ **Publisher Display**: Added publisher display below banxin with customizable font (fix #26)
- 🐛 **Bug Fix**: Fixed annotation and textbox incorrectly inheriting paragraph indentation (fix #37)
- 🐛 **Bug Fix**: Fixed MeiPi appearing on wrong page when crossing page boundaries
- 🐛 **Bug Fix**: Fixed font detection support for simplified/traditional Chinese names (fix #35)
- ♻️ **Refactoring**: Refactored border style system with style stack management for border, outer_border attributes

## [0.2.2] - 2026-01-31

- 🐛 **Bug Fix**: Fixed preamble chapter display on first page (fix #45)
- 🐛 **Bug Fix**: Fixed jiazhu column jumping at column end (fix #42)
- ✨ **Judou Enhancement**: Support for more Chinese punctuation symbols (fix #40)
- 🐛 **Bug Fix**: Fixed TextBox and annotation inheriting paragraph indent (fix #37)
- ✨ **Debug Feature**: Added debug ruler showing page grid coordinates (fix #31)
- ✨ **Font Detection**: Support simplified/traditional Chinese font names (fix #35)
- ♻️ **Refactoring**: Consolidated banxin text rendering logic
- ♻️ **Refactoring**: Moved title/publisher commands to metadata.sty
- ✅ **Module Cleanup**: Cleaned up banxin, guji, yinzhang module dependencies

## [0.2.1] - 2026-01-31

- ✨ **Color Preservation**: Sidenote color preservation across pages (fix #38, #44)
- ✨ **Style Stack Architecture**: Implemented Phase 3 style stack for multi-attribute support
- ✨ **Style Registry**: Phase 2 multi-attribute style storage (color, font_size, grid_height)
- 🐛 **Bug Fix**: Fixed sidenote rendering order, now correctly displays above silk columns (fix #38)
- 🐛 **Bug Fix**: Punctuation mode now correctly applies to sidenote content (fix #39)
- ♻️ **Jiazhu Migration**: Migrated jiazhu functionality to style stack architecture
- ♻️ **Refactoring**: Unified color registration mechanism

## [0.2.0] - 2026-01-31

- ✨ **Plugin Architecture**: Refactored to standardized plugin API for consistent component behavior
- ✨ **Global State Management**: Unified configuration via global tables for all modules
- ✨ **Metadata System**: Centralized book metadata management (title, publisher, chapter markers)
- ♻️ **Module Namespace**: Clear separation of core/, guji/, banxin/, util/, decorate/
- ♻️ **Major Refactoring**: Plugin system refactoring with standardized module interfaces

## [0.1.5] - 2026-01-28

- ✨ **Multi-font Support**: Added multi-font fallback chain and Chinese font setting commands (fix #23).
- ✨ **New Features**: Implemented `\decorate` and `\fix` functionalities, supporting vertical typesetting correction marks (fix #12).
- ✨ **Textbox Enhancements**: Textbox supports vertical compression (flattening) to fit grid positions (fix #24).
- 🐛 **Bug Fixes**: Fixed layout bugs including 0pt dimension parsing error, Judou positioning offsets, and long title squeezing (fix #19, #20).
- ✅ **Regression Tests**: Introduced automated regression testing program based on PDF rendering comparison.
- ♻️ **Refactoring**: Refactored core rendering logic and improved overall code stability.

## [0.1.4] - 2026-01-27

- ✨ Added Judou (punctuation marks) functionality
- 🐛 Fixed paragraph indentation and side note column switching issues
- ♻️ Major code refactoring for better readability and maintainability
- ✅ Added more test files

## [0.1.3] - 2026-01-25

- 🐛 Fixed inaccurate page breaks and page number positioning
- ✨ Annotation coordinates now more accurate, skipping page center to prevent clipping
- 📚 Completely typeset Dream of the Red Chamber (Jiaxu manuscript) Chapter 1
- ♻️ Better compliance with Expl3 syntax
- ✅ Added l3build test files for regression testing
- ✅ Established comprehensive Lua unit testing framework with `l3build test` command support
- 🐛 Completely fixed Mock logic and API inconsistency issues in unit tests

## [0.1.2] - 2026-01-22

- ♻️ Renamed src to tex
- 🐛 Completely fixed CRLF and BOM character issues on Windows
- 📦 Adopted l3build, see build.lua
- 🐛 Fixed package require paths to ensure release version works out of the box

## [0.1.1] - 2026-01-19

### Features
- ✨ Added annotation command, still using floating text box underneath

### Fixes
- 🐛 Fixed CRLF and BOM character issues on Windows

### Documentation
- 📖 Updated documentation with bilingual support

## [0.1.0] - 2026-01-18

### Major Features
- **Native Geometric Vertical Typesetting Engine**: Deep Lua customization with grid layout system designed for ancient book typesetting
- **Traditional Book Core Elements**: Complete support for Banxin (page center), Yuwei (fishtail), and traditional silk frames
- **Comprehensive Annotation System**: Flexible interlinear notes and side note functionality
- **Ready-to-use Template System**: Preset visual styles including Siku Quanshu and Dream of the Red Chamber manuscripts
- **Cross-platform Font Auto-detection**: Smart recognition of Windows, macOS, and Linux system fonts
- **Electronic Scroll/Traditional Page Support**: Traditional "tube page" logic and electronic reading adaptation
- **Absolute Positioning Seal System**: Support for placing collection seals anywhere on the page

### Project Infrastructure
- Automated CTAN packaging and release workflow
- Comprehensive bilingual user manuals and multiple classic ancient book reproduction examples
