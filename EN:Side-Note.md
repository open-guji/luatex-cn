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

---

## Side Notes (SideNode / 侧批)

Small annotations placed between text columns or at page margins.

### Usage
```latex
Main text\\侧批[yoffset=10pt, color=red]{This is the side note content}continued text.
```

### Parameters
- `yoffset`: Vertical offset for fine-tuning positions.
- `color`: Annotation color (default: red).
- `font-size`: Font size for the note.
- `grid-height`: Custom grid height for the note block.
- `border-padding-top`: Top border padding.
- `border-padding-bottom`: Bottom border padding.

### Global Configuration
```latex
\sidenoteSetup{
  color = red,
  font-size = 19pt,
  grid-height = 20pt,
  yoffset = 0em,
  border-padding-top = 0.5em,
  border-padding-bottom = 0.5em
}
```

### Cross-Page Color Preservation (v0.2.1+)
v0.2.1 introduced the style registry mechanism. Side note color settings now persist correctly across pages. Even when side note content spans multiple pages, colors remain consistent.

---

## Technical Implementation (For Developers)
- **Interlinear Notes**: Uses LuaTeX attributes to mark nodes. During layout, the system detects these attributes, pauses normal typesetting, and calls `core_textflow.lua` for column splitting and re-mapping to the grid. Migrated to style stack architecture since v0.2.1.
- **Side Notes**: Managed by `core_sidenote.lua`. It captures the content as an independent box and calculates the offset based on the current reference character's coordinates. Supports Phase 2 style registry for color preservation since v0.2.1.
- **Style Registry**: `luatex-cn-style-registry.lua` provides multi-attribute style storage, supporting deduplication and cross-page preservation for color, font_size, grid_height, and other attributes.

---

👉 Next Steps: Check [[Annotations | EN:Annotation]] or [[Judou | EN:Judou]].
