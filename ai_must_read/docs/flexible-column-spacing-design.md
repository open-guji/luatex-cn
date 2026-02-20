# 灵活列宽和间距系统设计

## 需求分析

### 当前问题

1. **列宽固定** - 所有列宽度相同，缺乏灵活性
2. **字号与列宽不匹配** - 调大字号后字符重叠，列宽没有自动调整
3. **缺少行间距控制** - 无法控制列与列之间的间距
4. **缺少段间距** - 段落之间应该比行间距稍大

### 核心需求

1. ✅ **`\行[width=...]` 设置列宽** - 已支持，但需要增强
2. 🆕 **字号自动调整列宽** - `font-size` 增大时，默认增大列宽
3. 🆕 **下间距（spacing-bottom）** - 列的右边（下方）的间距
4. 🆕 **上间距（spacing-top）** - 列的左边（上方）的间距
5. 🆕 **段间距（paragraph-spacing）** - 段落之间的间距（比行间距大）
6. 🆕 **模板级配置** - 所有间距参数可在模板中预设
7. ⚠️ **Grid Layout 排除** - 使用网格布局时，不应用这些灵活间距

## 参数命名体系

### 核心参数

```yaml
# 列宽度
column-width: <dim>           # 列的宽度（替代 width）
auto-width: true|false        # 是否自动根据字号计算列宽（默认 true）
width-scale: <number>         # 自动宽度的缩放因子（默认 1.0）

# 列间距（竖排方向的间距）
spacing-top: <dim>            # 列右边的间距（阅读顺序的"前方"）
spacing-bottom: <dim>         # 列左边的间距（阅读顺序的"后方"）
spacing: <dim>                # 同时设置上下间距（简写）

# 段落间距
paragraph-spacing: <dim>      # 段落之间的额外间距
```

### 术语说明

在竖排布局中（从右向左阅读）：
- **"上"** = 页面顶部 = 列的**右侧**（逻辑上的"前方"）
- **"下"** = 页面底部 = 列的**左侧**（逻辑上的"后方"）
- **spacing-top** = 列右边间距（前一列的后方 → 当前列的前方）
- **spacing-bottom** = 列左边间距（当前列的后方 → 下一列的前方）
- **行间距** = 列与列之间的水平距离（从右向左阅读方向）
- **段间距** = 段落结束后的额外间距

**阅读顺序示例**：
```
页面布局（从右向左阅读）：
     [列3] ←spacing→ [列2] ←spacing→ [列1]
      ↑                              ↑
    后列                          首列(起始)

spacing-top: 列的右边（阅读顺序上的"前方"）
spacing-bottom: 列的左边（阅读顺序上的"后方"）
```

## 架构设计

### 1. 参数层次结构

```
Global Defaults (全局默认值)
    ↓
Template Config (模板配置)
    ↓
Environment Setup (环境设置，如 \contentSetup)
    ↓
Local Override (局部覆盖，如 \行[...])
```

### 2. 参数传导路径

```
TeX Layer (用户 API)
    ↓ \keys_set:nn
TeX Variables (\l__luatexcn_column_xxx_tl)
    ↓ \lua_now:e
Lua Global State (_G.content, _G.column)
    ↓ Plugin Initialize
Lua Plugin Context (ctx.spacing_top, ctx.spacing_bottom, etc.)
    ↓ Layout Phase
Grid Layout Engine (layout-grid.lua)
    ↓ Render Phase
PDF Output (render-page.lua)
```

### 3. 模块职责划分

| 模块 | 职责 | 新增功能 |
|------|------|----------|
| **core-column.sty** | 定义 `\行` 命令的参数键 | 添加 spacing-top/bottom, auto-width, width-scale |
| **core-column.lua** | 管理列样式栈 | 添加间距参数到样式栈 |
| **core-content.sty** | 定义 `\contentSetup` 全局配置 | 添加默认间距参数 |
| **core-content.lua** | 管理全局内容参数 | 存储和传递间距参数 |
| **layout-grid.lua** | 网格布局逻辑 | 在 wrap() 时应用列间距 |
| **util-style-registry.lua** | 样式栈管理 | 存储和继承间距参数 |
| **template configs (.cfg)** | 模板预设 | 预设不同模板的间距风格 |

## 详细设计

### 1. TeX Layer API

#### A. `\行` 命令扩展

```latex
% core-column.sty
\keys_define:nn { luatexcn / column }
  {
    % 现有参数
    width .tl_set:N = \l__luatexcn_column_width_tl,
    align .choice:,
    font-size .tl_set:N = \l__luatexcn_column_local_size_tl,

    % 新增参数
    column-width .tl_set:N = \l__luatexcn_column_width_tl,  % 别名
    auto-width .bool_set:N = \l__luatexcn_column_auto_width_bool,
    auto-width .initial:n = true,
    width-scale .tl_set:N = \l__luatexcn_column_width_scale_tl,
    width-scale .initial:n = {1.2},

    spacing-top .tl_set:N = \l__luatexcn_column_spacing_top_tl,
    spacing-top .initial:n = {},
    spacing-bottom .tl_set:N = \l__luatexcn_column_spacing_bottom_tl,
    spacing-bottom .initial:n = {},
    spacing .meta:n = { spacing-top = #1, spacing-bottom = #1 },
  }
```

#### B. `\contentSetup` 扩展

```latex
% core-content.sty
\keys_define:nn { luatexcn / content }
  {
    % 现有参数
    font-size .tl_set:N = \l__luatexcn_content_font_size_tl,
    grid-width .tl_set:N = \l__luatexcn_content_grid_width_tl,
    grid-height .tl_set:N = \l__luatexcn_content_grid_height_tl,

    % 新增参数
    auto-column-width .bool_set:N = \l__luatexcn_content_auto_col_width_bool,
    auto-column-width .initial:n = false,  % Grid 模式默认关闭

    column-spacing-top .tl_set:N = \l__luatexcn_content_col_spacing_top_tl,
    column-spacing-top .initial:n = {0pt},
    column-spacing-bottom .tl_set:N = \l__luatexcn_content_col_spacing_bottom_tl,
    column-spacing-bottom .initial:n = {0pt},
    column-spacing .meta:n = {
      column-spacing-top = #1,
      column-spacing-bottom = #1
    },

    paragraph-spacing .tl_set:N = \l__luatexcn_content_para_spacing_tl,
    paragraph-spacing .initial:n = {0pt},
  }
```

### 2. Lua Layer 实现

#### A. Style Registry 扩展

```lua
-- util-style-registry.lua

-- 样式栈条目结构
local style_entry = {
    -- 现有字段
    font_color = nil,
    font_size = nil,
    font = nil,
    indent = nil,
    first_indent = nil,

    -- 新增字段
    spacing_top = nil,      -- 列上间距 (sp)
    spacing_bottom = nil,   -- 列下间距 (sp)
    column_width = nil,     -- 列宽度 (sp)
    auto_width = nil,       -- 是否自动宽度 (boolean)
    width_scale = nil,      -- 宽度缩放因子 (number)
}

-- 获取当前样式的间距
function style_registry.get_spacing_top(style_id)
    -- 从当前样式或继承链中获取 spacing_top
end

function style_registry.get_spacing_bottom(style_id)
    -- 从当前样式或继承链中获取 spacing_bottom
end

function style_registry.get_column_width(style_id, font_size_sp)
    local style = get_style(style_id)
    if style.column_width and style.column_width > 0 then
        return style.column_width
    end

    -- 自动宽度计算
    if style.auto_width and font_size_sp then
        local scale = style.width_scale or 1.0
        return font_size_sp * scale
    end

    return nil  -- 使用默认 grid_width
end
```

#### B. Column Module 扩展

```lua
-- core-column.lua

--- Push column style with spacing parameters
-- @param font_color (string|nil)
-- @param font_size (string|nil)
-- @param font (string|nil)
-- @param grid_height (string|nil)
-- @param spacing_top (string|nil)     -- NEW
-- @param spacing_bottom (string|nil)  -- NEW
-- @param column_width (string|nil)    -- NEW
-- @param auto_width (boolean|nil)     -- NEW
-- @param width_scale (number|nil)     -- NEW
-- @return (number) Style ID
function column.push_style(font_color, font_size, font, grid_height,
                          spacing_top, spacing_bottom, column_width,
                          auto_width, width_scale)
    local extra = {}
    if grid_height and grid_height ~= "" then
        extra.grid_height = constants.to_dimen(grid_height)
    end
    if spacing_top and spacing_top ~= "" then
        extra.spacing_top = constants.to_dimen(spacing_top)
    end
    if spacing_bottom and spacing_bottom ~= "" then
        extra.spacing_bottom = constants.to_dimen(spacing_bottom)
    end
    if column_width and column_width ~= "" then
        extra.column_width = constants.to_dimen(column_width)
    end
    if auto_width ~= nil then
        extra.auto_width = auto_width
    end
    if width_scale and width_scale ~= "" then
        extra.width_scale = tonumber(width_scale)
    end

    return style_registry.push_content_style(font_color, font_size, font, extra)
end
```

#### C. Layout Grid 扩展

```lua
-- layout-grid.lua

--- Apply column spacing when wrapping to next column
-- @param ctx (table) Grid context
-- @param params (table) Layout parameters
-- @param style_id (number) Current style ID
local function apply_column_spacing(ctx, params, style_id)
    -- Skip spacing in grid mode
    if params.use_grid_layout then
        return 0
    end

    -- Get spacing from style stack
    local spacing_bottom = style_registry.get_spacing_bottom(style_id) or 0
    local spacing_top = style_registry.get_spacing_top(style_id) or 0

    -- Total spacing = previous column's bottom + next column's top
    local total_spacing_sp = spacing_bottom + spacing_top
    local spacing_cols = math.ceil(total_spacing_sp / params.grid_width)

    return spacing_cols
end

--- Wrap to next column (enhanced with spacing)
function grid.wrap(ctx, params, callbacks, reset_indent, reset_content)
    -- ... existing wrap logic ...

    -- Apply column spacing
    local style_id = get_current_style_id()
    local spacing_cols = apply_column_spacing(ctx, params, style_id)

    ctx.cur_col = ctx.cur_col + 1 + spacing_cols

    -- ... rest of wrap logic ...
end
```

#### D. Paragraph Spacing

段落间距在以下情况触发：
1. `\par` 命令
2. `\end{段落}` 环境结束
3. 连续空行（LaTeX 自动转为 `\par`）

```lua
-- core-paragraph.lua

--- Insert paragraph spacing after \par
-- @param ctx (table) Layout context
-- @param params (table) Layout parameters
-- @param is_explicit_par (boolean) 是否显式 \par（而非自动段落结束）
local function insert_paragraph_spacing(ctx, params, is_explicit_par)
    if params.use_grid_layout then
        return  -- No paragraph spacing in grid mode
    end

    local para_spacing_sp = params.paragraph_spacing or 0
    if para_spacing_sp <= 0 then
        return
    end

    -- 段落间距应用于：
    -- 1. \par 或连续空行
    -- 2. \end{段落} 环境
    if not is_explicit_par then
        return  -- 仅在明确的段落结束时应用
    end

    -- Convert to columns (向左移动，即减少 cur_col 或增加间距)
    local spacing_cols = math.ceil(para_spacing_sp / params.grid_width)

    -- Skip columns (向左 = cur_col 减小，但实际实现中是增加间距)
    ctx.cur_col = ctx.cur_col + spacing_cols
end
```

### 3. 自动列宽计算

#### 计算公式

```lua
function calculate_auto_column_width(font_size_sp, width_scale, grid_width_sp)
    if not font_size_sp or font_size_sp <= 0 then
        return grid_width_sp  -- Fallback to default
    end

    local scale = width_scale or 1.2  -- 默认 1.2，留 20% 余量避免重叠
    local auto_width = font_size_sp * scale

    -- Ensure at least grid_width (minimum spacing)
    return math.max(auto_width, grid_width_sp)
end
```

#### 应用时机

1. **`\行[font-size=48pt]`** - 字号指定时，auto-width=true 则计算列宽
2. **`\行[width=100pt]`** - 显式宽度覆盖自动计算
3. **`\行[font-size=48pt, width-scale=1.2]`** - 字号 × 缩放因子

### 4. Grid Mode vs Free Mode

| 模式 | 使用场景 | 列宽 | 间距 | 段间距 |
|------|----------|------|------|--------|
| **Grid Layout** | 古籍、网格对齐 | 固定 `grid-width` | 无 | 无 |
| **Free Layout** | 现代书籍、灵活排版 | 自动或指定 | 支持 | 支持 |

#### 模式检测

```lua
function is_grid_mode(params)
    -- 如果设置了 n-column > 0 或 page-columns > 0，则为 Grid Mode
    return (params.n_column and params.n_column > 0) or
           (params.page_columns and params.page_columns > 0)
end
```

## 模板示例

### 古籍模板（Grid Mode）

```latex
% luatex-cn-guji-default.cfg
\contentSetup{
    font-size = 12pt,
    grid-width = 12pt,
    grid-height = 12pt,
    n-column = 10,           % 启用网格模式
    auto-column-width = false,  % 禁用自动列宽
    column-spacing = 0pt,    % 无列间距
    paragraph-spacing = 0pt, % 无段间距
}
```

### 现代书籍模板（Free Mode）

```latex
% luatex-cn-book-modern.cfg
\contentSetup{
    font-size = 15pt,
    n-column = 0,            % 禁用网格模式
    auto-column-width = true,   % 启用自动列宽
    column-spacing-top = 2pt,   % 列上间距
    column-spacing-bottom = 3pt, % 列下间距
    paragraph-spacing = 8pt,    % 段间距
}
```

### 中华书局模板（混合模式）

```latex
% luatex-cn-book-zhonghuashuju.cfg
\contentSetup{
    font-size = 15pt,
    grid-width = 20pt,       % 基准宽度
    n-column = 0,            % 灵活模式
    auto-column-width = true,
    column-spacing = 2pt,
    paragraph-spacing = 6pt,
}

% 标题命令（大字号，自动增大列宽）
\newcommand{\卷名}[1]{%
  \文本框[font-size=48pt, width-scale=1.1, spacing=5pt]{#1}%
}
```

## 实现计划

### Phase 1: 基础架构（核心功能）

1. ✅ 扩展 `\keys_define` 添加新参数
2. ✅ 扩展 style-registry 存储间距参数
3. ✅ 修改 column.push_style 传递间距
4. ✅ 实现自动列宽计算逻辑

### Phase 2: 布局引擎集成

1. ✅ 修改 layout-grid.lua 的 wrap() 应用列间距
2. ✅ 添加 Grid/Free 模式检测
3. ✅ 实现段落间距插入逻辑

### Phase 3: 模板配置

1. ✅ 更新现有模板配置文件
2. ✅ 添加示例文档展示不同间距效果
3. ✅ 编写文档说明参数用法

### Phase 4: 测试与优化

1. ✅ 回归测试确保向后兼容
2. ✅ 性能测试（间距计算开销）
3. ✅ 边界情况测试（负值、极大值等）

## 向后兼容性

### 兼容策略

1. **默认值保持不变** - 所有新参数默认值为 0pt 或 false
2. **Grid Mode 自动禁用** - 检测到 n-column > 0 时，自动禁用间距
3. **width 别名** - 保留 `width` 作为 `column-width` 的别名

### 迁移指南

```latex
% 旧代码（仍然有效）
\行[width=100pt]{内容}

% 新代码（推荐）
\行[column-width=100pt]{内容}
\行[font-size=48pt, auto-width=true]{内容}  % 自动计算列宽
```

## 总结

这个设计提供了：

✅ **灵活的列宽控制** - 支持固定、自动、缩放三种模式
✅ **精细的间距控制** - 上间距、下间距、段间距独立设置
✅ **模板级预设** - 不同模板可预设不同风格
✅ **Grid/Free 双模式** - 古籍用网格，现代书籍用灵活模式
✅ **向后兼容** - 现有代码无需修改
✅ **清晰的参数传导** - TeX → Lua → Layout → Render 路径明确

下一步可以开始实现 Phase 1 的基础架构。
