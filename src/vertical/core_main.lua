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
-- Version: 0.4.0 (Modularized)
-- Date: 2026-01-13
-- ============================================================================

-- Global state for pending pages
_G.vertical_pending_pages = {}

--- Process an inner box (like a GridTextbox)
-- Create module namespace - MUST use _G to ensure global scope
_G.vertical = _G.vertical or {}
local vertical = _G.vertical

-- Initialize global page number
vertical.current_page_number = vertical.current_page_number or 1

vertical.debug = vertical.debug or {
    enabled = false,
    verbose_log = false,
    show_grid = true,
    show_boxes = true
}

--- Reset the global page number to 1
function vertical.reset_page_number()
    vertical.current_page_number = 1
end

-- Load submodules using Lua's require mechanism
-- 加载子模块
local constants = package.loaded['base_constants'] or require('base_constants')
local utils = package.loaded['base_utils'] or require('base_utils')
local flatten = package.loaded['flatten_nodes'] or require('flatten_nodes')
local layout = package.loaded['layout_grid'] or require('layout_grid')
local render = package.loaded['render_page'] or require('render_page')
local textbox = package.loaded['core_textbox'] or require('core_textbox')

local D = node.direct


--- Main entry point called from TeX
-- @param box_num (number) TeX box register number
-- @param params (table) Parameter table
-- @return (number) Total pages generated
function vertical.prepare_grid(box_num, params)
    -- 1. Get box from TeX
    local box = tex.box[box_num]
    if not box then return end

    local list = box.list
    local g_width = constants.to_dimen(params.grid_width) or (65536 * 20)
    local g_height = constants.to_dimen(params.grid_height) or g_width

    -- Use grid_height (char height) as approximate char width for indent calculation
    local char_width = g_height

    local p_width = constants.to_dimen(params.paper_width) or 0
    local p_height = constants.to_dimen(params.paper_height) or 0
    local m_top = constants.to_dimen(params.margin_top) or 0
    local m_bottom = constants.to_dimen(params.margin_bottom) or 0
    local m_left = constants.to_dimen(params.margin_left) or 0
    local m_right = constants.to_dimen(params.margin_right) or 0

    local h_dim = constants.to_dimen(params.height) or (65536 * 300)
    local b_padding_top = constants.to_dimen(params.border_padding_top) or 0
    local b_padding_bottom = constants.to_dimen(params.border_padding_bottom) or 0
    local b_thickness = constants.to_dimen(params.border_thickness) or 26214 -- 0.4pt
    local ob_thickness = constants.to_dimen(params.outer_border_thickness) or (65536 * 2)
    local ob_sep = constants.to_dimen(params.outer_border_sep) or (65536 * 2)
    local b_interval = tonumber(params.n_column) or 8
    local banxin_on = (params.banxin_on == "true" or params.banxin_on == true)
    local p_cols = tonumber(params.page_columns)
    if not p_cols or p_cols <= 0 then
        if banxin_on and b_interval > 0 then
            -- If n-column is set AND banxin is on, we favor the symmetric structure (N + banxin + N)
            p_cols = (2 * b_interval + 1)
        elseif p_width > 0 and g_width > 0 then
            -- Auto-calculate columns based on paper width and margins
            local available_width = p_width - m_left - m_right - b_thickness
            if ob_thickness and ob_sep then
                available_width = available_width - 2 * (ob_thickness + ob_sep)
            end
            -- Add 0.1 grid width to avoid flooring 16.999 to 16 due to precision
            p_cols = math.floor(available_width / g_width + 0.1)
            if p_cols <= 0 then p_cols = 1 end
        else
            -- Ultimate fallback
            if banxin_on then
                p_cols = (2 * b_interval + 1)
            else
                p_cols = math.max(1, b_interval)
            end
        end
    end

    local limit = tonumber(params.col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_textbox = (params.is_textbox == true)
    local half_thickness = math.floor(b_thickness / 2)
    local border_w = p_cols * g_width + 2 * half_thickness
    local shift_x = 0
    local shift_y = 0
    
    if is_textbox then
        m_top = 0
        m_bottom = 0
        m_left = 0
        m_right = 0
    end

    local is_debug = (params.debug_on == "true" or params.debug_on == true)
    if is_debug then _G.vertical.debug.enabled = true end
    is_debug = _G.vertical.debug.enabled
    local is_border = (params.border_on == "true" or params.border_on == true)
    local is_outer_border = (params.outer_border_on == "true" or params.outer_border_on == true)

    local valign = params.vertical_align or "center"
    if valign ~= "top" and valign ~= "center" and valign ~= "bottom" then
        valign = "center"
    end

    -- 3. Pipeline Stage 1: Flatten VBox (if needed)
    if box.id == constants.VLIST then
        list = flatten.flatten_vbox(list, g_width, char_width)
        if is_debug then
            local count = 0
            local temp = list
            while temp do
                count = count + 1
                temp = D.getnext(temp)
            end
            utils.debug_log(string.format("[core] Post-flatten nodes: %d, Head: %s", count, tostring(list)))
        end
    end

    -- 4. Pipeline Stage 2: Calculate grid layout
    local layout_map, total_pages = layout.calculate_grid_positions(list, g_height, limit, b_interval, p_cols, {
        distribute = params.distribute,
        banxin_on = banxin_on,
    })

    -- 5. Pipeline Stage 3: Apply positions and render
    -- Build rendering params
    local is_textbox = (params.is_textbox == true)
    local start_page = params.start_page_number or _G.vertical.current_page_number

    local r_params = {
        grid_width = g_width,
        grid_height = g_height,
        total_pages = total_pages,
        vertical_align = valign,
        draw_debug = is_debug,
        draw_border = is_border,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        line_limit = limit,
        border_thickness = b_thickness,
        draw_outer_border = is_outer_border,
        outer_border_thickness = ob_thickness,
        outer_border_sep = ob_sep,
        n_column = b_interval,
        page_columns = p_cols,
        border_rgb = params.border_color,
        bg_rgb = params.background_color,
        font_rgb = params.font_color,
        paper_width = p_width,
        paper_height = p_height,
        margin_top = m_top,
        margin_bottom = m_bottom,
        margin_left = m_left,
        margin_right = m_right,
        shift_x = shift_x,
        shift_y = shift_y,
        banxin_upper_ratio = tonumber(params.banxin_upper_ratio) or 0.28,
        banxin_middle_ratio = tonumber(params.banxin_middle_ratio) or 0.56,
        banxin_lower_ratio = tonumber(params.banxin_lower_ratio) or 0.16,
        book_name = params.book_name or "",
        banxin_padding_top = constants.to_dimen(params.banxin_padding_top) or (65536 * 2), -- 2pt default
        banxin_padding_bottom = constants.to_dimen(params.banxin_padding_bottom) or 0,
        lower_yuwei = (params.lower_yuwei == "true" or params.lower_yuwei == true),
        chapter_title = params.chapter_title or "",
        chapter_title_top_margin = constants.to_dimen(params.chapter_title_top_margin) or (65536 * 20), -- 20pt default
        chapter_title_cols = tonumber(params.chapter_title_cols) or 1,
        chapter_title_font_size = params.chapter_title_font_size,
        chapter_title_grid_height = params.chapter_title_grid_height,
        column_aligns = params.column_aligns,
        start_page_number = start_page,
        jiazhu_font_size = params.jiazhu_font_size,
        jiazhu_align = params.jiazhu_align or "outward",
        font_size = constants.to_dimen(params.font_size),
        is_textbox = is_textbox,
        banxin_on = banxin_on,
    }

    if is_debug then
        utils.debug_log(string.format("[core] Calling apply_positions with start_page=%d (is_textbox=%s)", start_page, tostring(is_textbox)))
    end

    local rendered_pages = render.apply_positions(list, layout_map, r_params)

    -- Update global page number ONLY if this is a main document call
    if not is_textbox then
        local old_page_num = _G.vertical.current_page_number
        _G.vertical.current_page_number = old_page_num + #rendered_pages

        if is_debug then
            utils.debug_log(string.format("[core] Finished apply_positions. Pages: %d. Global page number: %d -> %d", 
                #rendered_pages, old_page_num, _G.vertical.current_page_number))
        end
    else
        if is_debug then
            utils.debug_log("[core] Finished apply_positions for textbox. Global page number remains " .. tostring(_G.vertical.current_page_number))
        end
    end

    -- 6. Store pages and return count
    _G.vertical_pending_pages = {}
    
    local outer_shift = is_outer_border and (ob_thickness + ob_sep) or 0
    local char_grid_height = limit * g_height
    local total_v_depth = char_grid_height + b_padding_top + b_padding_bottom + b_thickness + outer_shift * 2

    for i, page_info in ipairs(rendered_pages) do
        local new_box = node.new("hlist")
        new_box.dir = "TLT"
        new_box.list = page_info.head
        
        new_box.width = page_info.cols * g_width + b_thickness + outer_shift * 2

        new_box.height = 0
        new_box.depth = total_v_depth
        -- CRITICAL: Reset textbox attributes for MAIN DOCUMENT wrapper boxes
        -- (Inner textbox wrappers need these attributes set by verticalize_inner_box)
        node.set_attribute(new_box, constants.ATTR_TEXTBOX_WIDTH, 0)
        node.set_attribute(new_box, constants.ATTR_TEXTBOX_HEIGHT, 0)
        _G.vertical_pending_pages[i] = new_box
    end

    if is_debug then
        utils.debug_log("--- [core] Layout Map Summary ---")
        for n, pos in pairs(layout_map) do
            local tb_w = D.get_attribute(n, constants.ATTR_TEXTBOX_WIDTH) or 0
            if tb_w > 0 then
                utils.debug_log("  [layout_map] Block Node=" .. tostring(n) .. " at p=" .. (pos.page or 0) .. " c=" .. pos.col .. " r=" .. pos.row .. " w=" .. (pos.width or 0) .. " h=" .. (pos.height or 0))
            end
        end
    end

    return #_G.vertical_pending_pages
end

--- Load a prepared page into a TeX box register
-- @param box_num (number) TeX box register
-- @param index (number) Page index (0-based from TeX loop)
function vertical.load_page(box_num, index)
    local box = _G.vertical_pending_pages[index + 1]
    if box then
        tex.box[box_num] = box
        -- Clear from storage to avoid memory leaks if called multiple times
        -- Actually, we might need it for re-rendering, so keep it for now
        -- Or clear it on the last page.
    end
end

--- Interface for TeX to call to process and output pages
function vertical.process_from_tex(box_num, params)
    local total_pages = vertical.prepare_grid(box_num, params)
    
    for i = 0, total_pages - 1 do
        tex.print(string.format("\\directlua{vertical.load_page(%d, %d)}", box_num, i))
        tex.print("\\par\\nointerlineskip")
        tex.print(string.format("\\noindent\\hfill\\smash{\\box%d}", box_num))
        if i < total_pages - 1 then
            tex.print("\\newpage")
        end
    end
end

-- CRITICAL: Update global variable with the local one that has the function
_G.vertical = vertical

-- Return module
return vertical

