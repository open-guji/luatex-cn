[English Version](EN:Templates) | 中文版

# 模板使用与自定义

`luatex-cn` 的「模板」就是一份配置文件（`.cfg`），里面写 `\pageSetup`、`\contentSetup`、`\banxinSetup` 等设置命令。在文档类选项里写模板名即可加载。

## 内置模板

| 模板名称 | 文档类 | 说明 |
|---------|-------|------|
| `四库全书`（`default`） | `ltc-guji` | 经典官修书籍风格（黑白版），`ltc-guji` 的默认模板 |
| `四库全书彩色`（`SiKuQuanShu-colored`） | `ltc-guji` | 经典官修书籍风格（彩色版） |
| `红楼梦甲戌本`（`HongLouMengJiaXuBen`） | `ltc-guji` | 手抄本风格，支持侧批与眉批 |
| `欧式族谱`（`oushizupu`） | `ltc-guji` | 族谱风格 |
| （默认配置） | `ltc-cn-vbook` | 现代竖排，中国大陆标点 |
| （默认配置） | `ltc-tw-vbook` | 现代竖排，台湾标点 |

现代竖排两类没有命名模板，各自加载默认配置，详见 [[现代竖排 | ltc-book]]。

## 使用模板

在文档类选项中指定模板名称：

```latex
\documentclass[四库全书彩色]{ltc-guji}
\documentclass[红楼梦甲戌本]{ltc-guji}

% 也可以在导言区切换（这里要写英文名）
\gujiSetup{ template = HongLouMengJiaXuBen }
```

## 自定义模板

### 方法 1：创建配置文件（推荐）

模板名 `<名>` 的查找顺序：先找文档目录下的 `<名>.cfg`，再找 TeX 路径中的 `configs/` 目录。

| 文档类 | 文件名 |
|-------|-------|
| `ltc-guji` | `<名>.cfg` 或 `configs/luatex-cn-guji-<名>.cfg` |
| `ltc-cn-vbook`／`ltc-tw-vbook` | `<名>.cfg` 或 `configs/luatex-cn-vbook-<名>.cfg` |

然后 `\documentclass[<名>]{ltc-guji}` 即可加载。

#### guji 模板

```latex
% MyTemplate.cfg（放在文档目录下）

\gujiSetup{ template = default }   % 先套用四库全书，再改下面几项

\pageSetup{
    paper-width = 1077.2pt,
    paper-height = 1077.2pt,
    margin-top = 226.8pt,
    margin-bottom = 113.4pt,
    margin-left = 25.5pt,
    margin-right = 25.5pt,
}

\contentSetup{
    n-column = 12,
    font-size = 30pt,
    line-spacing = 45pt,
    n-char-per-col = 18,
    border = true,
}

\banxinSetup{
    banxin-upper-ratio = 0.18,
    banxin-middle-ratio = 0.38,
    upper-yuwei = true,
    lower-yuwei = true,
}

\endinput
```

#### cn-vbook / tw-vbook 模板

模板在默认配置之后加载，只需写要改的项：

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

\endinput
```

### 方法 2：在文档中直接配置

在导言区直接写设置命令，书名、卷名用 `\title`、`\chapter`：

```latex
\documentclass{ltc-guji}

\contentSetup{
    n-column = 10,
    font-size = 24pt,
    border = true,
}

\title{我的书名}

\begin{document}
\begin{正文}
\chapter{第一章}
% ...
\end{正文}
\end{document}
```

> `\gujiSetup` 目前只认 `template` 一个键；旧版 wiki 里写的 `\gujiSetup{book-name=…}` 和用 `\defineGujiTemplate` 打包版面参数的写法都会报未知键。

## 常用配置项

下表默认值是不加载模板时的代码默认值；各模板会覆盖其中一部分。完整参数见 [[命令索引 | Command-Reference]]。

| 配置命令 | 参数 | 说明 | 默认值 |
|---------|------|------|-------|
| `\gujiSetup` | `template` | 模板名称（英文名） | — |
| `\contentSetup` | `n-column` | 每半页列数（0 = 自由列宽） | 8 |
| | `n-char-per-col` | 每列字数（0 = 自动） | 0 |
| | `font-size` | 字号 | 12pt |
| | `grid-width`／`grid-height` | 格宽／格高 | 1.5em／1.2em |
| | `line-spacing` | 行距（natural 模式） | `\baselineskip` |
| | `border` | 显示丝栏 | false |
| | `border-color` | 丝栏颜色 | black |
| | `font-color` | 字体颜色 | _(空)_ |
| | `layout-mode` | 排版模式：`grid`／`natural` | `grid` |
| | `horizontal-align` | 行块水平位置：`right`／`center`／`left`（v0.4.5+） | `right` |
| `\pageSetup` | `paper-width`／`paper-height` | 纸张宽高 | 210mm／297mm |
| | `margin-*` | 页边距 | 0pt |
| | `twoside` | 对页（奇偶页镜像边距） | false |
| | `page-number-style` | 页码样式 | _(空)_ |
| `\banxinSetup` | `banxin-upper-ratio` | 版心上部比例 | 0.28 |
| | `upper-yuwei`／`lower-yuwei` | 上／下鱼尾 | true |
| | `book-ear` | 书耳（v0.4.5+） | false |
| `\punctSetup` | `punct-style` | 标点风格 | `taiwan` |
| | `punct-squeeze` | 标点挤压 | `true` |
| | `kinsoku` | 禁则处理 | `true` |

---

下一步：查看 [[调试模式 | Debug]] 或 [[功能详解 | Features]]
