English | [中文版](Side-Note)

# Interlinear & Side Notes

`luatex-cn` offers a comprehensive annotation system, including in-text interlinear notes and marginal side notes.

## Interlinear Notes (Jiazhu / 夹注)

Commonly seen in ancient books as double-line small characters between main body text.

### Usage
```latex
Main text\\夹注{This is interlinear note content. If it is long, it will automatically split into two columns and balance their lengths.}continued text.
```

### Key Features
- **Auto-Balancing Algorithm**: The system calculates the remaining space in the current column and splits the note content evenly into right and left sub-columns.
- **Cross-Column/Page Flow**: When a note doesn't fit in one column, it flows to the next column or page automatically.
- **Alignment Control**: Supports `left`, `right`, `center`, `inward`, and `outward` (default) alignment modes.
- **Balance Control (v0.2.6+)**: Use `auto-balance=false` to disable the automatic balancing algorithm. Useful for manual line breaks or replicating specific historical manuscript styles.

### Jiazhu Configuration
```latex
\jiazhuSetup{
  font-size = 12pt,
  font = {FandolSong-Regular},
  font-color = red,
  auto-balance = true, % Whether to auto-balance sub-column lengths
  align = outward      % Alignment mode
}
```


---

## Side Notes (SideNode / 侧批)

Small annotations placed between text columns or at page margins.

### Usage

Three syntax options:
```latex
% Basic usage
Main text\\侧批{This is the side note content}continued text.

% Positional parameter (auto-converts to em)
Main text\\侧批[5pt]{Note with adjusted height}continued text.
Main text\\侧批[0.5]{Equivalent to 0.5em}continued text.

% Named parameters
Main text\\侧批[yshift=10pt, color=red]{Both color and position}continued text.
```

### Parameters
- `yshift`: Vertical offset with positional parameter support. Pure numbers auto-convert to em units (e.g., `0.5` → `0.5em`).
- `xshift` <sup>v0.3.5+</sup>: Horizontal offset (default: 0pt).
- `color`: Annotation color (default: red).
- `font-size`: Font size for the note (default: 10pt).
- `grid-height`: Custom grid height for the note block (default: equals font size).
- `border-padding-top`: Top border padding (default: 0pt).
- `border-padding-bottom`: Bottom border padding (default: 0pt).

### Global Configuration
```latex
\sidenoteSetup{
  color = red,
  font-size = 19pt,
  grid-height = 20pt,
  xshift = 0pt,   % Horizontal offset (v0.3.5+)
  yshift = 0em,
  border-padding-top = 0.5em,
  border-padding-bottom = 0.5em
}
```

### Side Note Toggle <sup>v0.3.6+</sup>

Use `sidenote=false` to globally disable side note rendering (content is preserved but not drawn), useful for viewing body text layout only:
```latex
\sidenoteSetup{sidenote=false}  % Globally disable side notes
```

### Component-Level Punctuation Mode <sup>v0.3.5+</sup>

Side notes can use a different punctuation mode independent of the global setting:
```latex
% Side note uses judou mode (while global may be normal)
\Sidenote[punct-mode=judou]{note content}

% Or configure globally
\GlobalSettings{punct-mode=judou}
```

### Aliases
- Setup command: `\sidenoteSetup` / `\CePiSetup` / `\侧批设置` (Simplified) / `\側批設置` (Traditional)
- Vertical shift parameter: `yshift` / `纵移` (Simplified) / `縱移` (Traditional)
- Horizontal shift parameter: `xshift` / `横移` (Simplified) / `橫移` (Traditional)

### Cross-Page Color Preservation (v0.2.1+)
v0.2.1 introduced the style registry mechanism. Side note color settings now persist correctly across pages. Even when side note content spans multiple pages, colors remain consistent.

---

## Jiazhu Shortcut <sup>v0.3.4+</sup>

The `\jiazhuShortcut` command registers a bracket pair so that matching brackets in source code are automatically replaced with `\夹注{...}`, simplifying input when there are many interlinear notes.

### Usage

```latex
% Default: 【...】 becomes \夹注{...}
\jiazhuShortcut

% Custom bracket pair
\jiazhuShortcut{（}{）}

% With style parameters: all shortcuts use the specified style
\jiazhuShortcut[font-color=red, font-size=9pt]{（}{）}
```

### Effect

After registration, this source code:
```latex
Main text【annotation content】continued text
```
is equivalent to:
```latex
Main text\夹注{annotation content}continued text
```

### Aliases

| English | Simplified | Traditional |
|---------|------------|-------------|
| `\jiazhuShortcut` | `\夹注捷径` | `\夾注捷徑` |

### Notes

- Based on `process_input_buffer` preprocessing (text replacement before TeX parsing)
- Multiple bracket pairs can be registered simultaneously
- Optional parameters support all jiazhu parameters (font-size, font, color, align, etc.)

---

## Technical Implementation (For Developers)
- **Interlinear Notes**: Uses LuaTeX attributes to mark nodes. During layout, the system detects these attributes, pauses normal typesetting, and calls `core_textflow.lua` for column splitting and re-mapping to the grid. Migrated to style stack architecture since v0.2.1.
- **Side Notes**: Managed by `core_sidenote.lua`. It captures the content as an independent box and calculates the offset based on the current reference character's coordinates. Supports Phase 2 style registry for color preservation since v0.2.1.
- **Style Registry**: `luatex-cn-style-registry.lua` provides multi-attribute style storage, supporting deduplication and cross-page preservation for color, font_size, grid_height, and other attributes.

---

👉 Next Steps: Check [[Annotations | EN:Annotation]] or [[Judou | EN:Judou]].
