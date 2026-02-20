# LuaTeX-cn 用户手册

[English Version](luatex-cn-en-doc.md)

`luatex-cn` 是一个专门为 LuaTeX 设计的中文排版宏包，特别增强了对古籍垂直排版（Guji Layout）和现代竖排的支持。

---

## 1. 首页

### 项目简介

`luatex-cn` 宏包旨在为中文垂直排版提供专业的解决方案，主要特点包括：

- **古籍排版**：完整支持传统古籍的版面格式，包括乌丝栏、版心、鱼尾等元素
- **现代竖排**：支持简洁的现代竖排风格，适用于小说、报告等
- **注释系统**：提供夹注、侧批、眉批等多种注释方式
- **模板系统**：内置多种预设模板，支持自定义扩展

### 系统要求

- **编译器**: 必须使用 `LuaLaTeX` (版本 1.10+)。不支持 pdfLaTeX 或 XeLaTeX。
- **发行版**: 推荐使用 TeX Live 2024 或更高版本。

---

## 2. 快速开始

### 2.1 安装指南

#### 方法 1：通过 CTAN/包管理器安装（推荐）

- **TeX Live (Windows/Linux)**: 打开终端并运行 `tlmgr install luatex-cn`
- **MacTeX (macOS)**: 使用 **TeX Live Utility** 搜索并安装 `luatex-cn`
- **MiKTeX**: 打开 **MiKTeX Console**，进入 "Packages" 界面，搜索并点击安装 `luatex-cn`

#### 方法 2：从 GitHub Release 手动安装

1. **下载**: 前往 [GitHub Releases](https://github.com/open-guji/luatex-cn/releases) 页面，下载最新版本的 `luatex-cn-src-v*.zip`
2. **定位 texmf 目录**:
   - **Windows**: 通常位于 `C:\Users\<用户名>\texmf`
   - **macOS/Linux**: 通常位于 `~/texmf`
3. **放置文件**: 将下载的压缩包解压，将其中的所有文件放入 `texmf/tex/latex/luatex-cn/`
4. **刷新数据库**: 运行 `texhash`

#### 方法 3：使用 l3build 安装

如果你已经克隆了整个项目源码，可以使用 `l3build` 进行安装：

```bash
l3build install
```

#### 验证安装

创建一个简单的 `.tex` 文件并运行 `lualatex test.tex`，如果编译成功则安装成功。

### 2.2 快速入门

#### 古籍排版基础模板

创建一个 `.tex` 文件：

```latex
\documentclass[四库全书彩色]{ltc-guji}

\usepackage{enumitem}
\usepackage{tikz}

% 强烈建议指定字体，推荐全字库正楷
\setmainfont{TW-Kai}

\title{欽定四庫全書}
\chapter{史記\\卷一}

\begin{document}
\begin{正文}
欽定四庫全書

\begin{列表}
    \item 史記卷一
    \item \填充文本框[12]{漢太史令}司馬遷\空格 撰
    \item 五帝本紀第一
\end{列表}

\begin{段落}[indent=3]
这里是正文内容...
\夹注{这里是双行夹注内容，宏包会自动处理对齐与折行。}
\end{段落}

\end{正文}
\end{document}
```

使用 `lualatex` 编译即可获得带有彩色网格和自动版心的页面。

#### 现代竖排模板

```latex
\documentclass{ltc-book}

\setmainfont{Source Han Serif SC}

\begin{document}
\begin{正文}
这是一段现代竖排文本。
\end{正文}
\end{document}
```

### 2.3 模板使用与自定义

#### 内置模板

项目提供了以下内置模板：

| 模板名称 | 文档类 | 说明 |
|---------|-------|------|
| `四库全书` | `ltc-guji` | 经典官修书籍风格（黑白版） |
| `四库全书彩色` | `ltc-guji` | 经典官修书籍风格（彩色版） |
| `红楼梦甲戌本` | `ltc-guji` | 手抄本风格，支持侧批与眉批 |
| `default` | `ltc-book` | 默认现代竖排风格 |

#### 使用模板

在文档类选项中指定模板名称：

```latex
% 使用彩色四库全书模板
\documentclass[四库全书彩色]{ltc-guji}

% 使用红楼梦甲戌本模板
\documentclass[红楼梦甲戌本]{ltc-guji}
```

#### 自定义模板

##### 方法 1：创建配置文件

在 `configs/` 目录下创建 `luatex-cn-guji-<模板名>.cfg` 文件：

```latex
% luatex-cn-guji-MyTemplate.cfg

% 可以继承已有模板
\gujiSetup{ template = default }

% 页面设置
\pageSetup{
    paper-width = 1077.2pt,
    paper-height = 1077.2pt,
    margin-top = 226.8pt,
    margin-bottom = 113.4pt,
    margin-left = 25.5pt,
    margin-right = 25.5pt,
}

% 内容设置
\contentSetup{
    n-column = 12,
    font-size = 30pt,
    line-spacing = 45pt,
    n-char-per-col = 18,
    border = true,
}

% 版心设置
\banxinSetup{
    banxin-upper-ratio = 0.18,
    banxin-middle-ratio = 0.38,
    upper-yuwei = true,
    lower-yuwei = true,
}

\endinput
```

##### 方法 2：在文档中直接配置

```latex
\documentclass{ltc-guji}

\gujiSetup{
    book-name = 我的书名,
    chapter-title = 第一章,
}

\contentSetup{
    n-column = 10,
    font-size = 24pt,
    border = true,
}

\begin{document}
% ...
\end{document}
```

##### 方法 3：使用 defineGujiTemplate 定义模板

```latex
\defineGujiTemplate{我的模板}{
    book-name = 默认书名,
    n-column = 10,
    border = true,
}

% 使用自定义模板
\gujiSetup{ template = 我的模板 }
```

#### 字体配置

本宏包支持灵活的字体配置：

```latex
\usepackage{fontspec}

% 设置正文主字体
\setmainfont{JiGu}[
    RawFeature={+vert,+vrt2},  % 启用垂直排版
    CharacterWidth=Full         % 全角字符
]
```

推荐字体：
- **TW-Kai** (全字庫正楷體)：古籍排版首选
- **JiGu** (汲古书体)：仿古刻本效果
- **STKaiti** (华文楷体)：系统自带楷体

详细字体配置请参考：[luatex-cn-font-setup.md](./luatex-cn-font-setup.md)

---

## 3. 功能详解

### 3.1 文档类

#### `ltc-guji.cls` (古籍专用)

包含复杂的网格、鱼尾、版心控制，适用于重现历史文献。

#### `ltc-book.cls` (现代竖排)

适用于现代小说、报告，无网格，版式自由。

### 3.2 核心排版命令

#### 竖排命令

- **`\竖排[参数]{内容}`** / **`\VerticalRTT`**: 将指定内容按垂直网格排列

#### 文本框命令

- **`\TextBox[参数]{内容}`** / **`\文本框`**: 创建一个网格化的文本框
  - `height`: 占据的行数（网格高度）
  - `n-cols`: 内部细分列数（如一个大网格内排 3 列小字）
  - `box-align`: 内容对齐方式（`top`, `center`, `bottom`, `fill`）

- **`\填充文本框[高度]{内容}`**: 创建自动填充的文本框

#### 空格与占位

- **`\Space[长度]`** / **`\空格`**: 插入网格占位符

### 3.3 注释系统

#### 夹注（双行小字）

- **`\TextFlow{内容}`** / **`\文本流`** / **`\夹注`**: 生成传统古籍的"夹注"

```latex
正文内容\夹注{这里是双行小字注释}继续正文
```

#### 侧批

- **`\SideNode[参数]{内容}`** / **`\侧批`** / **`\CePi`**: 在版面边缘添加注释
  - `yoffset`: 垂直偏移量
  - `color`: 注释颜色（古籍常为红色）

```latex
\侧批[yoffset=1em, color=red]{这是侧批内容}
```

#### 批注（浮动批注框）

- **`\PiZhu[参数]{内容}`** / **`\批注`**: 创建浮动批注框，支持绝对定位
  - `x`, `y`: 绝对坐标
  - `height`: 批注框高度（以网格行为单位）
  - `font-size`: 批注字体大小
  - `color`: 批注颜色（支持 RGB 格式，如 `1 0 0` 表示红色）
  - `grid-width`, `grid-height`: 批注内部的行宽和字高

### 3.4 装饰与定位

#### 印章

- **`\YinZhang[参数]{图片路径}`** / **`\印章`**: 在当前页插入绝对定位的印章
  - `page`: 指定显示的页码
  - `x`, `y`: 坐标位置（相对于页面左上角）
  - `width`: 印章宽度

```latex
\印章[page=1, x=5cm, y=10cm, width=3cm]{seal.png}
```

### 3.5 段落控制

- **`\begin{Paragraph}[参数]`** / **`\begin{段落}`**:
  - `indent`: 全局缩进
  - `first-indent`: 首行缩进（默认为 1 或 2 个字符）
  - `bottom-indent`: 底部（右侧）留白

### 3.6 列表环境

- **`\begin{列表}`**: 创建垂直列表环境

```latex
\begin{列表}
    \item 第一项
    \item 第二项
\end{列表}
```

### 3.7 全局配置

#### gujiSetup（古籍配置）

```latex
\gujiSetup{
    book-name = 书名,           % 版心上方的书名
    chapter-title = 章节名,     % 版心中的章节名
    template = 四库全书彩色,    % 使用的模板
}
```

#### contentSetup（内容配置）

```latex
\contentSetup{
    n-column = 12,              % 每半页列数
    font-size = 30pt,           % 字体大小
    line-spacing = 45pt,        % 行距
    n-char-per-col = 18,        % 每列字符数
    border = true,              % 是否显示边框
    outer-border = false,       % 是否显示外边框
    font-color = {35, 25, 20},  % 字体颜色 (RGB)
    border-color = {180, 95, 75}, % 边框颜色 (RGB)
}
```

#### pageSetup（页面配置）

```latex
\pageSetup{
    paper-width = 1077.2pt,
    paper-height = 1077.2pt,
    margin-top = 226.8pt,
    margin-bottom = 113.4pt,
    margin-left = 25.5pt,
    margin-right = 25.5pt,
}
```

#### banxinSetup（版心配置）

```latex
\banxinSetup{
    banxin-upper-ratio = 0.18,  % 版心上部比例
    banxin-middle-ratio = 0.38, % 版心中部比例
    upper-yuwei = true,         % 上鱼尾
    lower-yuwei = true,         % 下鱼尾
    banxin-divider = true,      % 版心分隔线
}
```

### 3.8 配置项一览表

下表列出了主要配置命令及其参数：

| 配置命令 | 参数 | 说明 | 默认值 |
|---------|------|------|-------|
| `\gujiSetup` | `book-name` | 书名 | - |
| | `chapter-title` | 章节名 | - |
| | `template` | 模板名称 | `default` |
| `\contentSetup` | `n-column` | 每半页列数 | 12 |
| | `font-size` | 字体大小 | 30pt |
| | `line-spacing` | 行距 | 45pt |
| | `n-char-per-col` | 每列字符数 | 18 |
| | `border` | 显示边框 | true |
| | `font-color` | 字体颜色 (RGB) | {0,0,0} |
| | `border-color` | 边框颜色 (RGB) | {0,0,0} |
| `\pageSetup` | `paper-width` | 纸张宽度 | - |
| | `paper-height` | 纸张高度 | - |
| | `margin-*` | 页边距 | - |
| `\banxinSetup` | `banxin-upper-ratio` | 版心上部比例 | 0.18 |
| | `upper-yuwei` | 上鱼尾 | true |
| | `lower-yuwei` | 下鱼尾 | true |

### 3.9 调试模式

宏包提供了完整的调试功能，帮助排查排版问题。

#### 开启/关闭调试

```latex
\LtcDebugOn    % 或 \开启调试
\LtcDebugOff   % 或 \关闭调试
```

#### 模块级调试

```latex
\LtcDebugModuleOn{vertical}   % 或 \开启调试模块{vertical}
\LtcDebugModuleOff{vertical}  % 或 \关闭调试模块{vertical}
```

#### 显示辅助工具

```latex
% 显示页面边框
\LtcShowFrame   % 或 \显示边框

% 显示网格坐标
\LtcShowGrid[measure=cm]  % 或 \显示网格[measure=cm]
\LtcHideGrid              % 或 \隐藏网格

% 显示坐标（同显示网格）
\显示坐标[measure=pt]
\隐藏坐标
```

支持的单位：`cm`（默认）、`pt`、`mm`

#### 调试颜色设置

```latex
\LtcDebugColor{vertical}{blue}
```

---

## 4. 示例

### 4.1 史记五帝本纪

- **特点**：演示了高度复杂的古籍排版
- **功能**：
  - 绝对定位的红色印章（覆盖文字）
  - 版心自定义文字与单鱼尾
  - 复杂的夹注排版
  - 传统的乌丝栏与排版缩进

详见：[示例/史记五帝本纪/](../../示例/史记五帝本纪/)

### 4.2 史记目录

- **特点**：仿照清代《四库全书》北四阁本风格
- **功能**：
  - 标准的古籍目录布局
  - "八行二十一字"的行款限制
  - 典型的白口、四周双边、单鱼尾版式

详见：[示例/史记目录/](../../示例/史记目录/)

### 4.3 红楼梦甲戌本

- **特点**：模拟手抄本/批改本风格
- **功能**：
  - 侧批与眉批
  - 双列小字
  - 无鱼尾版心，底部页号显示

详见：[示例/红楼梦甲戌本/](../../示例/红楼梦甲戌本/)

### 4.4 现代竖排书

- **特点**：简洁的现代竖排风格
- **功能**：
  - 不带古籍元素的纯粹竖排文本支持
  - 适用于现代文学或报告的垂直排版需求

详见：[示例/现代竖排书/](../../示例/现代竖排书/)

---

## 5. 更多资源

- **项目主页**: [GitHub - open-guji/luatex-cn](https://github.com/open-guji/luatex-cn)
- **问题反馈**: [GitHub Issues](https://github.com/open-guji/luatex-cn/issues)
- **开发者指南**: [developer_guide.md](./developer_guide.md)
