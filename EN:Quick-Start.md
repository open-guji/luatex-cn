English | [中文版](Quick-Start)

# Quick Start

This page helps you quickly get started with `luatex-cn` for traditional Chinese book typesetting.

## Basic Template

```latex
\documentclass[四库全书]{guji}
% Optional: specify font
% \setmainfont{Noto Serif SC}

\title{钦定四库全书}
\chapter{史记\\卷一}

\begin{document}
\begin{正文}

This is sample vertical text for ancient book typesetting.

\end{正文}
\end{document}
```

## Common Commands

### Interlinear Notes (Double-line Small Text)

```latex
Main text\\夹注{This is interlinear note content, auto-balances}continued text.
```

### Side Notes

```latex
Main text\\侧批[yoffset=10pt]{This is side note content}continued text.
```

### Paragraph Indentation

```latex
\\begin{段落}[indent=2]
    天地玄黄\\\\
    宇宙洪荒
\\end{段落}
```

### Spaces

```latex
Need\\空格[2]two spaces here.
```

### Annotation Box

```latex
\\批注[x=5cm, y=2cm, height=6, color={1 0 0}]{Annotation content}
```

### Seal

```latex
\\印章[page=1, xshift=2cm, yshift=5cm]{seal.png}
```

### Force Column Break

```latex
End of this column\\\\
Start of new column
```

### Metadata Setup (v0.2.0+)

```latex
\title{Book Title}
\publisher{Publisher Name}
\ChapterMarker{Volume 1}
```

Or using the setup command:
```latex
\metadataSetup{
  title = Book Title,
  publisher = Publisher Name
}
```

### Debug Mode (v0.2.2+)

```latex
\LtcDebugOn   % Enable debug ruler, shows grid coordinates
\LtcDebugOff  % Disable debug mode
```

## Preset Styles

Choose preset styles via document class options:

| Option | Description |
|--------|-------------|
| `四库全书` | Qing Dynasty Siku Quanshu style, single fishtail |
| `红楼梦甲戌本` | Manuscript style, no fishtail |

```latex
\\documentclass[四库全书]{guji}
% or
\\documentclass[红楼梦甲戌本]{guji}
```

## Next Steps

- See [[Examples | EN:Examples]] for more complex usage
- Read [[Changelog | EN:Changelog]] for latest features
