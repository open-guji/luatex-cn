English | [中文版](Judou)

# Judou (Punctuation Modes)

**Judou** (jù dòu) refers to the traditional Chinese system of punctuation and pausing marks. `luatex-cn` can automatically convert modern punctuation into traditional styles suitable for ancient book typesetting.

## Punctuation Mode Overview

`luatex-cn` provides three punctuation modes (`punct-mode`), switchable via `\judouSetup` or convenience commands:

| Mode | Description | System |
|------|-------------|--------|
| `normal` (default) | Modern full-width punctuation with squeeze/kinsoku | [[Punctuation \| EN:Punctuation]] |
| `judou` | Convert to traditional Ju/Dou marks (circles/dots) | Judou system |
| `none` | Remove all punctuation (plain text / "Baiwen") | None |

**Note**: The punctuation system and judou system are **mutually exclusive**. When `punct-mode=normal`, the punctuation system handles squeeze/kinsoku; when `punct-mode=judou` or `none`, the judou system takes over.

## What is Judou Mode?
Traditional ancient books typically do not use modern full-width punctuation marks. Instead, they use small circles ("Ju") or dots ("Dou") attached to the characters.

- **Ju (句)**: Corresponds to periods (.), question marks (?), and exclamation marks (!). Rendered as a small circle (○).
- **Dou (读)**: Corresponds to commas (,), semicolons (;), and enumeration commas (、). Rendered as a small dot or tick (●).

### Supported Punctuation (v0.2.1+)
Since v0.2.1, the range of supported punctuation has been extended to include:
- Basic punctuation: periods, commas, enumeration commas, semicolons, colons
- Paired punctuation: quotation marks (「」『』""''), book title marks (《》〈〉), parentheses
- Special punctuation: dashes, ellipses, interpuncts, etc.

## Usage

### 1. Switching Punctuation Modes

```latex
% Enable judou mode
\JudouOn
\开启句读模式
\句读模式

% Return to modern punctuation
\JudouOff
\关闭句读模式
\正常标点模式

% Plain text mode (no punctuation)
\无标点模式
\开启无标点模式
```

### 2. Using with Different Document Classes

#### guji (Ancient Books)

```latex
\documentclass[四库全书]{guji}
\开启句读模式  % Use traditional judou

\begin{document}
\begin{正文}
人之初，性本善。
% Commas become dots, periods become circles at bottom-right
\end{正文}
\end{document}
```

#### cn-vbook / tw-vbook (Modern Books)

```latex
\documentclass{cn-vbook}
% cn-vbook defaults to modern punctuation (punct-mode=normal)

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。  % Modern punct with squeeze/kinsoku

\句读模式
寒来暑往，秋收冬藏。  % Switch to judou
\end{正文}
\end{document}
```

### 3. Dynamic Switching

```latex
\句读模式
人之初，性本善。       % Judou marks

\正常标点模式
现代文：他说："一二三。"  % Modern punctuation

\无标点模式
子曰学而时习之不亦说乎  % Plain text (Baiwen)
```

## Parameters

Fine-tune Judou appearance via `\judouSetup`:

| Key | Description | Default |
|-----|-------------|---------|
| `punct-mode` | Punctuation mode | `normal` |
| `judou-color` | Color of the marks | `red` |
| `judou-size` | Size of the marks | `1em` |
| `judou-pos` | Position relative to character | `right-bottom` |

```latex
\judouSetup{
    punct-mode = judou,
    judou-color = black,
    judou-size = 0.8em,
}
```

## Command Reference

| Command | Chinese Alias | Description |
|---------|--------------|-------------|
| `\JudouOn` | `\开启句读模式` | Enable judou mode |
| `\JudouOff` | `\关闭句读模式` | Disable judou mode |
| `\NormalPunctuationMode` | `\正常标点模式` | Switch to modern punct |
| `\JudouPunctuationMode` | `\句读模式` | Switch to judou mode |
| `\NonePunctuationMode` | `\无标点模式` | Switch to plain text |
| `\judouSetup{...}` | - | Configure judou parameters |

## Technical Details
Implemented via `luatex-cn-guji-judou.lua`:
1. **Identification**: Scans node stream for punctuation Unicode code points.
2. **Conversion**: In `judou` mode, punctuation nodes are removed and replaced by a decorate marker node attached to the preceding CJK character.
3. **Rendering**: The renderer draws the circle/dot at the specified anchor point (usually bottom-right) of the character.

---

👉 Next: [[Punctuation | EN:Punctuation]] | [[Features | EN:Features]]
