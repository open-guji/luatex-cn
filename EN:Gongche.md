English | [中文版](Gongche)

# Gongche Notation (工尺谱) <sup>v0.3.8+</sup>

Gongche is a traditional Chinese musical notation. This module provides commands for the main-char + notation-string composite (`\工尺`), single-note units with rhythm + octave decorators (`\音`), sustain/continuation units (`\拖音`), and small-text annotations (judou / gongdiao). It can faithfully reproduce traditional printed musical layouts from Kunqu, Cantonese, and Fujianese opera.

References: Song-dynasty Yue Ke's《九经三传沿革例》"音有平上去入之分，则随圈发"; Qing-dynasty Fang Chengpei's《雷峰塔传奇》gongche typesetting conventions.

## Command Overview

| Command | Alias | Purpose |
|---------|-------|---------|
| `\工尺{main}{notation}` | `\GongChe` | Main char + right-side gongche string |
| `\音[<opts>]{char}` | `\Yin` | Single note: stackable rhythm + octave markers |
| `\拖音[<rhythm>]` | `\Drag` | Sustain/continuation unit (uses `丨` as main char) |
| `\工尺设置{...}` | `\gongcheSetup` / `\工尺設置` | Global setup |
| `\句` / `\韵` / `\韻` | — | Sentence/rhyme markers |
| `\宫调{X}` / `\宮調{X}` / `\曲牌{X}` / `\调名注{X}` | — | Tune/rhyme name annotations |
| `\句读字{X}` | — | Generic small-text annotation (low-level) |

---

## `\工尺` — Main Char + Notation String

```latex
\工尺{春}{尺工六}
\工尺[颜色=red, 缩放=0.4]{眠}{合四上}
```

### Parameters

| Key | CN Alias | Default | Description |
|-----|----------|---------|-------------|
| `scale` | `缩放` / `縮放` | `0.5` | Notation string scale relative to main char |
| `color` | `颜色` / `顏色` | `black` | Notation color |
| `offset` | `偏移` | `0pt` | Horizontal offset |

Built on `\SideText` (right-side annotation). Will share styling with the `\旁注` API.

---

## `\音[opts]{char}` — Single Note with Rhythm/Octave Markers

`\音` is the Level 2/3 command. A single gongche character can carry up to two orthogonal markers simultaneously:

- **rhythm slot** (板眼): beat marks
- **octave slot** (八度): octave-position marks

### Rhythm Presets

| Preset | Default Char | Color | Usage |
|--------|--------------|-------|-------|
| `板` | `。` | red | Strong beat |
| `眼` | `、` | red | Weak beat |
| `头板` / `頭板` | `×` | red | Head beat |
| `底板` | `└` | red | Bottom beat |
| `底叮` | `⌐` | red | Bottom ding |

### Octave Presets

| Preset | Default Char | Position | Usage |
|--------|--------------|----------|-------|
| `高` | `亻` | Above main | Fujianese/Cantonese opera high octave |
| `低` | `彳` | Above main | Cantonese opera low octave |
| `昆低` | `⌒` | Below main | Kunqu low octave |

### Usage

```latex
% Bare note (no markers)
\音{尺}

% Rhythm only
\音[板]{尺}            % red 。 to the left
\音[眼]{工}            % red 、 to the left

% Octave only
\音[高]{尺}            % 亻 above main char
\音[昆低]{尺}          % ⌒ below main char

% Combined rhythm + octave
\音[板, 高]{尺}

% Custom colors and chars
\音[板, 颜色=blue]{尺}
\音[高, 八度颜色=red]{尺}
\音[字符=●, 缩放=0.3, 颜色=green]{尺}
```

### Parameters (key=value)

Bare `颜色` / `缩放` / `字符` affect the rhythm slot. The octave slot uses the prefixed `八度颜色` / `八度缩放` / `八度字符`.

| Slot | Keys | CN Aliases |
|------|------|------------|
| Rhythm | `rhythm-char` / `rhythm-color` / `rhythm-scale` / `rhythm-xshift` / `rhythm-yshift` | `字符` / `颜色` / `缩放` / `横偏` / `纵偏` |
| Octave | `octave-char` / `octave-color` / `octave-scale` / `octave-xshift` / `octave-yshift` | `八度字符` / `八度颜色` / `八度缩放` |

> Sign convention (from decorate.lua): `xshift > 0` = visual LEFT (toward main char), `yshift > 0` = visual DOWN.

---

## `\拖音[rhythm]` — Sustain/Continuation

Sustain unit; main char is `丨` (U+4E28 CJK STROKE). Combines with rhythm markers to mark each beat in a held note.

```latex
% A 4-beat "尺" note (attack on the board, then 3 sustain beats)
\工尺{春}{\音[板]{尺}\拖音[眼]\拖音[板]\拖音[眼]}

% Bare sustain (no rhythm marker)
\拖音
```

---

## Judou / Gongdiao Small-Text Annotations

Gongche scores often carry sentence/rhyme markers (句, 韵) and tune names (e.g., 仙吕调). These are roughly half-size, in-flow annotations.

```latex
% Sentence/rhyme
\工尺{春}{尺}\句       % "春尺。句"
\工尺{眠}{六}\韵       % "眠六。韵"

% Tune/rhyme names
\宫调{仙吕调}
\曲牌{【点绛唇】}
\调名注{一名「南吕」}
```

Low-level command: `\句读字{X}` renders `{\small X}`. The semantic shortcuts above are convenience aliases.

---

## Complete Example (Meng Haoran's "Spring Dawn")

```latex
\工尺{春}{\音[板]{尺}\拖音[眼]}\句
\工尺{眠}{\音[板]{工}}
\工尺{不}{\音[眼]{六}}
\工尺{觉}{\音[板, 高]{尺}}\韵
```

Full runnable examples: [`示例/工尺谱/`](https://github.com/open-guji/luatex-cn/tree/main/示例/工尺谱).

## Related Issues

- `#90` — Gongche Level 1/2/3 implementation
