English | [中文版](Punctuation)

# Punctuation System (v0.2.7+)

`luatex-cn` provides a complete modern punctuation processing system with squeeze, kinsoku (line-breaking rules), vertical quote replacement, and mainland/Taiwan style support.

## Punctuation System vs Judou System

`luatex-cn` has two mutually exclusive punctuation mechanisms:

| System | Use Case | punct-mode | Description |
|--------|----------|------------|-------------|
| **Punctuation** (this page) | Modern books | `normal` (default) | Squeeze, kinsoku, quote replacement |
| **[[Judou \| EN:Judou]]** | Ancient books | `judou` or `none` | Convert punct to circles/dots or remove |

When `punct-mode=normal`, the punctuation system is active; when `punct-mode=judou` or `none`, the judou system takes over and the punctuation system is automatically disabled.

## Punctuation Styles

### Taiwan Style (Default)

All punctuation marks are centered within the grid cell.

```latex
\punctSetup{punct-style=taiwan}
% or
\台湾标点风格
```

### Mainland Style

Period (。) and comma (，、) marks are offset toward the upper-right corner of the grid cell, matching mainland Chinese publishing conventions.

```latex
\punctSetup{punct-style=mainland}
% or
\大陆标点风格
```

## Configuration

Configure punctuation behavior via `\punctSetup`:

```latex
\punctSetup{
    punct-style = taiwan,    % Style: taiwan or mainland
    punct-squeeze = true,    % Squeeze: compress punct to half-grid
    kinsoku = true,          % Kinsoku: prevent misplaced punct
    punct-hanging = false,   % Hanging punctuation at line end (default off)
}
```

| Parameter | Description | Default | Values |
|-----------|-------------|---------|--------|
| `punct-style` | Punctuation style | `taiwan` | `taiwan`, `mainland` |
| `punct-squeeze` | Squeeze punctuation | `true` | `true`, `false` |
| `kinsoku` | Line-breaking rules | `true` | `true`, `false` |
| `punct-hanging` | Hanging punctuation at column end (see below) | `false` | `true`, `false` |

### clreq preset keys (identical to the horizontal package)

> ⚠️ These parameters are not yet in a release (latest is v0.3.8) — get them from the main branch.

Beyond the original parameters above, `\punctSetup` (CN alias `\标点设置`) offers a set of clreq presets whose **key names and values match [[luatex-cn-hori | EN:Horizontal]] exactly**, so one manuscript can keep the same conventions in vertical and horizontal mode:

| Parameter | Description | Default | Values |
|-----------|-------------|---------|--------|
| `style` | Overall style preset; `none` is the clreq "no adjustment" preset (neither squeezed nor hugging) | per document class | `mainland`, `taiwan`, `none` |
| `squeeze-mode` | How punctuation width adjustment is decided: `legacy` squeezes unconditionally (the `ltc-guji` default, zero layout change); `context` is context-sensitive, triggering only on adjacent marks or column start/end (the `ltc-cn-vbook` / `ltc-tw-vbook` default) | `legacy` | `legacy`, `context` |
| `adjacent-punct` | Consecutive-punctuation reduction, in character widths | `1.5` | `1.5`, `1`, `natural` |
| `line-start-bracket` | Trim half a character from the start side of an opening bracket at column start | `trim` | `trim`, `natural` |
| `line-end-punct` | Trim half a character from the end side of a column-final period-type mark | `compress` | `compress`, `natural` |
| `western-space` | Automatic 1/4-em spacing between Han characters and Western letters/digits (see "Mixed Chinese-Western text" below) | `true` | `true`, `false` |

> **Context-sensitive width adjustment** (clreq): a single mark between Han characters occupies a full character width; reduction happens only when marks run consecutively (2 → 1.5 widths with bracket marks involved, down to 1 with `adjacent-punct=1`). The direction follows the clreq principle that the side carrying the blank is the side that yields.

> **Glyph placement** is anchored by measured ink extents rather than the font's own design: mainland style hugs the upper right in vertical mode, Taiwan style is centered in both modes. Setting mainland style with a Taiwan font (or vice versa) therefore lands where the specification says it should.

## Hanging Punctuation (punct-hanging)

> ⚠️ Not yet in a release (latest is v0.3.8) — get it from the main branch.

clreq's hanging punctuation at line end: a period-type mark that lands at the **column end** moves entirely out of the column, hanging beyond the type area, so the column body is no longer compressed on its account. clreq notes that hanging suits vertical writing (in horizontal Taiwan/Hong Kong style the centered marks make it inadvisable).

```latex
\punctSetup{punct-hanging=true}   % CN alias: 标点悬挂
```

Off by default — hanging changes the layout of existing documents, so enabling it is a per-book style decision. Only takes effect under `squeeze-mode=context` (the `ltc-cn-vbook` / `ltc-tw-vbook` default).

## Mixed Chinese-Western Text (clreq)

> ⚠️ Not yet in a release (latest is v0.3.8) — get it from the main branch.

### CJK-Western spacing

Per clreq, a **1/4 character width** of spacing is inserted automatically between Han characters and Western letters/digits, participating in line adjustment (compressible to 1/8, stretchable to 1/2). Three exceptions take no spacing: next to Chinese pause/stop marks, after an opening bracket, and before a closing bracket.

- The rules share a single source with the horizontal package (`tex/shared/luatex-cn-cjk-western.lua`), so both modes keep the same conventions.
- Digit runs remain unbreakable units (symbol-separation rules): base letter-spacing inside, normal CJK-Western spacing at both ends.
- Only takes effect under `squeeze-mode=context`; disable with `western-space=false` (CN alias `中西间距`).

### Sideways Western text: `\Sideways`

Of clreq's three configurations for Western text in vertical writing, "rotated 90° clockwise" is provided by `\Sideways` (CN aliases `\横置` / `\橫置`) — suited to longer Western words and phrases; single letters and acronyms usually just sit upright, one per cell (the engine default):

```latex
引用\Sideways{LuaTeX}之名继续排版。
年份\Sideways{2026}与长词\Sideways{Typography}混排。
```

Letters in a sideways run join into a word (no inner letter-spacing, never stretched apart by justification), share one vertical baseline, are centered horizontally in the column, and get the usual 1/4-em CJK-Western spacing against surrounding Han characters.

### Extended punctuation classes

Connector marks (～ - –), interpuncts (· ・ ‧) and solidi (/ ／) are now classified: all three obey the line-start prohibition rules, and the **mainland-style interpunct `·` is fixed at half a character width** (clreq Appendix A, GB style — as in the name divider of 爱新觉罗·玄烨), while the Taiwan style takes a full width.

## Punctuation Squeeze

When enabled, periods, commas and other marks are compressed to half the grid cell height, producing a tighter, more elegant layout.

## Kinsoku (Line-Breaking Rules)

Follows Chinese typesetting standards (CLREQ) to prevent marks from appearing in inappropriate positions:

- **Line-start forbidden**: Closing brackets, periods, commas, middle marks cannot appear at column start
- **Line-end forbidden**: Opening brackets cannot appear at column end

## Vertical Quote Replacement

The system automatically replaces horizontal bracket/quote forms with Unicode Vertical Presentation Forms (e.g., 「→﹁, 」→﹂, （→︵, ）→︶, 《→︽, 》→︾, —→︱, …→︙).

## Using with cn-vbook / tw-vbook

The `ltc-cn-vbook` / `ltc-tw-vbook` document classes enable the punctuation system by default. Choose styles via templates:

```latex
% Default template: Taiwan style
\documentclass{ltc-cn-vbook}

% Zhonghua Shuju template: Mainland style
\documentclass[中华书局]{ltc-cn-vbook}
```

## Using with guji

The `ltc-guji` class also supports the punctuation system. When `punct-mode=normal`, it activates automatically:

```latex
\documentclass[四库全书]{ltc-guji}
\正常标点模式  % Use modern punctuation (not judou)
\punctSetup{punct-style=mainland}
```

## Switching Between Modes

You can dynamically switch between the punctuation and judou systems:

```latex
\正常标点模式    % Modern punctuation
\句读模式        % Judou mode (circles/dots)
\无标点模式      % Plain text (no punctuation)
```

## Technical Details

Implemented via `luatex-cn-core-punct.lua` in three stages:

1. **Flatten**: Classify punctuation characters and replace with vertical forms
2. **Layout**: Apply squeeze and kinsoku processing
3. **Render**: Apply mainland/Taiwan style position offsets

---

👉 Next: [[Judou | EN:Judou]] | [[Modern Vertical | EN:ltc-book]] | [[Features | EN:Features]]
