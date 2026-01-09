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

## 当前功能

### ✅ 已实现

1.  **原生竖排**
    - 使用 `\VerticalRTT{...}` 或 `\vertical{...}` 命令。
    - 汉字自动从上到下排列。
    - 列（行）自动从右向左堆叠。

2.  **OpenType 支持**
    - 字体特性的 `vert` 功能通常会自动生效（依赖字体本身的支持）。

3.  **右对齐**
    - 整个竖排块默认靠右显示。

### ⚠️ 当前限制

1.  **标点位置**：虽然 `dir RTT` 处理了大部分布局，但某些标点符号的旋转或位置可能仍依赖字体的 `vert` 特性，如果字体不支持，可能显示不理想。
2.  **西文旋转**：混排的英文/数字目前不会自动顺时针旋转 90 度（需要后续开发支持）。
3.  **高度固定**：目前的竖排高度在代码中硬编码为 `300pt`（可以通过后续增加参数来配置）。

---

## 未来规划

1.  **参数化高度**：允许用户指定竖排块的高度（如 `\vertical[height=10cm]{...}`）。
2.  **西文处理**：实现西文字符的顺时针旋转，以符合竖排规范。
3.  **更强的标点控制**：对于特殊标点（如括号、引号）进行更精细的位置调整。

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
