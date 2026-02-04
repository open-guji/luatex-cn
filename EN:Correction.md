[English Version] | [中文版](Correction)

# Correction & Decoration

`luatex-cn` provides tools for classical text correction and decoration, including correction marks, emphasis marks, and underlines (proper name marks / book title marks).

## Correction (GaiZi)

The `\fix` (or `\改`) command marks corrections in classical text editing. It retains the original character with a deletion mark (、) and places the replacement character at the bottom right.

### Usage

```latex
\fix{replacement}
% or Chinese alias
\改{替换字}
```

### Example

```latex
This has a \fix{correct}wrong text.
```
In this example, "wrong" will have a deletion mark (、), and "correct" will appear at smaller size in the bottom-right corner.

### Technical Details
- **Deletion Mark**: Automatically overlays a deletion point (、) on the character
- **Replacement Text**: Placed at bottom-right corner at 60% of original font size
- **Non-destructive**: Does not affect the original grid layout

---

## Decoration

The `\decorate` (or `\装饰`) command overlays decoration characters on **each character in the content**.

### Usage

```latex
\decorate[options]{content}
% or Chinese alias
\装饰[参数]{内容}
```

### Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `char` | Decoration character | `。` |
| `color` | Decoration color | `red` |
| `xoffset` / `xshift` | Horizontal offset | `0pt` |
| `yoffset` / `yshift` | Vertical offset | `0pt` |
| `scale` | Scale factor | `1.0` |
| `font-size` | Force specific font size | auto |

### Example

```latex
% Add a red circle on each character in "important"
\decorate[char=○, scale=0.8, color=red]{important}
```

---

## Emphasis Mark (ZhaoZhongHao / QuanDian)

A convenience wrapper for adding circle marks to the right side of characters.

### Usage

```latex
\EmphasisMark[color=red]{content}
% or Chinese aliases
\着重号[color=red]{内容}
\圈点{内容}
```

### Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `color` | Mark color | `red` |

### Example

```latex
This is \EmphasisMark{important} content.
% or classical style
\圈点{要旨}
```

---

## Underline / Proper Name Mark (ZhuanMingHao)

In vertical typesetting, underlines appear as vertical lines on the left side of characters, used to mark proper nouns like personal names and place names.

### Usage

```latex
\Underline[color=red, offset=0.6em]{content}
% or Chinese aliases
\下划线[color=red]{内容}
\下劃線{内容}
\专名号{内容}
```

### Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `color` | Line color | `red` |
| `offset` | Offset distance | `0.6em` |

### Example

```latex
% Mark a person's name
Know \专名号{Sima Qian}.
% or use underline command
\Underline{Confucius} said: Learn and practice.
```

---

## Wavy Underline / Book Title Mark (ShuMingHao)

In vertical typesetting, wavy underlines appear as wavy vertical lines on the left side of characters, used to mark book titles and chapter names.

### Usage

```latex
\WavyUnderline[color=red, offset=0.6em]{content}
% or Chinese aliases
\波浪线[color=red]{内容}
\波浪線{内容}
\书名号{内容}
```

### Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `color` | Line color | `red` |
| `offset` | Offset distance | `0.6em` |

### Example

```latex
% Mark a book title
Read \书名号{Records of the Grand Historian}.
% or use wavy underline command
\WavyUnderline{The Analerta} is a Confucian classic.
```

---

👉 Next: [[Textbox | EN:Textbox]] or [[Features | EN:Features]].
