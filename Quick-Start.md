[English Version](EN:Quick-Start) | 中文版

# 快速入门

本页面帮助你快速开始使用 `luatex-cn` 进行古籍排版。

## 基本模板

```latex
\documentclass[四库全书]{ltc-guji}
% 可选：指定字体
% \setmainfont{Noto Serif SC}

\title{钦定四库全书}
\chapter{史记\\卷一}

\begin{document}
\begin{正文}

這是古籍竖排的示例文本。

\end{正文}
\end{document}
```

## 常用命令

### 夹注（双行小字）

```latex
這是正文\\夹注{这是夹注内容，长夹注自动换列平衡}继续正文。
```

### 侧批

```latex
正文内容\\侧批[yoffset=10pt]{这是侧批内容}继续正文。
```

### 段落缩进

```latex
\\begin{段落}[indent=2]
    天地玄黄\\\\
    宇宙洪荒
\\end{段落}
```

### 空格

```latex
这里需要\\空格[2]两个空格的距离。
```

### 批注框

```latex
\\批注[x=5cm, y=2cm, height=6, color={1 0 0}]{这是批注内容}
```

### 印章

```latex
\\印章[page=1, xshift=2cm, yshift=5cm]{seal.png}
```

### 强制换列

```latex
这一列结束\\\\
新的一列开始
```

### 元数据设置（v0.2.0+）

```latex
\title{书名}
\publisher{出版社}
\ChapterMarker{卷一}
```

或使用中文命令：
```latex
\metadataSetup{
  title = 书名,
  publisher = 出版社
}
```

### 调试模式（v0.2.2+）

```latex
\LtcDebugOn   % 开启调试标尺，显示网格坐标
\LtcDebugOff  % 关闭调试模式
```

## 预设样式

通过文档类选项选择预设样式：

| 选项 | 说明 |
|------|------|
| `四库全书` | 清代四库全书风格，单鱼尾 |
| `红楼梦甲戌本` | 手抄本风格，无鱼尾 |

```latex
\\documentclass[四库全书]{ltc-guji}
% 或
\\documentclass[红楼梦甲戌本]{ltc-guji}
```

## 下一步

- 查看 [[示例 | Examples]] 了解更多复杂用法
- 阅读 [[更新日志 | Changelog]] 了解最新功能
