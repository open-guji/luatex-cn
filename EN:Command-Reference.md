English | [中文版](Command-Reference)

# Command Reference

> All user commands, environments and their keys. Each command and key is listed with its English, Simplified Chinese and Traditional Chinese names (identical forms are not repeated; "—" means that form does not exist).

---

## Value Types

The "Type" column uses these names:

| Type | Meaning | Examples |
|------|---------|----------|
| **dim** | A length with a unit: `pt`, `mm`, `cm`, `em` (width of the current font), `ex` (x-height of the current font), `sp` (65536sp = 1pt). | `12pt` `1.5em` `210mm` `0.4cm` |
| **size** | A font size; also a length, usually `pt` or `em` (relative to the base size). | `12pt` `0.8em` `16pt` |
| **color** | A color name (`red` `black` `blue`), 0–1 RGB (`1 0 0` is red) or 0–255 RGB (`255,128,0`). | `red` `1 0 0` `255,128,0` |
| **string** | Free text whose meaning depends on the key. | `grid` `taiwan` `right-bottom` |
| **int** | An integer, usually a number of cells or columns. | `0` `8` `2` |
| **bool** | `true` or `false`. Writing the bare key name means `true`. | `true` `false` (or just `border`) |
| **choice** | One of the listed values. | `top` `center` `bottom` |
| **shortcut** | Sets several related keys at once. | `spacing=5pt` sets `spacing-top` and `spacing-bottom` |

---

# Core Package

The core typesetting engine: page, content area, grid layout, columns, paragraphs, text boxes, styles.

---

## Page

**File**: `core/luatex-cn-core-page.sty`

### `\pageSetup`  `\页面设置`  `\頁面設置`

Page geometry, margins, split pages and so on; synced to the Lua side when called.

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| paper-width | 纸宽 | 紙寬 | dim | 210mm | Paper width |
| paper-height | 纸高 | 紙高 | dim | 297mm | Paper height |
| margin-top | 上边距 | 上邊距 | dim | 0pt | Top margin |
| margin-bottom | 下边距 | 下邊距 | dim | 0pt | Bottom margin |
| margin-left | 左边距 | 左邊距 | dim | 0pt | Left margin (only with `twoside=false`, or `mirror-margins=false`; v0.4.3+) |
| margin-right | 右边距 | 右邊距 | dim | 0pt | Right margin (same as above) |
| background-color | 底色 | 底色 | color | _(empty)_ | Page background |
| footskip | 页脚距 | 頁腳距 | dim | 0pt | Footer offset |
| topskip | 页头距 | 頁頭距 | dim | 0pt | Header offset |
| page-split-enabled | 开启分页 | 開啟分頁 | bool | true | Split-page (tube page) cropping |
| page-split-right-first | 右页优先 | 右頁優先 | bool | true | Output the right half first |
| twoside | — | — | bool | false | Facing pages: `true` reads only `margin-inner` / `margin-outer` (mirrored), `false` reads only `margin-left` / `margin-right`; setting the ignored pair emits a warning (v0.4.3+) |
| margin-inner | — | — | dim | _(empty)_ | Spine-side margin (only with `twoside=true` and `mirror-margins=true`). A vertical book's odd page is a left page with the spine on its right (follows the spine since v0.4.4) |
| margin-outer | — | — | dim | _(empty)_ | Fore-edge margin (same condition) |
| mirror-margins | 镜像边距 | 鏡像邊距 | bool | true | `false`: with `twoside=true` still read `margin-left` / `margin-right`, so the content area stays put on odd and even pages; the running header and page number still alternate (v0.4.4+) |
| binding-offset | 装订边距 | 裝訂邊距 | dim | 0pt | Gutter added on the spine side: right of odd pages, left of even pages; on the right when `twoside=false` (v0.4.4+) |
| facing-pages | 对页补页 | 對頁補頁 | bool | false | When a chapter (`\chapter`) lands at the top of an even page, insert a page before it so every chapter starts on an odd page; only `\chapter` inside a `正文` block counts; not applied in split-page mode (v0.4.4+) |
| blank-page-style | 补页样式 | 補頁樣式 | string | header | Style of inserted pages: `header` (default) keeps the frame, banxin / header and page number; `blank` / `空白` is fully blank (v0.4.4+) |
| header-enabled | 启用页眉 | 啟用頁眉 | bool | false | Running header |
| header-font-size | 页眉字号 | 頁眉字號 | size | 9pt | Header font size |
| page-number-style | 页码样式 | 頁碼樣式 | string | empty (unset) | `digits` (Chinese digit by digit) / `chinese` (Chinese place-value) / `arabic` / `none`. Unset: no vertical page number; the banxin page number uses Chinese place-value numerals |
| page-number-font-size | 页码字号 | 頁碼字號 | size | 9pt | Page number font size |

### `\enableSplitPage`  `\开启分页`  `\開啟分頁`

Turn on split-page (tube page) cropping; accepts key-value options.

### `\disableSplitPage`  `\关闭分页`  `\關閉分頁`

Turn off split-page cropping.

### `\SetPageNumber`  `\设置页码`  `\設置頁碼`

Set the page counter. Syntax: `\SetPageNumber{5}`

### `\ResetPageNumber`  `\重置页码`  `\重置頁碼`

Reset the page number to 1.

### `\换页`  `\換頁`

Force a page break; same as `\newpage`.

### `\InsertBlankPage`  `\补空白页`  `\補空白頁`

Insert a page here (v0.4.4+). Works inside a `正文` block and between blocks; two in a row give two pages; right after `\换页` it does not add an extra one. The optional `blank-page-style` (`补页样式`) applies to this page only: `\补空白页[补页样式=空白]`.

### Environment `Page`  `页`

Temporarily change page keys (paper size, margins…); restored at the end of the environment. Accepts every page key.

---

## Content Area

**File**: `core/luatex-cn-core-content.sty`

### `\contentSetup`  `\内容设置`  `\內容設置`

All layout keys of the body area: grid size, font, columns, borders, layout mode…

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| n-column | 行数 | 行數 | int | 8 | Columns per half page ("行" means a vertical column); 0 = free column width |
| n-char-per-col | 每行字数 | 每行字數 | int | 0 | Characters per column (0 = auto) |
| grid-width | 格宽 | 格寬 | dim | 1.5em | Cell width |
| grid-height | 格高 | 格高 | dim | 1.2em | Cell height |
| font-size | 字号 | 字號 | size | 12pt | Body font size |
| font | 字体 | 字體 | string | _(empty)_ | Body font name |
| font-features | 字体特性 | 字體特性 | string | _(empty)_ | OpenType features |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Body text color |
| vertical-align | 纵对齐 | 縱對齊 | string | center | Vertical alignment of a glyph in its cell |
| horizontal-align | 横对齐 | 橫對齊 | choice | right | Horizontal position of the column block in the content area: `right` (default, set from the right), `center`, `left`; Chinese values `居右` / `居中` / `居左` also work. Alias `h-align` (v0.4.5+, #175) |
| height | 高度 | 高度 | dim | _(auto)_ | Content height |
| layout-mode | 布局模式 | 佈局模式 | choice | grid | `grid` or `natural` |
| spacing-col | — | — | dim | _(empty)_ | Column spacing (the Chinese `行间距` now means `column-spacing`, below) |
| line-spacing | 行距 | 行距 | dim | \baselineskip | Line spacing (natural mode) |
| page-columns | 版面行数 | 版面行數 | string | _(empty)_ | Columns-per-page override |
| banxin-ratio | 版心比例 | 版心比例 | string | 0.7 | Banxin width relative to a column (0–1) |
| border | 边框 | 邊框 | bool | false | Column rules |
| border-thickness | 边框粗细 | 邊框粗細 | dim | 0.4pt | Rule width |
| border-color | 边框色 | 邊框色 | color | black | Rule color |
| padding-top | 上填充 | — | dim | 0pt | Space above the rules (alias `column-padding-top` / `栏上填充`) |
| padding-bottom | 下填充 | — | dim | 0pt | Space below the rules (alias `column-padding-bottom` / `栏下填充`) |
| outer-border | 外边框 | 外邊框 | bool | false | Outer frame |
| outer-border-thickness | 外边框粗细 | 外邊框粗細 | dim | 1pt | Outer frame width |
| outer-border-sep | 外边框间距 | 外邊框間距 | dim | 2pt | Gap between outer frame and rules |
| inter-cell-gap | 字间隙 | 字間隙 | dim | 0pt | Extra gap between cells |
| cell-height | 字格高 | 字格高 | dim | _(empty)_ | Cell height override |
| cell-width | 字格宽 | 字格寬 | dim | _(empty)_ | Cell width override |
| cell-gap | 字格间距 | 字格間距 | dim | _(empty)_ | Cell gap override |
| auto-column-width | 自动行宽 | 自動行寬 | bool | false | Compute column widths automatically |
| column-spacing-top | 行上间距 | 行上間距 | dim | 0pt | Space at the top of a column |
| column-spacing-bottom | 行下间距 | 行下間距 | dim | 0pt | Space at the bottom of a column |
| column-spacing | 行间距 | 行間距 | shortcut | — | Both of the above |
| paragraph-spacing | 段间距 | 段間距 | dim | 0pt | Paragraph spacing |
| n-bands | 分栏 | 分欄 | int | 1 | Number of bands (horizontal sections) |
| band-gap | 栏间距 | 欄間距 | dim | 0pt | Gap between bands |
| band-mode | 栏模式 | 欄模式 | choice | auto | `auto` (flows across pages) / `per-page` |
| band-heights | 栏高度 | 欄高度 | list | _(empty)_ | Band heights, comma separated |
| band-columns | 栏行数 | 欄行數 | string | _(empty)_ | Columns per band |
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column (rule) border |
| band-border | 栏边框 | 欄邊框 | string | _(empty)_ | Separator between bands |
| digital-mode | 数字模式 | 數字模式 | bool | false | Digitization mode (obeylines, one source line = one column) |
| ignore-spaces | 忽略空格 | — | bool | true | Ignore ASCII spaces in the source |
| indent | 缩进 | 縮進 | int | _(empty)_ | Indent of non-first lines (cells) |
| first-indent | 首行缩进 | 首行縮進 | int | _(empty)_ | First-line indent (cells) |

> **Note**: unknown keys are forwarded to the page keys.

### `\Content`  `\内容`  `\內容`

Hand text to the grid engine. Syntax: `\Content[keys]{text}`; accepts every content key.

### `\Space`  `\空格`

Insert N full-width spaces (U+3000). Syntax: `\Space[3]`

### `\MissingChar`  `\缺字`

Insert white squares □ (U+25A1) as placeholders for missing or illegible characters. Syntax: `\缺字` or `\缺字[3]`.

### `\Sideways`  `\横置`  `\橫置`

Rotate a Western string 90° clockwise inside a vertical column (clreq). Letters keep word spacing, share one baseline and are centred in the column. Syntax: `\横置{LuaTeX}`. For longer words; short strings stay upright one letter per cell (default).

### `\CombineUpright`  `\中横排`  `\中橫排`

Set two or three digits or a very short Western string horizontally in one cell (tate-chu-yoko). The group takes one cell and never breaks; beyond 1em it is only compressed horizontally. Syntax: `\中横排{12}`, e.g. `\中横排{12}月`.

### Environment `BodyText`  `正文`

Environment form of `\Content`; accepts every content key.
```latex
\begin{正文}[行数=10, 格高=1.5em]
  body text…
\end{正文}
```

### Environment `CenteredPage`  `居中页`  `居中頁`  <sup>v0.4.5+</sup>

For title and volume pages: breaks the page before and after, sets the text on a new page and centres the column block horizontally in the content area (i.e. `正文[horizontal-align=center]`). Place each column vertically with `\行[align=center]`; the optional argument goes to the body, e.g. `[horizontal-align=left]`. Do not nest it in another `正文`. (#175)

```latex
\begin{居中页}
  \行[align=center]{王又朴集}
  \行[align=center]{上}
\end{居中页}
```

### `\NewHalfPage`  `\换半页`  `\換半頁`  <sup>v0.3.6+</sup>

Jump to the next half page in split-page mode.

### `\IllustrationPage`  `\插图页`  `\插圖頁`  <sup>v0.3.6+</sup>

Mark the page as an illustration page: column rules are hidden (outer frames kept), after a half-page break. For full-page illustrations.

### `\EndIllustrationPage`  `\恢复丝栏`  `\恢復絲欄`  <sup>v0.3.6+</sup>

End `\插图页` and restore the column rules; usually after `\clearpage`.

---

## Style

**File**: `core/luatex-cn-core-style.sty`

### `\Style`  `\样式`  `\樣式`

Inline style override of font size, font, color, cell height and spacing, without changing the layout mode.

Syntax: `\Style[font-size=16pt, font-color=red]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| font-size | 字号 | 字號 | size | _(empty)_ | Font size |
| font | 字体 | 字體 | string | _(empty)_ | Font |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Text color |
| grid-height | 格高 | 格高 | dim | _(empty)_ | Cell height |
| grid-width | 格宽 | 格寬 | dim | _(empty)_ | Cell width |
| spacing-top | 上间距 | 上間距 | dim | _(empty)_ | Extra space above |
| spacing-bottom | 下间距 | 下間距 | dim | _(empty)_ | Extra space below |
| spacing | 间距 | 間距 | shortcut | — | Both of the above |
| xshift | 横移 | 橫移 | dim | _(empty)_ | X shift |
| yshift | 纵移 | 縱移 | dim | _(empty)_ | Y shift |
| padding-top | 上填充 | — | dim | _(empty)_ | Top padding |
| padding-bottom | 下填充 | — | dim | _(empty)_ | Bottom padding |
| padding | 填充 | — | shortcut | — | Both paddings |
| indent | 缩进 | 縮進 | int | _(empty)_ | Indent of non-first lines (cells) |
| first-indent | 首行缩进 | 首行縮進 | int | _(empty)_ | First-line indent (cells) |
| bottom-indent | 末行缩进 | 末行縮進 | int | _(empty)_ | Cells left empty at the end of each column |

### Environment `StyleEnv`  `样式设置`  `樣式設置`

Environment form of `\Style`; commands inside the content are expanded.

---

## Column

**File**: `core/luatex-cn-core-column.sty`

### `\Column`  `\行`

Set content as one vertical column, with alignment control.

Syntax: `\Column[align=center, font-size=16pt]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| align | 对齐 | 對齊 | choice | top | `top` `bottom` `center` `stretch` |
| last | 末行 | 末行 | bool | false | Put it in the last column of the half page |
| font-size | 字号 | 字號 | size | _(empty)_ | Font size |
| font | 字体 | 字體 | string | _(empty)_ | Font |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Text color (alias `color` / `颜色` / `顏色`) |
| width | 宽度 | 寬度 | dim | _(empty)_ | Column width |
| column-width | 行宽 | 行寬 | dim | _(empty)_ | Column width (alias) |
| auto-width | 自动宽度 | 自動寬度 | bool | true | Automatic width |
| width-scale | 宽度缩放 | 寬度縮放 | string | 1.2 | Scale for the automatic width |
| spacing-top | 上间距 | 上間距 | dim | _(empty)_ | Space above |
| spacing-bottom | 下间距 | 下間距 | dim | _(empty)_ | Space below |
| spacing | 间距 | 間距 | shortcut | — | Both of the above |
| padding-top | 上填充 | — | dim | _(empty)_ | Top padding inside the column |
| padding-bottom | 下填充 | — | dim | _(empty)_ | Bottom padding inside the column |
| padding | 填充 | — | shortcut | — | Both paddings |
| grid-height | 格高 | 格高 | dim | _(empty)_ | Cell height |

### `\LastColumn`  `\末行`

Put the content in the last column of the current half page; same as `\Column[last]{text}`.

---

## TextFlow

**File**: `core/luatex-cn-core-textflow.sty`

### `\TextFlow`  `\文本流`

Two-line small notes (jiazhu): the content is split into a right and a left sub-column.

Syntax: `\TextFlow[font-size=8pt]{note}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| only-column | 单列 | 單列 | choice | none | Single sub-column: `none` (two) `right` `left` |
| auto-balance | 自动均衡 | 自動均衡 | bool | true | Balance the two sub-columns (also `自动平衡` / `自動平衡`) |
| font-size | 字号 | 字號 | size | _(empty)_ | Font size |
| font | 字体 | 字體 | string | _(empty)_ | Font |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Text color (alias `color` / `颜色` / `顏色`) |
| align | 对齐 | 對齊 | string | _(empty)_ | Alignment |
| grid-height | 格高 | 格高 | dim | _(empty)_ | Small-type cell height |
| n-char-per-col | 每行字数 | 每行字數 | int | _(empty)_ | Characters per sub-column; cell height = column height ÷ N (v0.4.4+, #82) |

### `\DanHangJiaZhu`  `\单行夹注`  `\單行夾注`

Single-line jiazhu. Syntax: `\DanHangJiaZhu[right]{text}`; the option is `right` (default) or `left`, i.e. only the right or left sub-column.

### Environment `TextFlowEnv`  `文本流环境`  `文本流環境`

Environment form of `\TextFlow`.

---

## TextBox

**File**: `core/luatex-cn-core-textbox.sty`

### `\TextBox`  `\文本框`

Multi-column grid text box with borders, floating placement, background color…

Syntax: `\TextBox[height=5, border, background-color=yellow]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| height | 高度 | 高度 | int | 0 | Height (cells) |
| n-cols | 列数 | 列數 | int | 0 | Inner columns |
| outer-cols | 外列数 | 外列數 | int | 0 | Columns taken outside |
| fill | 填充 | 填充 | shortcut | — | Spread the content evenly (= `box-align=fill`) |
| box-align | 框对齐 | 框對齊 | string | top | Alignment of the box in its column |
| border | 边框 | 邊框 | bool | false | Border |
| border-shape | 边框形状 | 邊框形狀 | choice | none | `none` `rect` `octagon` `circle` |
| border-color | 边框色 | 邊框色 | color | _(empty)_ | Border color |
| border-width | 边框宽 | 邊框寬 | dim | 0.4pt | Border width |
| border-margin | 边框间距 | 邊框間距 | dim | 0pt | Border-to-content gap |
| border-margin-x | 边框横距 | 邊框橫距 | dim | _(empty)_ | Horizontal gap |
| border-margin-y | 边框纵距 | 邊框縱距 | dim | _(empty)_ | Vertical gap |
| border-offset | — | — | dim | 0pt | Distance of the border outside the background (`\墨围反白` uses 0.1em for a white gap) |
| outer-margin | 外间距 | 外間距 | dim | 0pt | Outer margin |
| outer-border | 外边框 | 外邊框 | bool | false | Outer frame |
| outer-border-thickness | 外边框粗细 | 外邊框粗細 | dim | 1pt | Outer frame width |
| outer-border-sep | 外边框间距 | 外邊框間距 | dim | 2pt | Gap between outer frame and border |
| banxin | 版心 | 版心 | bool | — | Banxin rule |
| column-align | 列对齐 | 列對齊 | string | _(empty)_ | Inner column alignment |
| vertical-align | 纵对齐 | 縱對齊 | string | _(empty)_ | Vertical alignment (alias of box-align) |
| floating | 悬浮 | 懸浮 | bool | false | Floating placement |
| floating-paper-width | 悬浮纸宽 | 懸浮紙寬 | dim | 0pt | Paper width in floating mode |
| x | 横坐标 | 橫坐標 | dim | 0pt | Floating X |
| y | 纵坐标 | 縱坐標 | dim | 0pt | Floating Y |
| background-color | 底色 | 底色 | color | _(empty)_ | Background |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Text color (alias `color` / `颜色`) |
| font-size | 字号 | 字號 | size | _(empty)_ | Font size |
| grid-width | 格宽 | 格寬 | dim | _(empty)_ | Inner cell width |
| grid-height | 格高 | 格高 | dim | _(empty)_ | Inner cell height |
| padding-top | — | — | dim | _(empty)_ | Top padding (alias `column-padding-top`, `fill-padding-top`) |
| padding-bottom | — | — | dim | _(empty)_ | Bottom padding (alias `column-padding-bottom`, `fill-padding-bottom`) |
| transparent | 透明 | 透明 | bool | true | Transparent background (`false` fills with the page background; v0.3.6+) |

### `\textboxSetup`  `\文本框设置`  `\文本框設置`

Default keys for every later `\TextBox`.

### `\FloatingTextBox`  `\悬浮文本框`

Floating text box; same as `\TextBox[floating=true, …]{text}`, placed with `x` / `y`.

### `\FillTextBox`  `\填充文本框`

Backward-compatible text box: an integer height (old style) or key-value options. See [[Textbox | EN:Textbox]].

### `\反白`  `\inverted`

White text on a dark background. Syntax: `\反白[keys]{text}`

`\反白`, `\墨围反白` and `\八角墨围反白` are inline by default (v0.4.4+): across a column break they continue character by character, and the background and border are drawn per run in each column. The inline implementation accepts the keys below; other text-box keys (such as `高度`, `填充`) fall back to a single text box that cannot break, with a warning in the log (v0.4.5+).

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| font-color | 字体颜色 | 字體顏色 | color | white | Text color (alias `color` / `颜色` / `顏色`) |
| background-color | 底色 | 底色 | color | 0.2 0.2 0.2 | Background |
| border-color | 边框色 | 邊框色 | color | _(empty)_ | Border color |
| border-width | 边框宽 | 邊框寬 | dim | 0.4pt | Border width |
| break | 断口 | 斷口 | choice | square | Corner shape at a column break: `square` (`直角`) or `octagon` (`八角`, every run a full octagon) |
| border-shape | 边框形状 | 邊框形狀 | choice | — | `none` / `rect` / `octagon` stay inline (v0.4.5+, #210); `circle` falls back to a single box |
| inline | 可断行 | 可斷行 | bool | true | `false` deliberately uses the single text box, without a warning |

### `\墨围`  `\bordered`  `\墨圍`

Thin rectangular frame for labels such as 索隱 or 集解. Syntax: `\墨围{text}`

### `\牌记`  `\colophon`  <sup>v0.3.6+</sup>

Colophon: an opaque, double-framed floating text box for colophon pages.

Syntax: `\牌记[key=value]{text}`

### `\墨围反白`  `\borderedInverted`  `\墨圍反白`

Rectangular black frame + white on black. Syntax: `\墨围反白{text}`

### `\八角墨围`  `\octagonBordered`  `\octagon`  `\八角墨圍`

Octagonal black frame. Syntax: `\八角墨围{text}`

### `\八角墨围反白`  `\octagonBorderedInverted`  `\八角墨圍反白`

Octagonal black frame + white on black. Syntax: `\八角墨围反白{text}`

### `\带圈`  `\circled`  `\帶圈`

Circle. Syntax: `\带圈{text}`

> The frames of 墨围, 八角墨围 and 带圈 scale with the surrounding font size (v0.4.4+).

---

## Table <sup>v0.3.4+</sup>

**File**: `core/luatex-cn-core-table.sty`

### Environment `Table`  `表格`

Inline table, used inside `\begin{正文}`. See [[Table | EN:Table]].

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| n-bands | 分栏 | 分欄 | int | 2 | Number of bands |
| band-gap | 栏间距 | 欄間距 | dim | 0pt | Gap between bands |
| band-heights | 栏高度 | 欄高度 | list | _(empty)_ | Band heights, comma separated |
| n-columns | 行数 | 行數 | string | _(empty)_ | Columns per band |
| header-rows | 表头栏数 | 表頭欄數 | int | 0 | Header bands |
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border style |
| band-border | 栏边框 | 欄邊框 | string | _(empty)_ | Separator between bands |
| column-fill | 行填充 | 行填滿 | string | _(empty)_ | Fill mode: `page` (`页` / `頁`) |

### `\Cell`  `\单元格`  `\單元格`

Table cell. Syntax: `\Cell[col-width=2]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| col-width | 行宽 | 行寬 | number | 1 | Column span (decimals allowed) |
| vertical-align | 纵对齐 | 縱對齊 | string | _(empty)_ | Vertical alignment |
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border of this cell |

### `\BandFormat`  `\栏格式`  `\欄格式`

Format of the current band; before its first `\Cell`.

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| column-border | 行边框 | 行邊框 | string | _(empty)_ | Column border of this band |
| padding-top | 上填充 | — | dim | _(empty)_ | Top padding |
| padding-bottom | 下填充 | — | dim | _(empty)_ | Bottom padding |
| padding | 填充 | — | dim | _(empty)_ | Both paddings |

### `\换栏`  `\換欄`

Force a break to the next band in body band mode.

---

## Paragraph

**File**: `core/luatex-cn-core-paragraph.sty`

### Environment `Paragraph`  `段落`

Block indentation with first-line, hanging and last-line indents.

```latex
\begin{段落}[缩进=2, 首行缩进=0]
  first column indented 0 cells…\\
  following columns indented 2 cells…
\end{段落}
```

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| indent | 缩进 | 縮進 | int | 0 | Base indent (cells) |
| first-indent | 首行缩进 | 首行縮進 | int | _(empty)_ | First-line indent (empty = follow indent) |
| bottom-indent | 末行缩进 | 末行縮進 | int | 0 | Cells left empty at the end of each column |

The environment also accepts every `\Style` key.

### `\Indent`  `\缩进`  `\縮進`

Force the indent of the current line; restored at `\\` or the end of the line. A negative value acts like taitou (into the top margin).

Syntax: `\缩进[3]` (default 0)

### `\抬头`  `\TaiTou`

Start a new column raised by N cells. N=0 is 平抬; N>0 reaches into the top margin.

Syntax: `\抬头[2]`

| Shortcut | English | Same as |
|----------|---------|---------|
| `\平抬` | `\PingTai` | `\抬头[0]` |
| `\单抬`  `\單抬` | `\DanTai` | `\抬头[1]` |
| `\双抬`  `\雙抬` | `\ShuangTai` | `\抬头[2]` |
| `\三抬` | `\SanTai` | `\抬头[3]` |

### `\挪抬`  `\NuoTai`

Insert N full-width spaces in place, without a column break.

Syntax: `\挪抬[2]`

| Shortcut | English | Same as |
|----------|---------|---------|
| `\空抬` | `\KongTai` | `\挪抬[1]` |

### `\相对抬头`  `\XiangDuiTaiTou`  `\相對抬頭`

Raise by N cells relative to the current indent: with indent=2, `\相对抬头[3]` gives indent=-1 (one cell into the top margin).

### `\换行`  `\HuanHang`  `\換行`

Force a column break.

---

## Sidenote

**File**: `core/luatex-cn-core-sidenote.sty`

### `\Sidenote`  `\侧批`  `\側批`

Side note between columns. Pinyin alias `\CePi`.

Syntax:
- Basic: `\Sidenote{note}`
- Positional shift: `\Sidenote[5pt]{note}` is `\Sidenote[yshift=5pt]{note}`
- Plain numbers are em: `\Sidenote[0.5]{note}` is `\Sidenote[0.5em]{note}`
- Named keys: `\Sidenote[yshift=5pt, color=blue]{note}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| sidenote | 侧批 | 側批 | bool | true | Output side notes <sup>v0.3.6+</sup> |
| yshift | 纵移 | 縱移 | dim | 0pt | Vertical shift (also positional) |
| xshift | 横移 | 橫移 | dim | 0pt | Horizontal shift <sup>v0.3.5+</sup> |
| grid-height | 格高 | 格高 | dim | _(empty)_ | Cell height (default = font size) |
| font-size | 字号 | 字號 | size | 10pt | Font size |
| color | 颜色 | 顏色 | color | red | Color (alias `font-color` / `字体颜色` / `字體顏色`) |
| background-color | 底色 | 背景色 | color | _(empty)_ | Background (Simplified also `背景色`) |
| column-padding-top | 栏上填充 | — | dim | 0pt | Top padding |
| column-padding-bottom | 栏下填充 | — | dim | 0pt | Bottom padding |

Punctuation keys such as `punct-mode` (`标点模式`) can also be given to a single side note, e.g. `\侧批[标点模式=judou]{…}`.

### `\sidenoteSetup`  `\侧批设置`  `\側批設置`

Default side-note keys.

---

## Footnote

**File**: `core/luatex-cn-footnote.sty`

### `\Footnote`  `\脚注`  `\腳注`

Insert a footnote. Mode 1 (endnote): stored and output by `\FlushFootnote`. Mode 2 (page): registered on the Lua side and output when the page is rendered.

Syntax: `\Footnote{note}`

### `\FlushFootnote`  `\输出脚注`  `\輸出腳注`

Output all stored notes and reset the counter. Mode 1 only.

### `\footnoteSetup`  `\脚注设置`  `\腳注設置`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| mode | 模式 | 模式 | choice | endnote | `endnote` or `page` |
| number-style | 编号样式 | 編號樣式 | choice | lujiao | `lujiao` (【一】) or `circled` (①) |
| separator | 分隔符 | 分隔符 | choice | blank | Gap between notes: `blank` (1em) `none` |
| font | 字体 | 字體 | string | _(empty)_ | Font |
| font-size | 字号 | 字號 | size | 0.8em | Font size (relative to the body) |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Color |
| indent | 缩进 | 縮進 | int | 2 | Hanging indent (cells) |
| spacing | 间距 | 間距 | dim | 0.5em | Spacing |
| marker-height | 序号高度 | 序號高度 | int | 2 | Cells taken by the number |
| counter-start | 起始编号 | 起始編號 | int | _(empty)_ | Start value |

### `\FootnoteParagraph`  `\脚注段落`  `\腳注段落`

Unnumbered note block (e.g. 索隱曰, 正義曰).

Syntax: `\FootnoteParagraph{索隱紀者記也……}`

### `\ResetFootnoteCounter`  `\重置脚注计数`  `\重置腳注計數`

Reset the counter (for per-page numbering in mode 2).

---

## Metadata

**File**: `core/luatex-cn-core-metadata.sty`

### `\metadataSetup`  `\元数据设置`  `\元數據設置`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| book-name | 书名 | 書名 | string | _(empty)_ | Book title |
| chapter-title | 章节标题 | 章節標題 | string | _(empty)_ | Chapter title |
| publisher | 出版商 | 出版商 | string | _(empty)_ | Publisher |

### `\title`

Set the book title (synced to the banxin and metadata).

### `\publisher`  `\出版商`

Set the publisher.

### `\ChapterMarker`  `\章节标记`  `\章節標記`

Insert a chapter marker; the banxin chapter title updates on later pages.

### `\chapter`  `\卷`

Set the chapter title and reset the page number. <sup>v0.3.5+</sup> An optional argument separates the banxin title from the body title.

- `\chapter{title}`: set the title and print it
- `\chapter*{title}`: metadata only
- `\chapter[banxin]{body}`: banxin shows "banxin", the body prints "body"
- `\chapter*[banxin]{body}`: set the banxin, print nothing

### `\section`  <sup>v0.3.5+</sup>

Section title. `\section{title}` / `\section*{title}` (starred: metadata only).

### `\subsection`  <sup>v0.3.5+</sup>

Subsection title. `\subsection{title}` / `\subsection*{title}`.

### `\sectionSetup`  `\标题设置`  `\標題設置`  <sup>v0.3.5+</sup>

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| chapter-indent | 章节缩进 | 章節縮進 | int | 0 | Chapter title indent (cells) |
| chapter-font-size | 章节字号 | 章節字號 | size | _(empty)_ | Chapter font size |
| chapter-font-color | 章节字体颜色 | 章節字體顏色 | color | _(empty)_ | Chapter color |
| chapter-font | 章节字体 | 章節字體 | string | _(empty)_ | Chapter font |
| chapter-spacing-top | — | — | dim | _(empty)_ | Extra space before chapters |
| section-indent | 篇缩进 | — | int | 1 | Section indent |
| section-font-size | 篇字号 | — | size | _(empty)_ | Section font size |
| section-font-color | 篇字体颜色 | — | color | _(empty)_ | Section color |
| section-font | 篇字体 | — | string | _(empty)_ | Section font |
| section-spacing-top | — | — | dim | _(empty)_ | Extra space before sections |
| subsection-indent | 节缩进 | 節縮進 | int | 2 | Subsection indent |
| subsection-font-size | 节字号 | 節字號 | size | _(empty)_ | Subsection font size |
| subsection-font-color | 节字体颜色 | 節字體顏色 | color | _(empty)_ | Subsection color |
| subsection-font | 节字体 | 節字體 | string | _(empty)_ | Subsection font |
| subsection-spacing-top | — | — | dim | _(empty)_ | Extra space before subsections |

---

## Component-level Settings

**File**: `core/luatex-cn-core-settings.sty`

There is no global settings command (the `\GlobalSettings` / `\全局设置` shown in older versions of this wiki does not exist). These keys can be given to side notes, annotations, marginal notes, text boxes, `\样式` and so on, and apply to that component only:

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| punct-mode | 标点模式 | 標點模式 | choice | _(empty)_ | `normal` `judou` `none` |
| punct-style | 标点标准 | 標點標準 | choice | _(empty)_ | `mainland` `taiwan` |
| debug | 调试 | 調試 | bool | _(empty)_ | Debug output |

Switch the document-wide mode with `\正常标点模式` / `\句读模式` / `\无标点模式` (see Judou below) and the style with `\标点设置{标点风格=…}`.

## Document Style

**File**: `core/luatex-cn-core-document.sty`

### `\documentSetup`  `\文档设置`  `\文檔設置`

Document-level default style (the bottom of the style stack), used wherever a component sets nothing. English keys only:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| font-color | color | _(empty)_ | Text color |
| font-size | size | _(empty)_ | Font size |
| font | string | _(empty)_ | Font |
| background-color | color | _(empty)_ | Page background |

---

## Punctuation

**File**: `core/luatex-cn-core-punct.sty`

### `\punctSetup`  `\标点设置`  `\標點設置`

Modern punctuation rules. See [[Punctuation | EN:Punctuation]].

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| punct-style | 标点风格 | 標點風格 | choice | taiwan | `taiwan` `mainland` |
| punct-squeeze | 标点压缩 | 標點壓縮 | bool | true | Squeeze consecutive punctuation |
| punct-hanging | 标点悬挂 | 標點懸掛 | bool | false | Hanging punctuation |
| kinsoku | 禁则 | 禁則 | bool | true | Line-breaking rules |
| western-space | 中西间距 | 中西間距 | bool | true | 1/4em between Chinese and Western text |
| style | 风格预设 | 風格預設 | choice | — | clreq preset: `mainland` `taiwan` `none` (same names and values as horizontal mode) |
| squeeze-mode | 宽度调整 | 寬度調整 | choice | legacy | `legacy` or `context` (context-sensitive) |
| adjacent-punct | 连续标点 | 連續標點 | choice | 1.5 | Combined width of adjacent punctuation: `1.5` `1` `natural` |
| line-start-bracket | — | — | choice | trim | Opening bracket or quote at a column start: `trim` (half) `natural` |
| line-end-punct | — | — | choice | compress | Stop at a column end: `compress` (half) `natural` |

### `\大陆标点风格`  `\DaLuBiaoDianFengGe`  `\大陸標點風格`

Switch to mainland punctuation style.

### `\台湾标点风格`  `\TaiWanBiaoDianFengGe`  `\臺灣標點風格`

Switch to Taiwan punctuation style.

---

# Guji Package

Features for classical books: judou, jiazhu, annotations, marginal notes, seals, title page, cover, table of contents entries.

---

## Guji Class

**File**: `ltc-guji.cls`

### `\gujiSetup`  `\古籍设置`  `\古籍設置`

Configuration of the guji class; currently one key:

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| template | — | — | string | — | Load a template |

Set the layout with `\pageSetup`, `\contentSetup`, `\banxinSetup` and so on.

**Built-in templates**:

| English | Simplified | Traditional |
|---------|-----------|-------------|
| default | 四库全书 | 四庫全書 |
| SiKuQuanShu-colored | 四库全书彩色 | 四庫全書彩色 |
| HongLouMengJiaXuBen | 红楼梦甲戌本 | 紅樓夢甲戌本 |
| oushizupu | 欧式族谱 | 歐式族譜 |

Chinese template names work only as class options, e.g. `\documentclass[四库全书彩色]{ltc-guji}`; write the English name in `\gujiSetup{template=…}`.

### `\defineGujiTemplate`  `\定义古籍模板`  `\定義古籍模板`

Define a template name for `\gujiSetup`. Note: the body is parsed with the `\gujiSetup` keys, which currently means only `template`; layout keys such as `n-column` give an unknown-key error. Use a configuration file for custom layouts (see [[Templates | EN:Templates]]).

---

## Judou

**File**: `guji/luatex-cn-guji-judou.sty`

### `\judouSetup`  `\句读设置`  `\句讀設置`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| judou-pos | 句读位置 | 句讀位置 | string | right-bottom | Mark position |
| judou-size | 句读大小 | 句讀大小 | size | 1em | Mark size |
| judou-color | 句读颜色 | 句讀顏色 | color | red | Mark color (alias `color` / `font-color` / `颜色` / `字体颜色`) |
| punct-mode | 标点模式 | 標點模式 | choice | normal | Punctuation mode |

### `\NormalPunctuationMode`  `\正常标点模式`  `\关闭句读模式`  `\正常標點模式`

Modern punctuation.

### `\JudouPunctuationMode`  `\句读模式`  `\开启句读模式`  `\句讀模式`

Judou marks.

### `\NonePunctuationMode`  `\无标点模式`  `\开启无标点模式`  `\無標點模式`

Remove all punctuation.

---

## JiaZhu

**File**: `guji/luatex-cn-guji-jiazhu.sty`

### `\JiaZhu`  `\夹注`  `\夾注`

Two-line small notes. Syntax: `\JiaZhu[font-size=8pt]{note}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| font-size | 字号 | 字號 | size | _(empty)_ | Font size |
| font | 字体 | 字體 | string | _(empty)_ | Font |
| font-color | 字体颜色 | 字體顏色 | color | _(empty)_ | Color (alias `color` / `颜色`) |
| align | 对齐 | 對齊 | string | outward | Alignment |
| grid-height | 格高 | 格高 | dim | _(empty)_ | Cell height (default from the font size) |
| n-char-per-col | 每行字数 | 每行字數 | int | _(empty)_ | Characters per sub-column; cell height = column height ÷ N; `grid-height` wins if both are given (v0.4.4+) |

### `\jiazhuSetup`  `\夹注设置`  `\夾注設置`

Default jiazhu keys (all of the above, including `n-char-per-col`).

### Environment `JiaZhuEnv`  `夹注环境`  `夾注環境`

Environment form.

### `\jiazhuShortcut`  `\夹注捷径`  `\夾注捷徑`

Register a bracket pair as jiazhu shorthand; matching pairs in the source become `\夹注{...}`.

- `\jiazhuShortcut`: registers `【...】`
- `\jiazhuShortcut{（}{）}`: custom pair
- `\jiazhuShortcut[font-color=red]{（}{）}`: with style keys

The optional argument accepts every jiazhu key.

---

## PiZhu (Annotation)

**File**: `guji/luatex-cn-guji-pizhu.sty`

### `\PiZhu`  `\批注`

Floating annotation box. Syntax: `\PiZhu[x=5cm, y=3cm]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| pizhu | 批注 | 批註 | bool | true | Output annotations <sup>v0.3.6+</sup> |
| x | 横坐标 | 橫坐標 | dim | _(empty)_ | X |
| y | 纵坐标 | 縱坐標 | dim | _(empty)_ | Y |
| height | 高度 | 高度 | int | _(empty)_ | Height (cells) |
| font-size | 字号 | 字號 | size | 18pt | Font size |
| color | 颜色 | 顏色 | color | 1 0 0 | Color (alias `font-color` / `字体颜色`) |
| grid-width | 格宽 | 格寬 | dim | 20pt | Cell width |
| grid-height | 格高 | 格高 | dim | 19pt | Cell height |

### `\pizhuSetup`  `\批注设置`  `\批注設置`

Default annotation keys.

---

## MeiPi (Marginal Note)

**File**: `guji/luatex-cn-guji-meipi.sty`

### `\MeiPi`  `\眉批`

Automatically placed note in the top margin.

Syntax: `\MeiPi[font-size=14pt]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| meipi | 眉批 | 眉批 | bool | true | Output marginal notes <sup>v0.3.6+</sup> |
| x | 横坐标 | 橫坐標 | dim | _(empty)_ | X override |
| y | 纵坐标 | 縱坐標 | dim | _(empty)_ | Y override |
| height | 高度 | 高度 | int | 7 | Height (cells) |
| font-size | 字号 | 字號 | size | 18pt | Font size |
| color | 颜色 | 顏色 | color | 1 0 0 | Color (alias `font-color` / `字体颜色`) |
| grid-width | 格宽 | 格寬 | dim | 20pt | Cell width |
| grid-height | 格高 | 格高 | dim | 19pt | Cell height |
| spacing | 间距 | 間距 | dim | 10pt | Spacing |
| gap | 间隔 | 間隔 | dim | 0pt | Extra gap |

### `\meipiSetup`  `\眉批设置`  `\眉批設置`

Default marginal-note keys.

---

## YinZhang (Seal)

**File**: `guji/luatex-cn-guji-yinzhang.sty`

### `\YinZhang`  `\印章`

Overlay a seal image on a given page.

Syntax: `\YinZhang[opacity=0.5, page=2]{seal.png}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| opacity | 不透明度 | 不透明度 | string | 1 | Opacity (0–1) |
| xshift | 横移 | 橫移 | dim | 0cm | Horizontal shift |
| yshift | 纵移 | 縱移 | dim | 0cm | Vertical shift |
| width | 宽度 | 寬度 | dim | 10cm | Seal width |
| page | 页 | 頁 | int | 1 | Target page |
| color | 颜色 | 顏色 | color | _(empty)_ | Tint |

`\yinzhangSetup` (`\印章设置` / `\印章設置`) sets defaults for these keys.

---

## TitlePage

**File**: `guji/luatex-cn-guji-titlepage.sty`

### Environment `TitlePage`  `书名页`  `書名頁`

Title page with automatic column layout.

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| border | 边框 | 邊框 | bool | false | Border |
| outer-border | 外边框 | 外邊框 | bool | false | Outer frame |

---

## SinglePage

**File**: `guji/luatex-cn-guji-danye.sty`

### Environment `SinglePage`  `单页`  `單頁`

A single (half) page: paper width and margins halved automatically. No own keys; takes the page keys.

### Environment `EmptySinglePage`  `空白页`  `空白頁`

A single page with no rules and no outer frame; the content may be empty. `\begin{空白页}[keys] … \end{空白页}`.

---

## Cover

**File**: `guji/luatex-cn-guji-cover.sty`

### Environment `Cover`  `封面`

Cover page; borders and banxin off.

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| background-color | 底色 | 底色 | color | _(empty)_ | Cover background |

### `\ThreadBoundCover`  `\线装书封面`  `\線裝書封面` (v0.4.3+)

One page of the modern blue thread-bound cover (uses `\begin{Cover}` inside). Syntax: `\线装书封面[keys]{title}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| volume | 册次 | 冊次 | text | _(empty)_ | Small type at the label foot, e.g. 第一冊 |
| juan | 卷次 | 卷次 | text | _(empty)_ | e.g. 卷一; set beside the volume |
| small-position | 小字位置 | 小字位置 | bottom / follow | bottom | `底部` / `随后` (`隨後`): small type at the label foot or right after the title |
| binding-thread | 订线 | 訂線 | bool | false | Draw the binding thread (preview) |
| thread-holes | 订线眼数 | 訂線眼數 | int | 4 | Number of holes (4 or 6) |
| thread-distance | 订线距 | 訂線距 | dim | page width × 0.08 | Thread distance from the right edge |
| thread-color | 订线颜色 | 訂線顏色 | color | 236, 236, 230 | Thread color |
| background-color | 底色 | 底色 | color | 30, 50, 90 | Cover color |
| label-color | 签条底色 | 簽條底色 | color | 232, 228, 212 | Label paper |
| ink-color | 墨色 | 墨色 | color | 25, 25, 25 | Title, small type and frame |
| label-width | 签条宽 | 簽條寬 | dim | page width × 0.23 | Label width |
| label-left | 签条左距 | 簽條左距 | dim | page width × 0.05 | Label left edge from the page |
| label-top | 签条上距 | 簽條上距 | dim | page height × 0.04 | Label top from the page |
| label-min-height | 签条最小高 | 簽條最小高 | dim | page height × 0.5 | Minimum label height |
| title-font-size | 书名字号 | 書名字號 | dim | label width × 0.56 | Title size |
| small-font-size | 小字字号 | 小字字號 | dim | title size × 0.3 | Volume / juan size |

Length keys left out (or `0pt`) follow the page proportions.

---

## Mulu (TOC Entry)

**File**: `guji/luatex-cn-guji-mulu.sty`

### `\条目`  `\TiaoMu`  `\條目`

A table-of-contents or index entry with indent levels 0–4.

Syntax: `\条目[2]{卷三 论语}`

---

# Banxin Package

The banxin (central fold): fishtails, divider, book title, chapter, page number, lower section, book ear.

---

## Banxin

**File**: `banxin/luatex-cn-banxin.sty`

### `\banxinSetup`  `\版心设置`  `\版心設置`

**Main keys**:

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| banxin | 版心 | 版心 | bool | false (on in `ltc-guji`) | Banxin |
| banxin-upper-ratio | 版心上比 | 版心上比 | string | 0.28 | Upper section (title) ratio (0–1) |
| banxin-middle-ratio | 版心中比 | 版心中比 | string | 0.56 | Middle section (chapter) ratio (0–1) |
| banxin-divider | 版心分隔线 | 版心分隔線 | bool | true | Divider lines |
| upper-yuwei | 上鱼尾 | 上魚尾 | bool | true | Upper fishtail |
| lower-yuwei | 下鱼尾 | 下魚尾 | bool | true | Lower fishtail |
| middle-section-text | 中部文字 | — | string | _(empty)_ | Middle text (usually set by `\chapter`) |
| upper-section | 上部 | — | text or keys | — | Upper section: text = book title; keys = table below |
| middle-section | 中部 | — | keys | — | Middle section keys |
| page-number | 页码 | 頁碼 | keys | — | Page number keys |
| lower-section | 下部 | — | text or keys | — | Lower section (carver / publisher): text, or keys below |
| book-ear | 书耳 | 書耳 | bool, text or keys | false | Book ear, see below (v0.4.5+, #87) |

The book title comes from `\title{...}` and the chapter from `\chapter{...}` by default.

**Upper section** (`upper-section={...}` / `上部={...}`):

| Key | Simplified | Type | Default | Description |
|-----|-----------|------|---------|-------------|
| font-size | 字号 | size | _(empty)_ | Title font size |
| grid-height | 格高 | dim | _(empty)_ | Title cell height |
| align | 对齐 | string | center | Alignment |
| top-padding | — | dim | 2pt | Space above |
| bottom-padding | — | dim | 10pt | Space below |
| background-color | 底色 | color | _(empty)_ | Background |
| font-color | 字体颜色 | color | _(empty)_ | Text color |

**Middle section** (`middle-section={...}` / `中部={...}`):

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| font-size | 字号 | — | size | _(empty)_ | Chapter font size |
| grid-height | 格高 | — | dim | _(empty)_ | Chapter cell height |
| top-margin | 上留白 | — | dim | 20pt | Space above |
| cols | 列数 | 列數 | int | 1 | Columns for the chapter title |
| align | 对齐 | 對齊 | string | center | Alignment |
| background-color | 底色 | — | color | _(empty)_ | Background |
| font-color | 字体颜色 | — | color | _(empty)_ | Text color |

**Page number** (`page-number={...}` / `页码={...}`):

| Key | Simplified | Type | Default | Description |
|-----|-----------|------|---------|-------------|
| show | 显示 | bool | true | Show the page number |
| font-size | 字号 | size | 14pt | Font size |
| grid-height | 格高 | dim | _(empty)_ | Cell height |
| align | 对齐 | string | right-bottom | `right-bottom`: lower banxin, right; `bottom-center`: lower banxin, centred; `center`: middle of the banxin right below the chapter (common in Ming and Qing editions) |
| bottom-padding | — | dim | 10pt | Space below (`right-bottom` / `bottom-center`) |

```latex
\banxinSetup{ page-number = { align = center } }
\版心设置{ 页码 = { 对齐 = center } }
```

**Lower section** (`lower-section={...}` / `下部={...}`):

| Key | Simplified | Type | Default | Description |
|-----|-----------|------|---------|-------------|
| font-size | 字号 | size | 10pt | Font size |
| grid-height | 格高 | dim | _(empty)_ | Cell height |
| align | 对齐 | string | right | Alignment |
| bottom-margin | 下留白 | dim | 5pt | Space below |
| top-padding | — | dim | 2pt | Space above |
| bottom-padding | — | dim | 10pt | Space below |
| background-color | 底色 | color | _(empty)_ | Background |
| font-color | 字体颜色 | color | _(empty)_ | Text color |

**Book ear** (`book-ear` / `书耳` / `書耳`) <sup>v0.4.5+</sup>:

A book ear is a small box outside the top corner of the frame that records the chapter title. `书耳=true` turns it on with the current `\chapter` title (it follows chapter changes); give text directly as `书耳=五帝本紀`, or keys:

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| show | 显示 | 顯示 | bool | false | Show (giving keys turns it on) |
| text | 文字 | 文字 | string | _(empty)_ | Text; empty = chapter title |
| position | 位置 | 位置 | choice | left | `left` (`左`) `right` (`右`) `both` (`两侧` / `兩側`). Left by default, which after split-page cropping falls on the left half page only |
| width | 宽度 | 寬度 | dim | 0.8 × column width | Box width |
| height | 高度 | 高度 | dim | from the text length | Box height |
| font-size | 字号 | 字號 | size | 0.6 × box width | Font size |

```latex
\banxinSetup{ 书耳 = true }
\banxinSetup{ book-ear = { position = both, font-size = 9pt } }
```

---

# Decorate Package

Character decoration and line marks.

---

## Decorate

**File**: `decorate/luatex-cn-decorate.sty`

### `\decorate`  `\装饰`  `\裝飾`

Attach a decoration symbol to every character.

Syntax: `\decorate[char=●, color=blue]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| char | 字符 | 字符 | string | 。 | Decoration character |
| color | 颜色 | 顏色 | color | red | Color |
| xshift | 横偏 / 横移 | 橫偏 / 橫移 | dim | 0pt | Horizontal shift |
| yshift | 纵偏 / 纵移 | 縱偏 / 縱移 | dim | 0pt | Vertical shift |
| font-size | 字号 | 字號 | size | _(empty)_ | Font size |
| scale | 缩放 | 縮放 | string | 1.0 | Scale |

### `\decorateSetup`  `\装饰设置`  `\裝飾設置`

Default `\装饰` keys.

### `\EmphasisMark`  `\着重号`  `\著重號`

Emphasis marks to the right of each character. Defaults: `\着重号设置` / `\emphasisMarkSetup` / `\圈点设置`.

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| char | 字符 | — | char | ○ | Mark (● in the vbook classes) |
| scale | 缩放 | 縮放 | number | 0.3 | Scale |
| color | 颜色 | 顏色 | color | black | Color |
| skip-punct | 跳过标点 | 跳過標點 | bool | false | No mark on punctuation (clreq 5.3.1; true in the vbook classes) |

### `\faSheng`  `\发圈`  `\發圈`  `\圈发`  `\圈發`

Tone circles at the corners of a character. `\发圈[tone=shang]{字}`, or the shortcuts `\平声{字}` `\上声{字}` `\去声{字}` `\入声{字}` (Traditional `\平聲` etc.). Batch: `\发圈批{平上去入}{春夏秋冬}` (`\fashengBatch`, tones paired with characters). Defaults: `\发圈设置` (`\fashengSetup` / `\發圈設置`).

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| tone | 声 | 聲 | choice | ping | `ping` `shang` `qu` `ru` (or `平` `上` `去` `入`, or a bare `上声` as a switch) |
| color | 颜色 | 顏色 | color | black | Circle color |
| char | 字符 | 字符 | char | ○ | Circle character |
| scale | 缩放 | 縮放 | number | 0.3 | Scale |
| offset | 偏移 | 偏移 | dim | 0.45em | Offset from the character centre |

See [[Correction & Decoration | EN:Correction]].

### `\SideText`  `\旁注`  `\旁註`

Small text beside a character (reading, collation). `\旁注{base}{right}` or `\旁注{base}{right}{left}`. Defaults with `\旁注设置` (`\sideTextSetup` / `\旁註設置`): `scale` (`缩放`, 0.5), `color` (`颜色`, black), `offset` (`偏移`, 0pt).

### `\fix`  `\改`

Correction: a 、 deletion mark over the previous character, with the replacement at its lower right.

Syntax: `甲\改{乙}`: 甲 should read 乙.

---

## LineMark

**File**: `decorate/luatex-cn-linemark.sty`

### `\LineMark`  `\线标`  `\線標`

Straight or wavy line beside the text.

Syntax: `\LineMark[type=wavy, color=red]{text}`

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| type | 类型 | 類型 | choice | straight | `straight` `wavy` |
| color | 颜色 | 顏色 | color | black | Line color |
| offset | 偏移 | 偏移 | dim | 0.6em | Distance from the text |
| amplitude | 振幅 | 振幅 | string | medium | Wave amplitude |
| line-width | 线宽 | 線寬 | dim | 0.8pt | Line width |
| style | 风格 | 風格 | string | standard | Rendering style |

### `\ProperNameMark`  `\专名号`  `\專名號`

Proper-name mark (straight). Also `\Underline` `\下划线` `\下劃線`.

### `\BookTitleMark`  `\书名号`  `\書名號`

Book-title mark (wavy). Also `\WavyUnderline` `\波浪线` `\波浪線`.

---

# Fonts Package

**File**: `fonts/luatex-cn-font-autodetect.sty`

Detects and applies Chinese fonts by operating system. See [[Fonts | EN:Fonts]].

### `\setfontfamily`  `\设置字体族`  `\設置字體族`

Set the main font and its fallback chain in one step. Syntax: `\setfontfamily{Font1,Font2}`

### `\setmainfont`  `\设置字体`  `\設置字體`

The standard fontspec command.

---

# Other Commands

- Horizontal mode (`\usepackage{luatex-cn}`): `\horiSetup`, interlinear marks and notes, `\字号` and more: see [[Horizontal | EN:Horizontal]]
- `ltc-guji-digital`: `\双列`, `\右小列`, `\左小列`, the `数字化内容` environment and more: see [[Digitalization | EN:Digitalization]]
- Gongche notation: see [[Gongche | EN:Gongche]]
- Layout export `\enableLayoutExport` (`\开启排版导出`): see [[Layout Export | EN:Layout-Export]]
- Elevation (taitou): see [[Elevation | EN:Taitou]]

---

# Debug Package

**File**: `debug/luatex-cn-debug.sty`

### `\LtcDebugOn`  `\开启调试`  `\开启调试模式`  `\開啟調試`

Enable debug output globally.

### `\LtcDebugOff`  `\关闭调试`  `\關閉調試`

Disable debug output globally.

### `\LtcDebugModuleOn`  `\开启调试模块`

Enable one module. Syntax: `\LtcDebugModuleOn{render}`

### `\LtcDebugModuleOff`  `\关闭调试模块`

Disable one module.

### `\LtcDebugColor`  `\调试颜色`  `\調試顏色`

Debug color of a module. Syntax: `\LtcDebugColor{render}{blue}`

### `\LtcShowFrame`  `\显示边框`  `\顯示邊框`

Show the text-area frame.

### `\LtcShowGrid`  `\显示网格`  `\显示坐标`  `\顯示網格`

Show a coordinate grid; origin at the top right.

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| measure | 单位 | 單位 | choice | _(empty)_ | Unit: `cm` `pt` `mm` |

### `\LtcHideGrid`  `\隐藏网格`  `\隐藏坐标`  `\隱藏網格`

Hide the grid.

See [[Debug Mode | EN:Debug]].

---

# Document Classes

## cn-vbook

**File**: `ltc-cn-vbook.cls`

Simplified Chinese vertical book class. Loads `luatex-cn-core` and `configs/luatex-cn-vbook-default.cfg`. A template name as a class option loads that configuration as well.

### `\skipHeader`  `\跳过页眉`

Skip the running header and page number on the current page (title pages, covers).

### vbook page keys

Set with `\pageSetup` (together with `header-enabled=true`):

| Key | Simplified | Traditional | Type | Default | Description |
|-----|-----------|-------------|------|---------|-------------|
| page-number-x | 页码横移 | 頁碼橫移 | dim | 3mm | Page number distance from the paper edge |
| page-number-y | 页码纵移 | 頁碼縱移 | dim | 52mm | Page number vertical position (an offset when `header-anchor=content`) |
| header-y | 页眉纵移 | 頁眉縱移 | dim | 52mm | Header vertical position (an offset when `header-anchor=content`) |
| page-number-position | 页码位置 | 頁碼位置 | choice | outer | `outer` (`外侧`, fore-edge) `inner` (`内侧`, spine) `center` (`居中`, foot centre) (v0.4.4+) |
| header-position | 页眉位置 | 頁眉位置 | choice | outer | `outer` (`外侧`) `inner` (`内侧`) (v0.4.4+) |
| header-anchor | 页眉锚点 | 頁眉錨點 | choice | paper | `paper` (`纸边`) from the paper edge; `content` (`内容区`) follow the content area (v0.4.4+) |
| header-sep | 页眉间距 | 頁眉間距 | dim | 6mm | Distance from the content area with `header-anchor=content` (v0.4.4+) |

> Vertical books bind on the right: an odd page is a left page with the spine on its right. By default the header and page number sit on the fore-edge (outer) side. See [[ltc-book | EN:ltc-book]].

### `\卷名`

Volume title (defined in `configs/luatex-cn-vbook-common.cfg`). Syntax: `\卷名{史記卷六}`; 24pt, 48pt space above.

### `\章节名`

Chapter title. Syntax: `\章节名{秦始皇本紀}`; 20pt, two-character indent.

## tw-vbook

**File**: `ltc-tw-vbook.cls`

Traditional Chinese vertical book class. Loads `luatex-cn-tw-vbook-default.cfg`; otherwise the same as `ltc-cn-vbook`.

## ltc-guji

**File**: `ltc-guji.cls`

Classical book class. Loads every guji module (judou, jiazhu, annotations, marginal notes, seals, title page, cover…).
