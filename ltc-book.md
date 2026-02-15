[English Version](EN:ltc-book) | 中文版

# 现代竖排文档类 (v0.2.7+)

luatex-cn 提供两个面向现代竖排中文书籍的文档类，与 `guji`（古籍排版）不同，它们采用简洁的现代设计：无版心、无鱼尾、无丝栏，适合当代出版物的竖排需求。

| 文档类 | 标点风格 | 说明 |
|--------|---------|------|
| **`cn-vbook`** (v0.2.8+) | 大陆 | 简体中文竖排书籍 |
| **`tw-vbook`** (v0.2.8+) | 台湾 | 繁体中文竖排书籍 |
| `ltc-book` | 台湾 | 旧名称，仍可使用 |

## 基本用法

```latex
\documentclass{cn-vbook}
\setmainfont{Noto Serif SC}

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。
寒来暑往，秋收冬藏。闰余成岁，律吕调阳。
\end{正文}
\end{document}
```

## 模板系统

通过文档类选项选择预设模板：

| 选项 | 说明 | 标点风格 |
|------|------|---------|
| (无) | 默认模板，16 开 (170×240mm)，12pt 字号 | 台湾 |
| `中华书局` | 中华书局风格，15pt 字号，启用脚注 | 大陆 |

```latex
% 使用默认模板
\documentclass{cn-vbook}

% 使用中华书局模板
\documentclass[中华书局]{cn-vbook}
```

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

`cn-vbook` / `tw-vbook` 默认启用现代标点系统。详见 [[标点系统 | Punctuation]]。

### 台湾风格 (默认)

```latex
\documentclass{cn-vbook}
% 标点居中，这是默认设置
```

### 大陆风格

```latex
\documentclass{cn-vbook}
\punctSetup{punct-style=mainland}
```

或直接使用中华书局模板（自动设置为大陆风格）：

```latex
\documentclass[中华书局]{cn-vbook}
```

### 句读模式

虽然现代竖排文档类默认使用现代标点，但也可以切换到句读模式：

```latex
\documentclass{cn-vbook}
\开启句读模式  % 切换到句读模式

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。
% 逗号变为右下角小点，句号变为右下角小圈
\end{正文}
\end{document}
```

## 脚注系统

现代竖排文档类内置脚注支持，提供段末注和页下注两种模式。

### 基本用法

```latex
\documentclass{cn-vbook}
\脚注设置{number-style=lujiao, indent=1em}

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
| `separator` | 分隔方式 | `blank` | `blank` (空行), `none` |
| `font-size` | 脚注字号 | `0.8em` | 任意尺寸 |
| `font-color` | 脚注颜色 | (继承) | 任意颜色 |
| `indent` | 缩进 | `1em` | 任意尺寸 |
| `spacing` | 间距 | `0.5em` | 任意尺寸 |

### 命令一览

| 命令 | 中文别名 | 说明 |
|------|---------|------|
| `\Footnote{内容}` | `\脚注{内容}` | 添加脚注 |
| `\FlushFootnote` | `\输出脚注` | 输出段末注 |
| `\footnoteSetup{...}` | `\脚注设置{...}` | 配置脚注参数 |
| `\ResetFootnoteCounter` | `\重置脚注计数` | 重置脚注编号 |

## 页码

现代竖排文档类自动在页面左下角显示竖排页码。

### 页码配置

通过 `\pageSetup` 配置：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `page-number-style` | 页码样式 | `digits` |
| `page-number-font-size` | 页码字号 | `9pt` |
| `page-number-x` | 页码 X 位置 | `3mm` |
| `page-number-y` | 页码 Y 位置 | `8mm` |

页码样式：
- `digits`：逐位中文数字（如 一二三）
- `chinese`：传统中文数字（如 一百二十三）
- `arabic`：阿拉伯数字
- `none`：不显示页码

## 自定义模板

创建 `configs/luatex-cn-book-<模板名>.cfg` 文件：

```latex
% configs/luatex-cn-book-mytemplate.cfg
\pageSetup{
    paper-width = 148mm,
    paper-height = 210mm,
    margin-top = 20mm,
    margin-bottom = 15mm,
    margin-left = 18mm,
    margin-right = 15mm,
    page-number-style = digits,
}

\contentSetup{
    font-size = 11pt,
    line-spacing = 13pt,
    grid-width = 13pt,
    grid-height = 13pt,
    vertical-align = center,
    n-column = 0,
    border = false,
}

\punctSetup{punct-style=taiwan}
```

然后在文档中使用：

```latex
\documentclass[mytemplate]{cn-vbook}
```

## 自由列宽模式

`cn-vbook` / `tw-vbook` 默认使用 `n-column=0`，即**自由列宽模式**。与 `guji` 的固定 8 列网格不同，自由模式下每列的宽度由内容决定，布局引擎自动追踪各列宽度并在内容超出页面宽度时分页。

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
