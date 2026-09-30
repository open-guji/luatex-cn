English | [中文版](Changelog)

# Changelog

All notable changes to this project will be documented here.

## [0.4.2] - 2026-09-30

- 🐛 **Annotations after taitou**: notes following `\抬头`/`\平抬`/`\单抬` no longer jump to the column head or fall into the top margin; the forced taitou indent no longer leaks into later annotations. `\单抬` *inside* an annotation still protrudes into the top margin (#165)
- 🐛 **Two consecutive body blocks**: two `正文` environments on the same page no longer overprint each other (no more 「一」 and 「二」 in the same banxin) and no longer raise `\prevdepth` errors; two-column parallel layouts using `分栏` + `\换栏` still share one page (#165)
- 🐛 **Banxin page-number style**: `\pageSetup{页码样式=digits}` (`digits`/`chinese`/`arabic`/`none`) now takes effect on banxin page numbers, sharing one formatter with vertical page numbers; the initial value is now "unset", so `\pageSetup{纸宽=...}` no longer switches banxin page numbers off as a side effect (#161)
- 🐛 **`\pageSetup` after `\disableSplitPage`**: the paper width is no longer halved and the page count no longer doubled; no extra blank page when called after `\begin{document}`. `\pageSetup` no longer sets `\topskip` unconditionally, so a `\topskip` set in the body is kept (#166)
- 🐛 **Horizontal CJK–Western spacing**: Western-only lines in fonts whose space is narrower than 1/4 em (e.g. Source Sans 3) no longer overflow the text block (#171); `/` `-` `·` `–` in strings like `1/4 em` or `a/b` are treated as Western half-width punctuation and no longer get 1/4em on both sides (#160)
- 🐛 **Judou color**: judou marks are no longer drawn in the body-text color in the colored Siku Quanshu template; `\句读设置{句读颜色=...}` now actually works (#157)
- 🐛 **Color key aliases and warnings**: `color`/`颜色` and `font-color`/`字体颜色` are interchangeable across jiazhu, textflow, line, textbox, judou, pizhu, meipi and sidenote; `\夹注设置{color=red}` no longer does nothing or recolors the whole text. Unknown keys now raise a warning instead of being silently dropped (#163)
- ♻️ **Faster large books**: scaled fonts for banxin vertical text are cached by (font, size). 《欽定儀象考成》(875 pages): 170s → 141s, output PDF byte-identical (fix #167, #172)
- ✅ **Tests**: new color-key self-check `test/color_test.py`, extra clreq assertions for CJK–Western spacing

## [0.4.1] - 2026-08-07

- 🐛 **No more hyphenated Western words in annotations/TextBox**: TextBox no longer lets TeX pre-break collected content (the old logic split English in annotations into S-/tate and misaligned columns); column breaking is now entirely handled by the grid engine. In grid mode (fixed cell height, e.g. `ltc-guji`), `\Sideways` now sizes glyphs by their advance width so rotated words set contiguously (fix #50)
- 📦 **CTAN packaging fixes** per CTAN review: upload renamed to `luatex-cn-v<version>.zip`, single top-level directory `luatex-cn/` on unpack, `README.md` at the package top level with an English abstract; the local build, CI release asset and CTAN upload are now one and the same file
- 📖 **Slimmer wiki PDFs**: example previews downsampled to 300 dpi and embedded as 64-color indexed images, emoji embedded as a monochrome vector font subset — zh 4.8→2.7 MB, en 4.3→1.8 MB

## [0.4.0] - 2026-08-06

Major clreq release: unified entry point `\usepackage{luatex-cn}`, a complete horizontal clreq pipeline, vertical clreq conformance (P1-P3), a shared rules kernel for both directions, a conformance declaration matrix backed by 119 metric assertions, and installation-free fonts.

Added:
- ✨ **Unified entry point**: `\usepackage{luatex-cn}` is now the single entry for everything - by default it loads the horizontal clreq pipeline (options pass through, e.g. `[style=taiwan]`); `[vertical]` or banxin-style keys load the vertical bundle (0.3.x semantics unchanged); under an ltc-* class it automatically takes the vertical branch (#148)
- ✨ **Horizontal clreq pipeline** (luatex-cn-hori): CJK-Western spacing of 1/4 em (compressible to 1/8, stretchable to 1/2, with the three clreq exceptions), punctuation width adjustment with Mainland/Taiwan/none presets, quote style conversion, four-level line-break prohibition plus inseparability rules, second-pass intra-line compression/stretch in clreq priority order, half-width line-end punctuation, hanging punctuation, and even distribution (#127-#131)
- ✨ **Horizontal interlinear marks**: `\专名` / `\书名号甲` / `\着重` (adjacent marks shrink 1/16 em on each side; no emphasis dots on punctuation), and `\拼音` / `\对照` word-aligned ruby (#129)
- ✨ **Horizontal paragraph and page level**: avoidance of single-character last lines, widow/orphan control, hanging-indent and indent environments, four last-line alignments, and traditional type sizes via `\字号` (shared with vertical) (#131)
- ✨ **All three vertical mixed-script configurations** (clreq P3): 1/4 em CJK-Western spacing wired into the solver; `\横置` rotates a Western string 90 degrees clockwise into the column; `\中横排` squeezes a short string (two-to-three digits etc.) horizontally into a single character cell (tate-chu-yoko) (#146, #147, #149)
- ✨ **Vertical hanging punctuation** (clreq 6.1.3): `\标点设置{punct-hanging=true}` hangs a column-final stop outside the text area; off by default
- ✨ **Vertical emphasis dots per clreq 5.3.1**: the two vbook classes default to solid dots `●` with no dots on punctuation; `\着重号设置` gains `char` / `scale` / `skip-punct` keys; ltc-guji keeps the classical circle convention
- ✨ **Shared clreq rules kernel** `tex/shared/`: the full punctuation table, the intra-line space allocation solver, four-level prohibition rules, and ink anchors - a single data source for both directions, pure Lua, unit-testable with texlua (#125)
- ✨ **clreq conformance matrix** [docs/CLREQ-CONFORMANCE.md](https://github.com/open-guji/luatex-cn/blob/main/docs/CLREQ-CONFORMANCE.md): per-clause status for both directions with evidence, documented intentional deviations, and not-implemented items with rationale
- ✨ **clreq assertion tests**: 119 metric assertions parsed from PDF content streams (per-glyph x coordinates horizontally, per-column baseline distances vertically), running in CI (#128)
- ✨ **Installation-free fonts**: `\设置字体族` accepts registry aliases and file paths; `download_fonts.py --user/--dest` installs without admin rights; SHA-256-pinned font manifest (#109, #122, #123)
- ✨ **Geometry self-check tests**: assert equal baseline spacing per column straight from the PDF, catching whole-glyph offsets without baseline images (#113)
- ✨ **Example "论辩的魂灵"** (Lu Xun): a real-world document for the horizontal clreq pipeline

Changed:
- ♻️ **Vertical layout now uses the shared intra-line solver** (clreq P2): 7 compression levels / 2 stretch levels plus a fallback, prohibition resolution by lexicographic comparison; digit runs, Western words and two-width punctuation locked as rigid units; all three ltc-guji baselines unchanged (#143)
- ♻️ **Context-sensitive vertical punctuation width**: a lone punctuation mark keeps its full cell; only consecutive marks compress. vbook classes default to `squeeze-mode=context`; ltc-guji keeps legacy unconditional squeezing
- ♻️ **Metrics-driven punctuation ink placement**: glyph bounding boxes anchor the ink to the style's canonical position (Mainland/Taiwan x horizontal/vertical), so the font's own glyph design no longer shifts layout
- ♻️ **`\标点设置` unified with the horizontal backend**: new `style` / `squeeze-mode` / `adjacent-punct` / `line-start-bracket` / `line-end-punct` keys

Fixed:
- 🐛 **Vertical inline-note bracket ink in the correct half-cell** (clreq 6.3.2.1), anchored by ink-center offset and consistent across four fonts (fix #105)
- 🐛 **Em dashes / ellipses as rigid two-cell units**: never split across columns, zero internal spacing so consecutive dashes join into one stroke; ccmp ligatures decomposed back to em dashes (fix #119)
- 🐛 **Footnote label geometry**: labels excluded from punctuation width adjustment; brackets scaled and centered on real ink; Chinese numerals up to thousands
- 🐛 **In-cell vertical centering now uses the em-box baseline**, fixing whole-glyph offsets for characters like 一 and 丶 whose ink does not cross the baseline (#113)
- 🐛 Others: decoration mark misplacement (#118), digital-mode empty left sub-column (#120), column-break guard (#108), `os.name` platform detection (#100), `run_all.lua` swallowing failures (#121)

Maintenance:
- ✅ Tests and examples moved entirely to verifiably-licensed open fonts; pixel-exact zero-tolerance regression baselines; CI runs unit + regression tests on every PR (#101, #106-#117)

## [0.3.8] - 2026-05-09

New gongche notation commands, tone-mark decorations, side note background color, and multiple sidenote/layout fixes.

- ✨ **Gongche Notation**: New `\音[ban/yan/high/low/kunlow]{note}` main commands, `\拖音` sustain/continuation unit, judou and gongdiao annotations, supporting full traditional Chinese musical notation layout (#90)
- ✨ **Tone-Mark Circles**: New `\发圈` / `\圈发` commands, adding tonal corner-circle decorations based on level/rising/departing/entering tones (fix #92)
- ✨ **Side Note Background**: `\侧批` adds `background-color` parameter (CN alias `底色` / `背景色`) to mask underlying column borders; special values `page` / `inherit` / `继承` / `页面` inherit the page background (#93)
- 🐛 **Side Note Wrapping & Taitou Alignment**: Fixed reverse-flow wrapping, taitou column alignment with body text top, and bottom-anchor auto-wrap (fix #91)
- 🐛 **Reverse-Flow Boundary**: page 0 / banxin column fallback fixes; extracted `wrap_to_next_column` helper to eliminate duplicated wrap logic (review #97)
- 🐛 **Floating Textbox Empty Page**: anchor marks `page_has_content`, preventing pages with only floating textboxes from being misidentified as empty (fix #98)
- 🐛 **Page-Fill Table Inner Border**: Lost left inner border on starting page — fixed by distinguishing `actual_band_cols` per page
- 🐛 **Illustration Page Full-Page Suppression**: Silk-frame suppression extends to both half-pages when no real text content exists on the entire page

## [0.3.7] - 2026-04-25

Table enhancements, sidenote API redesign, and multiple jiazhu/textbox fixes.

- ✨ **Table Enhancements**: Cross-page tables, customizable column rules; new `row-fill=half-page` mode
- ✨ **Sidenote API Redesign**: `\旁注{main}{right}{left?}` — supports `\文本框` content, spacing adapts to main character size (fix #94)
- ✨ **Guji `ignore-spaces` Option**: New option, default ignores source spaces
- ✨ **Banxin Page Number Toggle**: Added display toggle
- 🐛 **Textbox in Jiazhu**: Octagon size/alignment/vertical/sub-column x offset issues (fix #96)
- 🐛 **Parallel Mode Cross-Page Table**: Preserves band structure and horizontal rules, tight cell layout, cell-level column borders don't leak to overflow page
- 🐛 **Textbox Line Height & Space**: Inner line height uses outer grid height, fixes body `\octagon{}` overflow; trailing space after textbox occupies wrong row count
- 🐛 **Judou Column Wrap Position**: Marker mislocated to old column when wrapping
- 🐛 **Style Font Application**: `\样式[字体=X]` without size now applies font to TeX layer
- 🐛 **Fill Mode Padding**: Double-application of `padding_top`
- ♻️ **Chapter Manual Newline**: Switched to `\夹注` to adapt to TextBox rendering mode

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
