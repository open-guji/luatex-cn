# 字体设置说明 (Font Setup Guide)

## 概述

从此版本开始，`luatex-cn` 不再强制设置默认字体。用户可以自由选择是否使用 `fontspec` 包来设置字体。

## 变更内容

### 1. 类文件变更

- `ltc-guji.cls` 和 `ltc-book.cls` 不再自动加载 `fontspec` 包
- 移除了默认字体设置（之前默认为 `TW-Kai`）

### 2. 配置文件变更

所有模板配置文件（`.cfg`）已移除 `font-name` 参数，不再设置默认字体。

## 使用方式

### 方式一：在文档中设置字体（推荐）

用户可以在自己的 `.tex` 文件中加载 `fontspec` 并设置字体：

```latex
\documentclass{ltc-guji}

% 加载 fontspec 包
\usepackage{fontspec}

% 设置正文主字体（例如：汲古书体）
\setmainfont{JiGu}[
    RawFeature={+vert,+vrt2},  % 启用垂直排版
    CharacterWidth=Full         % 全角字符
]

\title{我的古籍}

\begin{document}
\begin{正文}
这是正文内容
\end{正文}
\end{document}
```

### 方式二：使用模板设置字体

如果需要在模板中统一设置字体，可以在配置文件中添加：

```latex
\gujiSetup{
    % ... 其他配置 ...
    font-name = JiGu,
    font-features = RawFeature={+vert,+vrt2}, CharacterWidth=Full,
}
```

或在 `\begin{正文}` 环境参数中设置：

```latex
\begin{正文}[
    font-name = JiGu,
    font-features = RawFeature={+vert,+vrt2}, CharacterWidth=Full
]
这是正文内容
\end{正文}
```

### 方式三：使用系统默认字体

如果不加载 `fontspec` 也不设置字体，LuaTeX 将使用系统默认字体。

## 常用字体设置示例

### 汲古书体（JiGu）
```latex
\setmainfont{JiGu}[RawFeature={+vert,+vrt2}, CharacterWidth=Full]
```

### TW-Kai（全字庫正楷體）
```latex
\setmainfont{TW-Kai}[RawFeature={+vert,+vrt2}, CharacterWidth=Full]
```

### 华文楷体（STKaiti）
```latex
\setmainfont{STKaiti}[RawFeature={+vert,+vrt2}, CharacterWidth=Full]
```

## 注意事项

1. **垂直排版特性**：对于中文垂直排版，建议添加 `RawFeature={+vert,+vrt2}` 参数以启用垂直排版字形
2. **全角字符**：建议添加 `CharacterWidth=Full` 参数以确保字符宽度一致
3. **字体安装**：确保系统已安装所需字体，或使用绝对路径指定字体文件

## 示例文件

参见 `example/font-setup-example.tex` 了解完整示例。

## 迁移指南

如果您的文档之前依赖模板的默认字体设置，请在文档开头添加：

```latex
\usepackage{fontspec}
\setmainfont{TW-Kai}[RawFeature={+vert,+vrt2}, CharacterWidth=Full]
```

这将恢复之前的默认字体行为。