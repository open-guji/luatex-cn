English | [中文版](Changelog)

# Changelog

All notable changes to this project will be documented here.

## [0.2.5] - 2026-02-05

- ✨ **Catalog Entry Command**: Added `\条目` command with hierarchical indentation for table of contents
- ✨ **Column Control Commands**: Added `\列` (Column) and `\末列` (LastColumn) commands for better layout control (fix #30)
- 🐛 **Bug Fix**: Fixed decoration underlines (专名号/书名号) not drawn on last character at column end (fix #54)
- 🐛 **Bug Fix**: Fixed character centering offset for some characters (e.g., "漢"), main text now uses width-based centering (fix #55)
- 🐛 **Bug Fix**: Fixed sidenote color leakage to banxin when crossing page boundaries (fix #48)

## [0.2.4] - 2026-02-03

- ✨ **Underline Support**: Added `\Underline` / `\下划线` commands (fix #5)
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
