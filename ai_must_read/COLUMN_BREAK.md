# 换列机制完整梳理

> 本文档系统梳理 luatex-cn 中所有换列相关的机制、命令和逻辑

## 目录

1. [换列的类型和触发方式](#换列的类型和触发方式)
2. [Penalty 机制详解](#penalty-机制详解)
3. [不同上下文中的换列](#不同上下文中的换列)
4. [核心函数：wrap_to_next_column](#核心函数wrap_to_next_column)
5. [换列的执行流程](#换列的执行流程)
6. [统一性分析与改进建议](#统一性分析与改进建议)

---

## 换列的类型和触发方式

### 1. 用户显式命令

#### `\换列` 命令
- **文件**：`tex/core/luatex-cn-core-paragraph.sty:204-208`
- **机制**：插入 `\penalty-10002`
- **用途**：用户手动强制换到下一列
- **示例**：
  ```latex
  第一列内容
  \换列
  第二列内容
  ```

#### `\newpage` / `\clearpage` 命令
- **文件**：`tex/core/luatex-cn-core-page.sty:252-253`
- **机制**：插入 `\penalty-10003`
- **用途**：强制换到新页
- **示例**：
  ```latex
  第一页内容
  \newpage
  第二页内容
  ```

#### `\\` 换行命令
- **文件**：LaTeX 标准命令
- **机制**：在 flatten_nodes.lua 中，某些 `\\` 会被转换为 `penalty -10002`
- **用途**：在某些上下文中强制换列
- **注意**：不是所有 `\\` 都会换列，取决于上下文

### 2. 环境/命令自动触发

#### 段落环境结束（Paragraph）
- **文件**：`tex/core/luatex-cn-core-paragraph.sty:87-93`
- **机制**：段落结束时插入 `\penalty-10001`（智能换列）
- **触发条件**：`\end{段落}` 或 `\end{Paragraph}`
- **行为**：
  - 检查下一个节点类型
  - 如果下一个是 textflow（夹注），不换列
  - 如果下一个是正文（GLYPH），换到新列
- **实现**：
  ```latex
  \par
  \penalty-10001\relax  % 智能换列标记
  ```

#### Column 环境（单列排版）
- **文件**：`tex/core/luatex-cn-layout-grid.lua:687-732`
- **机制**：Column 开始时自动换到新列
- **触发条件**：`\begin{Column}` 或检测到 `ATTR_COLUMN == 1`
- **行为**：
  ```lua
  flush_buffer()
  if ctx.cur_row > 0 then
      wrap_to_next_column(ctx, p_cols, interval, grid_height, 0, true, false)
  end
  ```

#### LastColumn（末列排版）
- **文件**：`tex/core/luatex-cn-layout-grid.lua:703-712`
- **机制**：跳转到当前半页的最后一列
- **触发条件**：`ATTR_COLUMN_ALIGN >= 4`
- **用途**：版心、书名等需要在末列显示的内容

### 3. 自动换列（边界检测）

#### 行数超过 line_limit
- **文件**：`tex/core/luatex-cn-layout-grid.lua:680-683`
- **机制**：在放置节点前检查 `cur_row >= effective_limit`
- **行为**：
  ```lua
  if ctx.cur_row >= effective_limit and not distribute then
      flush_buffer()
      wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, true, false)
  end
  ```
- **特殊情况**：distribute 模式（分布模式）允许溢出，后续压缩字符

#### TextFlow 自动换列
- **文件**：`tex/core/luatex-cn-core-textflow.lua`
- **机制**：textflow 内部有自己的双列（sub-column）系统
- **行为**：
  - 在双列对（right + left）内自动切换
  - 通过 `block_id` 管理不同 textflow 块的连续性
  - 超过限制时通过回调函数 `wrap` 换到下一列

#### GLUE/KERN 节点的空白处理
- **文件**：`tex/core/luatex-cn-layout-grid.lua:871-891`
- **机制**：累积连续的空白节点，超过阈值时插入空格行
- **行为**：
  ```lua
  for i = 1, num_cells do
      ctx.cur_row = ctx.cur_row + 1
      if ctx.cur_row >= effective_limit then
          flush_buffer()
          wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
      end
  end
  ```

---

## Penalty 机制详解

### Penalty 值的语义

| Penalty 值 | 名称 | 来源 | 触发时机 | 行为 |
|-----------|------|------|---------|------|
| `-10000` | 页面填充标记 | `core-page.lua`, `core-page-split.lua` | 页面分割时 | 允许分页，不强制换列 |
| `-10001` | 智能换列 | `段落环境结束` | `\end{段落}` | 检查下一个节点，textflow→不换列，正文→换列 |
| `-10002` | 强制换列 | `\换列`, flatten_nodes | 用户命令，某些 `\\` | 无条件换到下一列 |
| `-10003` | 强制换页 | `\newpage`, `\clearpage` | 用户命令 | 无条件换到新页 |
| `<= -10000` | 通用换列标记 | flatten_nodes | HLIST 行结束 | 在 flatten 时检测，防止过早换列 |

### Penalty 处理流程

#### 1. 智能换列（-10001）
**文件**：`tex/core/luatex-cn-layout-grid.lua:896-915`

```lua
if p_val == -10001 then
    local next_node = D.getnext(t)
    if next_node then
        local next_is_textflow = D.get_attribute(next_node, constants.ATTR_JIAZHU) == 1
        if not next_is_textflow then
            -- 下一个节点是正文，换到新列
            flush_buffer()
            if ctx.cur_row > ctx.cur_column_indent then
                wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
            end
            ctx.cur_column_indent = 0
        end
        -- 如果下一个是 textflow，不换列，让 textflow 自然延续
    end
end
```

**关键点**：
- 向前查看（lookahead）下一个节点
- 根据节点类型（textflow vs 正文）决定是否换列
- 实现了"段落结束智能换列"的语义

#### 2. 强制换列（-10002）
**文件**：`tex/core/luatex-cn-layout-grid.lua:377-384`

```lua
if p_val == -10002 then
    -- Forced column break (paragraph end)
    flush_buffer_fn()
    if ctx.cur_row > ctx.cur_column_indent then
        wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
    end
    ctx.cur_column_indent = 0
    return true
end
```

**关键点**：
- 无条件执行
- 刷新缓冲区
- 重置列缩进

#### 3. 强制换页（-10003）
**文件**：`tex/core/luatex-cn-layout-grid.lua:385-396`

```lua
elseif p_val == -10003 then
    -- Forced page break
    if ctx.page_has_content then
        flush_buffer_fn()
        ctx.cur_page = ctx.cur_page + 1
        ctx.cur_col = 0
        ctx.cur_row = 0
        ctx.cur_column_indent = 0
        ctx.page_has_content = false
        move_to_next_valid_position(ctx, interval, grid_height, indent)
    end
    return true
end
```

---

## 不同上下文中的换列

### 1. 正文（Main Text）

#### 触发方式
- 行数超过 `line_limit`：自动换列
- `\换列` 命令：强制换列
- `\newpage` 命令：强制换页
- 段落结束后遇到正文：智能换列

#### 特点
- 使用整列（full column）
- 每列 `line_limit` 行（通常 20 行）
- 支持缩进（indent）

#### 代码位置
- `tex/core/luatex-cn-layout-grid.lua:680-683` - 边界检测
- `tex/core/luatex-cn-layout-grid.lua:799-868` - GLYPH 节点处理

### 2. TextFlow（夹注/双列小字）

#### 触发方式
- 双列对（right + left sub-column）内自动切换
- 通过 `block_id` 切换到新的双列对
- 超过限制时通过 wrap 回调换列

#### 特点
- 使用双列系统（sub_col = 1/2）
- 每个双列对占用 2 个小列宽度
- 不同 `block_id` 的 textflow 在新的双列对开始
- 支持 `auto-balance` 自动平衡

#### 代码位置
- `tex/core/luatex-cn-core-textflow.lua` - textflow 核心逻辑
- `tex/core/luatex-cn-layout-grid.lua:734-761` - textflow 放置逻辑

#### 与正文的边界
- 段落结束时，penalty -10001 检查下一个节点
- 如果下一个是正文，换到新的整列
- 如果下一个是 textflow，不换列，继续在双列系统中

### 3. TextBox（文本框）

#### 触发方式
- TextBox 开始时不一定换列，取决于当前位置
- TextBox 结束后，后续内容在新位置继续

#### 特点
- 占据固定的宽度和高度（`tb_w` × `tb_h`）
- 可以跨列、跨页放置
- 内部有独立的坐标系统

#### 代码位置
- `tex/core/luatex-cn-core-textbox.lua` - textbox 核心逻辑
- `tex/core/luatex-cn-layout-grid.lua:767-795` - textbox 放置逻辑

### 4. Column（单列排版）

#### 触发方式
- Column 开始时自动换到新列
- Column 结束时，后续内容在新列继续

#### 特点
- 始终占据完整的一列
- 支持对齐模式（居中、左对齐、右对齐、末列）
- 用于版心、书名等固定位置的内容

#### 代码位置
- `tex/core/luatex-cn-core-column.lua` - column 核心逻辑
- `tex/core/luatex-cn-layout-grid.lua:687-732` - column 放置逻辑

### 5. 版心（BanXin）

#### 触发方式
- BanXin 通过 Column 实现，使用 LastColumn 模式
- 自动跳转到半页的最后一列

#### 特点
- 始终在半页的最后一列（interval 列）
- 占据整列高度
- 不影响其他列的布局

#### 代码位置
- `tex/banxin/luatex-cn-banxin.sty` - 版心定义
- `tex/core/luatex-cn-layout-grid.lua:703-712` - LastColumn 跳转逻辑

---

## 核心函数：wrap_to_next_column

**文件**：`tex/core/luatex-cn-layout-grid.lua:317-336`

### 函数签名
```lua
local function wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, reset_indent, reset_content)
```

### 参数说明
- `ctx`: 布局上下文（当前页、列、行等）
- `p_cols`: 每页的总列数
- `interval`: 版心间隔（每隔多少列有一个版心）
- `grid_height`: 网格高度（单个字符的高度）
- `indent`: 当前缩进值
- `reset_indent`: 是否重置缩进
- `reset_content`: 是否重置内容标记（影响版心显示）

### 核心逻辑
```lua
function wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, reset_indent, reset_content)
    ctx.cur_col = ctx.cur_col + 1
    ctx.cur_row = 0

    -- 重置标记
    if reset_indent then
        ctx.cur_column_indent = 0
    else
        ctx.cur_column_indent = indent
    end

    if reset_content then
        ctx.page_has_content = false
    end

    -- 检查是否跨页
    if ctx.cur_col >= p_cols then
        ctx.cur_page = ctx.cur_page + 1
        ctx.cur_col = 0
        ctx.page_has_content = false
    end

    -- 移动到有效位置（跳过版心列）
    move_to_next_valid_position(ctx, interval, grid_height, indent)
end
```

### 关键点
1. **列递增**：`ctx.cur_col + 1`
2. **行重置**：`ctx.cur_row = 0`
3. **跨页检测**：`cur_col >= p_cols` 时换页
4. **版心处理**：通过 `move_to_next_valid_position` 跳过保留列
5. **缩进管理**：根据 `reset_indent` 决定是否保持缩进

---

## 换列的执行流程

### 完整流程图

```
用户输入（LaTeX 代码）
    │
    ├─→ 显式命令 (\换列, \newpage)
    │       │
    │       └─→ 插入 penalty (-10002, -10003)
    │
    ├─→ 环境结束 (\end{段落})
    │       │
    │       └─→ 插入 penalty -10001
    │
    └─→ 正文/夹注节点
            │
            ↓
      TeX 处理 → Flatten Nodes (Stage 1)
            │
            ├─→ HLIST → 展平为 GLYPH + KERN
            │
            ├─→ 某些 \\ → penalty -10002
            │
            └─→ penalty 节点保留
            │
            ↓
      Layout Grid (Stage 2)
            │
            ├─→ 遍历节点，处理不同类型
            │
            ├─→ 检测边界 (cur_row >= line_limit)
            │       └─→ 自动 wrap_to_next_column
            │
            ├─→ 遇到 penalty 节点
            │       │
            │       ├─→ -10001: 智能换列（检查下一个节点）
            │       ├─→ -10002: 强制换列
            │       └─→ -10003: 强制换页
            │
            ├─→ TextFlow: 双列系统，自动管理换列
            │
            ├─→ Column: 开始时换列
            │
            └─→ TextBox: 独立布局，可能跨列
            │
            ↓
      Render Page (Stage 3)
            │
            └─→ 根据 layout_map 应用坐标，绘制 PDF
```

---

## 统一性分析与改进建议

### 当前存在的问题

#### 1. 换列方式多样，缺乏统一接口
**问题**：
- 有些通过 penalty 机制
- 有些通过直接调用 `wrap_to_next_column`
- 有些通过环境内部逻辑（如 textflow 的 wrap 回调）

**建议**：
- 所有换列最终都应该通过 penalty 机制或统一的换列接口
- 明确区分"请求换列"和"执行换列"

#### 2. Penalty 值语义重叠
**问题**：
- `-10000` 和 `<= -10000` 的区别不清晰
- flatten_nodes 中也使用 penalty，容易混淆

**建议**：
- 统一 penalty 值的命名和语义
- 在 constants.lua 中定义所有 penalty 常量：
  ```lua
  constants.PENALTY_PAGE_FILL = -10000
  constants.PENALTY_SMART_BREAK = -10001
  constants.PENALTY_FORCE_COLUMN = -10002
  constants.PENALTY_FORCE_PAGE = -10003
  ```

#### 3. 不同上下文的换列逻辑分散
**问题**：
- 正文换列在 layout-grid.lua
- textflow 换列在 textflow.lua
- column 换列在 column.lua
- 难以整体理解和维护

**建议**：
- 创建统一的换列管理器（ColumnBreakManager）
- 不同上下文注册换列策略
- 统一的换列请求接口

#### 4. 边界检测与显式换列的优先级不明确
**问题**：
- 有时先检测边界，有时先处理 penalty
- 不同顺序可能导致不同结果

**建议**：
- 明确换列检查的顺序：
  1. 处理 penalty（最高优先级）
  2. 检测边界（自动换列）
  3. 节点放置

### 改进方案草案

#### 方案 1：统一 Penalty 机制
**目标**：所有换列都通过 penalty 实现

**步骤**：
1. 定义所有 penalty 常量
2. 所有环境/命令都插入 penalty
3. layout-grid 统一处理所有 penalty
4. 移除直接调用 `wrap_to_next_column` 的代码

**优点**：
- 机制统一，易于理解
- 符合 TeX 的设计哲学
- 易于扩展新的换列类型

**缺点**：
- 需要大量重构现有代码
- penalty 机制有性能开销

#### 方案 2：分层换列系统
**目标**：区分"换列请求"和"换列执行"

**架构**：
```
应用层：\换列, \end{段落}, textflow 等
    ↓
请求层：ColumnBreakRequest (类型, 条件, 优先级)
    ↓
调度层：ColumnBreakScheduler (检查条件, 决策)
    ↓
执行层：wrap_to_next_column (实际换列)
```

**优点**：
- 分层清晰，易于维护
- 可以灵活控制换列策略
- 易于调试和追踪

**缺点**：
- 增加了系统复杂度
- 需要设计新的抽象层

#### 方案 3：混合方案（推荐）
**目标**：保留 penalty 机制，增强统一性

**步骤**：
1. **统一 penalty 常量定义**
   - 在 constants.lua 中定义所有 penalty
   - 所有代码引用常量而非魔法数字

2. **标准化 penalty 处理**
   - 在 `handle_penalty_breaks` 中处理所有 penalty
   - 明确每个 penalty 的语义和行为

3. **保留现有机制**
   - textflow、column 等保持当前逻辑
   - 但通过 penalty 与主流程交互

4. **文档化**
   - 创建完整的换列机制文档（本文档）
   - 在代码中添加清晰的注释

**优点**：
- 改动最小，风险最低
- 保留现有架构的优点
- 提升可维护性和可理解性

**缺点**：
- 不是完全统一的架构
- 仍然有一定复杂度

---

## 下一步行动

1. **短期**（立即执行）：
   - [ ] 在 constants.lua 中定义所有 penalty 常量
   - [ ] 替换所有魔法数字为常量引用
   - [ ] 补充代码注释，说明换列逻辑

2. **中期**（1-2 周）：
   - [ ] 重构 `handle_penalty_breaks`，统一处理所有 penalty
   - [ ] 标准化 textflow、column 等的换列接口
   - [ ] 编写换列机制的单元测试

3. **长期**（下一个版本）：
   - [ ] 考虑引入 ColumnBreakManager
   - [ ] 优化性能，减少不必要的换列检查
   - [ ] 支持用户自定义换列策略

---

## 附录：关键文件列表

### 核心文件
- `tex/core/luatex-cn-layout-grid.lua` - 布局网格，换列核心逻辑
- `tex/core/luatex-cn-core-paragraph.sty` - 段落环境，智能换列
- `tex/core/luatex-cn-core-page.sty` - 页面设置，换页命令
- `tex/core/luatex-cn-core-flatten-nodes.lua` - 节点展平，penalty 插入

### 上下文特定
- `tex/core/luatex-cn-core-textflow.lua` - TextFlow 双列系统
- `tex/core/luatex-cn-core-column.lua` - Column 单列排版
- `tex/core/luatex-cn-core-textbox.lua` - TextBox 文本框
- `tex/banxin/luatex-cn-banxin.sty` - 版心

### 工具和常量
- `tex/core/luatex-cn-constants.lua` - 常量定义
- `util/luatex-cn-debug.lua` - 调试工具

---

**文档版本**：v1.0
**更新日期**：2026-02-06
**维护者**：Open-Guji Team
