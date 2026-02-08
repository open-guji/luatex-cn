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
In this example, "wrong" is marked with a deletion symbol, and "correct" is placed at its bottom-right corner at 60% size.

### Technical Details
- **Deletion Mark**: Automatically overlays a deletion point (、) on the character.
- **Replacement Text**: Placed at bottom-right corner at 60% of original font size.
- **Non-destructive**: Does not affect the original grid layout.

---

## Text Decoration

Preset commands for marking text according to classical or modern standards.

### 1. Underline Marks

| Command | Alias | Description | Use Case |
|---------|-------|-------------|----------|
| `\Underline` | `\下划线` | Straight line on the left | General highlighting |
| `\专名号` | - | Straight line on the left | Proper names (Person, Place) |
| `\WavyUnderline` | `\波浪线` | Wavy line on the left | General highlighting |
| `\书名号` | - | Wavy line on the left | Book/Article titles |

**Options (`[options]`)**:
- `color`: Line color (default: `red`).
- `offset`: Distance from text (default: `0.6em`).

**Example**:
```latex
\专名号[color=black]{Confucius}
\书名号{The Analects}
```

**Technical Improvement (v0.2.6+)**: Underlines have been migrated from glyph-based (`|`) to **PDF Graphics** implementation. This solves:
- Line discontinuity at the end of columns/pages.
- Strong coupling between line thickness/position and specific fonts.
- Support for use within sidenotes, jiazhu, and textboxes.

---

## Elevation (Taitou / 抬头) <sup>v0.2.6+</sup>

`luatex-cn` provides full support for "Taitou" (Elevation/Rising), a traditional formatting used in ancient Chinese texts to show respect by starting a new line and raising the text height.

### Usage

| Command | Effect | Description |
|---------|--------|-------------|
| `\抬头[N]` | New line, raised by N cells | Core command, N can be pos/neg |
| `\平抬` | New line, top-aligned | Equivalent to `\抬头[0]` |
| `\单抬` | New line, 1 cell higher | Equivalent to `\抬头[1]` |
| `\双抬` | New line, 2 cells higher | Equivalent to `\抬头[2]` |
| `\三抬` | New line, 3 cells higher | Equivalent to `\抬头[3]` |
| `\相对抬头[N]` | Raise by N cells relative to indent | Used in indented contexts like Jiazhu |

### Automatic Border Wrapping
Taitou is deeply integrated with the Banxin (page frame) system. When text "breaks out" of the normal layout into the margin, `luatex-cn` automatically draws stepped border lines to ensure the silk frames correctly wrap the elevated text.

### Example
```latex
The Great\单抬 Sage Confucius
```


### 2. Emphasis Marks

| Command | Alias | Description |
|---------|-------|-------------|
| `\EmphasisMark` | `\着重号` | Add small circles (。) to the right of each char |
| `\圈点` | - | Same as above |

**Example**:
```latex
\EmphasisMark{Very Important}
```

---

## Generic Decoration

The `\decorate` (or `\装饰`) command allows overlaying arbitrary content on **each character**.

### Usage

```latex
\decorate[options]{content}
```

### Parameters

| Key | Description | Default |
|-----|-------------|---------|
| `char` | Decoration character | `。` |
| `color` | Color | `red` |
| `xoffset` | Horizontal offset (xshift) | `0pt` |
| `yoffset` | Vertical offset (yshift) | `0pt` |
| `scale` | Scale factor | `1.0` |
| `font-size` | Force specific font size | auto |

### Example

```latex
% Add a red circle on each character in "important"
\decorate[char=○, scale=0.8, color=red]{important}
```

---

👉 Next: [[Textbox | EN:Textbox]] or [[Features | EN:Features]].
