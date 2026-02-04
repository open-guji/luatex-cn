-- Copyright 2026 Open-Guji (https://github.com/open-guji)
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================
-- core_main.lua - 竖排引擎核心协调层
-- ============================================================================
-- 文件名: core_main.lua (原 core.lua)
-- 层级: 协调层 (Core/Coordinator Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块是整个 vertical 竖排系统的总入口和协调中心，负责：
--   1. 加载并组织所有子模块（flatten_nodes、layout_grid、render_page 等）
--   2. 接收来自 TeX 的盒子数据和配置参数
--   3. 执行三阶段流水线：展平 -> 布局模拟 -> 渲染应用
--   4. 管理多页输出，维护页面缓存（vertical_pending_pages）
--   5. 处理内嵌文本框（见 core_textbox.lua）
--
-- 【术语对照 / Terminology】
--   prepare_grid      - 准备网格（主入口函数，执行三阶段流水线）
--   load_page         - 加载页面（将渲染好的页面写回 TeX 盒子）
--   process_from_tex  - TeX 接口（供 TeX 调用的封装函数）
--   pending_pages     - 待处理页面缓存（多页渲染的临时存储）
--   box_num           - 盒子编号（TeX 盒子寄存器编号）
--   g_width/g_height  - 网格宽度/高度（单个字符格的尺寸）
--   b_interval        - 版心间隔（每隔多少列出现一个版心列）
--
-- 【注意事项】
--   • 模块必须设置为全局变量 _G.vertical，因为 TeX 从 Lua 调用时需要访问
--   • package.loaded 机制确保子模块不会被重复加载
--   • 多页渲染时需要临时保存 pending_pages 状态（见 core_textbox.lua）
--   • 重点：Textbox 在列表开头时必须配合 \leavevmode 使用，以确保进入水平模式并继承 \leftskip
--   • Textbox 逻辑已移至 core_textbox.lua
--   • 本模块不直接操作节点，而是调用子模块完成具体工作
--
-- 【整体架构 / Architecture】
--   TeX 层 (vertical.sty)
--      ↓ 调用 process_from_tex(box_num, params)
--   core_main.lua (本模块)
--      ↓ 调用 prepare_grid()
--   ┌────────────────────────────────────┐
--   │  Stage 1: flatten_nodes.lua       │ ← 展平嵌套盒子，提取缩进
--   ├────────────────────────────────────┤
--   │  Stage 2: layout_grid.lua         │ ← 虚拟布局，计算每个节点的页/列/行
--   ├────────────────────────────────────┤
--   │  Stage 3: render_page.lua         │ ← 应用坐标，绘制边框/背景/版心
--   └────────────────────────────────────┘
--      ↓ 返回渲染好的页面列表
--   load_page() → TeX 输出到 PDF
--
-- ============================================================================

-- Global state for pending pages
_G.vertical_pending_pages = {}

--- Process an inner box (like a GridTextbox)
-- Create module namespace - MUST use _G to ensure global scope
_G.core = _G.core or {}
local core = _G.core

-- Initialize global page number


-- Load submodules using Lua's require mechanism
-- 加载子模块
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('core')
local dbg_map = debug.get_debugger('layout_map')
local flatten = package.loaded['core.luatex-cn-core-flatten-nodes'] or
    require('core.luatex-cn-core-flatten-nodes')
local layout = package.loaded['core.luatex-cn-layout-grid'] or
    require('core.luatex-cn-layout-grid')
local render = package.loaded['core.luatex-cn-core-render-page'] or
    require('core.luatex-cn-core-render-page')
local textbox = package.loaded['core.luatex-cn-core-textbox'] or
    require('core.luatex-cn-core-textbox')
local sidenote = package.loaded['core.luatex-cn-core-sidenote'] or
    require('core.luatex-cn-core-sidenote')
local judou = package.loaded['guji.luatex-cn-guji-judou'] or
    require('guji.luatex-cn-guji-judou')
local page = package.loaded['core.luatex-cn-core-page'] or
    require('core.luatex-cn-core-page')
local metadata = package.loaded['core.luatex-cn-core-metadata'] or
    require('core.luatex-cn-core-metadata')

--- Register a vertical engine plugin
-- @param name (string) Unique plugin identifier
-- @param p (table) Plugin implementation containing initialize, flatten, layout, render
core.plugins = core.plugins or {}
core.ordered_plugins = core.ordered_plugins or {}

local function register_plugin(name, p)
    if not core.plugins[name] then
        table.insert(core.ordered_plugins, name)
    end
    core.plugins[name] = p
    dbg.log(string.format("Registered plugin: %s", name))
end

--- Reset the global page number to 1
local function reset_page_number()
    _G.page.current_page_number = 1
end

--- Set the global page number to a specific value
-- @param n (number) The page number to set
local function set_page_number(n)
    _G.page.current_page_number = tonumber(n) or 1
end

-- 加载子模块
register_plugin("judou", judou)
register_plugin("sidenote", sidenote)
register_plugin("textbox", textbox)

-- Helper function to safely convert dimension values to scaled points
-- Handles both raw numbers and em unit tables returned by to_dimen
local function safe_to_sp(val, base_size)
    if not val or val == "" or val == "nil" then return nil end
    if type(val) == "table" and val.unit == "em" then
        return math.floor((val.value or 0) * (base_size or 655360) + 0.5)
    end
    return tonumber(val)
end

-- Chapter marker function delegated to metadata module
local function insert_chapter_marker(title)
    metadata.insert_chapter_marker_to_box(title)
end

--- Stage 0: Initialization & Parameter Resolution
-- @param box_num (number) TeX box register number
-- @param params (table) Parameter table
-- @return list, engine_ctx, plugin_contexts, p_info
local function init_engine_context(box_num, params)
    local box = tex.box[box_num]
    if not box or not box.list then return nil end
    local list = box.list

    -- 0.1 Basic Grid Metrics
    -- For TextBox: use params; for Content: use _G.content
    local current_fs = font.getfont(font.current()).size or 655360
    local is_textbox = (params.is_textbox == true)
    local g_width, g_height
    if is_textbox then
        g_width = safe_to_sp(constants.to_dimen(params.grid_width) or (65536 * 20), current_fs)
        g_height = safe_to_sp(constants.to_dimen(params.grid_height) or g_width, current_fs)
    else
        -- _G.content.grid_* may be em tables, need safe_to_sp conversion
        local content_gw = _G.content.grid_width
        local content_gh = _G.content.grid_height
        if content_gw and content_gw ~= 0 then
            g_width = safe_to_sp(content_gw, current_fs)
        else
            g_width = safe_to_sp(constants.to_dimen(params.grid_width) or (65536 * 20), current_fs)
        end
        if content_gh and content_gh ~= 0 then
            g_height = safe_to_sp(content_gh, current_fs)
        else
            g_height = g_width
        end
    end
    local char_width = g_height -- Vertical text char width approximation

    -- 0.2 Paper & Margins (use global _G.page set by page.setup)
    local p_width = _G.page.paper_width or 0
    local p_height = _G.page.paper_height or 0
    local m_top = _G.page.margin_top or 0
    local m_bottom = _G.page.margin_bottom or 0
    local m_left = _G.page.margin_left or 0
    local m_right = _G.page.margin_right or 0

    -- Border settings: read from style stack
    -- Content pushes {border, outer_border, border_width, border_color}
    -- TextBox pushes {outer_border=false, border_width, border_color} and border if explicit
    local style_registry = package.loaded['util.luatex-cn-style-registry']
    local current_style = style_registry and style_registry.current() or {}
    local is_border = current_style.border or false
    local is_outer_border = current_style.outer_border or false
    local border_color = current_style.border_color or "0 0 0"
    -- Convert border_width from pt string to sp (style stack stores "0.4pt" format)
    local b_thickness = 26214 -- default 0.4pt
    if current_style.border_width then
        b_thickness = constants.to_dimen(current_style.border_width) or 26214
    end
    -- Outer border params (not in style stack - content-only feature)
    local ob_thickness = _G.content.outer_border_thickness or (65536 * 2)
    local ob_sep = _G.content.outer_border_sep or (65536 * 2)
    local b_padding_top = _G.content.border_padding_top or 0
    local b_padding_bottom = _G.content.border_padding_bottom or 0

    -- 0.4 Visual Flags & Features (use global _G.banxin set by banxin.setup)
    local banxin_on = _G.banxin and _G.banxin.enabled or false

    -- 0.7 Geometry Constraints
    local h_raw = params.height
    local h_dim = 0
    if type(h_raw) == "number" or (type(h_raw) == "string" and h_raw:match("^%d+$")) then
        h_dim = (tonumber(h_raw) or 0) * g_height
    else
        h_dim = safe_to_sp(constants.to_dimen(h_raw), g_height) or (65536 * 300)
    end
    params.absolute_height = h_dim

    local limit = tonumber(params.col_limit) or tonumber(params.line_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height + 0.1)
    end
    if limit <= 0 then limit = 20 end

    -- 0.5 Column Layout (use _G.content for main content, params for textbox)
    local b_interval, p_cols
    if is_textbox then
        -- TextBox: use params directly (n_cols -> page_columns from build_sub_params)
        b_interval = 0  -- no banxin in textbox
        p_cols = tonumber(params.page_columns) or 100
    else
        -- Content: read from _G.content (calculated by content.setup)
        b_interval = _G.content.n_column or 8
        if b_interval <= 0 and banxin_on then b_interval = 8 end
        p_cols = _G.content.page_columns or 1
    end

    if is_textbox then
        m_top, m_bottom, m_left, m_right = 0, 0, 0, 0
    end

    -- 0.8 Engine Context (Shared state for plugins)
    local engine_ctx = {
        -- Grid dimensions
        g_width = g_width,
        g_height = g_height,
        -- Layout parameters
        banxin_on = banxin_on,
        line_limit = limit,
        n_column = b_interval,
        page_columns = p_cols,
        -- Border rendering
        draw_border = is_border,
        border_thickness = b_thickness,
        half_thickness = math.floor(b_thickness / 2),
        outer_shift = is_outer_border and (ob_thickness + ob_sep) or 0,
        shift_x = (is_outer_border and (ob_thickness + ob_sep) or 0),
        shift_y = (is_outer_border and (ob_thickness + ob_sep) or 0) +
            (is_border and (b_thickness + b_padding_top) or 0),
        border_rgb_str = utils.normalize_rgb(border_color) or "0 0 0",
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        -- Registry data (set after layout)
    }

    -- Helper function to calculate reserved column coordinates
    engine_ctx.get_reserved_column_coords = function(col, total_cols)
        local rtl_col = total_cols - 1 - col
        local effective_half = engine_ctx.draw_border and engine_ctx.half_thickness or 0
        return {
            x = rtl_col * engine_ctx.g_width + effective_half + engine_ctx.shift_x,
            y = -(effective_half + engine_ctx.outer_shift),
            width = engine_ctx.g_width,
            height = engine_ctx.line_limit * engine_ctx.g_height + engine_ctx.b_padding_top + engine_ctx
                .b_padding_bottom,
        }
    end

    -- Helper function to get reserved columns for a page
    engine_ctx.get_reserved_cols = function(page_idx, total_cols)
        if engine_ctx.banxin_registry and engine_ctx.banxin_registry[page_idx] then
            return engine_ctx.banxin_registry[page_idx]
        end
        local reserved = {}
        local interval = engine_ctx.n_column
        if interval > 0 then
            for col = 0, total_cols - 1 do
                if _G.core.hooks.is_reserved_column(col, interval) then
                    reserved[col] = true
                end
            end
        end
        return reserved
    end

    -- 0.9 Plugin Initialization
    local plugin_contexts = {}
    for _, name in ipairs(core.ordered_plugins) do
        local p = core.plugins[name]
        if p.initialize then
            plugin_contexts[name] = p.initialize(params, engine_ctx)
        end
    end

    local p_info = {
        is_vlist = (box.id == constants.VLIST),
        char_width = char_width,
        p_width = p_width,
        p_height = p_height,
        m_top = m_top,
        m_bottom = m_bottom,
        m_left = m_left,
        m_right = m_right,
        ob_thickness = ob_thickness,
        ob_sep = ob_sep,
        is_textbox = is_textbox,
        is_outer_border = is_outer_border,
        h_dim = h_dim,
    }

    dbg.log(string.format("Stage 0: Initialized with g_height=%.2f pt, limit=%d, p_cols=%d",
        g_height / 65536, limit, p_cols))

    return list, engine_ctx, plugin_contexts, p_info
end

--- Stage 1: Node Stream Pre-processing (Flattening & Punctuation)
local function flatten_node_stream(list, params, engine_ctx, plugin_contexts, p_info)
    -- 1.1 Column Flattening
    if p_info.is_vlist then
        list = flatten.flatten_vbox(list, engine_ctx.g_width, p_info.char_width)
        dbg.log(string.format("Stage 1: Flattened head=%s", tostring(list)))
    end

    -- 1.2 Plugin Flattening
    for _, name in ipairs(core.ordered_plugins) do
        local p = core.plugins[name]
        if p.flatten then
            list = p.flatten(list, params, plugin_contexts[name])
        end
    end

    -- 1.3 Legacy/Internal Punctuation (to be migrated)
    dbg.log("Stage 1: Processed punctuation.")
    return list
end

--- Stage 2: Grid Layout & Logical Mapping
local function compute_grid_layout(list, params, engine_ctx, plugin_contexts, p_info)
    -- Read floating* from textbox plugin context only when is_textbox
    local tb_ctx = plugin_contexts["textbox"] or {}
    local is_floating = p_info.is_textbox and tb_ctx.floating
    local floating_x = p_info.is_textbox and tb_ctx.floating_x or 0

    -- Build layout params - for non-textbox, layout-grid.lua will use global fallbacks
    -- Only pass values that are explicitly needed or textbox-specific
    local layout_params = {
        distribute = params.distribute,             -- textbox-specific
        floating = is_floating,                     -- textbox-specific
        floating_x = floating_x,                    -- textbox-specific
        absolute_height = p_info.h_dim,             -- textbox-specific
        plugin_contexts = plugin_contexts,
    }

    -- For textbox: pass explicit values (no global fallback)
    if p_info.is_textbox then
        -- Enable center gap detection if there's a global banxin AND textbox has floating position
        -- This ensures meipi skips the center gap when crossing banxin
        local global_banxin_on = _G.banxin and _G.banxin.enabled or false
        layout_params.banxin_on = global_banxin_on and (floating_x > 0)
        layout_params.grid_width = engine_ctx.g_width
        layout_params.margin_right = p_info.m_right
        layout_params.chapter_title = params.chapter_title or ""
    end
    -- For non-textbox: layout-grid.lua will read from globals via helpers

    local layout_map, total_pages, page_chapter_titles, banxin_registry = layout.calculate_grid_positions(list,
        engine_ctx.g_height,
        engine_ctx.line_limit, engine_ctx.n_column, engine_ctx.page_columns,
        layout_params)
    engine_ctx.banxin_registry = banxin_registry
    engine_ctx.page_chapter_titles = page_chapter_titles
    engine_ctx.total_pages = total_pages

    dbg.log(string.format("Stage 2: Laid out total_pages = %d", total_pages))

    -- 2.1 Plugin Layout
    for _, name in ipairs(core.ordered_plugins) do
        local p = core.plugins[name]
        if p.layout then
            p.layout(list, layout_map, engine_ctx, plugin_contexts[name])
        end
    end

    -- 2.1 Adjust dimensions for auto-sized textboxes
    if p_info.is_textbox then
        local max_col = 0
        for _, pos in pairs(layout_map) do
            if pos.col > max_col then max_col = pos.col end
        end
        engine_ctx.page_columns = max_col + 1
    end

    -- 2.2 Get floating map from textbox plugin context
    local floating_map = plugin_contexts["textbox"] and plugin_contexts["textbox"].floating_map or {}
    dbg.log("Stage 2: Calculated floating positions.")

    return {
        layout_map = layout_map,
        total_pages = total_pages,
        page_chapter_titles = page_chapter_titles,
        banxin_registry = banxin_registry,
        floating_map = floating_map,
    }
end

--- Stage 3: Physical Rendering & Box Generation
local function generate_physical_pages(list, params, engine_ctx, plugin_contexts, layout_results, p_info)
    local layout_map = layout_results.layout_map
    local total_pages = layout_results.total_pages
    local floating_map = layout_results.floating_map

    local start_page = params.start_page_number or _G.page.current_page_number

    -- Build visual params - for non-textbox, render-page.lua reads from _G.content directly
    -- Only populate for textbox which has no global fallback
    local visual_ctx = {
        -- column_aligns is textbox-specific, always from plugin context
        column_aligns = plugin_contexts["textbox"] and plugin_contexts["textbox"].column_aligns or nil,
    }

    if p_info.is_textbox then
        -- TextBox: read visual params from style stack
        local style_registry = package.loaded['util.luatex-cn-style-registry']
        local current_style = style_registry and style_registry.current() or {}
        visual_ctx.vertical_align = current_style.vertical_align or "center"
        visual_ctx.bg_rgb = params.background_color
        visual_ctx.font_rgb = current_style.font_color
        visual_ctx.font_size = constants.to_dimen(current_style.font_size)
        -- Border shape decoration (uses border params from style stack)
        visual_ctx.border_shape = params.border_shape or "none"
        visual_ctx.border_color = current_style.border_color or "0 0 0"
        visual_ctx.border_width = current_style.border_width or "0.4pt"
        visual_ctx.border_margin = params.border_margin or "1pt"
    end
    -- For non-textbox: render-page.lua will read from _G.content via calculate_render_context()

    local render_ctx = {
        grid = {
            width = engine_ctx.g_width,
            height = engine_ctx.g_height,
            line_limit = engine_ctx.line_limit,
            -- n_column is mainly for banxin/layout, but might be needed for some calc
            n_column = engine_ctx.n_column,
            cols = engine_ctx.page_columns,
        },
        page = p_info,       -- { p_width, p_height, m_*, is_textbox, is_outer_border, ob_* }
        engine = engine_ctx, -- { border_thickness, draw_border, shifts, colors, reserved_cols helpers }
        visual = visual_ctx, -- For textbox: explicit params; for non-textbox: minimal (globals used)

        plugins = {
            floating_map = floating_map,
            plugin_contexts = plugin_contexts,
        },

        total_pages = total_pages,
        start_page_number = start_page,
    }

    local pages = render.apply_positions(list, layout_map, render_ctx)

    -- 3.1 Plugin Rendering
    for _, name in ipairs(core.ordered_plugins) do
        local p = core.plugins[name]
        if p.render then
            for i, page_info in ipairs(pages) do
                page_info.head = p.render(page_info.head, layout_map, render_ctx, plugin_contexts[name], engine_ctx,
                    i - 1,
                    page_info.cols)
            end
        end
    end

    -- 3.1 Update global state
    if not p_info.is_textbox then
        _G.page.current_page_number = start_page + #pages
    end

    -- 3.2 Construct TeX boxes
    _G.vertical_pending_pages = {}
    local outer_shift = engine_ctx.outer_shift
    local char_grid_height = p_info.is_textbox and p_info.h_dim or (engine_ctx.line_limit * engine_ctx.g_height)
    local total_v_depth = char_grid_height + engine_ctx.b_padding_top + engine_ctx.b_padding_bottom +
        engine_ctx.border_thickness + outer_shift * 2

    for i, page_info in ipairs(pages) do
        local new_box = node.new("hlist")
        new_box.dir = "TLT"

        -- For TextBox: wrap content with q/Q to scope any color changes
        -- This prevents font_color from leaking to subsequent text in the outer document
        local content_head = page_info.head
        if p_info.is_textbox then
            local D = node.direct
            local d_head = D.todirect(content_head)
            -- Insert "q" (save state) at beginning
            d_head = utils.insert_pdf_literal(d_head, "q")
            -- Find tail and insert "Q" (restore state) at end
            local tail = d_head
            while D.getnext(tail) do
                tail = D.getnext(tail)
            end
            local q_restore = utils.create_pdf_literal("Q")
            D.insert_after(d_head, tail, q_restore)
            content_head = D.tonode(d_head)
        end

        new_box.list = content_head
        new_box.width = page_info.cols * engine_ctx.g_width + engine_ctx.border_thickness + outer_shift * 2
        new_box.height = 0
        new_box.depth = total_v_depth

        if p_info.is_textbox then
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_WIDTH, page_info.cols)
            -- Use actual content rows for auto-height, or line_limit for fixed-height
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_HEIGHT, page_info.rows or engine_ctx.line_limit)
        else
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_WIDTH, 0)
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_HEIGHT, 0)
        end
        _G.vertical_pending_pages[i] = new_box
    end

    return #_G.vertical_pending_pages
end

--- Main entry point for typesetting
-- @param box_num (number) TeX box register number
-- @param params (table) Parameter table
-- @return (number) Total pages generated
local function typeset(box_num, params)
    local list, engine_ctx, plugin_contexts, p_info = init_engine_context(box_num, params)
    if not list then return 0 end

    -- Note: Base style is already pushed by init_style() in content.lua
    -- TextBox pushes its own style overrides when processing

    list = flatten_node_stream(list, params, engine_ctx, plugin_contexts, p_info)

    local layout_results = compute_grid_layout(list, params, engine_ctx, plugin_contexts, p_info)

    local total_pages = generate_physical_pages(list, params, engine_ctx, plugin_contexts, layout_results, p_info)

    return total_pages
end

--- Load a prepared page into a TeX box register
-- @param box_num (number) TeX box register
-- @param index (number) Page index (0-based from TeX loop)
-- @param copy (boolean) If true, copy the node list instead of moving it
local function load_page(box_num, index, copy)
    local box = _G.vertical_pending_pages[index + 1]
    if box then
        if copy then
            -- Copy the node list so the original is preserved
            tex.box[box_num] = node.copy_list(box)
        else
            -- Move the node to TeX and clear our reference
            tex.box[box_num] = box
            _G.vertical_pending_pages[index + 1] = nil
        end
    end
end

--- Interface for TeX to call to process and output pages
local function process(box_num, params)
    local total_pages = typeset(box_num, params)

    -- Check if split page is enabled
    -- CRITICAL: Do NOT enable split page output for textboxes (Content, etc.)
    local is_textbox = (params.is_textbox == true)
    local split_enabled = page.split and page.split.is_enabled and page.split.is_enabled()

    if split_enabled and not is_textbox then
        -- Split page mode: delegate to page.split module
        page.split.output_pages(box_num, total_pages)
    else
        -- Normal mode: delegate to page module
        page.output_pages(box_num, total_pages)
    end

    -- Clear registries that are no longer needed (they were only used during prepare_grid)
    -- This recovers memory for sidenotes and floating boxes immediately.
    sidenote.clear_registry()
    textbox.clear_registry()
end

--- Final cleanup function to be called at the end of the document
-- This safely flushes all remaining nodes in registries and clears tables
local function finalize_engine()
    local glyph_id = node.id("glyph")
    local before = node.count(glyph_id)
    dbg.log(string.format("Performing cleanup. Glyphs before: %d", before))

    -- 1. Flush and clear pending pages
    for i, box in pairs(_G.vertical_pending_pages) do
        if box then
            node.flush_list(box)
        end
    end
    _G.vertical_pending_pages = {}

    -- 2. Flush and clear sidenote registry
    if sidenote and sidenote.registry then
        for _, item in pairs(sidenote.registry) do
            local head = type(item) == "table" and item.head or item
            if head then
                node.flush_list(head)
            end
        end
        sidenote.clear_registry()
    end

    -- 3. Flush and clear textbox registries
    if textbox and textbox.floating_registry then
        for _, item in pairs(textbox.floating_registry) do
            if item.box then
                node.flush_list(item.box)
            end
        end
        textbox.clear_registry()
    end

    -- 4. Force garbage collection
    collectgarbage("collect")
    collectgarbage("collect") -- Second pass for finalizers
end

-- ========================================================================
-- Public API Export
-- ========================================================================

core.register_plugin       = register_plugin
core.reset_page_number     = reset_page_number
core.set_page_number       = set_page_number
core.insert_chapter_marker = insert_chapter_marker
core.typeset               = typeset
core.load_page             = load_page
core.process               = process

-- Return module
return core
