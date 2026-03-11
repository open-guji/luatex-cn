# layout_map 设计文档 (v2)

本文档定义 `luatex-cn` 的核心数据结构 `layout_map` 及其坐标系统。

> **状态**：本文档是目标设计（v2），当前代码仍为 v1。迁移按"现状 → 目标"分步进行。

---

## 一、核心概念

### 1.1 Component（组件）

所有在 `layout_map` 中注册的节点都是一个 **Component**。

Component 是排版完成后的最小定位单元：一个字形、一个文本框、一个侧批字符……
Component 之间可以有**包含关系**（父子嵌套）。

#### Component 的两种定位模式

| 模式 | 含义 | 占位行为 | 典型元素 |
|------|------|----------|---------|
| **block** | 占位式 | 占据网格空间，不与其他 block 重叠 | 正文字形、内联 TextBox、夹注字符 |
| **floating** | 漂浮式 | 可覆盖其他 component，不影响主布局流 | 浮动 TextBox（眉批、批注）、侧批 |

### 1.2 坐标系统

**坐标原点**：页面右上角 `(0, 0)`

```
页面右上角 = (0, 0)
  │
  │  x 正方向 → 从右向左
  │  y 正方向 → 从上向下
  │
  ├── col 0（最右列 = 第一列）
  ├── col 1
  ├── col 2  ...
  └── col N（最左列）
```

| 轴 | 正方向 | 说明 |
|----|--------|------|
| **x** | 从右向左 → | 与古籍阅读方向一致 |
| **y** | 从上向下 ↓ | y=0 是页顶，y 增大即向下 |

#### 绝对坐标与相对坐标

| 字段 | 含义 | 参考原点 |
|------|------|---------|
| `x`, `y` | **绝对坐标** | 页面右上角 |
| `rel_x`, `rel_y` | **相对坐标** | 父 component 的右上角 |

---

## 二、layout_map 结构

### 2.1 总览

`layout_map` 是一个 Lua table：**键**是节点指针（direct node），**值**是 component 信息表。

```lua
layout_map[node_ptr] = {
    -- ═══ 定位模式 ═══
    mode,                -- "block" | "floating"

    -- ═══ 核心坐标（所有 component 必有）═══
    page,                -- 页码 (0-indexed)
    x,                   -- 绝对 X 坐标 (sp)，页面右上角为原点
    y,                   -- 绝对 Y 坐标 (sp)，页面右上角为原点
    width,               -- 宽度 (sp)
    height,              -- 高度 (sp)

    -- ═══ 相对坐标（有父 component 时）═══
    rel_x,               -- 相对于父 component 的 X (sp)
    rel_y,               -- 相对于父 component 的 Y (sp)
    parent,              -- 父 component 的 node_ptr（可选）

    -- ═══ 网格坐标（仅网格模式下的 block）═══
    col,                 -- 逻辑列号 (0-indexed，0=最右列)
    band,                -- 栏编号 (0-indexed，0=无分栏)
    band_y_offset_sp,    -- 栏 Y 偏移 (sp)
    cell_height,         -- 单元格高度 (sp)
    cell_width,          -- 单元格宽度 (sp)

    -- ═══ 渲染修饰（布局引擎计算的结果）═══
    v_scale,             -- 垂直缩放因子（分布式布局）

    -- ═══ 模块特有字段 ═══
    sub_col,             -- 夹注子列号（0=正文, 1=右小列, 2=左小列）
    line_mark_id,        -- 专名号/书名号标记 ID
    is_sidenote,         -- 侧批标记
    sidenote_offset,     -- 侧批 X 偏移 (sp)
}
```

### 2.2 设计原则

#### layout_map 只存"排好的结果"

| 存入 layout_map | **不**存入 layout_map，留在 style_registry |
|-----------------|------------------------------------------|
| 节点在页面上的确切位置 | 字体颜色 (`font_color`) |
| 节点的确切尺寸 | 字体大小 (`font_size`)、字体 ID (`font`) |
| 缩放因子 (`v_scale`) | 偏移微调 (`xshift`, `yshift`) |
| 模块标记 (`sub_col`, `line_mark_id`) | 文本流对齐 (`textflow_align`) |
|                 | 缩进 (`indent`, `first_indent`) |
|                 | 边框、背景、调试标志等所有样式属性 |

**理由**：`font_color`、`xshift` 等属性描述的是"怎么画"，不是"在哪里"。渲染阶段可以通过节点的 `ATTR_STYLE_REG_ID` 属性直接从 `style_registry` 读取，不需要在 layout_map 中冗余存储。

---

## 三、字段详解

### 3.1 定位模式

#### `mode` — 定位模式

| 属性 | 值 |
|------|-----|
| 类型 | `string` |
| 可选值 | `"block"`, `"floating"` |
| 默认值 | `"block"` |

| 模式 | 布局参与 | 占用网格 | 可重叠 |
|------|---------|---------|--------|
| `block` | 参与主布局流 | 是 | 否 |
| `floating` | 不参与主布局流 | 否 | 是 |

---

### 3.2 核心坐标（所有 component 必有）

#### `page` — 页码

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 范围 | `0` ~ `total_pages - 1` |
| 索引 | **0-indexed** |

#### `x` — 绝对 X 坐标

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp (scaled points，1pt = 65536sp) |
| 原点 | 页面右上角 |
| 方向 | 从右向左为正 |

component 右上角在页面中的水平位置。

#### `y` — 绝对 Y 坐标

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp |
| 原点 | 页面右上角 |
| 方向 | 从上向下为正 |

component 右上角在页面中的垂直位置。

> **注意**：`y` 可以为负数。使用"抬头"（`\缩进[-1]`）时，节点在边框上方。

#### `width` — 宽度

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp |

component 的水平跨度。对于单个字形，等于 `cell_width` 或列宽。

#### `height` — 高度

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp |

component 的垂直跨度。对于单个字形，等于 `cell_height`。

---

### 3.3 相对坐标（有父 component 时）

#### `rel_x`, `rel_y` — 相对坐标

相对于父 component 右上角的偏移。

```
父 component 右上角 (parent.x, parent.y)
  │
  ├─ rel_x (向左)
  │
  ↓ rel_y (向下)
  │
  ● 子 component 右上角
```

满足关系：
```lua
child.x = parent.x + child.rel_x
child.y = parent.y + child.rel_y
```

#### `parent` — 父节点指针

| 属性 | 值 |
|------|-----|
| 类型 | `node_ptr` 或 `nil` |

指向父 component 在 layout_map 中的键。顶层 component 的 `parent` 为 `nil`。

---

### 3.4 网格坐标（仅 block 模式下网格布局中的 component）

这些字段在网格布局中提供**离散化坐标**，与 `x`/`y` 是同一位置的不同表达。

#### `col` — 逻辑列号

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 范围 | `0` ~ `page_columns - 1` |
| 方向 | **col 0 = 最右列** |

古籍从右往左排列，col 0 是最右边的第一列，col 递增向左。
版心列也占一个 col 编号（如 `n_column=10` 时，col 10 是版心列）。

#### `band` — 栏编号

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 范围 | `0` ~ `n_bands - 1` |
| 默认 | `0`（无分栏） |

多栏（band，用于表格等）时指示 component 所在的栏。

#### `band_y_offset_sp` — 栏 Y 偏移

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp |
| 默认 | `0` |

该 band 在页面内的 Y 起始偏移。`band 0` 偏移为 0，`band 1` 偏移为 `band_0_height + band_gap`。

#### `cell_height` — 单元格高度

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp |

该 component 在网格中占用的垂直空间。

| 场景 | cell_height |
|------|-------------|
| Grid 模式正文 | `grid_height`（固定值） |
| Natural 模式正文 | 字形实际高度 |
| 标点（大陆模式） | `grid_height × 0.5` |
| 标点（台湾模式） | `grid_height`（全格） |
| 夹注字符 | `grid_height × jiazhu_scale` |

#### `cell_width` — 单元格宽度

| 属性 | 值 |
|------|-----|
| 类型 | `number` 或 `nil` |
| 单位 | sp |
| 默认 | `nil`（使用列宽 `grid_width`） |

仅在单元格宽度与列宽不同时设置（如夹注半列）。

---

### 3.5 渲染修饰

#### `v_scale` — 垂直缩放因子

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 范围 | `0.0` ~ `1.0+` |
| 默认 | `1.0` |
| 触发 | 分布式布局且内容超过列高 |

```lua
v_scale = available_height / total_char_height
```

---

### 3.6 模块特有字段

这些字段由特定模块在布局阶段写入。

#### `sub_col` — 夹注子列号

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 值域 | `0` = 正文，`1` = 右小列，`2` = 左小列 |
| 默认 | `0` |
| 来源 | TextFlow 模块 |

#### `line_mark_id` — 专名号/书名号标记

| 属性 | 值 |
|------|-----|
| 类型 | `number` 或 `nil` |
| 来源 | 节点的 `ATTR_LINE_MARK_ID` 属性 |

同一 `line_mark_id` 的连续字符会被绘制一条连续下划线。

#### `is_sidenote` — 侧批标记

| 属性 | 值 |
|------|-----|
| 类型 | `boolean` |
| 默认 | `nil` |

标识该 component 是侧批内容。

#### `sidenote_offset` — 侧批 X 偏移

| 属性 | 值 |
|------|-----|
| 类型 | `number` |
| 单位 | sp |

侧批字符相对于锚点列边界的水平偏移。

---

## 四、Component 类型一览

### 4.1 block 类型

| 元素 | 来源模块 | 特有字段 | 说明 |
|------|---------|---------|------|
| 正文字形 | layout-grid | `col`, `cell_height` | 最基本的 component |
| 夹注字形 | textflow | `col`, `sub_col`, `cell_height` | 在列的左/右半列 |
| 内联 TextBox | textbox | `col`, `width`(列数), `height`(行数) | 占用多个网格单元 |
| 修饰符节点 | layout-grid | `col` | 句读/着重号标记 |
| WHATSIT 节点 | layout-grid | `col` | 锚点（sidenote/banxin） |

### 4.2 floating 类型

| 元素 | 来源模块 | 特有字段 | 说明 |
|------|---------|---------|------|
| 浮动 TextBox | textbox | `x`, `y` 为用户绝对坐标 | 眉批、批注等 |
| 侧批字形 | sidenote | `is_sidenote`, `sidenote_offset` | 放在列间隙 |

---

## 五、style_registry 与 layout_map 的职责划分

```
style_registry（样式栈）             layout_map（排版结果）
──────────────────────              ──────────────────────
描述"怎么画"                        描述"在哪里"
  │                                   │
  ├─ font_color                       ├─ page, x, y
  ├─ font_size, font                  ├─ width, height
  ├─ xshift, yshift                   ├─ col, band, cell_height
  ├─ textflow_align                   ├─ v_scale
  ├─ indent, first_indent             ├─ sub_col
  ├─ border, background               ├─ line_mark_id
  ├─ spacing, padding                 ├─ is_sidenote
  ├─ debug                            └─ mode (block/floating)
  └─ ...（共 32 个属性）
```

**在渲染阶段获取样式的方式**：

```lua
-- 读取位置 → 从 layout_map
local pos = layout_map[node]
local x, y = pos.x, pos.y

-- 读取样式 → 从 style_registry（通过节点属性）
local style_id = D.get_attribute(node, ATTR_STYLE_REG_ID)
local font_color = style_registry.get_font_color(style_id)
```

---

## 六、坐标转换

### 6.1 网格坐标 → 绝对坐标 (x, y)

布局引擎在写入 layout_map 时完成此转换。

**X 坐标**（从 `col` 计算）：

```
RTL 物理列号:
  rtl_col = total_cols - 1 - col

等宽模式:
  x = rtl_col × grid_width + half_thickness + shift_x

变宽模式:
  x = Σ col_widths[0..rtl_col-1] + half_thickness + shift_x
```

**Y 坐标**（从 `y_sp` 和 `band_y_offset_sp` 计算）：

```
y = y_sp + band_y_offset_sp + shift_y
```

> 其中 `shift_x`, `shift_y` 是边框/外边距引入的全局偏移。

### 6.2 绝对坐标 → LuaTeX 内部坐标

渲染阶段将 `(x, y)` 转换为 LuaTeX 的 `xoffset`/`yoffset`（y 向上为正）。

```lua
xoffset = x 方向翻转后的值（LuaTeX x 向右为正）
yoffset = -y 方向翻转后的值（LuaTeX y 向上为正）
```

### 6.3 坐标系对照

| 坐标系 | 原点 | X 正方向 | Y 正方向 | 使用场景 |
|--------|------|----------|----------|---------|
| **layout_map** | 页面右上角 | 从右向左 | 从上向下 | 排版结果 |
| **LuaTeX 内部** | 节点参考点 | 从左向右 | 从下向上 | glyph 定位 |
| **PDF 坐标** | 页面左下角 | 从左向右 | 从下向上 | 绘图指令 |

---

## 七、数据流全景图

```
                    ┌─────────────────────────────────────┐
                    │  Stage 1: Flatten (展平节点)          │
                    │  TeX 嵌套盒子 → 一维线性节点流        │
                    └──────────────┬──────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────────┐
                    │  Stage 2: Layout (虚拟布局)           │
                    │                                      │
                    │  ┌── 主布局引擎 ──────────────────┐   │
                    │  │ glyph → col_buffer → flush →   │   │
                    │  │   layout_map[node] = {         │   │
                    │  │     mode="block",              │   │
                    │  │     page, x, y, width, height, │   │
                    │  │     col, band, cell_height,    │   │
                    │  │     v_scale, sub_col, ...      │   │
                    │  │   }                            │   │
                    │  └────────────────────────────────┘   │
                    │                                      │
                    │  ┌── 浮动框插件 ──────────────────┐   │
                    │  │ floating_map → 合并写入：       │   │
                    │  │   layout_map[anchor] = {       │   │
                    │  │     mode="floating",           │   │
                    │  │     page, x, y, width, height  │   │
                    │  │   }                            │   │
                    │  └────────────────────────────────┘   │
                    │                                      │
                    │  ┌── 侧批插件 ────────────────────┐   │
                    │  │ placed_nodes → 合并写入：       │   │
                    │  │   layout_map[sn_node] = {      │   │
                    │  │     mode="floating",           │   │
                    │  │     is_sidenote=true,          │   │
                    │  │     page, x, y, width, height  │   │
                    │  │   }                            │   │
                    │  └────────────────────────────────┘   │
                    │                                      │
                    │  输出：统一的 layout_map               │
                    └──────────────┬──────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────────┐
                    │  Stage 3: Render (渲染)               │
                    │                                      │
                    │  对每个 component:                     │
                    │    位置 ← layout_map[node]            │
                    │    样式 ← style_registry[style_id]    │
                    │                                      │
                    │  block:                               │
                    │    group_nodes_by_page → 按页处理      │
                    │    glyph → xoffset/yoffset            │
                    │    block → kern + shift               │
                    │                                      │
                    │  floating:                            │
                    │    独立定位，叠加到页面上               │
                    │                                      │
                    │  输出：PDF 页面                        │
                    └─────────────────────────────────────┘
```

---

## 八、v1 → v2 迁移计划

### 8.1 变更清单

| 变更 | 影响范围 | 优先级 |
|------|---------|--------|
| **移除** `font_color`, `font_size`, `font`, `xshift`, `yshift`, `textflow_align` 从 layout_map | `apply_style_attrs()`, `handle_glyph_node()`, export | P1 |
| **新增** `mode` 字段 (`"block"` / `"floating"`) | 所有写入点 | P1 |
| **新增** `x`, `y` 绝对坐标 (sp) | 所有写入点 + `calc_grid_position()` | P2 |
| **新增** `width`, `height` 统一为 sp | 替换现有的列数/行数 `width`/`height` | P2 |
| **合并** `floating_map` → `layout_map` | textbox 模块 | P3 |
| **合并** `placed_nodes` → `layout_map` | sidenote 模块 | P3 |
| **新增** `parent`, `rel_x`, `rel_y` | 嵌套 component 支持 | P4 |
| **重命名** `y_sp` → 计算后存入 `y` | 主布局引擎 | P2 |
| **移除** `is_block`，用 `mode` 替代 | render-page-process | P1 |

### 8.2 迁移策略

**阶段一（P1）— 清理 layout_map，最小改动**：
1. 将 `font_color` 等 6 个样式字段从 `apply_style_attrs()` 中移除
2. 渲染阶段改为从 `style_registry` 直接读取（通过 `ATTR_STYLE_REG_ID`）
3. 新增 `mode` 字段（默认 `"block"`，TextBox 等设为 `"floating"`）
4. 全量测试确认无回归

**阶段二（P2）— 统一坐标**：
1. 在布局阶段计算完 `col`/`y_sp` 后，同时计算并存入 `x`/`y`（绝对坐标）
2. `width`/`height` 统一为 sp 单位
3. 渲染阶段逐步从 `x`/`y` 读取，替换原有的 `col` + `calc_grid_position()` 计算

**阶段三（P3）— 合并子系统**：
1. `floating_map` 条目合并到 `layout_map`（`mode="floating"`）
2. `placed_nodes` 条目合并到 `layout_map`（`mode="floating"`, `is_sidenote=true`）
3. 废弃 `floating_map` 和 `placed_nodes` 独立结构

**阶段四（P4）— 父子关系**：
1. 引入 `parent`, `rel_x`, `rel_y`
2. 为 TextBox 内部节点建立父子关系

---

## 九、附录

### A. 单位换算

| 单位 | 换算 |
|------|------|
| 1 pt | 65536 sp |
| 1 cm | 1864679.81 sp (≈ 28.4527pt) |
| 1 in | 4736286.72 sp (= 72.27pt) |
| 1 em | 当前字号（如 10pt = 655360 sp） |

### B. 网格常量

| 名称 | 含义 | 典型值 |
|------|------|--------|
| `grid_height` | 网格行高 | 655360 sp (10pt) |
| `grid_width` | 网格列宽 | 655360 sp (10pt) |
| `line_limit` | 每列最大行数 | 20 |
| `page_columns` | 每页最大列数 | 21 (= 2 × 10 + 1) |
| `n_column` | 版心间隔 | 10 |

### C. 完整 map_entry 示例

```lua
-- block: 普通正文字形
layout_map[glyph_node] = {
    mode             = "block",
    page             = 0,
    x                = 327680,        -- 绝对 X (sp)
    y                = 1310720,       -- 绝对 Y (sp)
    width            = 655360,        -- 10pt
    height           = 655360,        -- 10pt
    col              = 3,
    band             = 0,
    band_y_offset_sp = 0,
    cell_height      = 655360,
    cell_width       = nil,
    v_scale          = 1.0,
}

-- block: 夹注右小列字形
layout_map[jiazhu_node] = {
    mode             = "block",
    page             = 0,
    x                = 1638400,
    y                = 655360,
    width            = 327680,        -- 半列宽
    height           = 327680,        -- 半格高
    col              = 5,
    band             = 0,
    band_y_offset_sp = 0,
    cell_height      = 327680,
    cell_width       = 327680,
    v_scale          = 0.5,
    sub_col          = 1,             -- 右小列
}

-- block: 内联 TextBox
layout_map[textbox_node] = {
    mode             = "block",
    page             = 1,
    x                = 0,
    y                = 0,
    width            = 1966080,       -- 3 列 × 655360
    height           = 3276800,       -- 5 行 × 655360
    col              = 0,
    band             = 0,
    band_y_offset_sp = 0,
    cell_height      = nil,
}

-- floating: 浮动 TextBox（眉批）
layout_map[meipi_anchor] = {
    mode             = "floating",
    page             = 0,
    x                = 2621440,       -- 用户指定: 4cm 从右
    y                = 1310720,       -- 用户指定: 2cm 从顶
    width            = 655360,        -- 框宽
    height           = 3932160,       -- 框高
}

-- floating: 侧批字形
layout_map[sidenote_glyph] = {
    mode             = "floating",
    page             = 0,
    x                = 720896,
    y                = 1966080,
    width            = 327680,
    height           = 655360,
    col              = 4,             -- 锚点列
    is_sidenote      = true,
    sidenote_offset  = 163840,
}
```
