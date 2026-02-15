[English Version](EN:Debug) | 中文版

# 调试模式

`luatex-cn` 提供了完整的调试功能，帮助排查排版问题和定位元素位置。

---

## 1. 基础调试开关

### 1.1 全局开关

```latex
\LtcDebugOn    % 开启调试（或 \开启调试）
\LtcDebugOff   % 关闭调试（或 \关闭调试）
```

也可以在文档类选项中开启：

```latex
\documentclass[四库全书彩色, debug=true]{guji}
```

### 1.2 模块级调试

针对特定模块开启调试，减少日志量：

```latex
\LtcDebugModuleOn{vertical}   % 或 \开启调试模块{vertical}
\LtcDebugModuleOff{vertical}  % 或 \关闭调试模块{vertical}
```

**可用模块**：
- `vertical` - 竖排引擎
- `banxin` - 版心系统
- `sidenote` - 侧批
- `textflow` - 夹注分列
- `page` - 页面设置
- `page-split` - 筒子页分割
- `render` - 渲染阶段

---

## 2. 显示坐标网格

### 2.1 基本用法

在页面上叠加坐标网格，用于精确定位元素位置。

```latex
% 显示网格（默认单位 cm）
\LtcShowGrid              % 或 \显示网格

% 隐藏网格
\LtcHideGrid              % 或 \隐藏网格
```

### 2.2 指定单位

```latex
\LtcShowGrid[measure=cm]  % 厘米（默认）
\LtcShowGrid[measure=mm]  % 毫米
\LtcShowGrid[measure=pt]  % 点（1/72 英寸）
```

### 2.3 效果示例

```
    0    1    2    3    4    5    6 (cm)
  0 ┼────┼────┼────┼────┼────┼────┼
    │    │    │    │    │    │    │
  1 ┼────┼────┼────┼────┼────┼────┼
    │    │    │    │    │    │    │
  2 ┼────┼────┼────┼────┼────┼────┼
    │    │    │    │ ← 批注位于 (4, 2)
  3 ┼────┼────┼────┼────┼────┼────┼
```

### 2.4 别名

```latex
\显示坐标[measure=pt]  % 等同于 \LtcShowGrid[measure=pt]
\隐藏坐标              % 等同于 \LtcHideGrid
```

---

## 3. 显示页面边框

显示页面边界和内容区域：

```latex
\LtcShowFrame   % 或 \显示边框
```

效果：
- 红色线框：页面物理边界
- 蓝色线框：内容区域（margin 内）

---

## 4. 调试颜色设置

为不同模块的调试输出设置不同颜色（便于区分）：

```latex
\LtcDebugColor{vertical}{blue}
\LtcDebugColor{banxin}{red}
\LtcDebugColor{sidenote}{green}
```

---

## 5. 完整使用示例

### 5.1 定位批注位置

```latex
\documentclass[四库全书彩色]{guji}

% 开启调试和坐标网格
\LtcDebugOn
\显示坐标[measure=cm]

\begin{document}
\begin{正文}
测试文本\批注[x=4cm, y=2cm]{批注内容}
\end{正文}
\end{document}
```

### 5.2 调试侧批跨页

```latex
\documentclass[四库全书彩色, debug=true]{guji}

\开启调试模块{sidenote}
\显示网格

\begin{document}
\begin{正文}
正文内容\侧批{这是一条很长的侧批，可能会跨页显示，用于测试跨页颜色保持}
% ... 更多内容 ...
\end{正文}
\end{document}
```

### 5.3 检查版心渲染

```latex
\documentclass[四库全书彩色]{guji}

\开启调试模块{banxin}
\显示边框

\begin{document}
\begin{正文}
内容
\end{正文}
\end{document}
```

---

## 6. 调试输出说明

开启调试后，编译日志中会输出详细信息。

### 6.1 日志格式

```
[模块名] 消息内容
```

### 6.2 常见日志示例

**页面设置**：
```
[page] Configured: paper=400mm x 280mm, margins=133pt/84pt/133pt/84pt
[page-split] Enabled - target=200mm x 280mm
```

**侧批处理**：
```
[sidenote] Processing registry entry 1
[sidenote] Column wrap: base_indent=2, next_r=2
```

**渲染阶段**：
```
[render] Processing page 1, nodes=256
[render] Glyph: char=测, pos=(5, 3)
```

### 6.3 过滤日志

```bash
# 只看调试输出
lualatex file.tex 2>&1 | grep "\["

# 只看特定模块
lualatex file.tex 2>&1 | grep "\[sidenote\]"

# 只看错误
lualatex file.tex 2>&1 | grep -E "\[ERROR\]|\[WARNING\]"
```

---

## 7. Lua 端调试

### 7.1 输出调试信息

```lua
-- 使用项目的调试模块
local debug = require('debug.luatex-cn-debug')
local dbg = debug.get_debugger('my-module')

dbg.log("Processing node: " .. tostring(node))
dbg.log(string.format("Position: page=%d, col=%d, row=%d", p, c, r))
```

### 7.2 直接输出

```lua
-- 始终输出（不受调试开关影响）
texio.write_nl("term and log", "[DEBUG] message")

-- 格式化输出
texio.write_nl("term and log", string.format(
    "[DEBUG] x=%.1fpt, y=%.1fpt",
    x / 65536, y / 65536
))
```

### 7.3 打印节点信息

```lua
-- 打印节点类型和属性
local function debug_node(n)
    local D = node.direct
    local id = D.getid(n)
    local attr = D.get_attribute(n, ATTR_JIAZHU)
    texio.write_nl("term and log", string.format(
        "[DEBUG] Node: id=%d, attr=%s",
        id, tostring(attr)
    ))
end
```

---

## 8. TeX 端调试

### 8.1 输出变量值

```latex
% 显示 token list 内容
\tl_show:N \l_my_tl

% 输出到终端
\iow_term:x { value:~|\l_my_tl| }

% 输出到日志
\iow_log:x { Debug:~height=\l_my_height_tl }
```

### 8.2 条件调试

```latex
\bool_if:NT \g__luatexcn_debug_bool
  {
    \iow_term:n { [DEBUG]~Entering~environment }
  }
```

---

## 9. 坐标系统说明

### 9.1 页面坐标

```
(0, 0) ──────────────────────→ x (paperwidth)
  │
  │   ┌─────────────────┐
  │   │  内容区域        │
  │   │  (margin 内)    │
  │   └─────────────────┘
  │
  ↓
  y (paperheight)
```

### 9.2 竖排网格坐标

```
        列 1   列 2   列 3   (从右向左)
      ┌─────┬─────┬─────┐
行 1  │  字 │  字 │  字 │  ↑
      ├─────┼─────┼─────┤  │
行 2  │  字 │  字 │  字 │  │ 从上向下
      ├─────┼─────┼─────┤  │
行 3  │  字 │  字 │  字 │  ↓
      └─────┴─────┴─────┘
```

### 9.3 筒子页坐标

筒子页模式下，物理页面分为左右两半：

```
物理页面（40cm 宽）:
┌─────────────────────┬─────────────────────┐
│    左半 (20cm)      │     右半 (20cm)     │
│   → 输出为 Page 2   │   → 输出为 Page 1   │
│                     │                     │
│  x: 0 ────→ 20cm   │  x: 0 ────→ 20cm   │
└─────────────────────┴─────────────────────┘
```

**注意**：批注、印章等的 x 坐标是相对于**逻辑页面**（半页），不是物理页面。

---

## 10. 常见调试场景

### 10.1 元素位置不对

1. 开启坐标网格：`\显示坐标[measure=cm]`
2. 检查元素的 x, y 参数
3. 注意筒子页模式下坐标是相对于半页

### 10.2 颜色丢失

1. 开启模块调试：`\开启调试模块{render}`
2. 检查日志中是否有颜色信息
3. 确认是否跨页导致颜色堆栈断开

### 10.3 内容消失

1. 开启全局调试：`\LtcDebugOn`
2. 检查是否有节点被错误移除
3. 检查属性是否被 `\selectfont` 清除

### 10.4 版心位置错误

1. 显示边框：`\显示边框`
2. 开启版心调试：`\开启调试模块{banxin}`
3. 检查 margin 和 paper 尺寸设置

---

👉 返回：[[开发文档 | Development]] | [[功能详解 | Features]] | [[首页 | Home]]
