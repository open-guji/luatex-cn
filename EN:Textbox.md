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
\FillTextBox[height=10]{Content}
```

---

👉 Next: [[Features | EN:Features]].
