[English Version] | [中文版](Judou)

# Judou (Punctuation)

**Judou** (jù dòu) refers to the traditional Chinese system of punctuation and pausing marks. `luatex-cn` can automatically convert modern punctuation into traditional styles suitable for ancient book typesetting.

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

### 1. Global Activation
Enable it in the document class options:
```latex
\documentclass[judou-on=true]{ltc-guji}
```

### 2. Commands
You can switch modes anywhere in the document:

- `\JudouOn`: Enable the Judou processing mechanism.
- `\JudouOff`: Disable Judou processing.

Switching **Punctuation Styles**:

- `\JudouPunctuationMode` (or `\句读模式`): Convert modern punctuation to Ju/Dou marks.
- `\NonePunctuationMode` (or `\无标点模式`): Hide all punctuation (Plain text / "Baiwen").
- `\NormalPunctuationMode` (or `\正常标点模式`): Show standard modern full-width punctuation.

### Example
```latex
\JudouOn
\JudouPunctuationMode
人之初，性本善。
% "," becomes a dot, "." becomes a circle at the bottom-right.

\NonePunctuationMode
子曰学而时习之不亦说乎
% All punctuation is hidden.
```

## Parameters

Fine-tune Judou appearance via parameters:

| Key | Description | Default |
|-----|-------------|---------|
| `judou-color` | Color of the marks | `red` |
| `judou-size` | Size of the marks | `1em` |
| `judou-pos` | Position relative to character | `right-bottom` |

## Technical Details
Implemented via `luatex-cn-guji-judou.lua`:
1. **Identification**: Scans node stream for punctuation Unicode code points.
2. **Conversion**: In `judou` mode, punctuation nodes are removed and replaced by a `WHATSIT` node attached to the preceding CJK character.
3. **Rendering**: The renderer draws the circle/dot at the specified anchor point (usually bottom-right) of the character.
   - v0.1.5 optimized the positioning algorithm to ensure marks adhere closely to the character bounding box without extra gaps.
   - v0.2.1 fixed punctuation mode application for sidenote content (fix #39).
   - v0.2.2 extended the range of supported Chinese punctuation symbols (fix #40).

---

👉 Next: [[Side-Note | EN:Side-Note]] or [[Features | EN:Features]].
