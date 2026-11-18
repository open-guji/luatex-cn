[English Version](EN:ltc-book) | 中文版

# 现代竖排文档类 (v0.2.7+)

luatex-cn 提供两个面向现代竖排中文书籍的文档类，与 `ltc-guji`（古籍排版）不同，它们采用简洁的现代设计：无版心、无鱼尾、无丝栏，适合当代出版物的竖排需求。

| 文档类 | 标点风格 | 说明 |
|--------|---------|------|
| **`ltc-cn-vbook`** (v0.2.8+) | 中国大陆 | 简体中文竖排书籍 |
| **`ltc-tw-vbook`** (v0.2.8+) | 台湾 | 繁体中文竖排书籍 |

## 基本用法

```latex
\documentclass{ltc-cn-vbook}
\setmainfont{Noto Serif SC}

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。
寒来暑往，秋收冬藏。闰余成岁，律吕调阳。
\end{正文}
\end{document}
```

## 模板系统

两个文档类各自加载一份默认配置，共用 `configs/luatex-cn-vbook-common.cfg`：16 开（170×240mm），14pt 字号，自由列宽（`n-column=0`），对页（`twoside=true`，书脊侧 24mm、翻口侧 16mm），运行页眉与页码，脚注鹿角编号。

| 文档类 | 默认配置文件 | 标点风格 |
|--------|------------|---------|
| `ltc-cn-vbook` | `luatex-cn-vbook-default.cfg` | 中国大陆（`punct-style=mainland`） |
| `ltc-tw-vbook` | `luatex-cn-tw-vbook-default.cfg` | 台湾（`punct-style=taiwan`） |

文档类选项中写模板名会再加载 `<名>.cfg`（文档目录）或 `configs/luatex-cn-vbook-<名>.cfg`，见 [[模板与自定义 | Templates]]。目前没有内置的命名模板（旧版 wiki 提到的 `中华书局` 模板并不存在）。

## 与 guji 的区别

| 特性 | cn-vbook / tw-vbook | guji |
|------|---------|---------|
| 设计风格 | 现代简洁 | 传统古籍 |
| 版心/鱼尾 | 无 | 支持 |
| 边框/丝栏 | 无 | 支持 |
| 布局模式 | 自由列宽 (`n-column=0`) | 固定网格 (`n-column=8`) |
| 标点默认 | 现代标点 (normal) | 可选句读/正常 |
| 脚注 | 内置支持 | 需手动加载 |
| 页码 | 自动竖排 | 版心中缝 |

## 标点风格配置

`ltc-cn-vbook` / `ltc-tw-vbook` 默认启用现代标点系统。详见 [[标点系统 | Punctuation]]。

### 台湾风格（`ltc-tw-vbook` 默认）

```latex
\documentclass{ltc-tw-vbook}
% 标点居中，这是 tw-vbook 的默认设置
```

### 中国大陆风格（`ltc-cn-vbook` 默认）

```latex
\documentclass{ltc-cn-vbook}
% 或在任一类中显式指定：
\punctSetup{punct-style=mainland}
```

### 句读模式

虽然现代竖排文档类默认使用现代标点，但也可以切换到句读模式：

```latex
\documentclass{ltc-cn-vbook}
\开启句读模式  % 切换到句读模式

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。
% 逗号变为右下角小点，句号变为右下角小圈
\end{正文}
\end{document}
```

## 双面镜像页边距 (v0.3.2+)

竖排书在右侧装订：**奇数页是对开的左页**，书脊在它右边；偶数页是右页，书脊在它左边。vbook 默认启用双面模式（`twoside=true`），奇偶页自动镜像内外边距：

- **内边距** (`margin-inner`)：书脊侧边距（奇数页=右边距，偶数页=左边距），默认 `24mm`
- **外边距** (`margin-outer`)：翻口侧边距（奇数页=左边距，偶数页=右边距），默认 `16mm`

```latex
\pageSetup{
    twoside = true,
    margin-inner = 24mm,   % 书脊侧
    margin-outer = 16mm,   % 翻口侧
}
```

> 读哪一组边距由 `twoside` 决定（v0.4.3+）：`twoside=true` 只读 `margin-inner` / `margin-outer`，`twoside=false` 只读 `margin-left` / `margin-right`；设置了被忽略的一组会收到警告。`twoside=false` 时页眉页码固定在左侧，不随奇偶页交替。

> **v0.4.4 方向修正**：此前 `margin-inner` 按横排习惯放在奇数页左侧，实际落在翻口一侧。现在按书脊算，vbook 默认值同时互换为 inner 24mm／outer 16mm，默认版面不变。自己写了 `margin-inner ≠ margin-outer` 的文档左右会对调，把两个值互换即可。古籍模板的 inner／outer 相等，不受影响。

### 对页固定内容区 (v0.4.4+)

想让奇偶页的正文落在同一位置（类似 InDesign／Word 按上下左右边距固定内容区），用 `mirror-margins = false`：

```latex
\pageSetup{
    twoside = true,
    mirror-margins = false,     % 镜像边距 = false
    margin-left = 22mm, margin-right = 22mm,
    binding-offset = 8mm,       % 装订边距（要装订时加）
    header-anchor = content,    % 页眉锚点 = 内容区
}
```

| 参数 | 中文键 | 默认值 | 说明 |
|------|--------|--------|------|
| `mirror-margins` | `镜像边距`／`鏡像邊距` | `true` | 设为 `false` 时，`twoside = true` 也读 `margin-left`／`margin-right`，内容区在奇偶页同一位置；书眉、页码仍奇偶交替 |
| `binding-offset` | `装订边距`／`裝訂邊距` | `0pt` | 加在书脊一侧：奇数页加在右边，偶数页加在左边；`twoside = false` 时加在右边。三种边距模式都生效 |

三种边距模式：

| `twoside` | `mirror-margins` | 读取的边距 | 适用 |
|-----------|------------------|-----------|------|
| `true` | `true`（默认） | `margin-inner`／`margin-outer`，奇偶镜像 | 装订成书的对开版式 |
| `true` | `false` | `margin-left`／`margin-right`，每页相同 | 内容区固定、书眉页码仍交替 |
| `false` | — | `margin-left`／`margin-right`，每页相同 | 不装订打印、屏幕阅读 |

## 运行页眉 (v0.3.2+)

vbook 支持运行页眉，自动在奇偶页交替显示章节名和书名。

### 配置

```latex
\pageSetup{
    header-enabled = true,    % 启用页眉
    header-font-size = 9pt,   % 页眉字号
    header-y = 52mm,          % 页眉纵向位置
}
```

### 显示规则

| 页面 | 页眉内容 | 位置 |
|------|---------|------|
| 奇数页（左页） | 章节名 (`\chapter{...}`) | 左侧（翻口侧） |
| 偶数页（右页） | 书名 (`\title{...}`) | 右侧（翻口侧） |

页眉默认在外侧（翻口侧）上角，页码在外侧下角。`header-position = inner`（`页眉位置 = 内侧`）可把页眉移到书脊侧（v0.4.4+）。

### 页眉锚点 (v0.4.4+)

默认 `header-anchor = paper`（`页眉锚点 = 纸边`）：页眉、页码按 `header-y`／`page-number-x`／`page-number-y` 从纸边量。改了边距后要手动调这几个值。

`header-anchor = content`（`页眉锚点 = 内容区`）让页眉、页码跟着内容区走：放在内容区外侧 `header-sep`（`页眉间距`，默认 `6mm`）处，页眉顶端对齐内容区上边，页码底端对齐内容区下边。此时 `header-y`／`page-number-y` 若写了，就作为相对这两条边的偏移。

### 跳过页眉

在标题页等不需要页眉的页面使用 `\skipHeader`：

```latex
\skipHeader
\卷名{史記卷六}
\章节名{秦始皇本紀第六}
```

## 段落与首行缩进 (v0.3.2+)

vbook 支持段落首行缩进，通过 `\contentSetup` 或 `StyleEnv` 环境配置：

```latex
\contentSetup{
    first-indent = 2,   % 首行缩进2格
}
```

布局引擎自动检测段落边界（通过 `\par` 或空行），对每段首行应用缩进。

也可在 `\Style` 中临时设置：

```latex
\Style[first-indent=0]{不缩进的段落内容}
```

## 卷名与章节名命令 (v0.3.2+)

vbook 提供专用的标题命令：

| 命令 | 功能 | 示例 |
|------|------|------|
| `\卷名{...}` | 卷名标题（24pt，上间距48pt） | `\卷名{史記卷六}` |
| `\章节名{...}` | 章节名标题（20pt，首行缩进2字） | `\章节名{秦始皇本紀第六}` |

`\章节名` 会自动调用 `\chapter`，同步更新页眉和版心中的章节标题。

## 脚注系统

现代竖排文档类内置脚注支持，提供段末注和页下注两种模式。

### 基本用法

```latex
\documentclass{ltc-cn-vbook}
\脚注设置{number-style=lujiao, indent=2}

\begin{document}
\begin{正文}
天地玄黄\脚注{此为千字文首句}，宇宙洪荒\脚注{天地初开之意}。
\输出脚注  % 在段落末尾输出所有脚注
\end{正文}
\end{document}
```

### 配置参数

通过 `\footnoteSetup` (或 `\脚注设置`) 配置：

| 参数 | 说明 | 默认值 | 可选值 |
|------|------|--------|--------|
| `mode` | 脚注模式 | `endnote` | `endnote` (段末注), `page` (页下注) |
| `number-style` | 编号样式 | `lujiao` | `lujiao` (【一】), `circled` (①) |
| `separator` | 各条之间的分隔 | `blank` | `blank`（1em 空白）, `none` |
| `font-size` | 脚注字号 | `0.8em` | 任意尺寸 |
| `font-color` | 脚注颜色 | (继承) | 任意颜色 |
| `indent` | 悬挂缩进（格数） | `2` | 整数 |
| `marker-height` | 编号占用格数 | `2` | 整数 |
| `spacing` | 间距 | `0.5em` | 任意尺寸 |

### 命令一览

| 命令 | 中文别名 | 说明 |
|------|---------|------|
| `\Footnote{内容}` | `\脚注{内容}` | 添加脚注 |
| `\FlushFootnote` | `\输出脚注` | 输出段末注 |
| `\FootnoteParagraph{内容}` | `\脚注段落{内容}` | 无编号脚注段落（如"索隱曰…"） |
| `\footnoteSetup{...}` | `\脚注设置{...}` | 配置脚注参数 |
| `\ResetFootnoteCounter` | `\重置脚注计数` | 重置脚注编号 |

## 页码

现代竖排文档类自动显示竖排页码。启用 `twoside` 时，页码默认在外侧（翻口侧）下角，奇偶页交替。

### 页码配置

通过 `\pageSetup` 配置：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `page-number-style` | 页码样式 | `digits` |
| `page-number-font-size` | 页码字号 | `9pt` |
| `page-number-position` | 页码位置：`outer` 翻口侧、`inner` 书脊侧、`center` 页脚横向居中（中文键 `页码位置 = 外侧 / 内侧 / 居中`，v0.4.4+） | `outer` |
| `header-position` | 页眉位置：`outer` 翻口侧、`inner` 书脊侧（`页眉位置 = 外侧 / 内侧`，v0.4.4+） | `outer` |
| `header-anchor` | 页眉页码的定位基准：`paper` 纸边、`content` 内容区（`页眉锚点 = 纸边 / 内容区`，v0.4.4+） | `paper` |
| `header-sep` | `header-anchor = content` 时，页眉页码距内容区外边的距离（`页眉间距`，v0.4.4+） | `6mm` |
| `page-number-x` | 页码距页边的水平距离（`页码横移`） | `3mm` |
| `page-number-y` | 页码距页底的垂直距离（`页码纵移`）；`header-anchor = content` 时为相对内容区下边的偏移 | `52mm` |
| `header-y` | 页眉距页顶的垂直距离（`页眉纵移`）；`header-anchor = content` 时为相对内容区上边的偏移 | `52mm` |

`page-number-position` 只移动页码，`header-position` 只移动页眉。

> v0.4.4 起「内侧／外侧」按真正的装订方向（书脊）算，默认改为 `outer`，默认版面与之前相同。之前写了 `页码位置 = 内侧` 的文档，现在要写 `外侧` 才是原来的位置。

页码样式：
- `digits`：逐位中文数字（如 一二三）
- `chinese`：传统中文数字（如 一百二十三）
- `arabic`：阿拉伯数字
- `none`：不显示页码

## 自定义模板

在文档目录下创建 `<模板名>.cfg`（或放到 TeX 路径中的 `configs/luatex-cn-vbook-<模板名>.cfg`）。模板在默认配置之后加载，只写要改的项：

```latex
% mytemplate.cfg
\pageSetup{
    paper-width = 148mm,
    paper-height = 210mm,
    margin-top = 20mm,
    margin-bottom = 15mm,
    margin-inner = 18mm,
    margin-outer = 15mm,
    page-number-style = digits,
}

\contentSetup{
    font-size = 11pt,
    line-spacing = 13pt,
    grid-width = 13pt,
    grid-height = 13pt,
}

\punctSetup{punct-style=taiwan}
```

然后在文档中使用：

```latex
\documentclass[mytemplate]{ltc-cn-vbook}
```

## 自由列宽模式

`ltc-cn-vbook` / `ltc-tw-vbook` 默认使用 `n-column=0`，即**自由列宽模式**。与 `ltc-guji` 的固定 8 列网格不同，自由模式下每列的宽度由内容决定，布局引擎自动追踪各列宽度并在内容超出页面宽度时分页。

这种模式适合现代书籍中列宽不固定的场景，如混合不同字号、使用 `\行[宽度=3cm]{...}` 指定不等宽列等。

在自定义模板中启用：
```latex
\contentSetup{
    n-column = 0,           % 启用自由列宽
    grid-width = 13pt,
    grid-height = 13pt,
    border = false,
}
```

---

下一步：查看 [[标点系统 | Punctuation]] | [[功能详解 | Features]] | [[模板与自定义 | Templates]]
