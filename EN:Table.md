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
| n-columns | 行数 | 行數 | string | _(empty)_ | Columns per band |
| header-rows | 表头栏数 | 表頭欄數 | int | 0 | Number of header bands |
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border style (default for all bands) |
| band-border | 栏边框 | 欄邊框 | string | _(empty)_ | Horizontal separator between bands |
| column-fill | 行填充 | 行填滿 | string | _(empty)_ | Fill mode: `page` = fill entire page height |

---

## 3. Cell Command

### `\Cell` / `\单元格` / `\單元格`

Syntax: `\Cell[options]{content}`

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| col-width | 行宽 | 行寬 | number | 1 | Column span (supports decimals) |
| vertical-align | 纵对齐 | 縱對齊 | string | _(empty)_ | Vertical alignment |
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border of this cell |

```latex
% Ordinary cell
\单元格{content}

% Cell spanning two columns
\单元格[行宽=2]{spans two columns}
```

---

## 4. Band Format Command

### `\BandFormat` / `\栏格式` / `\欄格式`

Used at the beginning of a band (before any `\Cell`) to set per-band formatting.

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border for this band |
| padding-top | 上填充 | — | dim | _(empty)_ | Top padding |
| padding-bottom | 下填充 | — | dim | _(empty)_ | Bottom padding |
| padding | 填充 | — | dim | _(empty)_ | Set both top and bottom padding |

```latex
\begin{表格}[分栏=2]
  \栏格式[行边框=true, 上填充=1em]
  \单元格{first band, bordered}
  \单元格{first band, second cell}

  \栏格式[行边框=false]
  \单元格{second band, no border}
\end{表格}
```

---

## 5. Complete Examples

### 5.1 Basic table

```latex
\begin{正文}[行数=10, 边框=true]
  \begin{表格}[分栏=2, 栏间距=1em, 行边框=true]
    \单元格{世}
    \单元格{字}
    \单元格{名}
    \单元格{某甲}
    \单元格{某乙}
    \单元格{某丙}
  \end{表格}
\end{正文}
```

### 5.2 Band heights

```latex
\begin{表格}[分栏=3, 栏高度={5em,8em,5em}]
  \单元格{short band}
  \单元格{taller middle band}
  \单元格{short band}
\end{表格}
```

### 5.3 Fill the page (`column-fill=page`)

```latex
\begin{表格}[分栏=4, 行填充=页, 行边框=true, 栏边框=true]
  \单元格{fills the whole page height}
  ...
\end{表格}
```

---

## 6. Relation to Bands in BodyText

`\begin{表格}` is an **inline table** embedded in `\begin{正文}` and mixed with the body text.

`\begin{正文}` itself also accepts band parameters for **whole-page banding** (e.g. newspaper layout). The two are different use cases:

| Use case | How | Notes |
|----------|-----|-------|
| Table inside body text | `\begin{表格}[分栏=2]` | The table takes some columns; body text may come before and after |
| Whole page in bands | `\begin{正文}[分栏=2]` | The whole body area is split into bands |

### Band parameters of BodyText

In `\begin{正文}` or `\contentSetup`:

| Parameter | Chinese (S) | Chinese (T) | Type | Default | Description |
|-----------|-------------|-------------|------|---------|-------------|
| n-bands | 分栏 | 分欄 | int | 1 | Number of bands |
| band-gap | 栏间距 | 欄間距 | dim | 0pt | Gap between bands |
| band-mode | 栏模式 | 欄模式 | option | auto | Flow mode: `auto` (cross-page) / `per-page` |
| band-heights | 栏高度 | 欄高度 | list | _(empty)_ | Band heights |
| band-columns | 栏行数 | 欄行數 | string | _(empty)_ | Columns per band |
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border |
| band-border | 栏边框 | 欄邊框 | string | _(empty)_ | Band separator |

### `\换栏` / `\換欄`

Force break to the next band in BodyText band mode.

```latex
\begin{正文}[分栏=2, 栏间距=1em]
  first band…
  \换栏
  second band…
\end{正文}
```

---

👉 Next: [[Side Notes | EN:Side-Note]] or [[Textbox | EN:Textbox]].
