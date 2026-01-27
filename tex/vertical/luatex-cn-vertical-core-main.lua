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
_G.vertical = _G.vertical or {}
local vertical = _G.vertical

-- Initialize global page number
vertical.current_page_number = vertical.current_page_number or 1



--- Reset the global page number to 1
function vertical.reset_page_number()
    vertical.current_page_number = 1
end

--- Set the global page number to a specific value
-- @param n (number) The page number to set
function vertical.set_page_number(n)
    vertical.current_page_number = tonumber(n) or 1
end

-- Load submodules using Lua's require mechanism
-- 加载子模块
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')
local flatten = package.loaded['vertical.luatex-cn-vertical-flatten-nodes'] or
    require('vertical.luatex-cn-vertical-flatten-nodes')
local layout = package.loaded['vertical.luatex-cn-vertical-layout-grid'] or
    require('vertical.luatex-cn-vertical-layout-grid')
local render = package.loaded['vertical.luatex-cn-vertical-render-page'] or
    require('vertical.luatex-cn-vertical-render-page')
local textbox = package.loaded['vertical.luatex-cn-vertical-core-textbox'] or
    require('vertical.luatex-cn-vertical-core-textbox')
local sidenote = package.loaded['vertical.luatex-cn-vertical-core-sidenote'] or
    require('vertical.luatex-cn-vertical-core-sidenote')
local judou = package.loaded['vertical.luatex-cn-vertical-judou'] or
    require('vertical.luatex-cn-vertical-judou')


local D = node.direct


--- Main entry point called from TeX
-- @param box_num (number) TeX box register number
-- @param params (table) Parameter table
-- @return (number) Total pages generated
function vertical.prepare_grid(box_num, params)
    -- 1. Get box from TeX
    local box = tex.box[box_num]
    if not box then return 0 end

    local list = box.list
    if not list then return 0 end

    local g_width = constants.to_dimen(params.grid_width) or (65536 * 20)
    local g_height = constants.to_dimen(params.grid_height) or g_width

    -- Use grid_height (char height) as approximate char width for indent calculation
    local char_width = g_height

    local p_width = constants.to_dimen(params.paper_width) or constants.to_dimen(params.floating_paper_width) or 0
    if p_width <= 0 and _G.vertical and _G.vertical.main_paper_width then
        p_width = _G.vertical.main_paper_width
    end
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

    local limit = tonumber(params.col_limit) or tonumber(params.line_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end
    if limit <= 0 then limit = 20 end

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
    else
        -- Store main document paper_width for use by floating textboxes
        if p_width > 0 then
            _G.vertical = _G.vertical or {}
            _G.vertical.main_paper_width = p_width
        end
    end

    local is_debug = luatex_cn_debug and luatex_cn_debug.is_enabled("vertical")
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

    -- 3a. Pipeline Stage 1.5: Process Judou Mode (Transformation)
    if params.judou_on == "true" or params.judou_on == true then
        list = judou.process_judou(D.todirect(list), params)
        list = D.tonode(list)
    end

    -- 4. Pipeline Stage 2: Calculate grid layout
    print(string.format("[LUA] Final Layout Settings: g_height=%.2f pt, limit=%d, p_cols=%d", g_height / 65536, limit,
        p_cols))
    local layout_map, total_pages = layout.calculate_grid_positions(list, g_height, limit, b_interval, p_cols, {
        distribute = params.distribute,
        banxin_on = banxin_on,
        -- Pass floating textbox info for center gap detection
        floating = params.floating,
        floating_x = params.floating_x,
        floating_paper_width = params.floating_paper_width,
        paper_width = p_width,
        grid_width = g_width,
        margin_right = m_right
    })
    print(string.format("[LUA] Laid out total_pages = %d", total_pages))

    -- 4a. Pipeline Stage 2.5: For textboxes, determine actual columns used
    if is_textbox then
        local max_col = 0
        for _, pos in pairs(layout_map) do
            if pos.col > max_col then
                max_col = pos.col
            end
        end
        -- Adjust p_cols to the actual number of columns used (max_col + 1)
        p_cols = max_col + 1
        -- Also update total_pages if it's a single-page textbox that got pushed to page 2?
        -- No, total_pages is already correct.
    end

    local floating_map = textbox.calculate_floating_positions(layout_map, {
        list = list
    })

    local sidenote_map = sidenote.calculate_sidenote_positions(layout_map, {
        list = list,
        page_columns = p_cols,
        line_limit = limit,
        n_column = b_interval,
        banxin_on = banxin_on,
        grid_height = g_height
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
        -- draw_debug removed, use utils.is_debug_enabled()
        draw_border = is_border,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        col_limit = limit,  -- Correct parameter name for rows per column
        line_limit = limit, -- Backward compatibility
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
        book_name = params.book_name or "",
        banxin_padding_top = constants.to_dimen(params.banxin_padding_top) or (65536 * 2), -- 2pt default
        banxin_padding_bottom = constants.to_dimen(params.banxin_padding_bottom) or 0,
        lower_yuwei = (params.lower_yuwei == "true" or params.lower_yuwei == true),
        chapter_title = params.chapter_title or "",
        chapter_title_top_margin = constants.to_dimen(params.chapter_title_top_margin) or (65536 * 20), -- 20pt default
        chapter_title_cols = tonumber(params.chapter_title_cols) or 1,
        chapter_title_font_size = params.chapter_title_font_size,
        chapter_title_grid_height = params.chapter_title_grid_height,
        book_name_grid_height = params.book_name_grid_height,
        book_name_align = params.book_name_align or "center",
        upper_yuwei = (params.upper_yuwei == "true" or params.upper_yuwei == true),
        banxin_divider = (params.banxin_divider == "true" or params.banxin_divider == true),
        page_number_align = params.page_number_align or "right-bottom",
        page_number_font_size = constants.to_dimen(params.page_number_font_size),
        column_aligns = params.column_aligns,
        start_page_number = start_page,
        jiazhu_font_size = params.jiazhu_font_size,
        jiazhu_align = params.jiazhu_align or "outward",
        font_size = constants.to_dimen(params.font_size),
        is_textbox = is_textbox,
        banxin_on = banxin_on,
        sidenote_map = sidenote_map, -- Pass sidenote map to render
        floating_map = floating_map, -- Pass floating map to render
    }

    if is_debug then
        utils.debug_log(string.format("[core] Calling apply_positions with start_page=%d (is_textbox=%s)", start_page,
            tostring(is_textbox)))
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
            utils.debug_log("[core] Finished apply_positions for textbox. Global page number remains " ..
                tostring(_G.vertical.current_page_number))
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
        -- For textboxes, we store the ACTUAL column count as the width attribute
        if is_textbox then
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_WIDTH, page_info.cols)
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_HEIGHT, limit)
        else
            -- CRITICAL: Reset textbox attributes for MAIN DOCUMENT wrapper boxes
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_WIDTH, 0)
            node.set_attribute(new_box, constants.ATTR_TEXTBOX_HEIGHT, 0)
        end
        _G.vertical_pending_pages[i] = new_box
    end

    if is_debug then
        utils.debug_log("--- [core] Layout Map Summary ---")
        for n, pos in pairs(layout_map) do
            local tb_w = D.get_attribute(n, constants.ATTR_TEXTBOX_WIDTH) or 0
            if tb_w > 0 then
                utils.debug_log("  [layout_map] Block Node=" ..
                    tostring(n) ..
                    " at p=" ..
                    (pos.page or 0) ..
                    " c=" .. pos.col .. " r=" .. pos.row .. " w=" .. (pos.width or 0) .. " h=" .. (pos.height or 0))
            end
        end
    end

    return #_G.vertical_pending_pages
end

--- Load a prepared page into a TeX box register
-- @param box_num (number) TeX box register
-- @param index (number) Page index (0-based from TeX loop)
-- @param copy (boolean) If true, copy the node list instead of moving it
function vertical.load_page(box_num, index, copy)
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
function vertical.process_from_tex(box_num, params)
    local total_pages = vertical.prepare_grid(box_num, params)

    -- Check if split page is enabled
    -- CRITICAL: Do NOT enable split page output for textboxes (VerticalRTT, etc.)
    local is_textbox = (params.is_textbox == true)
    local split_enabled = _G.splitpage and _G.splitpage.is_enabled and _G.splitpage.is_enabled()

    if split_enabled and not is_textbox then
        -- Split page mode: output each page as two half-pages
        local target_w = _G.splitpage.get_target_width()
        local target_h = _G.splitpage.get_target_height()
        local right_first = _G.splitpage.is_right_first()

        -- Convert sp to pt for TeX
        local target_w_pt = target_w / 65536
        local target_h_pt = target_h / 65536

        for i = 0, total_pages - 1 do
            -- For split page, we need to output each page twice (left half and right half)
            -- First, load page into box (with copy=true so we can use it twice)
            local cmd_load = string.format("\\directlua{vertical.load_page(%d, %d, true)}", box_num, i)
            local cmd_dim = string.format("\\global\\pagewidth=%.5fpt", target_w_pt)
            local cmd_dim_h = string.format("\\global\\pageheight=%.5fpt", target_h_pt)

            if is_debug then
                utils.debug_log("[core] TeX CMD: " .. cmd_load)
                utils.debug_log("[core] TeX CMD: " .. cmd_dim)
            end

            tex.print(cmd_load)

            -- Set page dimensions to half width for first half
            tex.print(cmd_dim)
            tex.print(cmd_dim_h)

            -- Output first half (right side if right_first)
            tex.print("\\par\\nointerlineskip")
            if right_first then
                -- 右半页：将内容左移，使右半部分显示
                tex.print(string.format("\\noindent\\kern-%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}", target_w_pt,
                    box_num))
            else
                -- 左半页：不移动
                tex.print(string.format("\\noindent\\hbox to 0pt{\\smash{\\copy%d}\\hss}", box_num))
            end

            -- New page for second half
            tex.print("\\newpage")
            tex.print(cmd_dim)
            tex.print(cmd_dim_h)

            -- Output second half
            tex.print("\\par\\nointerlineskip")
            if right_first then
                -- 左半页：不移动
                tex.print(string.format("\\noindent\\hbox to 0pt{\\smash{\\copy%d}\\hss}", box_num))
            else
                -- 右半页：将内容左移
                tex.print(string.format("\\noindent\\kern-%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}", target_w_pt,
                    box_num))
            end

            if i < total_pages - 1 then
                tex.print("\\newpage")
            end
        end
    else
        -- Normal mode: output pages as-is
        for i = 0, total_pages - 1 do
            tex.print(string.format("\\directlua{vertical.load_page(%d, %d)}", box_num, i))
            tex.print("\\par\\nointerlineskip")
            tex.print(string.format("\\noindent\\hfill\\box%d", box_num))
            if i < total_pages - 1 then
                tex.print("\\newpage")
            end
        end
    end

    -- Clear registries that are no longer needed (they were only used during prepare_grid)
    -- This recovers memory for sidenotes and floating boxes immediately.
    sidenote.clear_registry()
    textbox.clear_registry()
end

--- Final cleanup function to be called at the end of the document
-- This safely flushes all remaining nodes in registries and clears tables
function vertical.cleanup()
    local glyph_id = node.id("glyph")
    local before = node.count(glyph_id)
    if utils.debug_log then utils.debug_log(string.format("[core] Performing cleanup. Glyphs before: %d", before)) end

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

    local after = node.count(glyph_id)
    if utils.debug_log then utils.debug_log(string.format("[core] Cleanup finished. Glyphs after: %d", after)) end

    -- Write to log even if debug is off
    if texio and texio.write_nl then
        texio.write_nl("log", string.format("[Guji-Cleanup] Glyph count: %d -> %d", before, after))
    end
end

-- CRITICAL: Ensure the cleanup function is in the global vertical table
_G.vertical = _G.vertical or {}
_G.vertical.cleanup = vertical.cleanup

-- Return module
return vertical
