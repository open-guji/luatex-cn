# 垂直对齐功能 (Vertical Alignment Feature)

## 概述

`cn_vertical` 包和 `guji` 类现在支持控制文字在格子中的垂直对齐方式。

## 参数

### `vertical-align`

控制文字在格子中的垂直位置。

**可选值：**
- `top` - 上对齐（文字靠近格子顶部）
- `center` - 居中对齐（文字在格子中央）**[默认值]**
- `bottom` - 下对齐（文字靠近格子底部）

## 使用示例

### 1. 使用 `\VerticalRTT` 命令

```latex
\documentclass{article}
\usepackage{fontspec}
\usepackage{cn_vertical}
\setmainfont{TW-Kai-98}

\begin{document}

% 居中对齐（默认）
\VerticalRTT[
    height=200pt,
    grid-width=40pt,
    grid-height=40pt,
    vertical-align=center
]{
    居中对齐的文字
}

% 上对齐
\VerticalRTT[
    height=200pt,
    grid-width=40pt,
    grid-height=40pt,
    vertical-align=top
]{
    上对齐的文字
}

% 下对齐
\VerticalRTT[
    height=200pt,
    grid-width=40pt,
    grid-height=40pt,
    vertical-align=bottom
]{
    下对齐的文字
}

\end{document}
```

### 2. 使用 `guji` 类

```latex
\documentclass{guji}

\begin{document}

% 居中对齐（默认）
\begin{guji-content}[template=sikuquanshu, vertical-align=center]
欽定四庫全書。史部一。正史類。
\end{guji-content}

% 上对齐
\begin{guji-content}[template=sikuquanshu, vertical-align=top]
欽定四庫全書。史部一。正史類。
\end{guji-content}

% 下对齐
\begin{guji-content}[template=sikuquanshu, vertical-align=bottom]
欽定四庫全書。史部一。正史類。
\end{guji-content}

\end{document}
```

### 3. 在模板中设置默认值

在 `.guji` 模板文件中可以设置默认的垂直对齐方式：

```latex
% mytemplate.guji
\gujiSetup{
    font-size = 28pt,
    grid-width = 54.3pt,
    grid-height = 30.15pt,
    vertical-align = center  % 设置默认居中对齐
}
```

## 技术说明

### 对齐计算

对于每个字符，垂直位置 `yoffset` 的计算方式如下：

- **top**: `yoffset = -row * grid_height - height`
  - 基线位于格子顶部

- **center**: `yoffset = -row * grid_height - (grid_height + height + depth) / 2 + depth`
  - 字符的视觉中心位于格子中心

- **bottom**: `yoffset = -row * grid_height - grid_height + depth`
  - 基线位于格子底部（保持原有行为）

其中：
- `height` 和 `depth` 是字符的高度和深度
- `grid_height` 是格子的高度
- `row` 是字符所在的行号

## 兼容性

- 默认值为 `center`（居中对齐）
- 如果不指定 `vertical-align` 参数，将使用默认值
- 与列表缩进、多列布局等其他功能完全兼容

## 更新日志

- **v0.3.0** (2026-01-11): 添加 `vertical-align` 参数支持
