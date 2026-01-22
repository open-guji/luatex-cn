# 自然排版模式 (Natural Layout Mode) 实现方案

> 状态：**Phase 1-3 已实施** — Phase 4-5 延后
> 日期：2026-02-09

## Context

当前 luatex-cn 的竖排引擎采用**固定网格模式**：每个字符占据一个等高的格子（`grid_height`），每列固定行数（`line_limit`）。这适合古籍排版，但不适合现代书籍——现代书需要字号可变、格子高度随字号变化、字间有弹性间距。

本方案在 `Content` 环境下新增 `layout-mode = natural` 模式，与现有 `grid` 模式并存。

## 核心思路

**关键洞察**：渲染层公式 `y = -row * grid_height` 已经支持小数 row（distribute 模式在用）。自然模式只需在 layout 阶段用 **连续 sp 坐标**代替整数行号，存为 `row = cur_y_sp / grid_height`，渲染层无需大改。

| 维度 | 固定网格 (grid) | 自然排版 (natural) |
|------|-----------------|-------------------|
| 格子高度 | 固定 `grid_height` | 每字 = `font_size` |
| 行号 | 整数 `cur_row += 1` | 小数 `cur_y_sp / grid_height` |
| 列满判断 | `cur_row >= line_limit` | `cur_y_sp + cell_h > col_height_sp` |
| 字间距 | 无（紧密排列） | glue（可拉伸/压缩） |
| 标点 | 占 1 格 | 占半格或更少 |
| 水平方向 | 不变（RTL、版心、边框） | 不变 |

## 分阶段实现

### Phase 1: MVP — 基本自然排版

**目标**：字号决定格高，连续 Y 坐标，自动换列。

#### 1.1 参数层 — `tex/core/luatex-cn-core-content.sty`

新增 key-value 参数：

```latex
% 新增变量声明（~line 33）
\tl_new:N \l__luatexcn_content_layout_mode_tl

% 新增 key 定义（~line 86 后）
layout-mode .tl_set:N = \l__luatexcn_content_layout_mode_tl,
layout-mode .initial:n = {grid},

% sync_to_lua 中新增（~line 144）
layout_mode = [=[\luaescapestring{\l__luatexcn_content_layout_mode_tl}]=],
```

#### 1.2 参数同步 — `tex/core/luatex-cn-core-content.lua`

- `_G.content` 新增 `layout_mode` 字段
- `sync_params()` 中解析 `params.layout_mode`

#### 1.3 管线传递 — `tex/core/luatex-cn-core-main.lua`

- `init_engine_context()` 中新增：
  ```lua
  engine_ctx.layout_mode = _G.content.layout_mode or "grid"
  engine_ctx.col_height_sp = engine_ctx.line_limit * engine_ctx.g_height
  ```
- `compute_grid_layout()` 将 `layout_mode` 和 `col_height_sp` 传入 layout params

#### 1.4 布局引擎（核心改动） — `tex/core/luatex-cn-layout-grid.lua`

**新增辅助函数**：

```lua
-- 获取节点的格子高度（= font_size）
local function get_cell_height(node, grid_height)
    local fs = get_node_font_size(node)  -- 已有函数，从 style_registry 读
    if fs and fs > 0 then return fs end
    local fid = D.getfield(node, "font")
    if fid then
        local f = font.getfont(fid)
        if f and f.size then return f.size end
    end
    return grid_height  -- 兜底
end
```

**`create_grid_context()` 扩展**：

```lua
-- natural 模式新增字段
ctx.cur_y_sp = 0           -- 列内累计 Y 位置（sp）
ctx.col_height_sp = params.col_height_sp or (line_limit * grid_height)
ctx.layout_mode = params.layout_mode or "grid"
ctx.inter_cell_gap = params.inter_cell_gap or 0
```

**主循环 GLYPH 处理分支**（~line 880）：

```lua
if ctx.layout_mode == "natural" then
    local cell_h = get_cell_height(t, grid_height)
    -- 换列判断
    if ctx.cur_y_sp + cell_h > ctx.col_height_sp then
        flush_buffer()  -- 会做 glue 分配
        wrap_to_next_column(...)
        ctx.cur_y_sp = 0
    end
    -- 记录位置（小数行号）
    table.insert(col_buffer, {
        node = t,
        page = ctx.cur_page,
        col = ctx.cur_col,
        relative_row = ctx.cur_y_sp / grid_height,  -- 小数！
        height = (D.getfield(t, "height") or 0) + (D.getfield(t, "depth") or 0),
        cell_height = cell_h,
    })
    ctx.cur_y_sp = ctx.cur_y_sp + cell_h + ctx.inter_cell_gap
else
    -- 现有 grid 模式代码不变
    ctx.cur_row = ctx.cur_row + 1
end
```

**`flush_buffer()` 扩展** — 写入 layout_map 时传递 cell_height：

```lua
-- 在 map_entry 构造中（~line 536-563）
if entry.cell_height then
    map_entry.cell_height = entry.cell_height
end
```

**Glue/Kern 节点处理**（~line 904）：

```lua
if ctx.layout_mode == "natural" then
    -- 直接累加 sp，不量化为格子数
    if net_width > 0 and ctx.cur_y_sp > 0 then
        ctx.cur_y_sp = ctx.cur_y_sp + net_width
        if ctx.cur_y_sp > ctx.col_height_sp then
            flush_buffer()
            wrap_to_next_column(...)
            ctx.cur_y_sp = 0
        end
    end
else
    -- 现有量化逻辑不变
end
```

**`wrap_to_next_column()` 扩展**：

```lua
-- 换列时重置 cur_y_sp
if ctx.layout_mode == "natural" then
    ctx.cur_y_sp = 0
end
```

#### 1.5 渲染层 — `tex/core/luatex-cn-render-position.lua`

`calc_grid_position()` 修改（~line 206）：

```lua
local cell_height = params.cell_height or grid_height  -- 新增：每节点格高

-- Y 方向居中时用 cell_height 代替 grid_height
if v_align == "center" then
    local char_total_height = h + d
    y_offset = y_offset - (cell_height + char_total_height) / 2 + d  -- 改 grid_height → cell_height
end
```

#### 1.6 渲染页面 — `tex/core/luatex-cn-core-render-page.lua`

`handle_glyph_node()` 中传递 cell_height：

```lua
-- 调用 calc_grid_position 时新增参数
cell_height = pos.cell_height,  -- 从 layout_map 读取
```

---

### Phase 2: Glue 分配（底端对齐）

**核心原则**：每一列的最后一个字的底部必须与列的底端对齐（`col_height_sp`），通过均匀拉伸字间 glue 实现。

**设计要点**：

1. **`inter_cell_gap` 的角色**：Phase 1 中的 `inter_cell_gap` 仅用于**换列判断**（决定一列能放多少字）。实际显示间距在 flush 时重算。
2. **所有列都做分配**：无论是列满换列还是内容结尾的最后一列，flush 时都执行底端对齐分配。
3. **数学保证**：最后一字底部 = `col_height_sp`。

**验算**（`col_height=100pt`, 5字各18pt）：
- `total_cells = 90pt`, `remaining = 10pt`, `gap = 10/4 = 2.5pt`
- 位置: 0, 20.5, 41, 61.5, 82 → 最后一字底部 = 82+18 = **100pt** ✓

在 `flush_buffer()` 中，natural 模式下**始终**执行分配：

```lua
if ctx.layout_mode == "natural" and #col_buffer > 0 then
    local N = #col_buffer

    -- 计算所有格子的总自然高度
    local total_cells = 0
    for _, e in ipairs(col_buffer) do
        total_cells = total_cells + (e.cell_height or grid_height)
    end

    -- 计算需要分配的剩余空间
    local remaining = ctx.col_height_sp - total_cells

    if N == 1 then
        -- 单字：顶端对齐（不拉伸），或居中
        -- col_buffer[1].relative_row = 0 / grid_height  -- 顶端
        -- 不做底端对齐（单字拉到底部无意义）
    elseif remaining > 0 then
        -- 多字：均匀分配间距，保证底端对齐
        local gap = remaining / (N - 1)
        local y = 0
        for i, e in ipairs(col_buffer) do
            e.relative_row = y / grid_height
            y = y + (e.cell_height or grid_height) + gap
        end
        -- 此时 y = total_cells + (N-1)*gap = total_cells + remaining = col_height_sp ✓
    elseif remaining < 0 then
        -- 溢出（理论上不应发生，因为换列已处理）：保持原位，不压缩
    end
    -- remaining == 0：完美填满，无需调整
end
```

**Phase 1 与 Phase 2 的衔接**：

Phase 1 中放置字符时用 `inter_cell_gap` 做近似计算：
```lua
ctx.cur_y_sp = ctx.cur_y_sp + cell_h + ctx.inter_cell_gap
```
这决定了"一列大约放多少字"。Phase 2 的 flush 分配会**覆盖**这些临时位置，重算 `relative_row` 使最后一字底端对齐。两者不冲突——`inter_cell_gap` 控制密度，分配控制精确位置。

同时新增 `inter-cell-gap` 参数（content.sty → content.lua → layout params），默认值 `0pt`（让系统自动分配全部间距）。

---

### Phase 3: 标点半格

利用已有的 `ATTR_PUNCT_TYPE` 属性：

```lua
local function get_cell_height(node, grid_height)
    local base = ...  -- font_size
    local punct_type = D.get_attribute(node, constants.ATTR_PUNCT_TYPE)
    if punct_type and punct_type > 0 then
        return base * 0.5  -- 标点占半格
    end
    return base
end
```

---

### Phase 4: TextFlow/夹注整合

TextFlow 需要跟踪 `cur_y_sp` 而非整数行。这是最复杂的整合点，延后处理。

---

### Phase 5: 缩进、禁则、调试网格

- 缩进：natural 模式下 `indent=2` → 跳过 `2 * font_size` 高度
- 禁则（kinsoku）：换列判断改为基于 `cur_y_sp`
- 调试网格：用 `pos.cell_height` 代替 `grid_height` 画格子

---

## 需要修改的文件清单

| 文件 | 改动量 | 说明 |
|------|--------|------|
| `tex/core/luatex-cn-core-content.sty` | 小 (~10行) | 新增 `layout-mode` 参数定义和同步 |
| `tex/core/luatex-cn-core-content.lua` | 小 (~5行) | `_G.content.layout_mode` 字段 |
| `tex/core/luatex-cn-core-main.lua` | 小 (~10行) | `engine_ctx` 传递 `layout_mode`, `col_height_sp` |
| `tex/core/luatex-cn-layout-grid.lua` | **大 (~100行)** | 核心：natural 模式分支、`get_cell_height`、glue 分配 |
| `tex/core/luatex-cn-render-position.lua` | 小 (~5行) | `cell_height` 参数支持 |
| `tex/core/luatex-cn-core-render-page.lua` | 小 (~5行) | 传递 `cell_height` 到坐标计算 |

## 数据结构变更

### layout_map entry（natural 模式新增字段加粗）

```lua
layout_map[node] = {
    page = 0,              -- 页码
    col = 3,               -- 列号
    row = 2.347,           -- 小数行号 (= cur_y_sp / grid_height)
    height = 786432,       -- 字形 height+depth (sp)
    cell_height = 655360,  -- **新增：该节点的格高 (sp)**
    font_size = 655360,    -- 已有：字号
    font_color = "1 0 0",  -- 已有：颜色
    v_scale = 1.0,         -- 已有：缩放
}
```

### engine_ctx 新增

```lua
engine_ctx.layout_mode = "natural"     -- 新增
engine_ctx.col_height_sp = 12345678    -- 新增：列高 (sp) = line_limit * g_height
```

### grid context (ctx) 新增

```lua
ctx.cur_y_sp = 0             -- 新增：列内 Y 坐标 (sp)
ctx.col_height_sp = 0        -- 新增：列高上限 (sp)
ctx.layout_mode = "grid"     -- 新增
ctx.inter_cell_gap = 0       -- 新增：字间距 (sp)
```

## 验证方式

1. **新建测试文件** `test/regression_test/tex/natural_layout.tex`：
   - 混合字号文本（12pt + 16pt + 10pt）
   - 验证字号不同时格高自动变化
   - 验证自动换列
   - 验证列满时 glue 拉伸

2. **回归测试**：`python3 test/regression_test.py check` — 所有现有测试必须通过（grid 模式不受影响）

3. **手动检查 PDF** — 确认字符垂直居中、列对齐正确

## 向后兼容保证

- `layout-mode` 默认值 = `grid`，所有现有行为零改变
- 每处改动都用 `if layout_mode == "natural"` 分支守卫
- `grid_height` 在 natural 模式中仍作为"参考单位"用于小数行号计算

## 使用示例

```latex
% 现代书竖排
\Content[
    layout-mode = natural,
    font-size = 12pt,
    grid-width = 1.5em,
    n-column = 0,           % 无版心
    page-columns = 20,
]{
    这是一段{\fontsize{16pt}{16pt}\selectfont 大号文字}然后恢复正常。
    标点符号，只占半格。
}

% 古籍竖排（不受影响）
\Content[
    layout-mode = grid,     % 默认值，可省略
    n-column = 8,
    n-char-per-col = 20,
]{
    史記卷一...
}
```
