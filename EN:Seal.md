English | [中文版](Seal)

# Seals (YinZhang / 印章)

The `\印章` command adds images like collection marks or personal seals to the page, supporting absolute positioning and opacity.

## Usage

```latex
\印章[page=1, xshift=2cm, yshift=5cm, opacity=0.8, width=3cm]{seal.png}
```

## Parameters

- `page`: Page number where the seal appears (default: 1).
- `xshift` / `yshift`: Offsets from the page center or margin.
- `opacity`: Opacity (0.0 to 1.0). For ancient books, 0.7-0.9 is recommended to simulate ink absorption.
- `width`: Display width of the seal image.
- `color`: (Optional) Color for vector-based seals.

## Features

- **Layer Management**: Seals are rendered during the `shipout/background` hook by default, appearing below the text. This can be customized if foreground placement is needed.
- **Multi-point Layout**: Multiple seal commands can be used on the same page; they are positioned independently based on their coordinates.
- **Absolute Positioning**: Uses TikZ's coordinate system for pinpoint accuracy on the page.

## Technical Implementation
Seals leverage LaTeX `shipout` hooks. Each call to `\印章` registers a `tikzpicture` block inside the appropriate hook, wrapped in an `\ifnum\value{page}=N` conditional to ensure images are output on the correct page and at the correct layer.

---

👉 Next Steps: Check [[Judou | EN:Judou]] or [[Features Overview | EN:Features]].
