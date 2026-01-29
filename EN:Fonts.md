[English Version] | [中文版](Fonts)

# Fonts

`luatex-cn` provides intelligent cross-platform font detection and a powerful multi-font fallback mechanism to gracefully handle missing characters (rare glyphs).

## 1. Automatic Font Detection

By default, the `ltc-guji` document class automatically selects the most suitable installed fonts based on your operating system:

- **Windows**: Prioritizes SimSun, SimHei, etc.
- **macOS**: Prioritizes Songti SC, PingFang SC, etc.
- **Linux**: Prioritizes Fandol series or Noto CJK series.

To manually trigger and apply the auto-detected font:
```latex
\ApplyAutoFont
```

## 2. Font Family & Fallback

v0.1.5 introduces the concept of **Font Family**. By setting a font family, the system establishes a "fallback chain". When the main font lacks a specific character (e.g., a rare CJK ideograph), it automatically looks for it in the next font in the chain.

### `\setFontFamily`

This command accepts a comma-separated list of fonts. The first font in the list becomes the main font, and the rest serve as fallbacks.

```latex
% Sets "Source Han Serif SC" as the main font.
% If a character is missing, it tries "SimSun", then "SimHei".
\setFontFamily{Source Han Serif SC, SimSun, SimHei}
```

Chinese Alias:
```latex
\设置字体族{Source Han Serif SC, SimSun, SimHei}
```

### `\DeclareFontFallback`

To define a named fallback chain for custom usage:

```latex
% Define a chain named "mybackup"
\DeclareFontFallback{mybackup}{SimSun, SimHei}

% Apply this chain to a specific font
\setmainfont{MyCustomFont}[RawFeature={fallback=mybackup}]
```

## 3. Standard Font Setting

If you only need to set a single font without fallback logic:

```latex
\setmainfont{KaiTi}
% or
\设置字体{KaiTi}
```

> [!NOTE]
> For vertical layout, `luatex-cn` generally handles vertical features (`RawFeature={+vert}`) automatically.

---

👉 Next: [[Correction | EN:Correction]] or [[Features | EN:Features]].
