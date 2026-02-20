# LEARNING.md - 开发经验与教训总结

本文档记录了 `luatex-cn` 项目开发过程中的重要问题与解决方案。

---

## 目录

1. [Lua 与 LaTeX 交互](#一-lua-与-latex-交互)
2. [expl3 语法陷阱](#二-expl3-语法陷阱)
3. [LuaTeX 特有机制](#三-luatex-特有机制)
4. [PDF 渲染问题](#四-pdf-渲染问题)
5. [参数传递链路](#五-参数传递链路)
6. [特殊功能实现](#六-特殊功能实现)
7. [布局引擎陷阱](#七-布局引擎陷阱)

---

## 一、 Lua 与 LaTeX 交互

### 1.1 `\directlua` 中的 Lua 注释陷阱

**问题**：在 `\directlua{...}` 中使用 `--` 注释会导致后续代码静默失败。

**原因**：LaTeX 将多行内容"线性化"为一行，`--` 之后的内容全部变成注释。

```latex
% ❌ 错误：整个块变成 "local x = 1 -- 注释 local y = 2"
\directlua{
  local x = 1
  -- 这是注释
  local y = 2
}

% ✅ 正确：使用多行注释或移除注释
\directlua{ local~x~=~1;~--[[注释]]--~local~y~=~2 }
```

**最佳实践**：
- 复杂 Lua 逻辑放在独立 `.lua` 文件中
- `\directlua` 只负责 `require()` 和简单调用
- 避免在 `\directlua` 中使用 `--` 行注释

### 1.2 Lua 模块加载

**问题**：模块加载失败但没有错误提示。

**解决方案**：
```lua
-- ✅ 使用 require + 全局变量
cn_vertical_constants = require('base_constants')
package.loaded['base_constants'] = cn_vertical_constants

-- ✅ 加载前清空缓存
package.loaded["module_name"] = nil
```

**命名规范**：
- `base_` - 基础层
- `core_` - 协调层
- `layout_` - 布局层
- `render_` - 渲染层

### 1.3 从 Lua 向 TeX 传递数据

```lua
-- ❌ 错误：\string 阻止命令执行
tex.print("\\string\\setmainfont{SimSun}")

-- ✅ 正确：使用 token.set_macro
token.set_macro("fontauto@fontname", "SimSun")
```

```latex
% TeX 中使用
\expandafter\setmainfont\expandafter{\fontauto@fontname}
```

### 1.4 TeX 到 Lua 参数传递的正确语法

**日期**: 2026-01-31

**问题**：在 `\lua_now:e` 上下文中参数传递使用了错误的语法，导致 Lua 接收到字面字符串而非实际值。

**错误示例**：
```latex
% ❌ 错误：双反斜杠导致变量未展开
\lua_now:e {
  judou_mod.setup({
    punct_mode~=~[=[\\luaescapestring{\\l__luatexcn_judou_punct_mode_tl}]=],
    color~=~[=[\\luaescapestring{\\l__luatexcn_judou_color_tl}]=]
  })
}
```

**结果**：Lua 接收到 `"\\luaescapestring{\\l__luatexcn_judou_punct_mode_tl}"` 而非 `"judou"`

**正确写法**：
```latex
% ✅ 正确：单反斜杠 + \tl_use:N
\lua_now:e {
  judou_mod.setup({
    punct_mode~=~[=[\luaescapestring{\tl_use:N~\l__luatexcn_judou_punct_mode_tl}]=],
    color~=~[=[\luaescapestring{\tl_use:N~\l__luatexcn_judou_color_tl}]=]
  })
}
```

**原因分析**：
- `\lua_now:e` 使用 e-type 扩展，`\\` 会被解释为 `\`
- 双反斜杠阻止了变量的正确展开
- 必须使用单反斜杠 + `\tl_use:N` 来展开 token list 变量

**调试方法**：
```lua
-- 在 Lua 端打印接收到的参数值
texio.write_nl("term_and_log", string.format("[DEBUG] param = %s", tostring(param)))
```

**参考文件**：
- `tex/guji/luatex-cn-guji-judou.sty` (正确示例)
- `tex/core/luatex-cn-core-textbox.sty` (参考模式)

### 1.5 `\lua_now:e` vs `\lua_now:n` - 模块加载的正确语法

**日期**: 2026-01-31

**问题**：使用 `\lua_now:e` 加载 Lua 模块导致模块变量为 `nil`。

**错误症状**：
```
[\directlua]:1: attempt to index a nil value (global 'judou_mod')
```

**根本原因**：
- `\lua_now:e` 会对参数进行 TeX 扩展
- 纯 Lua 代码（如 `require` 语句）不需要也不应该被 TeX 扩展

**错误写法**：
```latex
% ❌ 错误：e-type 扩展破坏 Lua 代码
\lua_now:e { judou_mod = require('guji.luatex-cn-guji-judou') }
```

**正确写法**：
```latex
% ✅ 正确：n-type 不进行扩展
\lua_now:n { judou_mod = require('guji.luatex-cn-guji-judou') }
```

**规则总结**：

| 用途 | 扩展类型 | 示例 |
|------|---------|------|
| **传递 TeX 变量到 Lua** | `\lua_now:e` | `\lua_now:e { mod.setup({ param = [=[\luaescapestring{\tl_use:N~\var}]=] }) }` |
| **执行纯 Lua 代码** | `\lua_now:n` | `\lua_now:n { mod = require('module') }` |

**修复的文件**（2026-01-31）：
- `tex/guji/luatex-cn-guji-judou.sty` (line 23)
- `tex/guji/luatex-cn-guji-jiazhu.sty` (line 26)
- `tex/core/luatex-cn-core-metadata.sty` (line 19)

**关键要点**：
1. **`:e` 扩展**：用于需要 TeX 变量展开的场景（调用 Lua 函数并传参）
2. **`:n` 不扩展**：用于纯 Lua 代码（`require`、赋值等）
3. **调试**：使用 `texio.write_nl()` 打印模块对象验证是否加载成功

---

## 二、 expl3 语法陷阱

> **详细文档**: 参见 `ai_must_read/expl3_note.md` - 包含参数展开、xparse 陷阱等完整说明

### 2.1 空格与换行被忽略

**问题**：`ExplSyntaxOn` 模式下空格被忽略，影响配置文件加载和 Lua 代码。

```latex
% ❌ 错误：.cfg 中的 "1 0 0" 变成 "100"
\ExplSyntaxOn
\InputIfFileExists{config.cfg}{}{}

% ✅ 正确：加载配置前退出 ExplSyntax
\ExplSyntaxOff
\InputIfFileExists{config.cfg}{}{}
\ExplSyntaxOn
```

### 2.2 `\directlua` 与 expl3 不兼容

**问题**：多行 Lua 代码在 expl3 环境中被破坏。

**解决方案**：
1. 将 `\directlua` 命令定义放在 `\ExplSyntaxOff` 之后
2. 使用 `\lua_now:e` 时用 `~` 代替空格
3. 复杂逻辑放在独立 `.lua` 文件

### 2.3 布尔值传递

**问题**：`keys_set:nn` 不会自动展开布尔表达式。

```latex
% ❌ 错误：传递的是宏本身
\keys_set:nn { module } { option = \bool_if:NTF \l_bool {true}{false} }

% ✅ 正确：先判断再传递字面值
\bool_if:NTF \l_bool
  { \keys_set:nn { module } { option = true } }
  { \keys_set:nn { module } { option = false } }
```

### 2.4 Token List 空值检测

**问题**：通过 keys 系统传递的空值可能包含不可见 token。

```latex
% ❌ 可能失败
\tl_if_empty:NTF \l_var { default } { use }

% ✅ 先展开再检查
\tl_set:Nx \l_tmp_tl { \l_var }
\tl_if_empty:NTF \l_tmp_tl { default } { use }
```

### 2.5 xparse 可选参数与 `\exp_args` 不兼容

**问题**：`\exp_args:N...` 无法处理 xparse 的 `[...]` 可选参数。

```latex
% ❌ 错误
\exp_args:NnV \MyCmd [\l_opts_tl] {content}

% ✅ 正确：使用 \use:x
\tl_set:Nx \l_opts_tl { key=\l_var, ... }
\use:x { \exp_not:N \MyCmd [\l_opts_tl]{\exp_not:n{content}} }
```

### 2.6 Class/sty 文件尾部空格

**问题**：未注释的换行符导致空白页。

```latex
% ❌ 危险
\ExplSyntaxOff

\endinput

% ✅ 安全
\ExplSyntaxOff%
%
\endinput%
```

---

## 三、 LuaTeX 特有机制

### 3.1 `dir RTT` 竖排模式

**核心要素**：
- `\pardir RTT \textdir RTT`：文本从上到下，行从右到左
- `\hsize` 定义列高度（竖排模式）
- 不要过早自己造轮子，先利用原生机制

### 3.2 `\selectfont` 清除属性

**关键**：`\selectfont` 会清除所有 LuaTeX 属性！

```latex
% ❌ 错误：属性被清除
\setluatexattribute\myattr{1}
\fontsize{...}{...}\selectfont
#1  % 属性已丢失

% ✅ 正确：属性在 selectfont 之后设置
\fontsize{...}{...}\selectfont
\setluatexattribute\myattr{1}
#1  % 属性有效
```

### 3.3 节点管理

**避免双重释放**：
```lua
-- ❌ 危险：节点可能还在其他链表中
node.free(D.tonode(n))

-- ✅ 安全：先断链再释放
D.setnext(D.getprev(n), D.getnext(n))
-- 确保 n 不再被引用后再释放
```

**自定义 Whatsit 节点**：在 shipout 前必须删除，否则后端报错。

```lua
if uid == constants.MY_WHATSIT_ID then
    -- 处理完毕后删除
    p_head = D.remove(p_head, curr)
    node.flush_node(D.tonode(curr))
end
```

### 3.4 动态字体缩放

**问题**：`font.define()` 后 `font.getfont()` 返回 `nil`。

**解决**：在缩放前保存原始字体数据：
```lua
local base_font_data = font.getfont(font_id)  -- 先保存
local scaled_font_id = font.define(...)
-- 后续使用 base_font_data × scale_factor
```

### 3.5 节点所有权

`tex.box[n] = node_list` 转移所有权给 TeX。需要重用时必须复制：
```lua
tex.box[box_num] = node.copy_list(original_box)
```

---

## 四、 PDF 渲染问题

### 4.1 颜色指令

```lua
-- ❌ 错误：PDF 不认识颜色名称
"black rg"

-- ✅ 正确：归一化 RGB 数值
"0 0 0 rg"
```

### 4.2 绘制顺序（画家模型）

后绘制的覆盖先绘制的。正确顺序：
1. 背景色（最先）
2. 字体颜色
3. 边框、版心
4. 文字内容
5. 调试框架（最后）

使用 `insert_before(head, head, node)` 在最底层插入。

### 4.3 颜色堆栈泄漏

**问题**：`\color{red}` 在盒子中可能导致颜色泄漏。

**解决**：使用 `\textcolor{red}{text}`，确保 Push/Pop 成对。

### 4.4 悬浮框的位移补偿

悬浮框需要"负向补偿 Kern"实现真正的 overlay：
```lua
p_head = D.insert_before(p_head, p_head, Kern(rel_x))
D.insert_after(p_head, kern_node, box)
D.insert_after(p_head, box, Kern(-(rel_x + box_width)))  -- 补偿
```

### 4.5 跨页颜色保持

**问题**：使用 `\color{}` 的内容（如侧批、夹注）在跨页时失去颜色。

**根本原因**：
- `group_nodes_by_page()` 将节点按页分组时会断开节点链接
- 颜色堆栈节点（color push）可能在页 1，但文字节点在页 2
- PDF 颜色状态不会自动跨页保持

**错误方案**：
```lua
-- ❌ 在 handle_glyph_node 中检测属性并包裹颜色会破坏渲染
if D.get_attribute(curr, ATTR_JIAZHU) == 1 then
    -- 直接包裹会导致内容消失
end
```

**正确方案**：通过 layout_map 传递颜色
```latex
% 1. TeX 层：存储颜色到 Lua 全局
\lua_now:e { _G.comp.current_color = [=[#1]=] }
\color{#1}  % 正常应用颜色
```

```lua
-- 2. Layout 层：从全局读取并存入 layout_map
local color = (_G.comp and _G.comp.current_color) or nil
layout_map[node] = {
    page = p, col = c, row = r,
    comp_color = color  -- 传递颜色
}
```

```lua
-- 3. Render 层：从 layout_map 读取并独立应用
local color = pos.comp_color
if color and color ~= "" then
    local rgb = utils.normalize_rgb(color)
    local push = utils.create_pdf_literal("q " .. utils.create_color_literal(rgb, false))
    local pop = utils.create_pdf_literal("Q")
    p_head = D.insert_before(p_head, curr, push)
    D.insert_after(p_head, kern, pop)  -- 包裹 glyph + kern
end
```

**关键点**：
- 颜色值通过 layout_map 传递，每页独立应用
- 不依赖跨页的颜色堆栈状态
- `q/Q` 确保颜色只影响当前包裹的内容

**适用场景**：侧批、夹注、批注等可能跨页的有色组件

### 4.6 悬浮框坐标定位（筒子页模式）

**日期**: 2026-01-31

**问题**：悬浮框（`\批注`）的 x 坐标设为 4cm，但实际显示位置偏差约 2cm。

**根本原因**：

1. **错误使用 TeX 默认偏移**：最初使用 `tex_offset = 72.27pt (1in = 2.54cm)` 作为内容起点偏移
2. **实际内容起点不同**：真正的内容起点是 `margin_left`（由页面设置决定，本例为 133pt ≈ 4.7cm）
3. **筒子页模式的复杂性**：物理页面 40cm 宽，分割为两个 20cm 逻辑页面

**坐标系统理解**：

```
物理页面（40cm 宽）:
┌─────────────────────────────────────────────┐
│    左半 (20cm)      │     右半 (20cm)       │
│   → 输出为 Page 2   │   → 输出为 Page 1     │
│                     │                       │
│                     │  ← split_page_offset  │
└─────────────────────────────────────────────┘

逻辑页面坐标（从右向左）:
  x=0 ─────────────────────────────────→ x=20cm
  (右边缘)                              (左边缘)

内容区域起点：margin_left (133pt ≈ 4.7cm) 从逻辑页面左边缘
```

**错误代码**：
```lua
-- ❌ 错误：使用 TeX 默认偏移（72.27pt）
local tex_offset = 72.27 * 65536  -- 1 inch in sp
local rel_x = position_from_logical_left - tex_offset
```

**正确代码**：
```lua
-- ✅ 正确：使用实际页面边距 + 筒子页偏移
local m_left = (_G.page and _G.page.margin_left) or 0

-- 筒子页模式：需要偏移到物理页面右半部分
local split_page_offset = 0
if splitpage_mod and splitpage_mod.enabled then
    split_page_offset = splitpage_mod.target_width  -- 逻辑页宽（20cm）
end

-- 从逻辑页右边缘计算到左边缘的位置
local position_from_logical_left = logical_page_width - item.x - box_width

-- 最终 kern = 筒子页偏移 + 逻辑位置 - 内容边距
local rel_x = split_page_offset + position_from_logical_left - m_left
```

**关键公式解析**：

| 变量 | 含义 | 示例值 |
|------|------|--------|
| `item.x` | 用户指定的 x 坐标（从右边缘） | 4cm = 113.8pt |
| `logical_page_width` | 逻辑页面宽度 | 20cm = 568pt |
| `box_width` | 悬浮框宽度 | ~28pt |
| `position_from_logical_left` | 从逻辑页左边缘的位置 | 568 - 113.8 - 28 ≈ 426pt |
| `split_page_offset` | 筒子页偏移（右半页） | 568pt |
| `m_left` | 内容区边距 | 133pt |
| `rel_x` | 最终 kern 值 | 568 + 426 - 133 ≈ 861pt |

**调试方法**：
```lua
-- 启用坐标网格后输出实际位置
if debug_mod and debug_mod.show_grid then
    local actual_x = logical_page_width - (m_left + rel_x) - box_width
    texio.write_nl("term and log", string.format(
        "[FLOATING BOX] Expected x=%.1fcm | Actual x=%.1fcm",
        item.x / 65536 / 28.3465, actual_x / 65536 / 28.3465))
end
```

**验证方法**：
```latex
\documentclass[debug=true]{ltc-guji}
\显示坐标  % 启用坐标网格
\begin{document}
\begin{正文}
第一页\批注[x=4cm,y=2cm]{批注内容}
\end{正文}
\end{document}
```

**教训**：
1. **不要假设 TeX 默认偏移**：不同文档类/页面设置的边距不同，应从 `_G.page.margin_left` 获取
2. **筒子页需要额外偏移**：Page 1 在物理页面右半，需要加 `target_width` 偏移
3. **坐标调试必备网格**：使用 `\显示坐标` 可视化验证，配合日志输出定位问题

**参考文件**：
- `tex/core/luatex-cn-core-textbox.lua` (`render_floating_box` 函数)
- `tex/debug/luatex-cn-debug.lua` (坐标网格实现)

---

## 五、 参数传递链路

### 5.1 完整链路示例

```
guji.cls (定义 key-value)
    ↓
cn_vertical.sty (接收并转发)
    ↓
core_main.lua (转发给渲染层)
    ↓
render_page.lua (转发给子模块)
    ↓
render_banxin.lua (实际使用)
```

**教训**：添加新参数必须走完整个链路，不要遗漏中间层。

### 5.2 显式传递优于隐式状态

在复杂的 LaTeX-Lua 链式调用中，参数应随调用链层层下传，避免依赖全局状态。

---

## 六、 特殊功能实现

### 6.1 筒子页 (Split Page)

**难点**：
- `\AtBeginShipout` 中不能用 `\newpage`（无限递归）
- LuaTeX 用 `\pdfextension literal` 替代 `\pdfliteral`
- 双倍宽度盒子放入单倍宽度页面会报 Overfull

**解决**：使用 `\hbox to 0pt{\smash{\copy N}\hss}` 隐藏盒子尺寸。

### 6.2 TikZ Overlay

**问题**：TikZ 的 `remember picture, overlay` 不能放在 `guji-content` 中。

**解决**：使用 shipout 钩子：
```latex
\AddToHook{shipout/foreground}{%
  \begin{tikzpicture}[remember picture, overlay]
    ...
  \end{tikzpicture}
}
```

### 6.3 动态章节标题

**方案**：基于属性的标记机制
1. Lua 维护全局注册表存储章节标题
2. `\chapter` 插入零宽标记节点，带属性 `ATTR_CHAPTER_REG_ID`
3. 布局引擎检测属性，更新当前章节
4. 按页缓存传递给渲染层

### 6.4 段落缩进泄漏

**问题**：`\end{段落}` 后的正文也被缩进。

**解决**：
1. 环境结束前重置属性
2. Lua 中只对 `indent > 0` 的节点应用列级跟踪

```lua
if indent > 0 then
    if cur_row < indent then cur_row = indent end
end
```

---

## 核心教训总结

| 类别 | 要点 |
|------|------|
| Lua 交互 | 复杂逻辑放 `.lua` 文件，`\directlua` 保持简单 |
| expl3 | 加载配置前 `\ExplSyntaxOff`，注意空格和展开 |
| 属性 | 在 `\selectfont` 之后设置，shipout 前清理自定义节点 |
| 渲染 | 注意绘制顺序，颜色用数值，悬浮框需补偿 |
| 参数 | 显式传递，完整走链路 |
| 调试 | 用 `texio.write_nl` 输出日志，Git 比对定位问题 |

---

## 调试技巧速查

```lua
-- Lua 调试输出
texio.write_nl("term and log", "[DEBUG] message")

-- 打印节点属性
print(string.format("Node ID=%d attr=%s", id,
    tostring(D.get_attribute(t, ATTR_XXX))))
```

```latex
% TeX 调试
\tl_show:N \l_my_tl
\iow_term:x { value: |\l_my_tl| }
```

```bash
# 查看特定输出
lualatex file.tex 2>&1 | grep "\[DEBUG\]"
```

---

## 七、 布局引擎陷阱

### 7.1 Natural Mode `flush_buffer` 覆盖 y_sp 导致缩进丢失

**日期**: 2026-02-12

**问题**：`\脚注` 设置了 `indent=1em` 的强制缩进（forced indent），通过 `ATTR_INDENT` + `encode_forced_indent(cells)` 正确设置在脚注字符上。`apply_indentation()` 也正确将 `cur_y_sp` 设置为 `indent * grid_height`（即 1 格的偏移量）。但最终渲染结果中，脚注列的第一个字符与正文列的第一个字符在同一高度——缩进完全不可见。

**根本原因**：

`flush_buffer()` 中的 Natural Mode 重排代码（tight packing 路径）**始终从 y=0 开始重新计算所有 y_sp**，完全丢弃了布局阶段通过 `apply_indentation` 设置的缩进偏移：

```lua
-- ❌ 错误：start from 0 discards indent offset
local y = 0
for _, e in ipairs(col_buffer) do
    e.y_sp = y  -- overwrites the indented y_sp!
    y = y + (e.cell_height or grid_height)
end
```

**修复方案**：使用 col_buffer 中第一个条目的原始 y_sp 作为起始位置，保留缩进偏移：

```lua
-- ✅ 正确：preserve indent offset from first entry
local start_y = col_buffer[1].y_sp or 0
local remaining = ctx.col_height_sp - total_cells - start_y

if N == 1 then
    -- keep original y_sp (preserves indent)
elseif remaining > 0 and remaining < min_cell and N > 1 then
    local gap = remaining / (N - 1)
    local y = start_y
    for _, e in ipairs(col_buffer) do
        e.y_sp = y
        y = y + (e.cell_height or grid_height) + gap
    end
else
    local y = start_y
    for _, e in ipairs(col_buffer) do
        e.y_sp = y
        y = y + (e.cell_height or grid_height)
    end
end
```

**调试方法**：在 layout 循环中添加临时日志，对比 "glyph 入 buffer 时的 y_sp" 和 "flush_buffer 后 layout_map 中的 y_sp"，即可发现差异。

**关键教训**：
1. **Layout 有两阶段**：字符入 buffer 时设置 y_sp（包含缩进），flush_buffer 时可能重算 y_sp。要确认最终写入 layout_map 的值。
2. **Natural Mode 的 tight packing 是破坏性重写**：它不是微调，而是完全覆盖 y_sp。任何依赖 y_sp 初始值的功能都会受影响。
3. **调试 y_sp 问题的正确位置**：在 flush_buffer 的 `layout_map[entry.node] = map_entry` 处检查最终值，而非 glyph 入 buffer 时。

**影响的文件**：
- `tex/core/luatex-cn-layout-grid.lua` (`flush_buffer` 函数，Natural Mode 分支)
- `tex/core/luatex-cn-footnote.sty` (forced indent 设置)

### 7.2 TeX 段落构建器不保留自定义属性

**日期**: 2026-02-12

**问题**：在 `\penalty -10002` 节点上通过 `tex.setattribute` 设置的 `ATTR_COLUMN_BREAK_INDENT` 在最终的节点流中丢失。

**根本原因**：TeX 的段落构建器（paragraph builder）在断行时会**消耗**原始 penalty 节点，并创建**新的** penalty 节点。新节点**不携带**任何自定义属性。此外，flatten 阶段也会创建合成 penalty 节点（`D.new(constants.PENALTY)`），同样没有自定义属性。

**解决方案**：不要依赖 penalty 节点携带自定义属性。改为将属性设置在**字符节点**（glyph）上，因为字符节点在段落构建器和 flatten 过程中被保留（通过 `copy_node_with_attributes`）。

```latex
% ❌ 错误：属性设在 penalty 上，会丢失
\lua_now:e { tex.setattribute(ATTR_INDENT, value) }
\penalty -10002  % penalty 节点被段落构建器替换

% ✅ 正确：属性设在 glyph 上，会保留
\lua_now:e { tex.setattribute(ATTR_INDENT, encode_forced_indent(cells)) }
\penalty -10002
后续文字内容  % glyph 节点保留 ATTR_INDENT
```

**关键教训**：
- 段落构建器是黑盒：输入的节点可能被消耗/替换/重排
- 只有**字符节点**上的属性是可靠的（因为 flatten 的 `copy_node_with_attributes` 会保留）
- penalty、glue 等非字符节点的属性在段落构建后不可信

### 7.3 `_G` 全局状态污染导致 page_columns 和标点布局错误

**日期**: 2026-02-14

**问题**：两个独立 bug，根因相同 —— `_G` 全局状态被意外读写，导致布局计算错误。

#### Bug A: Column 每列新起一页（page_columns=1）

**现象**：`column.tex` 测试每个 `\Column` 独占一页（18 页），正常应该多列排在同一页（3 页）。

**根本原因**：`register_col_width()` 在 `_G.content.col_widths` 为 nil 时自动创建空表：

```lua
-- ❌ 错误：无条件创建 col_widths，正常 BodyText 也会被污染
function register_col_width(width_sp)
    _G.content.col_widths = _G.content.col_widths or {}  -- 创建了不该存在的表！
    table.insert(_G.content.col_widths, width_sp)
end
```

**执行时序**：
```
process_grid:
  vbox_set (展开TeX → \行[column-width=50pt] → register_col_width → col_widths={50pt})
  sync_to_lua → calc_page_columns → 发现 col_widths 有 1 项 → page_columns=1 !!
```

**正确方案**：
```lua
-- ✅ 只在 TitlePage 模式（col_widths 已被 init_col_widths 初始化）时注册
function register_col_width(width_sp)
    if not (_G.content and _G.content.col_widths) then return end
    table.insert(_G.content.col_widths, width_sp)
end
```

#### Bug B: 台湾模式标点占半格

**现象**：tw-vbook 的标点只占半格，应该和正文一样占整格。

**根本原因**：`get_cell_height()` 硬编码所有标点返回 `base * 0.5`，不区分大陆/台湾：

```lua
-- ❌ 错误：无条件将标点设为半格
if punct_type and punct_type > 0 then
    return math.floor(base * 0.5)
end
```

另一个陷阱：cn-vbook/tw-vbook 使用 **natural 布局模式**（`layout_mode="natural"`），导致 `engine_ctx.default_cell_height=nil`，`punct.layout()` 中的 squeeze 逻辑根本不会执行到。所以即使在 `punct.layout()` 中加了 taiwan 跳过，也无效。

**正确方案**：
```lua
-- ✅ 检查 punct style 和 squeeze 设置
if punct_type and punct_type > 0 then
    local style = (_G.punct and _G.punct.style) or "mainland"
    local squeeze = not (_G.punct and _G.punct.squeeze == false)
    if style ~= "taiwan" and squeeze then
        return math.floor(base * 0.5)
    end
end
```

#### 架构层面的教训

**`_G` 全局状态是这两个 bug 的共同根因**：

| 问题 | `_G` 滥用方式 | 后果 |
|------|-------------|------|
| page_columns=1 | `register_col_width` 意外创建 `_G.content.col_widths` | 覆盖正常的 banxin 分页计算 |
| 标点半格 | `get_cell_height` 需隐式读取 `_G.punct.style` | helpers 层依赖未声明的全局状态 |
| punct.layout 不执行 | `default_cell_height` 依赖 `_G.content.layout_mode` | 代码路径完全取决于隐式全局值 |

**关键教训**：
1. **`_G` 表的字段不应该有"存在即为真"语义**：`col_widths` 的存在/不存在决定了走哪条计算路径，但任何代码都能创建它。应该用显式模式标志。
2. **vbox 构建会触发 Lua 副作用**：TeX 的 `\vbox_set:Nn` 在收集内容时会执行宏，宏中的 `\lua_now` 调用会修改全局状态。这发生在 `sync_to_lua` 之前。
3. **多条件优先级链（if col_widths / elseif banxin / elseif grid / else）非常脆弱**：最高优先级条件被意外满足时，所有正常路径都被跳过。
4. **调试此类问题的高效方法**：用 `texio.write_nl` 在关键位置打印全局状态值（不依赖 debug 模块开关），快速定位是"哪个值不对"而非"哪行代码有bug"。

---

## 八、 页面环境与 Shipout Hook 交互

### 8.1 `\topskip` 在 document body 中赋值导致空白页

**日期**: 2026-02-14

**问题**：封面（Cover）环境后总是产生一个多余的空白页。page.tex 输出 11 页而非 10 页。

**现象**：
- 两个连续的 SinglePage（单页）环境之间会产生空白页
- 空白页不是真正空白，包含一个 vlist 节点（w=1136pt h=12pt）
- 仅当 SinglePage 内有可见内容时才出现

**根本原因**：`\luatexcn_apply_geometry:` 中包含 `\dim_set:Nn \topskip { 0pt }`，每次 SinglePage 开始时都会在 document body 中执行。这个 `\topskip` 赋值与 TikZ/eso-pic 加载的 shipout hook 交互，导致在连续 SinglePage 之间产生虚假空白页。

```latex
% ❌ 错误：在 document body 中设置 \topskip
\cs_new:Npn \luatexcn_apply_geometry:
  {
    \dim_set:Nn \topskip { \l__luatexcn_page_topskip_tl }  % ← 在每个 SP 开始时执行
    ...
  }
```

**最小复现**（使用 plain article + eso-pic）：
```latex
\documentclass{article}
\usepackage{eso-pic}  % 或 tikz，任何注册 shipout hook 的包
\begin{document}
Page one content
\clearpage
\topskip=0pt    % ← 在 \clearpage 之后赋值 \topskip → 触发空白页
Page two content
\end{document}
% 结果：3 页（page 2 是空白页）
```

**修复方案**：将 `\topskip` 从 `\luatexcn_apply_geometry:`（每页调用）移到 `\pageSetup`（仅在 preamble 调用一次）。

```latex
% ✅ 正确：topskip 只在 preamble 设置一次
\cs_new:Npn \pageSetup
  {
    ...
    \luatexcn_apply_geometry:
    % topskip 只在这里设置，不在 apply_geometry 中
    \dim_set:Nn \topskip { \l__luatexcn_page_topskip_tl }
    \__luatexcn_page_apply_split:
  }

% apply_geometry 中不再包含 topskip 赋值
\cs_new:Npn \luatexcn_apply_geometry:
  {
    \dim_set:Nn \paperwidth { ... }
    \dim_set:Nn \paperheight { ... }
    \dim_set:Nn \pagewidth { ... }
    \dim_set:Nn \pageheight { ... }
    % NOTE: \topskip intentionally NOT set here
  }
```

**调试过程**：
1. 对比封面和书名页（都调用单页），发现两个连续单页就会产生空白页
2. 用 `pre_shipout_filter` 回调检查空白页内容，发现有实际节点
3. 二分法逐行注释 `\luatexcn_apply_geometry:`，定位到 `\topskip` 赋值
4. 用最小 article 文档 + eso-pic 确认是 `\topskip` + shipout hook 的交互

**关键教训**：
1. **`\topskip` 在 document body 中赋值是危险的**：当文档加载了 TikZ、eso-pic 等注册 shipout hook 的包时，`\clearpage` 后的 `\topskip` 赋值可能产生虚假空白页
2. **shipout hook 的副作用难以预测**：hook 中的 TikZ overlay 代码可能在 main vertical list 上产生节点（whatsit），这些节点被 TeX 视为"有内容"，触发额外的 shipout
3. **二分法是定位此类问题的最有效方法**：逐行注释函数内容，直到空白页消失，即可精确定位根因
4. **`\NewEnviron` 的分组效应**：`\NewEnviron` 创建 TeX group，内部的 `\dim_set:Nn` 是局部赋值，group 结束后被撤销。如果需要维度在环境结束后生效，必须用 `\dim_gset:Nn`（全局赋值）

### 8.2 `tex.set("global", "paperwidth", ...)` 对 TeX dimen 无效

**日期**: 2026-02-14

**问题**：尝试在 Lua 中全局设置 `\paperwidth` 失败，赋值被静默忽略。

**根本原因**：`\paperwidth` 是 TeX `\dimen` 寄存器（由 LaTeX 定义），不是 LuaTeX 的内部参数。`tex.set("global", ...)` 只对 LuaTeX 内部参数（如 `pagewidth`、`pageheight`）有效。

```lua
-- ✅ 有效：pagewidth/pageheight 是 LuaTeX 内部参数
tex.set("global", "pagewidth", target_w)
tex.set("global", "pageheight", target_h)

-- ❌ 无效（静默失败）：paperwidth 是 TeX \dimen 寄存器
tex.set("global", "paperwidth", target_w)
tex.set("global", "paperheight", target_h)

-- ✅ 正确方式：通过 TeX 层全局赋值 \paperwidth
-- 在 .sty 中使用 \dim_gset:Nn \paperwidth { ... }
```

**`tex.set` 支持的参数类型**：
| 类型 | 示例 | `tex.set("global", ...)` |
|------|------|--------------------------|
| LuaTeX 内部参数 | `pagewidth`, `pageheight` | ✅ 有效 |
| TeX `\dimen` 寄存器 | `\paperwidth`, `\paperheight` | ❌ 静默失败 |

**解决方案**：在 TeX 层（.sty 文件）中使用 `\dim_gset:Nn` 进行全局赋值：
```latex
\cs_new:Npn \__luatexcn_page_restore_dims_globally:
  {
    \dim_gset:Nn \paperwidth { \l__luatexcn_page_paper_width_tl }
    \dim_gset:Nn \paperheight { \l__luatexcn_page_paper_height_tl }
    \dim_gset:Nn \pagewidth { \l__luatexcn_page_paper_width_tl }
    \dim_gset:Nn \pageheight { \l__luatexcn_page_paper_height_tl }
  }
```

**教训**：Lua 层的 `tex.set` 不是万能的。对于 LaTeX 定义的 dimen 寄存器，全局赋值必须在 TeX 层完成。而且 `tex.set` 对不支持的参数名不会报错，只会静默忽略。
