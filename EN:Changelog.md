English | [中文版](Changelog)

# Changelog

All notable changes to this project will be documented here.

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
