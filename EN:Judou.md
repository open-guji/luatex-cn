English | [中文版](Judou)

# Judou (Punctuation Marks)

Judou is the traditional way of punctuating vertical text in ancient China. `luatex-cn` can automatically process modern punctuation and offers specialized typesetting modes.

## What is Judou Mode?
Traditional Chinese typesetting doesn't use modern full-width commas and periods. Instead, it uses small circles ("Ju") or dots ("Dou") placed at the bottom-right corner of the preceding character.

## Usage

### Global Activation
```latex
\documentclass[judou-on=true]{ltc-guji}
```

### Commands
- `\JudouOn`: Enables automatic Judou conversion.
- `\JudouOff`: Disables conversion (restores modern punctuation or hides them).
- `\句读模式` / `\JudouPunctuationMode`: Switches to traditional Judou visual style.
- `\无标点模式` / `\NonePunctuationMode`: Hides all punctuation characters.

## Punctuation Modes (`punct-mode`)

| Mode | Effect |
|------|--------|
| `normal` | Displays modern full-width punctuation. |
| `judou` | Maps commas and periods to Ju/Dou marks at the bottom-right of characters. |
| `none` | Removes all punctuation for a clean, unpunctuated text. |

## Technical Implementation
Punctuation processing occurs in the Lua layer via the `vertical-judou.lua` module:
1. **Identification**: Scans the node stream and identifies punctuation via Unicode codes.
2. **Conversion**: In `judou` mode, it removes the punctuation glyph node and inserts a `WHATSIT` node immediately following the previous visible CJK character.
3. **Rendering**: During rendering, it uses the coordinates of the preceding character to draw a small circle or dot at its bottom-right anchor.

---

👉 Next Steps: Check [[Interlinear & Side Notes | EN:Side-Note]] or [[Features Overview | EN:Features]].
