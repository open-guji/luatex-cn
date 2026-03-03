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

### Features
- **Auto-Extension**: If `height` is 0, the box extends naturally.
- **Compression (Flat Text)**: If `height` is fixed and content is too long, text is vertically compressed (v0.1.5).
- **Independent Indentation** (v0.2.2+): Textbox content no longer inherits paragraph indentation from main text, ensuring layout independence (fix #37).

## Bordered Text / Moquan (v0.3.2+)

`\墨围` (`\bordered`) is a shortcut for a thin rectangular border, used to highlight labels like "索隱" (Commentary), "集解" (Collected Explanations), etc.

```latex
\墨围{集解}裴駰曰……
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
