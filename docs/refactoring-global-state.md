# 重构计划：消除 `_G` 全局状态隐式耦合

> 创建日期：2026-02-14
> 状态：Phase 1, 3, 4 已完成。Phase 2 已取消。

## 目录

1. [问题描述](#问题描述)
2. [全局状态清单](#全局状态清单)
3. [Phase 1: 已完成 — helpers 函数参数化](#phase-1-已完成--helpers-函数参数化)
4. [Phase 3: 已完成 — 插件上下文迁移](#phase-3-已完成--插件上下文迁移)
5. [Phase 4: 已完成 — generate_physical_pages 参数化](#phase-4-已完成--generate_physical_pages-参数化)
6. [残留 _G 读取说明](#残留-_g-读取说明)

---

## 问题描述

两个生产 bug 暴露了 `_G` 全局状态的脆弱性：

**Bug A (Column page_columns=1)**: `register_col_width()` 意外创建 `_G.content.col_widths`，污染 `calc_page_columns()` 优先级链。

**Bug B (Taiwan punctuation half-cell)**: `get_cell_height()` 直接读 `_G.punct.style` 绕过 plugin context。

两个 bug 的共同根因：**通过 `_G` 全局表的隐式耦合**。

---

## 全局状态清单

### 重构后状态

| 表 | 状态 | 说明 |
|----|------|------|
| `_G.core` | ✅ 保留 | 插件注册 + hooks 分发 |
| `_G.page` | ✅ 保留 | 文档页面尺寸单例 |
| `_G.content` | ✅ 保留 | 内容配置 + 计算布局；`col_widths_sp` 用于跨 typeset 传递 |
| `_G.vertical_pending_pages` | ✅ 保留 | typeset/load_page 间的页面缓存 |
| `_G.punct` | ⚠️ 模块内部 | setup() 写入，initialize() 读取（同模块内） |
| `_G.judou` | ⚠️ 模块内部 | setup() 写入，initialize() 读取；跨模块读取已迁移到 plugin context |
| `_G.banxin` | ✅ 保留 | 单字段，`init_engine_context()` 中一次性读入 engine_ctx |
| `_G.metadata` | ✅ 保留 | `init_engine_context()` 中一次性读入 layout_params |
| `_G.textbox` | ⚠️ 模块内部 | initialize() 已复制到 plugin context |
| `_G.footnote` | ⚠️ 模块内部 | initialize() 已复制到 plugin context |

---

## Phase 1: 已完成 — helpers 函数参数化

**Commits**: `a192829`, `614b587`

**改动总结**:
- layout-grid-helpers.lua: 所有 `_G` fallback 已移除，函数只接受显式参数
- layout-grid.lua: 所有 `_G.content` 读取替换为 `params.*` 直接访问
- core-main.lua: `layout_params` 统一为所有模式传递完整参数，defaults 在定义处设定

**原则**:
1. helpers 函数不读 `_G`，只用传入的参数
2. 默认值在参数定义处（core-main.lua layout_params）设定，不在调用处设定
3. 不保留 `_G` fallback

---

## Phase 3: 已完成 — 插件上下文迁移

**Commit**: `041f015`

**改动总结**:
- `judou.initialize()` 返回完整 context（pos/size/color/punct_mode）
- 调换 plugin 注册顺序：judou 先于 punct（punct 需要读 judou 的 plugin context）
- plugin 初始化循环传递 `plugin_contexts` 给每个 `initialize()`
- `punct.initialize()` 从 `plugin_contexts["judou"]` 读取 punct_mode，不再读 `_G.judou`
- `visual_ctx` 从 `plugin_contexts["judou"]` 获取 judou 渲染参数
- `render-page.lua` 从 `ctx.visual` 读取 judou/textflow_align，不再读 `_G.judou`/`_G.jiazhu`
- 删除 dead code：`_G.jiazhu` 从未被初始化，jiazhu align 通过 style stack 传递

---

## Phase 4: 已完成 — generate_physical_pages 参数化

**Commit**: `2e25952`

**改动总结**:
- `engine_ctx` 新增 `vertical_align`、`content_width`、`start_page_number`
- `generate_physical_pages()` 从 `engine_ctx` 读取，不再直接读 `_G.content`/`_G.page`
- `render-page.lua` 从 `render_ctx.grid.content_width` 读取，不再读 `_G.content`

**无法迁移的 _G 读取**:
- `_G.content.col_widths_sp`：跨 typeset 调用传递（正文 → textbox），必须保留 `_G` 读取

---

## 残留 _G 读取说明

### 合理保留的 _G 读取

| 位置 | 读取 | 原因 |
|------|------|------|
| core-main.lua `init_engine_context()` | `_G.content.*`, `_G.page.*`, `_G.banxin.*` | **单一入口点**：所有 _G 读取集中在此，值存入 engine_ctx 后传递 |
| core-main.lua `generate_physical_pages()` | `_G.content.col_widths_sp` | 跨 typeset 传递：textbox 需要读外层正文的 free mode 数据 |
| core-punct.lua `initialize()` | `_G.punct.*` | 模块自身管理的状态（setup 写入，initialize 读取） |
| layout-grid.lua `export_free_mode_data()` | 写 `_G.content.col_widths_sp` | 跨 typeset 输出：正文写入，textbox 读取 |
