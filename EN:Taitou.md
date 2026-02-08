English | [中文版](Taitou)

# Elevation (Taitou / 抬头) <sup>v0.2.6+</sup>

`luatex-cn` provides full support for "Taitou" (Elevation/Rising), a traditional formatting used in ancient Chinese texts to show respect by starting a new line and raising the text height.

## Usage

| Command | Effect | Description |
|---------|--------|-------------|
| `\抬头[N]` | New line, raised by N cells | Core command, N can be pos/neg |
| `\平抬` | New line, top-aligned | Equivalent to `\抬头[0]` |
| `\单抬` | New line, 1 cell higher | Equivalent to `\抬头[1]` |
| `\双抬` | New line, 2 cells higher | Equivalent to `\抬头[2]` |
| `\三抬` | New line, 3 cells higher | Equivalent to `\抬头[3]` |
| `\相对抬头[N]` | Raise by N cells relative to indent | Used in indented contexts like Jiazhu |

## Automatic Border Wrapping
Taitou is deeply integrated with the Banxin (page frame) system. When text "breaks out" of the normal layout into the margin, `luatex-cn` automatically draws stepped border lines to ensure the silk frames correctly wrap the elevated text.

## Example
```latex
The Great\单抬 Sage Confucius
```

## Technical Details
The Elevation feature is defined in `luatex-cn-core-paragraph.sty` and implemented across `luatex-cn-core-textflow.lua` and `luatex-cn-layout-grid.lua`. When an elevation command is invoked, the layout engine adjusts the starting row (`cur_row`) for the current column and records the elevation height. The rendering layer in `luatex-cn-core-render-border.lua` then uses this data to draw the stepped border lines.

---

👉 Next: [[Templates & Format | EN:Templates]] or [[Features | EN:Features]].
