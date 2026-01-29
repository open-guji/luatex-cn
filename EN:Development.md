English | [中文版](Development)

# Development Documentation

This document summarizes the core design philosophy, modular architecture, and the complete development workflow for the `luatex-cn` typesetting engine.

## 1. Core Architecture: Three-Layer Design

`luatex-cn` utilizes a three-layer architecture to decouple layout logic from rendering:

1. **LaTeX Interface Layer (`.sty`, `.cls`)**: Defines user commands; sets attributes and parameters via `luatexbase`.
2. **Coordination Layer (`core_*.lua`)**: Manages logic flow. For instance, `core_main` orchestrates the main process, while `core_textflow` handles interlinear note splitting.
3. **Processing Layer (`layout_*.lua`, `render_*.lua`)**:
   - **Flattening**: Converts TeX node lists into linear Lua tables.
   - **Layout**: Calculates grid coordinates for each character and its associated elements.
   - **Rendering**: Reassembles content based on coordinates and outputs PDF instructions.

## 2. Participating in Development

We welcome contributions and Pull Requests (PRs).

### 2.1 Fork & Workflow
1. **Fork the Repo**: Click the Fork button on GitHub.
2. **Clone**: Clone your forked repository locally.
3. **Coding**: Main source code is located in the `tex/` directory.

> [!TIP]
> VS Code with LaTeX Workshop is recommended for development.

### 2.2 Testing

Please ensure all tests pass before submitting a PR.

1. **Install Dependencies**: You need `l3build` installed.
2. **Unit Tests**:
   Run Lua unit tests:
   ```bash
   l3build test
   ```
   This invokes `test/run_all.lua`.

3. **Regression Tests**:
   We use automated regression testing based on PDF rendering comparison to prevent layout regressions.
   ```bash
   l3build check
   ```
   This compiles `.lvt` files in `testfiles/` and compares the output logs (`.tlg`) against baselines. If your changes affect layout, ensure these pass. If layout changes are intentional, update baselines:
   ```bash
   l3build save test-name
   ```

### 2.3 Release
For release procedures, please refer to [[Release | EN:Release]].

## 3. Key Technical Details

### Vertical Direction (RTT)
Leverages LuaTeX's `dir RTT` attribute. In RTT mode, text flows top-to-bottom, and lines stack right-to-left.

### Attribute Management
Uses LuaTeX attributes to pass metadata across languages (e.g., "this glyph belongs to an interlinear note").
> [!WARNING]
> \selectfont clears all active attributes. Ensure attributes are reset AFTER setting the font size.

### Node Ownership
Passing nodes to TeX via `tex.box[n] = node` transfers ownership. Use `node.copy_list()` if you need to reuse nodes.

## 4. Development Lessons (LEARNING)
- **Color Commands**: Must use normalized RGB (e.g., `0 0 0 rg`), not names.
- **Rendering Order**: PDF follows the "painter's model"—later content overlays earlier content. Insert backgrounds at the head of the list to ensure they are at the bottom.
- **Module Loading**: Standardize on `require()` and utilize `package.loaded` for caching.
