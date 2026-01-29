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

👉 Next: [[Textbox | EN:Textbox]] or [[Features | EN:Features]].
