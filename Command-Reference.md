# 命令索引 (Command Reference)

> 本页列出 luatex-cn 全部用户命令、环境及其参数。每个命令/环境均提供英文、简体中文、繁体中文三套名称（同形则省略）。

---

## 通用类型说明

参数表中的"类型"列使用以下名称：

| 类型名 | 说明 | 示例 |
|--------|------|------|
| **度量** | 带单位的长度值。支持的单位：`pt`（磅）、`mm`（毫米）、`cm`（厘米）、`em`（当前字号的宽度）、`ex`（当前字号的 x 高度）、`sp`（TeX 最小单位，65536sp = 1pt）。 | `12pt` `1.5em` `210mm` `0.4cm` |
| **字号** | 字体大小，本质也是度量值。常用 `pt` 或 `em`（相对于基准字号）。 | `12pt` `0.8em` `16pt` |
| **颜色** | 颜色值。支持三种格式：颜色名（如 `red` `black` `blue`）；0-1 小数 RGB（如 `1 0 0` 表示红色）；0-255 整数 RGB（如 `255,128,0`）。 | `red` `1 0 0` `255,128,0` |
| **字符串** | 一般文本值，含义由具体参数决定。 | `grid` `taiwan` `right-bottom` |
| **整数** | 整数值，通常表示格数或列数。 | `0` `8` `2` |
| **是/否** | 布尔值，`true` 或 `false`。也可省略值，直接写参数名等价于 `true`。 | `true` `false`（或直接 `border`） |
| **选项** | 只能从给定选项中选一个。可选值会在说明中列出。 | `top` `center` `bottom` |
| **快捷** | 组合参数，自动设置多个关联参数。 | `spacing=5pt` → 同时设置 `spacing-top` 和 `spacing-bottom` |

---

# Core 核心宏包

核心排版引擎，提供页面、内容区域、网格布局、列、段落、文本框、样式等基础功能。

---

## 页面 (Page)

**文件**: `core/luatex-cn-core-page.sty`

### `\pageSetup`  `\页面设置`  `\頁面設置`

配置页面几何尺寸、边距、筒子页等参数。调用后同步到 Lua 层。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| paper-width | 纸宽 | 紙寬 | 度量 | 210mm | 纸张宽度 |
| paper-height | 纸高 | 紙高 | 度量 | 297mm | 纸张高度 |
| margin-top | 上边距 | 上邊距 | 度量 | 0pt | 上边距 |
| margin-bottom | 下边距 | 下邊距 | 度量 | 0pt | 下边距 |
| margin-left | 左边距 | 左邊距 | 度量 | 0pt | 左边距 |
| margin-right | 右边距 | 右邊距 | 度量 | 0pt | 右边距 |
| background-color | 底色 | 底色 | 颜色 | _(空)_ | 页面背景色 |
| footskip | 页脚距 | 頁腳距 | 度量 | 0pt | 页脚偏移 |
| topskip | 页头距 | 頁頭距 | 度量 | 0pt | 页头偏移 |
| page-split-enabled | 开启分页 | 開啟分頁 | 是/否 | true | 是否启用筒子页裁剪 |
| page-split-right-first | 右页优先 | 右頁優先 | 是/否 | true | 筒子页先印右页 |
| page-number-style | 页码样式 | 頁碼樣式 | 字符串 | none | 页码显示风格 |
| page-number-font-size | 页码字号 | 頁碼字號 | 字号 | 9pt | 页码字号 |

### `\enableSplitPage`  `\开启分页`  `\開啟分頁`

启用筒子页（电子简策）裁剪模式，可接受 key-value 参数配置。

### `\disableSplitPage`  `\关闭分页`  `\關閉分頁`

关闭筒子页裁剪。

### `\SetPageNumber`  `\设置页码`  `\設置頁碼`

将页码计数器设为指定值。语法：`\SetPageNumber{5}`

### `\ResetPageNumber`  `\重置页码`  `\重置頁碼`

将页码重置为 1。

### 环境 `Page`  `页`

在环境内临时修改页面参数（纸张尺寸、边距等），环境结束后自动恢复。支持全部页面参数。

---

## 内容区域 (Content)

**文件**: `core/luatex-cn-core-content.sty`

### `\contentSetup`  `\内容设置`  `\內容設置`

配置正文区域的所有排版参数：网格尺寸、字体、行列数、边框、布局模式等。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| n-column | 行数 | 行數 | 整数 | 8 | 每半页行数（竖排时"行"即列） |
| n-char-per-col | 每行字数 | 每行字數 | 整数 | 0 | 每行字数（0=自动） |
| grid-width | 格宽 | 格寬 | 度量 | 1.5em | 字格宽度 |
| grid-height | 格高 | 格高 | 度量 | 1.2em | 字格高度 |
| font-size | 字号 | 字號 | 字号 | 12pt | 正文字号 |
| font | 字体 | 字體 | 字符串 | _(空)_ | 正文字体名 |
| font-features | 字体特性 | 字體特性 | 字符串 | _(空)_ | 字体 OpenType 特性 |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 正文字体颜色 |
| vertical-align | 纵对齐 | 縱對齊 | 字符串 | center | 字符在格中的纵向对齐 |
| height | 高度 | 高度 | 度量 | _(自动)_ | 内容区高度 |
| layout-mode | 布局模式 | 佈局模式 | 选项 | grid | 布局引擎：`grid` 或 `natural` |
| spacing-col | 列间距 | 列間距 | 度量 | _(空)_ | 列间距 |
| line-spacing | 行距 | 行距 | 度量 | \baselineskip | 行距（natural 模式） |
| page-columns | 版面行数 | 版面行數 | 字符串 | _(空)_ | 每页行数覆盖 |
| banxin-ratio | 版心比例 | 版心比例 | 字符串 | 0.7 | 版心在行中的比例（0-1） |
| border | 边框 | 邊框 | 是/否 | false | 是否显示栏线 |
| border-thickness | 边框粗细 | 邊框粗細 | 度量 | 0.4pt | 栏线粗细 |
| border-color | 边框色 | 邊框色 | 颜色 | black | 栏线颜色 |
| border-padding-top | 边框上填充 | 边框上填充 | 度量 | 0pt | 栏线上方留白 |
| border-padding-bottom | 边框下填充 | 边框下填充 | 度量 | 0pt | 栏线下方留白 |
| outer-border | 外框 | 外框 | 是/否 | false | 是否显示外框 |
| outer-border-thickness | 外框粗细 | 外框粗細 | 度量 | 1pt | 外框线宽 |
| outer-border-sep | 外框间距 | 外框間距 | 度量 | 2pt | 外框与栏线间距 |
| inter-cell-gap | 字间隙 | 字間隙 | 度量 | 0pt | 字格间附加间距 |
| cell-height | 字格高 | 字格高 | 度量 | _(空)_ | 单字格高度覆盖 |
| cell-width | 字格宽 | 字格寬 | 度量 | _(空)_ | 单字格宽度覆盖 |
| cell-gap | 字格间距 | 字格間距 | 度量 | _(空)_ | 字格间距覆盖 |
| auto-column-width | 自动列宽 | 自動列寬 | 是/否 | false | 自动计算列宽 |
| column-spacing-top | 列上间距 | 列上間距 | 度量 | 0pt | 列顶部留白 |
| column-spacing-bottom | 列下间距 | 列下間距 | 度量 | 0pt | 列底部留白 |
| column-spacing | 列间距(快捷) | 列間距(快捷) | 快捷 | — | 同时设置列上/下间距 |
| paragraph-spacing | 段间距 | 段間距 | 度量 | 0pt | 段落间距 |

> **注意**: 未识别的参数会自动转发到页面（Page）参数。

### `\Content`  `\内容`  `\內容`

将文本交给网格排版引擎处理。语法：`\Content[keys]{文本内容}`。支持全部 content 参数。

### `\Space`  `\空格`

插入 N 个全角空格（U+3000），用于网格中的手动间距。语法：`\Space[3]`

### 环境 `BodyText`  `正文`

`\Content` 的环境形式，支持全部 content 参数。
```latex
\begin{正文}[行数=10, 格高=1.5em]
  此处为正文内容……
\end{正文}
```

---

## 样式 (Style)

**文件**: `core/luatex-cn-core-style.sty`

### `\Style`  `\样式`  `\樣式`

行内样式覆盖，可改变字号、字体、字体颜色、格高、间距。不影响布局模式。

语法：`\Style[font-size=16pt, font-color=red]{内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| font-size | 字号 | 字號 | 字号 | _(空)_ | 覆盖字号 |
| font | 字体 | 字體 | 字符串 | _(空)_ | 覆盖字体 |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 覆盖字体颜色 |
| grid-height | 格高 | 格高 | 度量 | _(空)_ | 覆盖格高 |
| spacing-top | 上间距 | 上間距 | 度量 | _(空)_ | 上方附加间距 |
| spacing-bottom | 下间距 | 下間距 | 度量 | _(空)_ | 下方附加间距 |
| spacing | 间距 | 間距 | 快捷 | — | 同时设置上/下间距 |

### 环境 `StyleEnv`  `样式环境`  `樣式環境`

`\Style` 的环境形式，允许内容中使用命令展开。

---

## 行/列 (Column)

**文件**: `core/luatex-cn-core-column.sty`

### `\Column`  `\行`

单列竖排文本，支持对齐方式控制。

语法：`\Column[align=center, font-size=16pt]{内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| align | 对齐 | 對齊 | 选项 | top | 对齐方式：`top` `bottom` `center` `stretch` |
| last | 末列 | 末列 | 是/否 | false | 放置在当前半页末列 |
| font-size | 字号 | 字號 | 字号 | _(空)_ | 覆盖字号 |
| font | 字体 | 字體 | 字符串 | _(空)_ | 覆盖字体 |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 覆盖字体颜色 |
| width | 宽度 | 寬度 | 度量 | _(空)_ | 列宽 |
| column-width | 列宽 | 列寬 | 度量 | _(空)_ | 列宽（别名） |
| auto-width | 自动宽度 | 自動寬度 | 是/否 | true | 自动计算列宽 |
| width-scale | 宽度缩放 | 寬度縮放 | 字符串 | 1.2 | 自动宽度缩放系数 |
| spacing-top | 上间距 | 上間距 | 度量 | _(空)_ | 列顶部间距 |
| spacing-bottom | 下间距 | 下間距 | 度量 | _(空)_ | 列底部间距 |
| spacing | 间距 | 間距 | 快捷 | — | 同时设置上/下间距 |
| grid-height | 格高 | 格高 | 度量 | _(空)_ | 覆盖格高 |

### `\LastColumn`

放置内容到当前半页末列。等价于 `\Column[last]{内容}`。

---

## 文本流 (TextFlow)

**文件**: `core/luatex-cn-core-textflow.sty`

### `\TextFlow`  `\文本流`

双行小注（夹注）排版。将内容分为左右两小列排版。

语法：`\TextFlow[font-size=8pt]{注释内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| only-column | 单列 | 單列 | 选项 | none | 仅使用单列：`none`(双列) `right` `left` |
| auto-balance | 自动均衡 | 自動均衡 | 是/否 | true | 自动均衡左右列字数 |
| font-size | 字号 | 字號 | 字号 | _(空)_ | 覆盖字号 |
| font | 字体 | 字體 | 字符串 | _(空)_ | 覆盖字体 |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 覆盖字体颜色 |
| align | 对齐 | 對齊 | 字符串 | _(空)_ | 对齐方式 |

### `\DanHangJiaZhu`  `\单行夹注`  `\單行夾注`

单列夹注。语法：`\DanHangJiaZhu[列号]{内容}`

### 环境 `TextFlowEnv`  `文本流环境`  `文本流環境`

`\TextFlow` 的环境形式。

---

## 文本框 (TextBox)

**文件**: `core/luatex-cn-core-textbox.sty`

### `\TextBox`  `\文本框`

多列网格文本框，支持边框、悬浮定位、背景色等。

语法：`\TextBox[height=5, border, background-color=yellow]{内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| height | 高度 | 高度 | 整数 | 0 | 文本框高度（格数） |
| n-cols | 列数 | 列數 | 整数 | 0 | 内部列数 |
| outer-cols | 外列数 | 外列數 | 整数 | 0 | 外部占用列数 |
| fill | 填充 | 填充 | 是/否 | false | 均分排布内容 |
| box-align | 框对齐 | 框對齊 | 字符串 | top | 文本框在列中的对齐 |
| border | 边框 | 邊框 | 是/否 | false | 显示边框 |
| border-shape | 边框形状 | 邊框形狀 | 选项 | none | 边框形状：`none` `octagon` `circle` |
| border-color | 边框色 | 邊框色 | 颜色 | _(空)_ | 边框颜色 |
| border-width | 边框宽 | 邊框寬 | 度量 | 0.4pt | 边框线宽 |
| border-margin | 边框间距 | 邊框間距 | 度量 | 0pt | 边框与内容间距 |
| outer-border | 外框 | 外框 | 是/否 | false | 显示外框 |
| outer-border-thickness | 外框粗细 | 外框粗細 | 度量 | 1pt | 外框线宽 |
| outer-border-sep | 外框间距 | 外框間距 | 度量 | 2pt | 外框与边框间距 |
| banxin | 版心 | 版心 | 是/否 | — | 是否显示版心线 |
| column-align | 列对齐 | 列對齊 | 字符串 | _(空)_ | 内部列对齐 |
| vertical-align | 纵对齐 | 縱對齊 | 字符串 | _(空)_ | 纵向对齐（别名 box-align） |
| floating | 悬浮 | 懸浮 | 是/否 | false | 悬浮定位模式 |
| floating-paper-width | 悬浮纸宽 | 懸浮紙寬 | 度量 | 0pt | 悬浮模式下的纸宽 |
| x | 横位 | 橫位 | 度量 | 0pt | 悬浮 X 坐标 |
| y | 纵位 | 縱位 | 度量 | 0pt | 悬浮 Y 坐标 |
| background-color | 底色 | 底色 | 颜色 | _(空)_ | 背景色 |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 字体颜色 |
| font-size | 字号 | 字號 | 字号 | _(空)_ | 字号 |
| grid-width | 格宽 | 格寬 | 度量 | _(空)_ | 内部网格宽度 |
| grid-height | 格高 | 格高 | 度量 | _(空)_ | 内部网格高度 |

### `\FillTextBox`  `\填充文本框`

向后兼容的文本框命令，接受整数高度（旧式）或 key-value 参数。

### `\反白`  `\inverted`

反白效果快捷命令：黑底白字。语法：`\反白{内容}`

### `\八角框`  `\octagon`

八角形边框快捷命令。语法：`\八角框{内容}`

### `\带圈`  `\circled`  `\帶圈`

圆形边框快捷命令。语法：`\带圈{内容}`

### `\反白八角框`  `\invertedOctagon`

反白 + 八角边框组合。

---

## 段落 (Paragraph)

**文件**: `core/luatex-cn-core-paragraph.sty`

### 环境 `Paragraph`  `段落`

块级缩进环境，支持首行/悬挂/末行缩进。

```latex
\begin{段落}[缩进=2, 首行缩进=0]
  第一列缩进0格……\\
  后续列缩进2格……
\end{段落}
```

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| indent | 缩进 | 縮進 | 整数 | 0 | 基础缩进（格数） |
| first-indent | 首行缩进 | 首行縮進 | 整数 | _(空)_ | 首行缩进（空=跟随 indent，明确值覆盖） |
| bottom-indent | 行尾缩进 | 行尾縮進 | 整数 | 0 | 行尾缩进（行末要空几格） |

### `\SetIndent`  `\设置缩进`  `\設置縮進`

强制设置当前行缩进值，在 `\\` 或行尾自动恢复。

语法：`\SetIndent{3}`

### `\抬头`  `\TaiTou`

另起一列，文字提升 N 格。N=0 为平抬，N>0 伸入天头区域。

语法：`\抬头[2]`（提升2格）

| 快捷命令 | 英文 | 等价于 |
|----------|------|--------|
| `\平抬` | `\PingTai` | `\抬头[0]` |
| `\单抬`  `\單抬` | `\DanTai` | `\抬头[1]` |
| `\双抬`  `\雙抬` | `\ShuangTai` | `\抬头[2]` |
| `\三抬` | `\SanTai` | `\抬头[3]` |

### `\挪抬`  `\NuoTai`

不换行，在当前位置插入 N 个全角空格。

语法：`\挪抬[2]`（插入2格空白）

| 快捷命令 | 英文 | 等价于 |
|----------|------|--------|
| `\空抬` | `\KongTai` | `\挪抬[1]` |

### `\相对抬头`  `\XiangDuiTaiTou`  `\相對抬頭`

相对当前缩进位置上移 N 格。如当前 indent=2，`\相对抬头[3]` 则 indent=-1（伸入天头1格）。

### `\换行`  `\HuanHang`  `\換行`

强制换列。

---

## 侧批 (SideNode)

**文件**: `core/luatex-cn-core-sidenote.sty`

### `\SideNode`  `\侧批`  `\側批`

侧批注释，渲染在页面边缘。也可用拼音别名 `\CePi`。

语法：
- 基础：`\SideNode{批注内容}`
- 位置参数（自动转换为 em）：`\SideNode[5pt]{高度调整}` 等同于 `\SideNode[yshift=5pt]{高度调整}`
- 数值自动转换为 em：`\SideNode[0.5]{内容}` 等同于 `\SideNode[0.5em]{内容}`
- 命名参数：`\SideNode[yshift=5pt, color=blue]{批注内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| yshift | 纵移 | 縱移 | 度量 | 0pt | 纵向偏移（支持位置参数） |
| grid-height | 格高 | 格高 | 度量 | _(空)_ | 侧批格高（默认=字号） |
| font-size | 字号 | 字號 | 字号 | 10pt | 侧批字号 |
| color | 颜色 | 顏色 | 颜色 | red | 侧批颜色 |
| border-padding-top | 边框上填充 | 边框上填充 | 度量 | 0pt | 上方填充 |
| border-padding-bottom | 边框下填充 | 边框下填充 | 度量 | 0pt | 下方填充 |

### `\sidenodeSetup`  `\侧批设置`  `\側批設置`

配置侧批默认参数。

---

## 脚注 (Footnote)

**文件**: `core/luatex-cn-footnote.sty`

### `\Footnote`  `\脚注`  `\腳注`

插入脚注。Mode 1（段末注）：存储到序列，在 `\FlushFootnote` 时输出。Mode 2（页下注）：注册到 Lua 层，页面渲染时自动输出。

语法：`\Footnote{校勘记内容}`

### `\FlushFootnote`  `\输出脚注`  `\輸出腳注`

输出所有已存储的脚注并重置计数器。仅 Mode 1（段末注）有效。

### `\footnoteSetup`  `\脚注设置`  `\腳注設置`

配置脚注参数。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| mode | 模式 | 模式 | 选项 | endnote | 脚注模式：`endnote`(段末注) `page`(页下注) |
| number-style | 编号样式 | 編號樣式 | 选项 | lujiao | 编号风格：`lujiao`(【一】) `circled`(①) |
| separator | 分隔符 | 分隔符 | 选项 | blank | 分隔方式：`blank`(空格) `none` |
| font | 字体 | 字體 | 字符串 | _(空)_ | 脚注字体 |
| font-size | 字号 | 字號 | 字号 | 0.8em | 脚注字号（相对于正文字号） |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 脚注字体颜色 |
| indent | 缩进 | 縮進 | 度量 | 1em | 脚注缩进 |
| spacing | 间距 | 間距 | 度量 | 0.5em | 脚注间距 |

### `\ResetFootnoteCounter`  `\重置脚注计数`  `\重置腳注計數`

重置脚注计数器（Mode 2 页下注按页重置时使用）。

---

## 元数据 (Metadata)

**文件**: `core/luatex-cn-core-metadata.sty`

### `\metadataSetup`  `\元数据设置`  `\元數據設置`

配置书籍元数据。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| book-name | 书名 | 書名 | 字符串 | _(空)_ | 书名 |
| chapter-title | 章节标题 | 章節標題 | 字符串 | _(空)_ | 章节标题 |
| publisher | 出版商 | 出版商 | 字符串 | _(空)_ | 出版商名称 |

### `\title`

设置书名（同步到版心和元数据）。

### `\publisher`  `\出版商`

设置出版商。

### `\ChapterMarker`  `\章节标记`  `\章節標記`

插入章节标记，后续页面的版心章节标题自动更新。

### `\chapter`

设置章节标题并重置页码。

---

## 标点 (Punct)

**文件**: `core/luatex-cn-core-punct.sty`

### `\punctSetup`  `\标点设置`  `\標點設置`

配置现代标点处理规则。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| punct-style | 标点风格 | 標點風格 | 选项 | taiwan | 标点位置风格：`taiwan` `mainland` |
| punct-squeeze | 标点压缩 | 標點壓縮 | 是/否 | true | 连续标点压缩 |
| punct-hanging | 标点悬挂 | 標點懸掛 | 是/否 | false | 标点悬挂 |
| kinsoku | 禁则 | 禁則 | 是/否 | true | 禁则处理 |

### `\大陆标点风格`  `\DaLuBiaoDianFengGe`  `\大陸標點風格`

快捷命令：切换到大陆标点风格。

### `\台湾标点风格`  `\TaiWanBiaoDianFengGe`  `\臺灣標點風格`

快捷命令：切换到台湾标点风格。

---

# Guji 古籍宏包

古籍专用功能：句读、夹注、批注、眉批、印章、书名页、封面、目录条目。

---

## 古籍文档类 (Guji Class)

**文件**: `guji.cls`

### `\gujiSetup`  `\古籍设置`  `\古籍設置`

古籍文档类的主配置命令。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| template | 模板 | 模板 | 字符串 | — | 加载预设模板 |

**内置模板**:

| 英文 | 简体 | 繁体 |
|------|------|------|
| default | 四库全书 | 四庫全書 |
| SiKuQuanShu-colored | 四库全书彩色 | 四庫全書彩色 |
| HongLouMengJiaXuBen | 红楼梦甲戌本 | 紅樓夢甲戌本 |

### `\defineGujiTemplate`  `\定义古籍模板`  `\定義古籍模板`

定义自定义古籍模板。

---

## 句读 (Judou)

**文件**: `guji/luatex-cn-guji-judou.sty`

### `\judouSetup`  `\句读设置`  `\句讀設置`

配置句读显示参数。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| judou-pos | 句读位置 | 句讀位置 | 字符串 | right-bottom | 句读符号位置 |
| judou-size | 句读大小 | 句讀大小 | 字号 | 1em | 句读符号大小 |
| judou-color | 句读颜色 | 句讀顏色 | 颜色 | red | 句读颜色 |
| punct-mode | 标点模式 | 標點模式 | 选项 | normal | 标点模式 |

### `\NormalPunctuationMode`  `\正常标点模式`  `\正常標點模式`

切换到正常标点模式。

### `\JudouPunctuationMode`  `\句读模式`  `\句讀模式`

切换到句读标点模式。

### `\NonePunctuationMode`  `\无标点模式`  `\無標點模式`

移除所有标点。

---

## 夹注 (JiaZhu)

**文件**: `guji/luatex-cn-guji-jiazhu.sty`

### `\JiaZhu`  `\夹注`  `\夾注`

双行小字注释。语法：`\JiaZhu[font-size=8pt]{注释内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| font-size | 字号 | 字號 | 字号 | _(空)_ | 夹注字号 |
| font | 字体 | 字體 | 字符串 | _(空)_ | 夹注字体 |
| font-color | 字体颜色 | 字體顏色 | 颜色 | _(空)_ | 夹注字体颜色 |
| align | 对齐 | 對齊 | 字符串 | outward | 对齐方式 |

### `\jiazhuSetup`  `\夹注设置`  `\夾注設置`

配置夹注默认参数。

### 环境 `JiaZhuEnv`  `夹注环境`  `夾注環境`

夹注的环境形式。

---

## 批注 (PiZhu)

**文件**: `guji/luatex-cn-guji-pizhu.sty`

### `\PiZhu`  `\批注`

浮动批注框。语法：`\PiZhu[x=5cm, y=3cm]{批注内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| x | 横位 | 橫位 | 度量 | _(空)_ | X 坐标 |
| y | 纵位 | 縱位 | 度量 | _(空)_ | Y 坐标 |
| height | 高度 | 高度 | 整数 | _(空)_ | 批注高度（格数） |
| font-size | 字号 | 字號 | 字号 | 18pt | 批注字号 |
| color | 颜色 | 顏色 | 颜色 | 1 0 0 | 批注颜色 |
| grid-width | 格宽 | 格寬 | 度量 | 20pt | 批注格宽 |
| grid-height | 格高 | 格高 | 度量 | 19pt | 批注格高 |

### `\pizhuSetup`  `\批注设置`  `\批注設置`

配置批注默认参数。

---

## 眉批 (MeiPi)

**文件**: `guji/luatex-cn-guji-meipi.sty`

### `\MeiPi`  `\眉批`

自动定位的眉批注释，出现在页面天头区域。

语法：`\MeiPi[font-size=14pt]{眉批内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| x | 横位 | 橫位 | 度量 | _(空)_ | X 坐标覆盖 |
| y | 纵位 | 縱位 | 度量 | _(空)_ | Y 坐标覆盖 |
| height | 高度 | 高度 | 整数 | 7 | 眉批高度（格数） |
| font-size | 字号 | 字號 | 字号 | 18pt | 眉批字号 |
| color | 颜色 | 顏色 | 颜色 | 1 0 0 | 眉批颜色 |
| grid-width | 格宽 | 格寬 | 度量 | 20pt | 眉批格宽 |
| grid-height | 格高 | 格高 | 度量 | 19pt | 眉批格高 |
| spacing | 间距 | 間距 | 度量 | 10pt | 眉批间距 |
| gap | 间隔 | 間隔 | 度量 | 0pt | 眉批额外间隔 |

### `\meipiSetup`  `\眉批设置`  `\眉批設置`

配置眉批默认参数。

---

## 印章 (YinZhang)

**文件**: `guji/luatex-cn-guji-yinzhang.sty`

### `\YinZhang`  `\印章`

在指定页面覆盖馆藏印/私印图像。

语法：`\YinZhang[opacity=0.5, page=2]{seal.png}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| opacity | 不透明度 | 不透明度 | 字符串 | 0.7 | 印章不透明度（0-1） |
| xshift | 横移 | 橫移 | 度量 | -5.3cm | 水平偏移 |
| yshift | 纵移 | 縱移 | 度量 | -6.4cm | 垂直偏移 |
| width | 宽度 | 寬度 | 度量 | 12.9cm | 印章宽度 |
| page | 页 | 頁 | 整数 | 1 | 目标页码 |
| color | 颜色 | 顏色 | 颜色 | _(空)_ | 印章着色 |

---

## 书名页 (TitlePage)

**文件**: `guji/luatex-cn-guji-titlepage.sty`

### 环境 `TitlePage`  `书名页`  `書名頁`

古籍书名页，自动处理列布局。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| border | 边框 | 邊框 | 是/否 | false | 显示边框 |
| outer-border | 外框 | 外框 | 是/否 | false | 显示外框 |

---

## 单页 (SinglePage)

**文件**: `guji/luatex-cn-guji-danye.sty`

### 环境 `SinglePage`  `单页`  `單頁`

单页模式（筒子页的半页），自动计算纸宽/2 和边距/2。无专属参数，继承页面（Page）参数。

---

## 封面 (Cover)

**文件**: `guji/luatex-cn-guji-cover.sty`

### 环境 `Cover`  `封面`

封面页环境。自动关闭边框和版心。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| background-color | 底色 | 底色 | 颜色 | _(空)_ | 封面背景色 |

---

## 目录条目 (Mulu)

**文件**: `guji/luatex-cn-guji-mulu.sty`

### `\条目`  `\TiaoMu`  `\條目`

输出一个目录/索引条目，支持缩进层级 (0-4)。

语法：`\条目[2]{卷三 论语}`

---

# Banxin 版心宏包

版心装饰功能：鱼尾、分隔线、书名/章节/页码/出版商标注。

---

## 版心 (Banxin)

**文件**: `banxin/luatex-cn-banxin.sty`

### `\banxinSetup`  `\版心设置`  `\版心設置`

配置版心参数。版心包含上鱼尾、书名区、分隔线、章节标题区、页码区、下鱼尾、出版商区。

**主参数**:

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| banxin | 版心 | 版心 | 是/否 | false | 是否启用版心 |
| banxin-upper-ratio | 版心上比 | 版心上比 | 字符串 | 0.28 | 上鱼尾区占比（0-1） |
| banxin-middle-ratio | 版心中比 | 版心中比 | 字符串 | 0.56 | 中间区占比（0-1） |
| banxin-padding-top | 版心上填充 | 版心上填充 | 度量 | 2pt | 版心上方留白 |
| banxin-padding-bottom | 版心下填充 | 版心下填充 | 度量 | 10pt | 版心下方留白 |
| banxin-divider | 版心分隔线 | 版心分隔線 | 是/否 | true | 是否显示分隔线 |
| upper-yuwei | 上鱼尾 | 上魚尾 | 是/否 | true | 是否显示上鱼尾 |
| lower-yuwei | 下鱼尾 | 下魚尾 | 是/否 | true | 是否显示下鱼尾 |
| chapter-title | 章节标题 | 章節標題 | 字符串 | _(空)_ | 章节标题 |

**书名区参数** (通过 `book-name={...}` 传入):

| 参数 | 简体 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| font-size | 字号 | 字号 | _(空)_ | 书名字号 |
| grid-height | 格高 | 度量 | _(空)_ | 书名格高 |
| align | 对齐 | 字符串 | center | 书名对齐方式 |

**章节区参数** (通过 `chapter={...}` 传入):

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| font-size | 字号 | 字号 | 字号 | _(空)_ | 章节字号 |
| grid-height | 格高 | 格高 | 度量 | _(空)_ | 章节格高 |
| top-margin | 上留白 | 上留白 | 度量 | 20pt | 章节区上方留白 |
| cols | 列数 | 列數 | 整数 | 1 | 章节标题列数 |

**页码区参数** (通过 `page-number={...}` 传入):

| 参数 | 简体 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| font-size | 字号 | 字号 | 14pt | 页码字号 |
| grid-height | 格高 | 度量 | _(空)_ | 页码格高 |
| align | 对齐 | 字符串 | right-bottom | 页码对齐 |

**出版商区参数** (通过 `publisher={...}` 传入):

| 参数 | 简体 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| font-size | 字号 | 字号 | 10pt | 出版商字号 |
| grid-height | 格高 | 度量 | _(空)_ | 出版商格高 |
| align | 对齐 | 字符串 | right | 出版商对齐 |
| bottom-margin | 下留白 | 度量 | 5pt | 出版商下方留白 |

---

# Decorate 装饰宏包

字符装饰与线标功能。

---

## 装饰 (Decorate)

**文件**: `decorate/luatex-cn-decorate.sty`

### `\decorate`  `\装饰`  `\裝飾`

对内容中的每个字符附加装饰符号。

语法：`\decorate[char=●, color=blue]{内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| char | 字符 | 字符 | 字符串 | 。 | 装饰字符 |
| color | 颜色 | 顏色 | 颜色 | red | 装饰颜色 |
| xshift | 横偏 / 横移 | 橫偏 / 橫移 | 度量 | 0pt | 水平偏移 |
| yshift | 纵偏 / 纵移 | 縱偏 / 縱移 | 度量 | 0pt | 垂直偏移 |
| font-size | 字号 | 字號 | 字号 | _(空)_ | 装饰字号 |
| scale | 缩放 | 縮放 | 字符串 | 1.0 | 装饰缩放比例 |

### `\EmphasisMark`  `\着重号`  `\著重號`

着重号（圈点）快捷命令。在字符右侧加「。」标记。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| color | 颜色 | 顏色 | 颜色 | red | 着重号颜色 |

### `\fix`  `\改`

改字命令。在前一字上叠加「、」删除标记，并在右下角添加替换字。

语法：`甲\改{乙}` — 表示"甲"应改为"乙"。

---

## 线标 (LineMark)

**文件**: `decorate/luatex-cn-linemark.sty`

### `\LineMark`  `\线标`  `\線標`

通用线标命令，支持直线/波浪线样式。

语法：`\LineMark[type=wavy, color=red]{内容}`

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| type | 类型 | 類型 | 选项 | straight | 线型：`straight` `wavy` |
| color | 颜色 | 顏色 | 颜色 | black | 线色 |
| offset | 偏移 | 偏移 | 度量 | 0.6em | 线距文字偏移 |
| amplitude | 振幅 | 振幅 | 字符串 | medium | 波浪振幅 |
| line-width | 线宽 | 線寬 | 度量 | 0.8pt | 线宽 |
| style | 风格 | 風格 | 字符串 | standard | 渲染风格 |

### `\ProperNameMark`  `\专名号`  `\專名號`

专名号（直线标记）。也可用 `\Underline` `\下划线` `\下劃線`。

### `\BookTitleMark`  `\书名号`  `\書名號`

书名号（波浪线标记）。也可用 `\WavyUnderline` `\波浪线` `\波浪線`。

---

# Fonts 字体宏包

**文件**: `fonts/luatex-cn-font-autodetect.sty`

---

根据操作系统自动检测并应用中文字体。

获取自动检测到的字体名称。

获取自动检测到的字体特性字符串。


### `\setfontfamily`  `\设置字体族`  `\設置字體族`

一步设置主字体及递补链。语法：`\setfontfamily{Font1,Font2}`

### `\setmainfont`  `\设置字体`  `\設置字體`

标准 fontspec 命令透传。

---

# Debug 调试宏包

**文件**: `debug/luatex-cn-debug.sty`

---

### `\LtcDebugOn`  `\开启调试`  `\開啟調試`

全局启用调试输出。

### `\LtcDebugOff`  `\关闭调试`  `\關閉調試`

全局关闭调试输出。

### `\LtcDebugModuleOn`  `\开启调试模块`

启用指定模块的调试输出。语法：`\LtcDebugModuleOn{render}`

### `\LtcDebugModuleOff`  `\关闭调试模块`

关闭指定模块的调试输出。

### `\LtcDebugColor`  `\调试颜色`  `\調試顏色`

设置模块的调试输出颜色。语法：`\LtcDebugColor{render}{blue}`

### `\LtcShowFrame`  `\显示边框`  `\顯示邊框`

显示页面文本区域边框。

### `\LtcShowGrid`  `\显示网格`  `\顯示網格`

显示页面坐标网格。原点在右上角。

| 参数 | 简体 | 繁体 | 类型 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| measure | 单位 | 單位 | 选项 | _(空)_ | 坐标单位：`cm` `pt` `mm` |

### `\LtcHideGrid`  `\隐藏网格`  `\隱藏網格`

隐藏页面坐标网格。


---

# 文档类 (Document Classes)

## cn-vbook

**文件**: `cn-vbook.cls`

简体中文竖排书籍文档类。自动加载 `luatex-cn-core` 和默认模板 `luatex-cn-vbook-default.cfg`。

类选项中传入模板名可加载对应配置文件。

## tw-vbook

**文件**: `tw-vbook.cls`

繁体中文竖排书籍文档类。加载 `luatex-cn-tw-vbook-default.cfg`。其他与 `cn-vbook` 相同。

## guji  ltc-guji

**文件**: `guji.cls`  `ltc-guji.cls`

古籍文档类。加载全部古籍功能模块（句读、夹注、批注、眉批、印章、书名页、封面等）。
