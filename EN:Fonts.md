[English Version] | [中文版](Fonts)

# Fonts

`luatex-cn` provides intelligent cross-platform font detection and a powerful multi-font fallback mechanism to gracefully handle missing characters (rare glyphs).

## 1. Automatic Font Detection

By default, the `ltc-guji` (or `ltc-cn-vbook` / `ltc-tw-vbook`) document class automatically selects the most suitable installed fonts based on your operating system:

- **Windows**: Prioritizes SimSun, SimHei, etc.
- **macOS**: Prioritizes Songti SC, PingFang SC, etc.
- **Linux**: Prioritizes Fandol series or Noto CJK series.

To manually trigger and apply the auto-detected font:
```latex
\ApplyAutoFont
```

### Chinese Font Name Support (v0.2.2+)

Since v0.2.2, font detection supports simplified and traditional Chinese font names:

```latex
\设置字体{宋体}          % Simplified Chinese name
\设置字体{標楷體}        % Traditional Chinese name
\设置字体{思源宋体}      % Open source font Chinese name
```

The system automatically maps Chinese font names to corresponding system fonts.

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

### Registry Aliases and Font Files (No Installation Needed)

`\setFontFamily` also accepts **registry aliases** and **font filenames/paths**; all three forms can be mixed, and none requires installing fonts into the system:

```latex
\setFontFamily{Jigmo}                      % alias: expands to a Jigmo + Jigmo2 fallback chain
\setFontFamily{fonts/MyFont.ttf, TW-Kai}   % file path mixed with a font name
\setFontFamily{TW-Kai, Jigmo2.ttf}         % bare filenames work too
```

Each font resolves in three steps:

1. **Installed on the system** → used by name;
2. **Local file** → searched in `./fonts/`, the document directory, then kpse (covering TEXMFHOME and OSFONTDIR);
3. **Not found anywhere** → compilation stops with an error that prints the exact download-script commands (see §4), instead of rendering tofu.

System fonts and local files mix per member — e.g. with Jigmo installed but only `Jigmo2.ttf` on disk, the `{Jigmo}` alias still builds the chain correctly. Built-in aliases so far: `Jigmo` (Jigmo + Jigmo2).

To define a named fallback chain for custom usage:

```latex
% Define a chain named "mybackup"

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

## 4. Fonts Without System Installation

Don't want to (or can't) install fonts into the system font library? LuaTeX can load fonts **by file** — as long as the `.ttf`/`.otf` file sits in the document directory, a `./fonts/` subdirectory, or your TEXMFHOME tree, referencing it by filename just works.

The repository ships a download script (requires Python 3) that fetches recommended open-source fonts (TW-Kai series, Jigmo, KingHwa Old Song, Zhuque Fangsong, etc.) according to `scripts/font-manifest.json`, with SHA-256 verification:

```bash
# Option 1: install into your personal TeX tree (recommended; available everywhere)
# Goes to TEXMFHOME/fonts/truetype/luatex-cn/ — no admin rights, no system fonts touched
python3 scripts/download_fonts.py --all --user

# Option 2: download into your document project (self-contained, easy to redistribute)
python3 scripts/download_fonts.py --all --dest ./fonts
```

Then reference fonts **by filename** in your document:

```latex
% Bare filename works when the font is in TEXMFHOME or next to the .tex file
\setmainfont{TW-Kai-98_1.ttf}

% Use Path for a subdirectory
\setmainfont{TW-Kai-98_1.ttf}[Path=./fonts/]
```

> [!NOTE]
> - After `--user` installation, run `luaotfload-tool --update` once if you want to reference fonts by **font name** instead of filename.
> - Fonts distributed as npm woff2 slices (e.g. Zhuque Fangsong) are downloaded and merged into a single TTF automatically (vertical features preserved); this requires `pip install fonttools brotli`.

---

👉 Next: [[Correction | EN:Correction]] or [[Features | EN:Features]].
