# cn_vertical - 中文竖排包

这是一个用于 LuaTeX 的中文竖排包，利用 LuaTeX 原生 `dir` 属性（RTT 模式）实现传统中文竖直排版。

---

## 目录

- [快速开始](#快速开始)
- [实现原理](#实现原理)
- [当前功能](#当前功能)
- [未来规划](#未来规划)
- [更新日志](#更新日志)

---

## 快速开始

### 最简单的例子

```latex
\documentclass{article}
\usepackage{fontspec}
\setmainfont{Microsoft YaHei} % 或其他支持竖排特性的字体
\usepackage{cn_vertical}

\begin{document}

\section{竖排演示}

\VerticalRTT{
    天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。
    寒来暑往，秋收冬藏。闰余成岁，律吕调阳。
    （多行文本会自动从右向左分栏）
}

或者使用别名：

\vertical{
    云腾致雨，露结为霜。金生丽水，玉出昆冈。
}

\end{document}
```

---

## 实现原理

### 核心机制：原生 `dir RTT`

本包废弃了手动堆叠字符盒子的旧方案，转而使用 LuaTeX 引擎原生的方向支持 (`dir`)。

1.  **`RTT` 模式**：
    - `RTT` (Right-to-Left Top-to-Bottom) 表示：
        - 文字流动：从上到下。
        - 换列方向：从右到左。
    - 这是传统汉字竖排的标准模式。

2.  **右对齐布局**：
    - 竖排文本块被放置在一个右对齐的容器中，符合古籍阅读习惯（从页面右侧开始）。

#### 关键代码

**Lua 模块** ([cn_vertical.lua](cn_vertical.lua))：

```lua
function cn_vertical.vertical_rtt(text)
    local vertical_height = "300pt" -- 默认列高
    
    tex.print("\\par")
    -- 1. 创建右对齐容器
    tex.print("\\hbox to \\hsize{\\hfill")
    
    -- 2. 使用 vbox dir RTT 开启竖排模式
    tex.print("\\vbox dir RTT {")
    tex.print("\\hsize=" .. vertical_height) -- 必须指定高度以触发换列
    tex.print("\\pardir RTT \\textdir RTT")
    tex.print("\\noindent " .. text)
    tex.print("}") 
    
    tex.print("}") -- end hbox
    tex.print("\\par")
end
```

---

## 功能特性

### ✅ 已实现功能

1.  **原生竖排 (`dir RTT`)**
    - 使用 `\VerticalRTT{...}` 或 `\vertical{...}`。
    - 汉字从上到下，列从右向左。

2.  **智能分行与自动排版**
    - **自动断行**：支持在任意汉字之间自动断行，无需手动控制，多行文本自然流动。
    - **标准 LaTeX 行为**：源码中的换行符会被视为标准空格（CJK 间可能会显示为空白），这符合原生 LaTeX 习惯。

3.  **高度自适应**
    - 默认情况下，竖排块会自动计算并填充当前页面的剩余高度。
    - 也可以通过参数 (`height`) 手动指定高度。

4.  **参数化控制**
    - 支持通过键值对参数调整高度、列间距和字间距。

### ⚙️ 参数说明

```latex
\vertical[key=value]{...}
```

| 参数键 | 说明 | 默认值 |
| :--- | :--- | :--- |
| `height` | 竖排块高度。不指定则自动填充页面剩余空间。 | 自动 (剩余页高) |
| `spacing-col` | 列间距（即水平方向的行距）。 | 继承当前 `\baselineskip` |
| `spacing-char` | 字间距（字符垂直间距）。 | `20` |

### ⚠️ 当前限制

1.  **标点位置**：依赖字体的 `vert` 特性，某些标点可能并未完美居中或旋转。
2.  **西文旋转**：混排的西文目前保持原样（侧倒），尚未实现顺时针旋转 90 度。

## 未来规划

1.  **西文旋转**：实现西文字符的顺时针旋转，符合竖排惯例。
2.  **标点微调**：优化标点符号的挤压和定位。

---

## 更新日志

### v0.3.0 (2025-01-08)

- **重构**：全面转向 LuaTeX 原生 `dir RTT` 方案。
- **新增**：`\VerticalRTT` 和 `\vertical` 命令。
- **废弃**：移除了基于 vbox 手动堆叠的旧实现。
- **特性**：支持从右到左的自动分栏。

### v0.2.0 (2025-01-08)

- 实现基于 `\vbox`/`\hbox` 的简单竖排方案（已被 v0.3.0 取代）。

### v0.1.0

- 初始探索版本。
