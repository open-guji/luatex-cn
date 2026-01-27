English | [中文版](Development)

# Development Documentation

This document summarizes the core design philosophy and modular architecture of the `luatex-cn` typesetting engine.

## 1. Core Architecture: Three-Layer Design

`luatex-cn` utilizes a three-layer architecture to decouple layout logic from rendering:

1. **LaTeX Interface Layer (`.sty`, `.cls`)**: Defines user commands; sets attributes and parameters via `luatexbase`.
2. **Coordination Layer (`core_*.lua`)**: Manages logic flow. For instance, `core_main` orchestrates the main process, while `core_textflow` handles interlinear note splitting.
3. **Processing Layer (`layout_*.lua`, `render_*.lua`)**:
   - **Flattening**: Converts TeX node lists into linear Lua tables.
   - **Layout**: Calculates grid coordinates for each character and its associated elements.
   - **Rendering**: Reassembles content based on coordinates and outputs PDF instructions.

## 2. Key Technical Details

### Vertical Direction (RTT)
Leverages LuaTeX's `dir RTT` attribute. In RTT mode, text flows top-to-bottom, and lines stack right-to-left.

### Attribute Management
Uses LuaTeX attributes to pass metadata across languages (e.g., "this glyph belongs to an interlinear note").
> [!WARNING]
> \selectfont clears all active attributes. Ensure attributes are reset AFTER setting the font size.

### Node Ownership
Passing nodes to TeX via `tex.box[n] = node` transfers ownership. Use `node.copy_list()` if you need to reuse nodes.

## 3. Development Lessons (LEARNING)
- **Color Commands**: Must use normalized RGB (e.g., `0 0 0 rg`), not names.
- **Rendering Order**: PDF follows the "painter's model"—later content overlays earlier content. Insert backgrounds at the head of the list to ensure they are at the bottom.
- **Module Loading**: Standardize on `require()` and utilize `package.loaded` for caching.

---

👉 For more details, refer to `ai_must_read/LEARNING.md` in the source repository.
