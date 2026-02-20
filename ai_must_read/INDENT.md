# Indent 系统完整架构文档

> **最后更新**: 2026-02-06
> **状态**: 已统一并实现完整功能
> **相关 Commits**: 66dd13b, 05337ab, 0f281b4

## 目录

- [一、核心概念：三层优先级](#一核心概念三层优先级)
- [二、Indent 值的编码](#二indent-值的编码)
- [三、不同环境的处理方式](#三不同环境的处理方式)
- [四、命令级别的控制](#四命令级别的控制)
- [五、处理流程（各阶段统一）](#五处理流程各阶段统一)
- [六、统一性保证](#六统一性保证)
- [七、使用示例对照表](#七使用示例对照表)
- [八、总结：统一的设计原则](#八总结统一的设计原则)

---

## 一、核心概念：三层优先级

整个 indent 系统基于**三层优先级**设计，从高到低依次检查：

```
优先级 1（最高）：强制缩进 (Forced Indent)
    ↓ 如果没有强制缩进
优先级 2（中等）：显式缩进 (Explicit Indent)
    ↓ 如果没有显式缩进（值为0或unset）
优先级 3（最低）：样式栈缩进 (Style Stack Indent)
```

**设计原则**：
- **明确优先级**：高优先级的值会覆盖低优先级的值
- **清晰语义**：强制 = 必须，显式 = 建议，栈 = 继承
- **无歧义**：任何情况下 indent 值的来源都是唯一确定的

---

## 二、Indent 值的编码

### 1. 特殊常量（`core/luatex-cn-constants.lua`）

```lua
-- 强制缩进为 0（绕过 style stack）
INDENT_FORCE_ZERO = -2

-- 继承 style stack（默认行为）
INDENT_INHERIT = 0

-- 强制任意缩进值的基准
-- 强制缩进为 N: INDENT_FORCE_BASE - N = -1000 - N
INDENT_FORCE_BASE = -1000
```

### 2. 编码/解码函数

```lua
-- 编码：将缩进值转换为 attribute 值
encode_forced_indent(0) → -2          -- INDENT_FORCE_ZERO
encode_forced_indent(3) → -1003       -- INDENT_FORCE_BASE - 3

-- 解码：检查是否强制缩进，返回实际值
is_forced_indent(-2)    → true, 0     -- 强制为 0
is_forced_indent(-1003) → true, 3     -- 强制为 3
is_forced_indent(2)     → false, nil  -- 非强制
is_forced_indent(0)     → false, nil  -- 继承栈
```

**为什么使用负数编码？**
- 正数：用于显式缩进值 (indent=2)
- 0：特殊值，表示"继承 style stack"
- 负数：用于强制缩进编码，不会与正常值冲突

---

## 三、不同环境的处理方式

### 1. 段落环境（Paragraph）

#### 设置方式

```latex
\begin{段落}[indent=2, first-indent=3]
  第一列缩进三格（首行）
  第二列缩进两格
  第三列缩进两格
\end{段落}
```

#### 处理流程

**开始时**（`core/luatex-cn-core-paragraph.sty`）：
```latex
% 1. 推入 style stack
\edef\paragraph_style_id{\lua_now:e {
  require('util.luatex-cn-style-registry').push_indent(
    \int_use:N \l__luatexcn_paragraph_indent_int,
    \int_use:N \l__luatexcn_paragraph_first_indent_int
  )
}}

% 2. 设置 attributes（显式缩进，优先级2）
\setluatexattribute\cnverticalindent{\l__luatexcn_paragraph_indent_int}
\setluatexattribute\cnverticalfirstindent{\l__luatexcn_paragraph_first_indent_int}
```

**布局时**（`core/luatex-cn-layout-grid.lua`）：
```lua
local function get_indent_for_current_pos(block_id, base_indent, first_indent)
    if block_id and block_id > 0 and first_indent >= 0 then
        if not block_start_cols[block_id] then
            block_start_cols[block_id] = { page = ctx.cur_page, col = ctx.cur_col }
        end
        local start_info = block_start_cols[block_id]
        if ctx.cur_page == start_info.page and ctx.cur_col == start_info.col then
            return first_indent  -- 首列使用 first_indent
        end
    end
    return base_indent  -- 后续列使用 base_indent
end
```

**结束时**：
```latex
% 弹出 style stack
\edef\parent_style_id{\lua_now:n {
  local style_registry = require('util.luatex-cn-style-registry')
  style_registry.pop()
  local current_id = style_registry.current_id() or 0
  tex.print(current_id)
}}
```

#### 继承行为

子环境**继承**父环境的 style stack：

```latex
\begin{段落}[indent=2]       % indent=2 推入栈
  外层缩进两格

  \begin{段落}[indent=4]     % indent=4 推入栈
    内层缩进四格
  \end{段落}                 % 弹出 indent=4

  恢复缩进两格                % 继承外层的 indent=2
\end{段落}                   % 弹出 indent=2
```

---

### 2. Textflow/夹注环境

#### 设置方式

```latex
% 命令形式（不支持内部命令展开）
\夹注[auto-balance=false]{内容...}

% 环境形式（支持内部命令展开，如 \平抬）
\begin{夹注环境}[auto-balance=false, font-size=19.6pt]
  内容...可以使用 \平抬 等命令
\end{夹注环境}
```

#### 处理流程（两层）

**A. Chunk 级别**（整个 textflow 块的基础偏移）

在 `core/luatex-cn-core-textflow.lua` 的 `place_nodes()` 中：

```lua
-- 获取继承的缩进（从 style stack）
local chunk_indent = callbacks.get_indent(params.block_id, params.base_indent, params.first_indent)

-- 应用到整个 chunk
if ctx.cur_row < chunk_indent then
    ctx.cur_row = chunk_indent
end
```

**B. 节点级别**（每个字符的个别调整）**【2026-02-06 最新改进】**

```lua
for _, node_info in ipairs(chunk.nodes) do
    -- 检查节点是否有强制缩进（如 \平抬 设置的 INDENT_FORCE_ZERO）
    local node_indent_attr = D.get_attribute(node_info.node, constants.ATTR_INDENT)
    local is_forced, forced_indent_value = constants.is_forced_indent(node_indent_attr)

    local node_row
    if is_forced and type(forced_indent_value) == "number" and forced_indent_value == 0 then
        -- \平抬 情况：强制顶格（row=0）
        node_row = node_info.relative_row  -- 不加 cur_row 偏移
    else
        -- 正常情况：继承 chunk 的偏移
        node_row = ctx.cur_row + node_info.relative_row
    end

    layout_map[node_info.node] = {
        page = ctx.cur_page,
        col = ctx.cur_col,
        row = node_row,  -- 使用计算后的 row
        sub_col = node_info.sub_col
    }
end
```

#### 关键特性

- ✅ **继承 style stack**：从父环境继承 indent
- ✅ **支持节点级别强制缩进**：`\平抬` 可以在 textflow 中工作
- ✅ **两层处理**：chunk 级别提供基础偏移，节点级别允许个别调整

#### 示例

```latex
\begin{段落}[indent=2]              % indent=2 推入 style stack
  正文缩进两格

  \夹注{                            % 继承 indent=2
    夹注内容缩进两格。
    \平抬 顶格内容（indent=0）      % 节点级别强制 indent=0
    继续缩进两格。
  }
\end{段落}
```

---

### 3. Column 环境（单列排版）

#### 设置方式

```latex
\begin{Column}[align=center, width=5em]
  单列内容
\end{Column}
```

#### 处理流程

- 单列内容**不使用** indent（由 `align` 参数控制对齐）
- **不继承** style stack indent
- 使用独立的布局系统（`core/luatex-cn-core-column.lua`）

---

## 四、命令级别的控制

### 1. `\SetIndent{N}` - 临时强制缩进

#### 实现（`core/luatex-cn-core-paragraph.sty`）

```latex
\NewDocumentCommand{\SetIndent}{ m }
  {
    % 1. 推入临时样式到 style stack
    \edef\temp_style_id{\lua_now:e {
      local sr = require('util.luatex-cn-style-registry')
      tex.print(sr.push_indent(#1, #1))
    }}
    \setluatexattribute\cnverticalstyle{\temp_style_id}

    % 2. 设置强制缩进 attribute（优先级1）
    \lua_now:n {
      local constants = require('core.luatex-cn-constants')
      local forced_value = constants.encode_forced_indent(#1)
      tex.setattribute(constants.ATTR_INDENT, forced_value)
      tex.setattribute(constants.ATTR_FIRST_INDENT, forced_value)
    }

    \bool_set_true:N \l__luatexcn_setindent_active_bool
  }
```

#### 行为特性

- ✅ **完全强制**：使用 `encode_forced_indent()`，绕过 style stack 继承
- ✅ **自动恢复**：在 `\\` 或段落结束时自动清除
- ✅ **Breaking Change**：不再是"建议性"缩进，而是强制缩进

#### 作用范围

```latex
\begin{段落}[indent=2]
  正常缩进两格（显式，优先级2）
  \SetIndent{1}临时缩进一格（强制，优先级1）\\
  恢复缩进两格（显式，优先级2）
  \SetIndent{0}临时顶格（强制，优先级1）\\
  恢复缩进两格
\end{段落}
```

---

### 2. `\平抬` - 换行并顶格

#### 实现（`core/luatex-cn-core-paragraph.sty`）

```latex
\NewDocumentCommand{\平抬}{}
  {
    \\  % 换行
    \lua_now:n {
      local constants = require('core.luatex-cn-constants')
      tex.setattribute(constants.ATTR_INDENT, constants.INDENT_FORCE_ZERO)
      tex.setattribute(constants.ATTR_FIRST_INDENT, constants.INDENT_FORCE_ZERO)
    }
  }
```

#### 行为特性

- ✅ **强制顶格**：indent = 0，优先级最高
- ✅ **在段落中工作**：换行后下一列顶格
- ✅ **在 textflow 中工作**：通过节点级别 ATTR_INDENT 检查实现【2026-02-06 新增】

#### 作用范围

```latex
% 在段落中
\begin{段落}[indent=2]
  正常缩进两格
  \平抬 顶格显示（indent=0）
  恢复缩进两格
\end{段落}

% 在夹注中【2026-02-06 开始支持】
\begin{段落}[indent=2]
  \夹注{
    正常缩进两格。
    \平抬 顶格显示（节点级别 indent=0）
    继续缩进两格。
  }
\end{段落}
```

#### 技术实现（textflow 中的特殊处理）

```lua
-- 在 place_nodes() 中，对每个 textflow 节点检查
local node_indent_attr = D.get_attribute(node_info.node, constants.ATTR_INDENT)
if node_indent_attr == constants.INDENT_FORCE_ZERO then
    -- 不使用 chunk 的 cur_row 偏移，直接使用 relative_row
    node_row = node_info.relative_row  -- 顶格（row=0）
else
    -- 正常情况
    node_row = ctx.cur_row + node_info.relative_row
end
```

---

## 五、处理流程（各阶段统一）

整个 indent 系统在三个阶段依次处理：

### 1. TeX 输入阶段

```
用户输入 LaTeX 代码
  ↓
命令/环境解析（expl3 + xparse）
  ↓
设置 attributes
  - ATTR_INDENT: 缩进值（可能是强制编码）
  - ATTR_FIRST_INDENT: 首行缩进
  ↓
管理 style stack
  - push_indent(): 进入环境时
  - pop(): 离开环境时
  ↓
生成 node tree（LuaTeX 节点树）
```

**相关文件**：
- `core/luatex-cn-core-paragraph.sty`
- `guji/luatex-cn-guji-jiazhu.sty`
- `util/luatex-cn-style-registry.lua`

---

### 2. Layout 阶段（最核心）

```
遍历 node tree
  ↓
【段落/普通节点】
  读取 node.ATTR_INDENT
    ↓
  检查优先级：
    1. 强制缩进？→ 使用 forced_value
    2. 显式缩进？→ 使用 ATTR_INDENT
    3. 否则 → 查询 style stack
    ↓
  设置 cur_row（当前行位置）
  ↓
  放入 layout_map[node] = {page, col, row}

【Textflow 节点】
  A. Chunk 级别（整体偏移）:
     查询 style stack → 设置 cur_row

  B. 节点级别（个别调整）:
     for each node in chunk:
       检查 node.ATTR_INDENT:
         - INDENT_FORCE_ZERO？
           → row = relative_row (顶格)
         - 否则？
           → row = cur_row + relative_row (继承)

     放入 layout_map[node] = {page, col, row, sub_col}
```

**相关文件**：
- `core/luatex-cn-layout-grid.lua`
  - `get_indent_for_current_pos()`：获取当前位置缩进
  - 主循环：处理普通节点
- `core/luatex-cn-core-textflow.lua`
  - `place_nodes()`：处理 textflow 节点
  - 节点级别 ATTR_INDENT 检查

---

### 3. Render 阶段

```
读取 layout_map
  ↓
for each node:
  读取 {page, col, row, sub_col}
    ↓
  计算 PDF 坐标:
    x = page_width - col * grid_width - ...
    y = row * grid_height
    ↓
  输出到 PDF
```

**特点**：
- 不再处理 indent（已经在 Layout 阶段转换为 `row`）
- 只负责坐标转换和渲染

**相关文件**：
- `core/luatex-cn-render-page.lua`

---

## 六、统一性保证

### ✅ 已实现的统一

#### 1. 编码统一

**问题**（改进前）：
- 强制缩进使用不同的魔数（-1, -2, -999）
- 没有统一的编码/解码函数

**解决**（改进后）：
- 所有强制缩进使用 `encode_forced_indent()`
- 所有检查使用 `is_forced_indent()`
- 常量集中定义在 `core/luatex-cn-constants.lua`

```lua
-- 统一接口
constants.INDENT_FORCE_ZERO = -2
constants.INDENT_FORCE_BASE = -1000
constants.encode_forced_indent(N)
constants.is_forced_indent(attr_value)
```

#### 2. 优先级统一

**原则**：Forced > Explicit > Stack

**实现位置**：
- `core/luatex-cn-layout-grid.lua`：普通节点
- `core/luatex-cn-core-textflow.lua`：textflow 节点

**一致性检查**：
```lua
-- 伪代码（两个地方的逻辑一致）
local is_forced, forced_value = is_forced_indent(attr_value)
if is_forced then
    return forced_value  -- 优先级 1
elseif attr_value and attr_value > 0 then
    return attr_value    -- 优先级 2
else
    return style_stack.get_indent()  -- 优先级 3
end
```

#### 3. 继承统一

**机制**：所有环境通过 style stack 管理继承

```lua
-- 进入环境
style_registry.push_indent(indent, first_indent)

-- 离开环境
style_registry.pop()

-- 查询当前缩进
local indent = style_registry.get_indent(style_id)
```

**配对规则**：
- 每个 `push_indent()` 必须有对应的 `pop()`
- 使用 TeX 的环境系统自动管理配对

#### 4. 命令行为统一

**改进前**：
- `\SetIndent` 可能被 style stack 覆盖
- `\平抬` 只在段落中工作

**改进后**：
- 都使用强制编码（`encode_forced_indent()`）
- 都支持在段落和 textflow 中工作
- 行为一致、可预测

---

### 🎯 关键改进点（2026-02-06）

#### 1. Textflow 节点级别支持

**之前**：
- Textflow 只在 chunk 级别处理 indent
- 所有节点共享同一个 `cur_row` 偏移
- `\平抬` 在 textflow 中不起作用

**现在**：
- 每个节点都检查 `ATTR_INDENT`
- 支持节点级别的强制缩进（`INDENT_FORCE_ZERO`）
- `\平抬` 可以在 textflow/夹注中正常工作

**相关 Commit**: `0f281b4`

#### 2. 环境形式支持命令展开

**之前**：
- `\按{...}` 使用 `+m` 参数捕获内容
- 内部命令（如 `\平抬`）被当作纯文本，无法展开

**现在**：
- 创建 `按环境` 环境形式
- 使用 `\begin{夹注环境}...\end{夹注环境}`
- 内部命令可以正常展开和执行

**相关 Commit**: `66dd13b`, `05337ab`

#### 3. 完全强制的 `\SetIndent`

**之前**：
- `\SetIndent` 设置显式缩进（优先级2）
- 可能被强制缩进覆盖

**现在**：
- `\SetIndent` 设置强制缩进（优先级1）
- **Breaking Change**：完全绕过 style stack
- 使用 `encode_forced_indent()` 编码

**相关 Commit**: 在 indent 重构系列提交中

---

## 七、使用示例对照表

| 场景 | 代码示例 | indent 来源 | 优先级 | 说明 |
|------|---------|------------|--------|------|
| **段落基础缩进** | `\begin{段落}[indent=2]` | 显式 | 2 | 推入 style stack |
| **段落首行缩进** | `\begin{段落}[first-indent=3]` | 显式 | 2 | 仅首列生效 |
| **临时强制缩进** | `\SetIndent{1}` | 强制 | 1 | 自动恢复 |
| **临时顶格** | `\平抬` | 强制 | 1 | indent=0 |
| **夹注继承父缩进** | `\begin{段落}[indent=2]`<br>`\夹注{...}` | Style Stack | 3 | 从父环境继承 |
| **夹注内顶格** | `\夹注{...\平抬...}` | 强制（节点级） | 1 | **新增支持** |
| **嵌套段落** | `\begin{段落}[indent=2]`<br>`\begin{段落}[indent=4]` | 显式 + Stack | 2+3 | 内层覆盖外层 |
| **强制后恢复** | `\SetIndent{0}内容\\`<br>`继续` | 强制 → Stack | 1 → 3 | 换行后恢复 |

---

## 八、总结：统一的设计原则

### 1. 单一真相来源（Single Source of Truth）

indent 值最终存储在 `layout_map` 的 `row` 字段：

```lua
layout_map[node] = {
    page = ...,
    col = ...,
    row = ...,  -- 这里存储了最终计算的缩进结果
    sub_col = ...
}
```

- 所有后续阶段（render）只读取这个值
- 不会重复计算或产生歧义

### 2. 清晰的优先级（Clear Priority）

三层优先级无歧义：

```
Forced (1) > Explicit (2) > Stack (3)
```

- 任何情况下，indent 值的来源都是唯一确定的
- 代码中所有检查都遵循这个优先级
- 文档清晰说明每个命令/环境使用哪个优先级

### 3. 一致的接口（Consistent Interface）

所有环境都使用相同的机制：

```
TeX 层: attributes + style stack
  ↓
Layout 层: 统一优先级检查 → 计算 row
  ↓
Render 层: 读取 row → 输出坐标
```

- 新增环境只需遵循现有接口
- 维护者容易理解和扩展

### 4. 分层处理（Layered Processing）

每个阶段只负责自己的任务：

- **TeX 层**：设置 attributes，管理 style stack
- **Layout 层**：解析优先级，计算位置
- **Render 层**：坐标转换，输出 PDF

职责分明，降低耦合。

### 5. 节点级别粒度（Node-Level Granularity）

支持**单个字符级别**的缩进控制：

- 段落中：通过 `\SetIndent` 和 `\平抬`
- Textflow 中：通过节点级别 ATTR_INDENT 检查

这是最细粒度的控制，满足复杂排版需求。

---

## 附录：相关文件清单

### 核心实现

| 文件 | 功能 | 关键函数/变量 |
|------|------|--------------|
| `core/luatex-cn-constants.lua` | Indent 常量和编码 | `INDENT_FORCE_ZERO`<br>`encode_forced_indent()`<br>`is_forced_indent()` |
| `core/luatex-cn-core-paragraph.sty` | 段落环境和命令 | `\begin{段落}`<br>`\SetIndent`<br>`\平抬` |
| `core/luatex-cn-layout-grid.lua` | 普通节点布局 | `get_indent_for_current_pos()`<br>主循环中的 indent 检查 |
| `core/luatex-cn-core-textflow.lua` | Textflow 布局 | `place_nodes()`<br>节点级别 ATTR_INDENT 检查 |
| `util/luatex-cn-style-registry.lua` | Style stack 管理 | `push_indent()`<br>`pop()`<br>`get_indent()` |

### 测试用例

| 文件 | 测试内容 |
|------|---------|
| `test/regression_test/tex/paragraph.tex` | `\SetIndent` 和 `\平抬` 在段落中 |
| `test/regression_test/tex/jiazhu.tex` | `\平抬` 在夹注中 |
| `全书复刻/.../column1.tex` | 实际排版案例（`\注` + `\按`） |

---

## 变更历史

### 2026-02-06
- ✅ 实现 textflow 节点级别 ATTR_INDENT 检查
- ✅ `\平抬` 现在支持在 textflow/夹注中工作
- ✅ 创建环境形式（`夹注环境`）支持命令展开
- ✅ 统一 indent 系统文档

### 之前的重构
- ✅ 统一强制缩进编码（constants）
- ✅ 扩展支持任意值的强制缩进（INDENT_FORCE_BASE）
- ✅ `\SetIndent` 改为完全强制（Breaking Change）
- ✅ 添加详细文档注释

---

**文档维护者注意**：
- 当 indent 系统有重大变更时，请更新本文档
- 保持示例代码与实际实现一致
- 更新"变更历史"部分
