[English Version] | [中文版](Textbox)

# Textbox

`luatex-cn` provides powerful vertical text box capabilities with grid alignment.

## Basic Textbox

The `\TextBox` (or `\文本框`) command creates an independent vertical text area.

### Usage

```latex
\TextBox[options]{Content}
```

### Options

| Key | Description | Default |
|-----|-------------|---------|
| `height` | Height in grid units. 0 for auto-extension. | `0` |
| `n-cols` | Number of columns. | `0` |
| `border` | Show border. | `false` |
| `background-color` | Background color. | None |
| `floating` | Enable floating mode (needs x, y). | `false` |
| `transparent` | Whether background is transparent (v0.3.6+). When false, fills with page background color. | `true` |

### Features
- **Auto-Extension**: If `height` is 0, the box extends naturally.
- **Compression (Flat Text)**: If `height` is fixed and content is too long, text is vertically compressed (v0.1.5).
- **Independent Indentation** (v0.2.2+): Textbox content no longer inherits paragraph indentation from main text, ensuring layout independence (fix #37).

## Border Shortcut Commands (v0.3.2+, extended in v0.3.4)

Quick commands for adding borders and/or inverted (white-on-black) effects to inline labels. Size is automatically calculated based on content.

### Command Overview

| Command | English | Traditional | Effect |
|---------|---------|-------------|--------|
| `\墨围{text}` | `\bordered` | `\墨圍` | Rectangular black border |
| `\反白{text}` | `\inverted` | — | White text on black (no border) |
| `\墨围反白{text}` | `\borderedInverted` | `\墨圍反白` | Rectangular border + inverted |
| `\八角墨围{text}` | `\octagonBordered` | `\八角墨圍` | Octagonal border |
| `\八角墨围反白{text}` | `\octagonBorderedInverted` | `\八角墨圍反白` | Octagonal border + inverted |
| `\带圈{text}` | `\circled` | `\帶圈` | Circular border |

### Usage

```latex
\墨围{集解}裴駰曰……
\反白{正義}張守節曰……
\八角墨围{校勘}此字疑誤……
\带圈{一}
```

### Inverted text across columns (v0.4.4+)

`\反白` / `\墨围反白` / `\八角墨围反白` are now laid out inline: when a column runs out of cells the text continues character by character in the next column (or the next sub-column inside a jiazhu), instead of the whole block jumping to the next column and leaving a gap. The background and border are drawn per contiguous run in each column.

| Key | Chinese key | Description |
|-----|-------------|-------------|
| `break` | `断口` / `斷口` | Corner shape where a run is cut by a column break: `square` (default; only the ends of the whole run are octagonal) or `octagon` (every run is a full octagon) |
| `inline` | `可断行` / `可斷行` | `false` falls back to the old single-textbox implementation |

Passing textbox-only keys (`高度`, `填充`, `padding-top`, …) also falls back to the single textbox, e.g. `\八角墨围反白[高度=3, 填充]{...}`.

### Scaling with the font size (v0.4.4+)

Inside a jiazhu or at a temporarily smaller size, the circle of `\带圈` and the frames of `\墨围` / `\八角墨围` / `\反白` scale with the current font size and are centred vertically in their row, instead of being drawn at body-text height and running into neighbouring characters.

### Border Padding Control

Use `border-margin-x` / `border-margin-y` for separate horizontal and vertical padding:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `border-margin` | Unified border padding | `0pt` |
| `border-margin-x` | Horizontal border padding | _(follows border-margin)_ |
| `border-margin-y` | Vertical border padding | _(follows border-margin)_ |
| `outer-margin` | External textbox margin | `0pt` |

## Fill Textbox

`\FillTextBox` (or `\填充文本框`) is a variant of `\TextBox` with default fill alignment.

```latex
\FillTextBox[17]{……}            % a bare integer means height=17 (grid cells)
\FillTextBox[height=17]{……}     % same, key-value form
\FillTextBox[height=120pt]{……}  % absolute height
\FillTextBox[height=4]{天地玄黄宇宙}洪荒   % 6 characters squeezed into 4 cells
```

- **Flat text**: when the content exceeds the cell count the glyphs are compressed vertically as a whole, keeping their width; ratio = cells ÷ characters (83 characters in 17 cells is about 1/5 and nearly a line, so reduce `font-size` or add cells). Shorter content is spread out evenly.
- A bare integer in the brackets is `height=N`; use the key-value form to add other keys (`font-size`, `border`, …).
- Unlike `\TextBox[height=N]`, which never compresses and only top-aligns in N cells.
- Works directly inside `正文`, `列表` and `段落`; no extra package needed.

---

👉 Next: [[Features | EN:Features]].
