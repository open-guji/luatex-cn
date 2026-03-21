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

## Toggle Control <sup>v0.3.6+</sup>

Both PiZhu and MeiPi support `pizhu=false` / `meipi=false` toggles in Setup or per-call to disable rendering:
```latex
\pizhuSetup{pizhu=false}  % Globally disable PiZhu
\meipiSetup{meipi=false}  % Globally disable MeiPi
```

## Features

- **Absolute Positioning**: Does not occupy main body space; overlaid directly at specified coordinates.
- **Auto-Columnizing**: If content exceeds the set `height`, it automatically starts a new column within the box.
- **Clip Prevention**: Position calculations account for Banxin (page center) to prevent content being cut off by borders.
- **Multi-column Support**: Internal columns can be precisely controlled via `n-cols`.
- **Independent Indentation** (v0.2.2+): Annotation content no longer inherits paragraph indentation from main text (fix #37).

## Technical Implementation
Under the hood, annotations are based on `core_textbox.lua`. Content is rendered into an independent vertical grid system. This produced box is then overlaid during the page rendering stage using `shipout` logic in `render_page.lua`.

---

# Marginal Notes (MeiPi / 眉批) <sup>v0.2.3+</sup>

The `\眉批` command places annotations at the top of the page (above the main text), a common format in traditional Chinese book annotations. Unlike `\批注`, MeiPi automatically calculates positions, arranging from right to left to avoid overlap.

## Usage

```latex
% Auto-positioning (recommended)
\眉批[height=5]{Marginal note content}

% Manual Y coordinate
\眉批[height=5, y=50pt]{Marginal note content}

% Fully manual positioning
\眉批[height=5, x=100pt, y=50pt]{Marginal note content}
```

## Parameters

- `height`: Number of grid rows (height) for the note, **required**.
- `x`: Horizontal position. Auto-calculated if not specified, arranging right-to-left.
- `y`: Vertical position. Auto-calculated if not specified, aligning bottom edge to main text top.
- `color`: Color, default red `{1 0 0}`.
- `font-size`: Font size, default 18pt.
- `grid-width`: Grid width, default 20pt.
- `grid-height`: Grid height, default 19pt.

## Features

- **Auto-arrangement** (v0.2.3+): Multiple MeiPi notes automatically arrange right-to-left. Spacing configurable via `\meipiSetup{spacing=...}`.
- **Smart Positioning**: Y coordinate auto-calculated so bottom edge aligns with main text top.
- **Cross-page Support** (v0.2.3+): MeiPi correctly appears on the page where its anchor is located, not the previous page.
- **Independent Indentation**: MeiPi content does not inherit paragraph indentation from main text.

## Configuration

```latex
\meipiSetup{
  spacing = 10pt,  % Spacing between MeiPi notes
  gap = 0pt        % Gap between MeiPi bottom and main text top
}
```

## Technical Implementation
MeiPi is based on `guji/luatex-cn-guji-meipi.lua`. It inserts anchor nodes into the node list to record positions, then during layout phase determines which page the MeiPi should appear on based on the **first node with layout information after** the anchor.

---

👉 Next Steps: Check [[Seals | EN:Seal]] or [[Judou | EN:Judou]].
