[English Version](EN:Templates) | 中文版

# 模板使用与自定义

`luatex-cn` 提供了灵活的模板系统，支持内置模板和自定义模板。

## 内置模板

| 模板名称 | 文档类 | 说明 |
|---------|-------|------|
| `四库全书` | `ltc-guji` | 经典官修书籍风格（黑白版） |
| `四库全书彩色` | `ltc-guji` | 经典官修书籍风格（彩色版） |
| `红楼梦甲戌本` | `ltc-guji` | 手抄本风格，支持侧批与眉批 |
| `default` | `ltc-book` | 默认现代竖排风格 |

## 使用模板

在文档类选项中指定模板名称：

```latex
% 使用彩色四库全书模板
\documentclass[四库全书彩色]{ltc-guji}

% 使用红楼梦甲戌本模板
\documentclass[红楼梦甲戌本]{ltc-guji}
```

## 自定义模板

### 方法 1：创建配置文件

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

### 方法 2：在文档中直接配置

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

### 方法 3：使用 defineGujiTemplate 定义模板

```latex
\defineGujiTemplate{我的模板}{
    book-name = 默认书名,
    n-column = 10,
    border = true,
}

% 使用自定义模板
\gujiSetup{ template = 我的模板 }
```

## 配置项一览表

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

---

👉 下一步：查看 [[调试模式 | Debug]] 或 [[功能详解 | Features]]
