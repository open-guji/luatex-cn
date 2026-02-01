English | [中文版](Annotation)

# Annotations (PiZhu / 批注)

The `\批注` command allows placing floating annotation boxes anywhere on the page, simulating post-publication notes or commentaries in ancient manuscripts.

## Usage

```latex
\批注[x=5cm, y=2cm, height=6, color={1 0 0}]{Annotation content}
```

## Parameters

- `x`: Horizontal position of the top-left corner (relative to page center).
- `y`: Vertical position of the top-left corner (relative to page center).
- `height`: Number of grid rows (height) allocated for the box.
- `color`: Color in RGB format (e.g., `{1 0 0}` for red).
- `font-size`: Font size inside the annotation.
- `grid-width`: Custom grid cell width for the box.
- `grid-height`: Custom grid cell height for the box.

## Features

- **Absolute Positioning**: Does not occupy main body space; overlaid directly at specified coordinates.
- **Auto-Columnizing**: If content exceeds the set `height`, it automatically starts a new column within the box.
- **Clip Prevention**: Position calculations account for Banxin (page center) to prevent content being cut off by borders.
- **Multi-column Support**: Internal columns can be precisely controlled via `n-cols`.
- **Independent Indentation** (v0.2.2+): Annotation content no longer inherits paragraph indentation from main text (fix #37).

## Technical Implementation
Under the hood, annotations are based on `core_textbox.lua`. Content is rendered into an independent vertical grid system. This produced box is then overlaid during the page rendering stage using `shipout` logic in `render_page.lua`.

---

👉 Next Steps: Check [[Seals | EN:Seal]] or [[Judou | EN:Judou]].
