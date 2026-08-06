English | [中文版](Home)

# LuaTeX-CN Wiki

Welcome to the LuaTeX-CN Wiki. This site provides comprehensive documentation for users and developers to help you create high-quality Chinese typesetting with LuaTeX-CN — classical vertical books, modern vertical books, and clreq-conformant horizontal documents.

> **Current Version**: [v0.4.0](https://github.com/open-guji/luatex-cn/releases) | **CTAN**: [v0.4.0](https://ctan.org/pkg/luatex-cn)

## Quick Access

- 🚀 [[Quick Start | EN:Quick-Start]] - Get started with your first project in 5 minutes
- 📦 [[Installation | EN:Installation]] - Install LuaTeX-CN on your system
- 📚 [[Examples | EN:Examples]] - Explore "Records of the Grand Historian" (Shiji) and "Dream of the Red Chamber"

## Documentation

### 1. Fundamentals
- [[Templates & Format | EN:Templates]] - Understand the "Banxin" (Page Center) concept
- [[Font Setup | EN:Fonts]] - Config Chinese fonts and fallback chains
- [[Layout Control | EN:Features]] - Chapters, TOC entries, and fine-grained layout control

### 2. Writing Modes
**Vertical — four document classes**
- [[guji (Ancient Books) | EN:Quick-Start]] - Traditional vertical typesetting (default class)
- [guji-digital](https://github.com/open-guji/luatex-cn/tree/main/test/digital_test) - Digitization mode: one source line = one vertical column, for reproducing a source edition's page layout exactly
- [[cn-vbook / tw-vbook (Modern Books) | EN:ltc-book]] - Modern vertical books with punct squeeze and footnotes

**Horizontal — one package**
- [[\usepackage{luatex-cn} (horizontal) | EN:Horizontal]] - Modern horizontal Chinese per W3C clreq: CJK–Western spacing, four kinsoku levels, per-line compression/stretch, interlinear marks and ruby, paragraph and widow control. Loads on top of `article` and friends — it is a package, not a class
- [clreq conformance matrix](https://github.com/open-guji/luatex-cn/blob/main/docs/CLREQ-CONFORMANCE.md) - per-clause status for both directions, with evidence and documented deviations

### 3. Punctuation & Judou
- [[Punctuation System | EN:Punctuation]] - Modern punct styles (mainland/Taiwan), squeeze, kinsoku
- [[Judou | EN:Judou]] - Classical Chinese punctuation (judou/plain/normal modes)

### 4. Specialized Commands
- [[Interlinear & Side Notes | EN:Side-Note]] - Detailed usage of jiazhu and side notes
- [[Annotations & Marginal Notes | EN:Annotation]] - Floating annotations and marginal notes (MeiPi)
- [[Decorations | EN:Correction]] - Underlines, book titles, and correction marks
- [[Elevation | EN:Taitou]] - Honorific elevation formatting

### 5. Advanced Features
- [[Text Boxes | EN:Textbox]] - Absolute positioning and adaptive containers
- [[Seals | EN:Seal]] - Adding and positioning electronic seals
- [[Debugging | EN:Debug]] - Grid visualization and layout debugging

---

## Developers

For information on contributing or understanding the internal architecture:
- [[Development Guide | EN:Development]]
- [[Release Process | EN:Release]]

---

## Contact

- **Contact**: Sheldon Li
- **Email**: sheldonli.dev@gmail.com
