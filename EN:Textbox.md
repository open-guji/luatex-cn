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

## Fill Textbox

`\FillTextBox` (or `\填充文本框`) is a variant of `\TextBox` with default fill alignment.

```latex
\FillTextBox[height=10]{Content}
```

---

👉 Next: [[Features | EN:Features]].
