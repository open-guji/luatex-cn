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
    punct-hanging = false,   % Hanging (in development)
}
```

| Parameter | Description | Default | Values |
|-----------|-------------|---------|--------|
| `punct-style` | Punctuation style | `taiwan` | `taiwan`, `mainland` |
| `punct-squeeze` | Squeeze punctuation | `true` | `true`, `false` |
| `kinsoku` | Line-breaking rules | `true` | `true`, `false` |
| `punct-hanging` | Hanging punctuation | `false` | `true`, `false` |

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
\documentclass[中华书局]{cn-vbook}
```

## Using with guji

The `ltc-guji` class also supports the punctuation system. When `punct-mode=normal`, it activates automatically:

```latex
\documentclass[四库全书]{guji}
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
