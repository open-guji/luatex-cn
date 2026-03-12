English | [中文版](Table)

# Table <sup>v0.3.4+</sup>

`luatex-cn` provides an inline table environment for vertical typesetting, supporting cell grouping, multi-band layout, and fine-grained border control. Tables are embedded within `\begin{BodyText}...\end{BodyText}`.

> **Note**: The table feature is currently experimental.

---

## 1. Basic Usage

```latex
\begin{BodyText}
Text before the table...

\begin{Table}[n-bands=3, band-gap=0.5em]
  \Cell{Band 1, Cell 1}
  \Cell{Band 1, Cell 2}
  \Cell{Band 2, Cell 1}
  \Cell{Band 2, Cell 2}
  \Cell{Band 3, Cell 1}
  \Cell{Band 3, Cell 2}
\end{Table}

Text after the table...
\end{BodyText}
```

---

## 2. Table Environment

### `\begin{Table}` / `\begin{表格}`

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| n-bands | 分栏 | 分欄 | int | 2 | Number of horizontal bands |
| band-gap | 栏间距 | 欄間距 | dim | 0pt | Gap between bands |
| band-heights | 栏高度 | 欄高度 | list | _(empty)_ | Band heights, comma-separated (e.g. `10em,8em`) |
| n-columns | 列数 | 列數 | string | _(empty)_ | Columns per band |
| header-rows | 表头栏数 | 表頭欄數 | int | 0 | Number of header bands |
| column-border | 列边框 | 列邊框 | string | _(empty)_ | Column border style (default for all bands) |
| band-border | 栏边框 | 欄邊框 | string | _(empty)_ | Horizontal separator between bands |
| column-fill | 列填充 | 列填滿 | string | _(empty)_ | Fill mode: `page` = fill entire page height |

---

## 3. Cell Command

### `\Cell` / `\单元格` / `\單元格`

Syntax: `\Cell[options]{content}`

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| col-width | 列宽 | 列寬 | number | 1 | Column span (supports decimals) |
| vertical-align | 纵对齐 | 縱對齊 | string | _(empty)_ | Vertical alignment |

---

## 4. Band Format Command

### `\BandFormat` / `\栏格式` / `\欄格式`

Used at the beginning of a band (before any `\Cell`) to set per-band formatting.

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| column-border | 列边框 | 列邊框 | string | _(empty)_ | Column border for this band |
| padding-top | 上填充 | — | dim | _(empty)_ | Top padding |
| padding-bottom | 下填充 | — | dim | _(empty)_ | Bottom padding |
| padding | 填充 | — | dim | _(empty)_ | Set both top and bottom padding |

---

## 5. Band Mode in BodyText

The `\begin{BodyText}` environment also supports band parameters for full-page horizontal sectioning:

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| n-bands | 分栏 | 分欄 | int | 1 | Number of bands |
| band-gap | 栏间距 | 欄間距 | dim | 0pt | Gap between bands |
| band-mode | 栏模式 | 欄模式 | option | auto | Flow mode: `auto` (cross-page) / `per-page` |
| band-heights | 栏高度 | 欄高度 | list | _(empty)_ | Band heights |
| band-columns | 栏列数 | 欄列數 | string | _(empty)_ | Columns per band |
| column-border | 列边框 | 列邊框 | string | _(empty)_ | Column border |
| band-border | 栏边框 | 欄邊框 | string | _(empty)_ | Band separator |

### `\换栏` / `\換欄`

Force break to the next band in BodyText band mode.

---

👉 Next: [[Side Notes | EN:Side-Note]] or [[Textbox | EN:Textbox]].
