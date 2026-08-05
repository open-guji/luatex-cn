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

---

## Elevation (Taitou / 抬头) <sup>v0.2.6+</sup>

`luatex-cn` provides full support for "Taitou" (Elevation/Rising). See: **[[Elevation | EN:Taitou]]**.

---


### 2. Emphasis Marks

| Command | Alias | Description |
|---------|-------|-------------|
| `\EmphasisMark` | `\着重号` / `\著重號` | Add an emphasis mark to the right of each character |
| `\emphasisMarkSetup` | `\着重号设置` / `\圈点设置` | Global setup |

| Parameter | CN alias | Default | Description |
|-----------|----------|---------|-------------|
| `char` | `字符` | `○` | Mark character |
| `scale` | `缩放` | `0.3` | Mark scale factor |
| `color` | `颜色` | `black` | Mark color |
| `skip-punct` | `跳过标点` | `false` | No emphasis marks on punctuation (clreq 5.3.1) |

**Per-class defaults** (main branch): `ltc-guji` keeps the traditional quandian convention — hollow circle `○` on every character including punctuation; `ltc-cn-vbook` / `ltc-tw-vbook` preset `char=●, skip-punct=true`, i.e. the solid dot with no marks on punctuation as specified by clreq 5.3.1.

> Taiwan note: the Ministry of Education's Punctuation Guidance (2008 revision) does not include this mark, though it still appears in publishing practice; `ltc-tw-vbook` takes clreq's generic form (`●`), changeable per book via `\着重号设置{char=…}`.

**Example**:
```latex
\EmphasisMark{Very Important}
\EmphasisMark[skip-punct=false]{标点，也加。}   % per-call override
\emphasisMarkSetup{char=●, color=red}          % change the convention globally
```

### 3. FaSheng / Tone-Mark Circles <sup>v0.3.8+</sup>

Per Song-dynasty Yue Ke's《九经三传沿革例》: "音有平上去入之分，则随圈发". Places tone-mark circles at the four corners of a character.

| Command | Alias | Description |
|---------|-------|-------------|
| `\faSheng` | `\发圈` / `\圈发` / `\發圈` / `\圈發` | Single-character tone mark |
| `\fashengBatch` | `\发圈批` / `\發圈批` | Parallel batch (tone string + char string) |
| `\fashengSetup` | `\发圈设置` / `\發圈設置` | Global setup |
| `\平声` / `\上声` / `\去声` / `\入声` | — | Tone shorthand commands |

**Corner convention**: Ping (level) = bottom-left, Shang (rising) = top-left, Qu (departing) = top-right, Ru (entering) = bottom-right.

**Usage**:
```latex
% Bare tone shortcut: tone in brackets
\faSheng[平]{字}
\faSheng[上]{字}
\faSheng[去]{字}
\faSheng[入]{字}

% Explicit key=value (English keys also work)
\faSheng[tone=qu, color=red]{字}

% Shorthand commands
\平声{字}\上声{字}\去声{字}\入声{字}

% Parallel batch: tone string + main char string (1:1 mapping)
\发圈批{平上去入}{春夏秋冬}
```

**Parameters**:

| Key | CN Alias | Default | Description |
|-----|----------|---------|-------------|
| `tone` | `声` / `聲` | `ping` | Tone, one of `ping` / `shang` / `qu` / `ru`, or `平` / `上` / `去` / `入` |
| `color` | `颜色` / `顏色` | `black` | Circle color |
| `char` | `字符` | `○` | Circle character |
| `scale` | `缩放` / `縮放` | `0.3` | Circle scale |
| `offset` | `偏移` | `0.45em` | Offset from character center |

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
