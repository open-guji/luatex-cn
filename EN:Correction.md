[English Version] | [中文版](Correction)

# Correction & Decoration

`luatex-cn` provides tools for classical text correction and custom decoration.

## Correction (GaiZi)

The `\fix` (or `\改`) command is used to mark corrections. It retains the original character with a deletion mark (、) and places the corrected character at the bottom right.

### Usage

```latex
\fix{Replacement}
% or
\改{Replacement}
```

### Example

```latex
This is a \fix{correct}wrong text.
```

## Decoration

The `\decorate` (or `\装饰`) command allows overlaying arbitrary content on the **previous character**.

### Usage

```latex
\decorate[scale=0.8, color=red]{○}
```

### Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `color` | Color of decoration | `red` |
| `xoffset` | Horizontal offset | `0pt` |
| `yoffset` | Vertical offset | `0pt` |
| `scale` | Scale factor | `1.0` |

---

## Underline (Book Title & Proper Name Marks)

`luatex-cn` supports underlining in vertical text for book titles (书名号) and proper names (专名号).

### Usage

Use `|` characters to wrap text that needs underlining:

```latex
|BookTitle|  % Book title mark (single underline)
||ProperName||  % Proper name mark (double underline/wavy line)
```

### Example

```latex
Read |Records of the Grand Historian|, know ||Sima Qian||.
```

In this example, "Records of the Grand Historian" will have a book title underline, and "Sima Qian" will have a proper name mark.

### Technical Details
- **Book Title Mark**: Single `|` wrapping, displays as single underline
- **Proper Name Mark**: Double `||` wrapping, displays as double underline or wavy line
- **Vertical Adaptation**: Underlines automatically convert to vertical lines on the right side of characters, following vertical typesetting conventions

---

👉 Next: [[Textbox | EN:Textbox]] or [[Features | EN:Features]].
