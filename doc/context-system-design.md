# 排版上下文管理系统 - 架构设计与实施规划

## 文档信息

- **创建日期**：2026-01-31
- **状态**：设计阶段
- **当前版本**：v0.1 (阶段 1 待实现)

---

## 一、问题背景

### 1.1 问题起源

在修复 issue #44 (侧批跨页颜色) 和夹注跨页颜色问题时，发现了一个更深层次的架构问题：

**不仅仅是跨页颜色问题，而是更广泛的排版上下文继承与恢复问题。**

### 1.2 需要保持的属性

| 类别 | 属性示例 | 典型场景 |
|------|----------|----------|
| 字体 | family, size, features | 正文 → 夹注 → 正文 |
| 颜色 | text_color, bg_color | 正文 → 侧批 → 跨页 |
| 布局 | indent, align, spacing | 段落 → 文本框 → 段落 |
| 网格 | grid_height | 大字 → 小字 → 大字 |
| 装饰 | judou_on, style | 有句读 → 无句读 |

### 1.3 问题场景

1. **跨页**：页 1 有色文本 → 页 2 应保持颜色
2. **跨结构**：正文 → 文本框 → 正文（字体/颜色应恢复）
3. **嵌套**：段落[indent=2] → 夹注[color=red, size=small] → 继续段落
4. **部分覆盖**：子环境只改 5 个参数，其余 5 个应继承父环境

### 1.4 现有方案的局限

| 组件 | 当前方案 | 问题 |
|------|----------|------|
| 侧批 | metadata 传递 | 只适用于独立渲染的组件 |
| 夹注 | `_G.jiazhu.current_color` | 不支持嵌套，无法部分覆盖 |
| 通用 | 无统一机制 | 每个组件重复实现 |

---

## 二、核心概念

### 2.1 排版上下文 (Typesetting Context)

上下文是一组排版参数的集合，定义了某个环境下的完整排版状态。

```lua
local Context = {
    -- 字体相关
    font_family = "TW-Kai",
    font_size = 20 * 65536,      -- sp
    font_features = "+vert,+vrt2",

    -- 颜色相关
    text_color = "0 0 0",        -- RGB
    bg_color = nil,

    -- 布局相关
    indent = 0,
    first_indent = -1,
    align = "justified",

    -- 网格相关
    grid_height = nil,           -- nil = use global

    -- 装饰相关
    judou_enabled = true,

    -- 元数据
    context_type = "main",       -- main/paragraph/jiazhu/textbox
    parent_id = nil,             -- 继承链
}
```

### 2.2 上下文栈

使用**栈**而非链表的原因：

1. **自然对应 TeX 的 group 嵌套**
   - `\begin{A} ... \begin{B} ... \end{B} ... \end{A}`
   - 进入环境 = 压栈，退出环境 = 弹栈

2. **LIFO 保证正确顺序**
   - 最近进入的环境最先退出
   - 当前上下文总在栈顶，访问 O(1)

3. **支持部分覆盖 + 继承**
   - 子环境继承父环境的所有参数
   - 只覆盖显式指定的参数
   - 其余参数自动继承

### 2.3 上下文继承示例

```
[全局上下文: 黑色, 20pt, indent=0]
  ↓ 进入段落
[段落上下文: 继承颜色和字体, indent=2]
    ↓ 进入夹注
  [夹注上下文: 继承 indent=2, 覆盖 color=red, size=14pt]
    ↓ 退出夹注
[段落上下文: 恢复到 黑色, 20pt, indent=2]  ← 自动恢复
  ↓ 退出段落
[全局上下文: 恢复]
```

---

## 三、分阶段实施方案

### 阶段 1：颜色注册表（MVP - 最小可用版本）

**目标**：解决当前的跨页颜色问题

**实现范围**：
- 仅处理 `color` 属性
- 使用简单注册表：`id -> color_string`
- 通过 `ATTR_COLOR_REG_ID` 属性传递

**预计代码量**：~200 行
**预计时间**：1-2 小时
**状态**：**待实现**

#### 3.1.1 新增文件

```
tex/util/luatex-cn-color-registry.lua  （颜色注册表模块）
```

#### 3.1.2 修改文件

```
tex/core/luatex-cn-constants.lua       （添加 ATTR_COLOR_REG_ID）
tex/core/luatex-cn-layout-grid.lua     （Layout 层保存颜色）
tex/core/luatex-cn-core-render-page.lua（Render 层应用颜色）
tex/util/luatex-cn-utils.lua           （工具函数）
```

#### 3.1.3 核心逻辑

**颜色注册表**：
```lua
-- tex/util/luatex-cn-color-registry.lua
_G.color_registry = {
    next_id = 1,
    colors = {}  -- id -> color_string
}

function register_color(color_str)
    local id = _G.color_registry.next_id
    _G.color_registry.colors[id] = color_str
    _G.color_registry.next_id = id + 1
    return id
end

function get_color(id)
    return _G.color_registry.colors[id]
end
```

**Layout 层自动保存**：
```lua
-- layout-grid.lua
local color_id = D.get_attribute(t, constants.ATTR_COLOR_REG_ID)
local color = nil
if color_id then
    local color_registry = require('util.luatex-cn-color-registry')
    color = color_registry.get(color_id)
end

layout_map[t] = {
    page = ctx.cur_page,
    col = ctx.cur_col,
    row = ctx.cur_row,
    color = color  -- 自动添加颜色
}
```

**Render 层自动应用**：
```lua
-- render-page.lua (handle_glyph_node)
local color = pos.color
if color and color ~= "" then
    local rgb_str = utils.normalize_rgb(color)
    local color_cmd = utils.create_color_literal(rgb_str, false)
    local push = utils.create_pdf_literal("q " .. color_cmd)
    local pop = utils.create_pdf_literal("Q")

    p_head = D.insert_before(p_head, curr, push)
    D.insert_after(p_head, k, pop)
end
```

#### 3.1.4 成功标准

- [ ] 夹注跨页颜色正确
- [ ] 侧批跨页颜色正确（可选，或保持现有实现）
- [ ] 回归测试通过
- [ ] 代码简洁，无冗余

---

### 阶段 2：扩展属性注册表

**目标**：支持颜色 + 字体大小 + 网格高度

**实现范围**：
- 注册表存储多个属性：`id -> {color, font_size, grid_height}`
- 仍使用单一属性 `ATTR_STYLE_REG_ID`
- 向后兼容阶段 1

**预计代码量**：+100 行
**预计时间**：1-2 小时
**状态**：**未开始**

#### 3.2.1 核心变化

```lua
-- 从单值注册表
_G.color_registry.colors[id] = "1 0 0"

-- 扩展为多值注册表
_G.style_registry.styles[id] = {
    color = "1 0 0",
    font_size = 14 * 65536,
    grid_height = 20 * 65536,
}
```

#### 3.2.2 迁移路径

- 重命名：`color_registry` → `style_registry`
- 兼容层：`get_color(id)` → `get_style(id).color`
- 旧代码无需修改

---

### 阶段 3：完整上下文栈系统

**目标**：支持嵌套、继承、跨结构

**实现范围**：
- 完整的上下文栈 (push/pop/inherit)
- 与 TeX group 对应
- 支持任意层级嵌套
- 部分覆盖 + 自动继承

**预计代码量**：+300 行
**预计时间**：4-6 小时
**状态**：**未开始**

#### 3.3.1 核心 API

```lua
-- core/luatex-cn-context-manager.lua

-- 进入新上下文（自动继承父环境）
local ctx_id = context.enter("jiazhu", {
    text_color = "1 0 0",
    font_size = 14 * 65536
})

-- 退出上下文（自动恢复父环境）
context.exit()

-- 获取当前上下文
local ctx = context.current()

-- 继承逻辑（内部使用）
local child_ctx = context.inherit(parent_ctx, overrides)
```

#### 3.3.2 TeX 层接口

```latex
% 高层宏（自动管理上下文）
\begin{夹注}[font-color=red, font-size=14pt]
内容
\end{夹注}

% 低层接口（手动管理）
\__luatexcn_context_push:n { color=red, size=14pt }
内容
\__luatexcn_context_pop:
```

---

## 四、架构原则

### 4.1 设计原则

1. **渐进式**：每个阶段都是可用的，不依赖后续阶段
2. **分层清晰**：TeX 层、Layout 层、Render 层职责明确
3. **自动化**：Layout/Render 自动处理，插件无需感知
4. **可扩展**：易于添加新属性，不破坏现有代码
5. **高性能**：属性访问 O(1)，注册表查询 O(1)

### 4.2 向后兼容

- 阶段 1 → 2：只扩展注册表，不影响现有代码
- 阶段 2 → 3：可选升级，旧代码仍可工作
- 现有插件：可逐步迁移，无需一次性修改

### 4.3 错误处理

- 无效 ID：返回 nil，使用默认值
- 栈下溢：保持全局上下文
- 属性冲突：后设置的覆盖先设置的

---

## 五、与现有系统的集成

### 5.1 夹注 (Jiazhu)

**迁移前**：
```lua
-- TeX 层存储
_G.jiazhu.current_color = color

-- Layout 层手动保存
layout_map[node].jiazhu_color = _G.jiazhu.current_color

-- Render 层手动应用
if pos.jiazhu_color then apply_color(...) end
```

**迁移后（阶段 1）**：
```lua
-- TeX 层设置属性
D.set_attribute(node, ATTR_COLOR_REG_ID, color_id)

-- Layout 层自动保存（无需修改）
-- Render 层自动应用（无需修改）
```

### 5.2 侧批 (Sidenote)

**选项 1**：保持现有实现（metadata 传递）
**选项 2**：迁移到通用机制

推荐保持现有实现，因为侧批有独立的渲染函数。

### 5.3 其他组件

- 批注 (Pizhu)：待确认是否有跨页问题
- 装饰 (Decorate)：单字符，无跨页问题
- 文本框 (Textbox)：整体渲染，无跨页问题

---

## 六、测试计划

### 6.1 阶段 1 测试

#### 单元测试
- [ ] 颜色注册表：注册、查询、去重
- [ ] 属性设置：正确的 ID 关联
- [ ] Layout 保存：layout_map 中包含颜色
- [ ] Render 应用：PDF 输出包含 q/rg/Q

#### 集成测试
- [ ] 夹注跨页：红色夹注从页 1 到页 2 保持红色
- [ ] 多颜色：同一页面多个不同颜色的夹注
- [ ] 嵌套（如适用）：段落中的彩色夹注

#### 回归测试
- [ ] 所有现有测试通过
- [ ] 侧批测试不受影响
- [ ] 性能无明显下降

### 6.2 阶段 2 & 3 测试

待阶段 1 完成后补充。

---

## 七、风险与缓解

### 7.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 属性 ID 冲突 | 严重 | 使用 `luatexbase.new_attribute` |
| 注册表膨胀 | 中等 | 定期清理，文档结束时重置 |
| 性能下降 | 低 | 基准测试，优化查询逻辑 |

### 7.2 兼容性风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 破坏现有代码 | 严重 | 充分测试，渐进式迁移 |
| TeX 引擎差异 | 低 | 仅使用标准 LuaTeX API |

---

## 八、时间规划

| 阶段 | 预计时间 | 里程碑 |
|------|----------|--------|
| 阶段 1 设计 | ✅ 已完成 | 设计文档 |
| 阶段 1 实现 | 1-2 小时 | 颜色注册表可用 |
| 阶段 1 测试 | 0.5 小时 | 回归测试通过 |
| 阶段 2 实现 | 1-2 小时 | 多属性支持 |
| 阶段 3 实现 | 4-6 小时 | 完整上下文栈 |

---

## 九、参考资料

### 9.1 相关 Issue

- [#44](https://github.com/open-guji/luatex-cn/issues/44) - 侧批跨页颜色问题
- [#38](https://github.com/open-guji/luatex-cn/issues/38) - 侧批渲染顺序问题

### 9.2 相关文档

- `ai_must_read/LEARNING.md` - 第 4.5 节：跨页颜色保持
- `.claude/commands/fix-github-issue.md` - Issue 修复流程

### 9.3 相关代码

- `tex/core/luatex-cn-core-sidenote.lua` - 侧批实现（metadata 方案）
- `tex/core/luatex-cn-core-textflow.lua` - 夹注实现（全局变量方案）
- `tex/core/luatex-cn-layout-grid.lua` - Layout 阶段
- `tex/core/luatex-cn-core-render-page.lua` - Render 阶段

---

## 十、下一步行动

### 立即执行（阶段 1）

1. ✅ 保存设计文档到 `doc/context-system-design.md`
2. ⏳ 创建 `tex/util/luatex-cn-color-registry.lua`
3. ⏳ 添加 `ATTR_COLOR_REG_ID` 到 constants
4. ⏳ 修改 layout-grid.lua（自动保存颜色）
5. ⏳ 修改 render-page.lua（自动应用颜色）
6. ⏳ 迁移夹注实现
7. ⏳ 测试并更新基线
8. ⏳ 提交代码

### 后续规划

- 阶段 2：等阶段 1 稳定后 1-2 周内启动
- 阶段 3：等阶段 2 验证后再决定是否实现

---

## 附录 A：术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| 上下文 | Context | 一组排版参数的集合 |
| 上下文栈 | Context Stack | 管理嵌套上下文的数据结构 |
| 注册表 | Registry | ID → 数据的映射表 |
| 属性 | Attribute | LuaTeX 节点的附加属性 |
| 继承 | Inheritance | 子上下文从父上下文复制参数 |
| 覆盖 | Override | 子上下文修改继承的参数 |

---

**文档维护**：每个阶段完成后更新此文档的状态和测试结果。
