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
-- render_page.lua - 坐标应用与视觉渲染（第三阶段主模块）
-- ============================================================================
-- 文件名: render_page.lua (原 render.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责排版流水线的第三阶段，将虚拟坐标应用到实际节点并绘制视觉元素：
--   1. 根据 layout_map 为每个节点设置 xoffset/yoffset（文字）或 kern/shift（块）
--   2. 插入负 kern 以抵消 TLT 方向盒子的水平推进
--   3. 调用子模块绘制边框、版心、背景
--   4. 文本框（Textbox）块由其内部逻辑渲染好后，在此模块仅作为整体块进行定位
--   5. 按页拆分节点流，生成多个独立的页面盒子
--   6. 可选绘制调试网格（蓝色框显示字符位置，红色框显示 textbox 块）
--
-- 【术语对照 / Terminology】
--   apply_positions   - 应用坐标位置（将虚拟坐标转为实际节点属性）
--   xoffset/yoffset   - 字形偏移（glyph 专用定位属性）
--   kern              - 字距调整（用于水平定位块级节点）
--   shift             - 盒子垂直偏移（box.shift 属性）
--   RTL               - 从右到左（Right-To-Left，竖排时列序）
--   page_nodes        - 页面节点分组（按页分组的节点列表）
--   p_head            - 页面头节点（当前页的节点链头部）
--   outer_shift       - 外边框偏移（外边框厚度+间距）
--
-- 【注意事项】
--   • Glyph 节点使用 xoffset/yoffset 定位，块级节点（HLIST/VLIST）使用 Kern+Shift
--   • RTL 列序转换：物理列号 = total_cols - 1 - 逻辑列号
--   • 绘制顺序严格控制：背景最底层 → 边框 → 版心 → 文字（通过 insert_before 实现）
--   • 所有 PDF 绘图指令使用 pdf_literal 节点（mode=0，用户坐标系）
--   • Kern 的 subtype=1 表示"显式 kern"，不会被后续清零（用于保护版心等特殊位置）
--   • 【重要】如果 xoffset/yoffset 计算错误（如 0 或 超出页面范围），文字将不可见
--   • 【重要】PDF literal 语法错误（如缺少 q/Q 对，或非法颜色值）会破坏整页渲染
--
-- 【整体架构 / Architecture】
--   输入: 节点流 + layout_map + 渲染参数（颜色、边框、页边距等）
--      ↓
--   apply_positions()
--      ├─ 按页分组节点（遍历 layout_map，根据 page 分组）
--      ├─ 对每一页：
--      │   ├─ 绘制背景色（render_background.draw_background）
--      │   ├─ 设置字体颜色（render_background.set_font_color）
--      │   ├─ 绘制外边框（render_border.draw_outer_border）
--      │   ├─ 绘制列边框（render_border.draw_column_borders，跳过版心列）
--      │   ├─ 绘制版心列（render_banxin.draw_banxin_column，含分隔线和文字）
--      │   ├─ 应用节点坐标
--      │   │   ├─ Glyph: 调用 render_position.calc_grid_position()
--      │   │   └─ Block: 使用 Kern 包裹 + Shift
--      │   └─ 可选：绘制调试网格
--      └─ 返回 result_pages[{head, cols}]
--      ↓
--   输出: 多个渲染好的页面（每页是一个 HLIST，dir=TLT）
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local content = package.loaded['core.luatex-cn-core-content'] or
    require('core.luatex-cn-core-content')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('luatex-cn-render-position')
local decorate_mod = package.loaded['decorate.luatex-cn-decorate'] or
    require('decorate.luatex-cn-decorate')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('render')
local page_mod = package.loaded['core.luatex-cn-core-page'] or
    require('core.luatex-cn-core-page')
local textbox_mod = package.loaded['core.luatex-cn-core-textbox'] or
    require('core.luatex-cn-core-textbox')


-- Internal functions for unit testing
local _internal = {}


-- 辅助函数：计算渲染上下文（尺寸、偏移、列数等）
-- For non-textbox (Content), reads static values from _G.content
-- For textbox, reads from passed ctx params
local function calculate_render_context(ctx)
    -- Unpack nested contexts
    local engine = ctx.engine
    local grid = ctx.grid
    local page = ctx.page
    local visual = ctx.visual
    local is_textbox = page.is_textbox

    -- Static values: from _G.content for Content, from ctx for textbox
    local border_thickness, half_thickness, ob_thickness_val, ob_sep_val
    local b_padding_top, b_padding_bottom
    local grid_width, grid_height

    if is_textbox then
        -- TextBox: use values from ctx (passed from main.lua)
        border_thickness = engine.border_thickness
        half_thickness = engine.half_thickness
        ob_thickness_val = page.ob_thickness
        ob_sep_val = page.ob_sep
        b_padding_top = engine.b_padding_top
        b_padding_bottom = engine.b_padding_bottom
        grid_width = grid.width
        grid_height = grid.height
    else
        -- Content: read static values from _G.content
        border_thickness = _G.content.border_thickness or 26214
        half_thickness = math.floor(border_thickness / 2)
        ob_thickness_val = _G.content.outer_border_thickness or (65536 * 2)
        ob_sep_val = _G.content.outer_border_sep or (65536 * 2)
        b_padding_top = _G.content.border_padding_top or 0
        b_padding_bottom = _G.content.border_padding_bottom or 0
        grid_width = grid.width   -- Still from grid (calculated in main.lua)
        grid_height = grid.height -- Still from grid (calculated in main.lua)
    end

    -- Dynamic values: always from ctx (calculated per-invocation in main.lua)
    local outer_shift = engine.outer_shift
    local shift_x = engine.shift_x
    local shift_y = engine.shift_y

    local interval = grid.n_column
    local p_cols = grid.cols
    local line_limit = grid.line_limit

    -- Visual params: from _G.content for Content, from ctx for textbox
    local vertical_align, background_rgb_str, text_rgb_str
    local border_shape, border_color_str, border_width, border_margin
    if is_textbox then
        vertical_align = visual.vertical_align or "center"
        background_rgb_str = utils.normalize_rgb(visual.bg_rgb)
        text_rgb_str = utils.normalize_rgb(visual.font_rgb)
        -- Border shape decoration parameters
        border_shape = visual.border_shape or "none"
        border_color_str = utils.normalize_rgb(visual.border_color) or "0 0 0"
        border_width = constants.to_dimen(visual.border_width) or (65536 * 0.4)
        border_margin = constants.to_dimen(visual.border_margin) or (65536 * 1)
    else
        vertical_align = _G.content.vertical_align or "center"
        background_rgb_str = utils.normalize_rgb(_G.content.background_color)
        text_rgb_str = utils.normalize_rgb(_G.content.font_color)
        border_shape = "none"
        border_color_str = nil
        border_width = 0
        border_margin = 0
    end

    -- Colors: border from engine (already normalized in main.lua)
    local b_rgb_str = engine.border_rgb_str

    return {
        border_thickness = border_thickness,
        half_thickness = half_thickness,
        ob_thickness_val = ob_thickness_val,
        ob_sep_val = ob_sep_val,
        outer_shift = outer_shift,
        shift_x = shift_x,
        shift_y = shift_y,
        interval = interval,
        p_cols = p_cols,
        line_limit = line_limit,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        b_rgb_str = b_rgb_str,
        background_rgb_str = background_rgb_str,
        text_rgb_str = text_rgb_str,
        grid_width = grid_width,
        grid_height = grid_height,
        vertical_align = vertical_align,
        -- TextFlow align default (per-node align from style stack takes precedence)
        textflow_align = (_G.jiazhu and _G.jiazhu.align) or "outward",
        -- Judou parameters from _G.judou global (set by judou.setup)
        judou_pos = (_G.judou and _G.judou.pos) or "right-bottom",
        judou_size = (_G.judou and _G.judou.size) or "1em",
        judou_color = (_G.judou and _G.judou.color) or "red",
        -- Border shape decoration parameters (textbox only)
        border_shape = border_shape,
        border_color_str = border_color_str,
        border_width = border_width,
        border_margin = border_margin,
    }
end

_internal.calculate_render_context = calculate_render_context

-- 辅助函数：将节点按页分组
local function group_nodes_by_page(d_head, layout_map, total_pages)
    local page_nodes = {}
    for p = 0, total_pages - 1 do
        page_nodes[p] = { head = nil, tail = nil, max_col = 0, max_row = 0 }
    end

    local t = d_head
    while t do
        local next_node = D.getnext(t)
        local pos = layout_map[t]
        D.setnext(t, nil)

        if pos then
            local p = pos.page or 0
            if page_nodes[p] then
                if not page_nodes[p].head then
                    page_nodes[p].head = t
                else
                    D.setnext(page_nodes[p].tail, t)
                end
                page_nodes[p].tail = t
                if pos.col > page_nodes[p].max_col then page_nodes[p].max_col = pos.col end
                -- Track max row for actual content height calculation
                -- Note: pos.row can be fractional (from distribute_rows), use math.ceil
                -- Note: pos.height is in sp (physical), NOT grid row count
                local row = pos.row or 0
                local row_ceil = math.ceil(row)
                if row_ceil > page_nodes[p].max_row then page_nodes[p].max_row = row_ceil end
            else
                node.flush_node(D.tonode(t))
            end
        else
            node.flush_node(D.tonode(t))
        end
        t = next_node
    end
    return page_nodes
end

_internal.group_nodes_by_page = group_nodes_by_page

-- 辅助函数：处理单个字形的定位
local function handle_glyph_node(curr, p_head, pos, params, ctx)
    -- vertical_align now comes from ctx (read from _G.content or params in calculate_render_context)
    local vertical_align = ctx.vertical_align or "center"
    local d = D.getfield(curr, "depth") or 0
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    local v_scale = pos.v_scale or 1.0

    -- column_aligns is textbox-specific, still comes from params.visual
    local h_align = "center"
    local visual = params.visual
    if visual and visual.column_aligns and visual.column_aligns[pos.col] then
        h_align = visual.column_aligns[pos.col]
    end

    local final_x, final_y = text_position.calc_grid_position(pos.col, pos.row,
        {
            width = w,
            height = h * v_scale,
            depth = d * v_scale,
            char = D.getfield(curr, "char"),
            font = D.getfield(curr, "font")
        },
        {
            grid_width = ctx.grid_width,
            grid_height = ctx.grid_height,
            total_cols = ctx.p_total_cols,
            shift_x = ctx.shift_x,
            shift_y = ctx.shift_y,
            v_align = vertical_align,
            h_align = h_align,
            half_thickness = ctx.half_thickness,
            sub_col = pos.sub_col,
            textflow_align = pos.textflow_align or ctx.textflow_align,
        }
    )

    -- Verbose glyph logging removed for performance and clarity
    -- debug.log("render", string.format("  [render] GLYPH char=%d [c:%.0f, r:%.2f] ...", ...))

    if v_scale == 1.0 then
        D.setfield(curr, "xoffset", final_x)
        D.setfield(curr, "yoffset", final_y)
    else
        -- Squeeze using PDF matrix
        local x_bp = final_x * utils.sp_to_bp
        local y_bp = final_y * utils.sp_to_bp
        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)

        -- Matrix: [1 0 0 v_scale x y]
        local literal_str = string.format("q 1 0 0 %.4f %.4f %.4f cm", v_scale, x_bp, y_bp)
        local n_start = utils.create_pdf_literal(literal_str)
        local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())

        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    end

    -- Insert negative kern to keep baseline position correct for next nodes
    local k = D.new(constants.KERN)
    D.setfield(k, "kern", -w)
    D.insert_after(p_head, curr, k)

    -- Apply font_color if stored in layout_map (Phase 2: General style preservation)
    -- This handles cross-page font_color preservation for all components (jiazhu, sidenote, etc.)
    local font_color = pos.font_color
    if font_color and font_color ~= "" then
        local rgb_str = utils.normalize_rgb(font_color)
        local color_cmd = utils.create_color_literal(rgb_str, false)  -- false = fill color (rg)
        local color_push = utils.create_pdf_literal("q " .. color_cmd)
        local color_pop = utils.create_pdf_literal("Q")

        p_head = D.insert_before(p_head, curr, color_push)
        D.insert_after(p_head, k, color_pop)  -- Insert after the kern
    end

    return p_head
end

_internal.handle_glyph_node = handle_glyph_node

-- 辅助函数：处理 HLIST/VLIST（块）的定位
local function handle_block_node(curr, p_head, pos, ctx)
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    local rtl_col_left = ctx.p_total_cols - (pos.col + (pos.width or 1))
    local final_x = rtl_col_left * ctx.grid_width + ctx.half_thickness + ctx.shift_x

    local final_y_top = -pos.row * ctx.grid_height - ctx.shift_y
    D.setfield(curr, "shift", -final_y_top + h)

    local k_pre = D.new(constants.KERN)
    D.setfield(k_pre, "kern", final_x)

    local k_post = D.new(constants.KERN)
    D.setfield(k_post, "kern", -(final_x + w))

    p_head = D.insert_before(p_head, curr, k_pre)
    D.insert_after(p_head, curr, k_post)
    return p_head
end

_internal.handle_block_node = handle_block_node

-- Expose decorate.handle_node for backward compatibility in tests
_internal.handle_decorate_node = decorate_mod.handle_node

-- 辅助函数：绘制调试网格/框
local function handle_debug_drawing(curr, p_head, pos, ctx)
    local show_me = false
    local color_str = "0 0 1 RG"

    if pos.is_block then
        if dbg.is_enabled() then
            show_me = true
            color_str = "1 0 0 RG"
        end
    else
        if dbg.is_enabled() then
            show_me = true
        end
    end

    if show_me then
        local _, tx_sp = text_position.calculate_rtl_position(pos.col, ctx.p_total_cols, ctx.grid_width,
            ctx.half_thickness, ctx.shift_x)
        local ty_sp = text_position.calculate_y_position(pos.row, ctx.grid_height, ctx.shift_y)
        local tw_sp = ctx.grid_width
        local th_sp = -ctx.grid_height

        if pos.sub_col and pos.sub_col > 0 then
            tw_sp = ctx.grid_width / 2
            if pos.sub_col == 1 then
                tx_sp = tx_sp + tw_sp
            end
        end

        if pos.is_block then
            tw_sp = pos.width * ctx.grid_width
            th_sp = -pos.height * ctx.grid_height
        end
        return utils.draw_debug_rect(p_head, curr, tx_sp, ty_sp, tw_sp, th_sp, color_str)
    end
    return p_head
end

_internal.handle_debug_drawing = handle_debug_drawing

-- 辅助函数：处理单个页面的所有节点
local function process_page_nodes(p_head, layout_map, params, ctx)
    local curr = p_head
    -- Initialize last_font_id with current fallback font
    ctx.last_font_id = ctx.last_font_id or params.font_id or font.current()
    while curr do
        local next_curr = D.getnext(curr)
        local id = D.getid(curr)

        if id == constants.GLYPH or id == constants.HLIST or id == constants.VLIST then
            local pos = layout_map[curr]
            if pos then
                if not pos.col or pos.col < 0 then
                    dbg.log(string.format("  [render] SKIP Node=%s ID=%d (invalid col=%s)", tostring(curr),
                        id, tostring(pos.col)))
                else
                    if id == constants.GLYPH then
                        local dec_id = D.get_attribute(curr, constants.ATTR_DECORATE_ID)
                        if dec_id and dec_id > 0 then
                            p_head = decorate_mod.handle_node(curr, p_head, pos, params, ctx, dec_id)
                            -- Remove the original marker node to prevent ghost rendering at (0,0)
                            p_head = D.remove(p_head, curr)
                            node.flush_node(D.tonode(curr))
                        else
                            -- Track the font from regular glyphs for decoration fallback
                            ctx.last_font_id = D.getfield(curr, "font")
                            p_head = handle_glyph_node(curr, p_head, pos, params, ctx)
                            if dbg.is_enabled() then
                                p_head = handle_debug_drawing(curr, p_head, pos, ctx)
                            end
                        end
                    else
                        p_head = handle_block_node(curr, p_head, pos, ctx)
                        if dbg.is_enabled() then
                            p_head = handle_debug_drawing(curr, p_head, pos, ctx)
                        end
                    end
                end
            elseif dbg.is_enabled() then
                -- CRITICAL DEBUG: If it has Jiazhu attribute but no pos, it's a bug!
                local has_jiazhu = (D.get_attribute(curr, constants.ATTR_JIAZHU) == 1)
                if has_jiazhu then
                    dbg.log(string.format("  [render] DISCARDED JIAZHU NODE=%s (not in layout_map!) char=%s",
                        tostring(curr), (id == constants.GLYPH and tostring(D.getfield(curr, "char")) or "N/A")))
                end
            end
        elseif id == constants.GLUE then
            local pos = layout_map[curr]
            if pos and pos.col and pos.col >= 0 then
                -- This is a positioned space (user glue with width)
                -- Zero out the natural glue width and insert kern for positioning
                local glue_width = D.getfield(curr, "width") or 0
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)

                -- Calculate grid position (same logic as glyph but simpler - no centering needed)
                local _, final_x = text_position.calculate_rtl_position(pos.col, ctx.p_total_cols, ctx.grid_width,
                    ctx.half_thickness, ctx.shift_x)
                local final_y = text_position.calculate_y_position(pos.row, ctx.grid_height, ctx.shift_y)

                -- Insert kern to move to correct position, then kern back
                local k_pre = D.new(constants.KERN)
                D.setfield(k_pre, "kern", final_x)
                local k_post = D.new(constants.KERN)
                D.setfield(k_post, "kern", -final_x)

                p_head = D.insert_before(p_head, curr, k_pre)
                D.insert_after(p_head, curr, k_post)

                dbg.log(string.format("  [render] GLUE (space) [c:%d, r:%.2f]", pos.col, pos.row))
                p_head = handle_debug_drawing(curr, p_head, pos, ctx)
            else
                -- Not positioned - zero out (baseline/lineskip glue)
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)
            end
        elseif id == constants.KERN then
            local subtype = D.getfield(curr, "subtype")
            if subtype ~= 1 then
                D.setfield(curr, "kern", 0)
            end
        elseif id == constants.WHATSIT then
            local uid = D.getfield(curr, "user_id")
            if uid == constants.SIDENOTE_USER_ID or uid == constants.FLOATING_TEXTBOX_USER_ID then
                p_head = D.remove(p_head, curr)
                node.flush_node(D.tonode(curr))
            end
        end
        curr = next_curr
    end

    return p_head
end

_internal.process_page_nodes = process_page_nodes

-- 辅助函数：定位浮动文本框
_internal.position_floating_box = textbox_mod.render_floating_box

-- 辅助函数：渲染单个页面
local function render_single_page(p_head, p_max_col, p_max_row, p, layout_map, params, ctx)
    if not p_head then return nil, 0 end

    local p_total_cols = p_max_col + 1
    local p_cols = ctx.p_cols
    -- Always enforce full page width to ensure correct RTL/SplitPage absolute positioning
    if p_cols > 0 and p_total_cols < p_cols then
        p_total_cols = p_cols
    end

    -- Actual content dimensions (for special border shapes)
    local actual_cols = p_max_col + 1
    local actual_rows = p_max_row + 1

    local grid_width = ctx.grid_width
    local grid_height = ctx.grid_height
    local border_thickness = ctx.border_thickness
    local line_limit = ctx.line_limit
    local b_padding_top = ctx.b_padding_top
    local b_padding_bottom = ctx.b_padding_bottom
    local grid = params.grid
    local engine = params.engine
    local page = params.page
    local plugins = params.plugins

    local draw_border = engine.draw_border
    local draw_outer_border = page.is_outer_border
    local shift_x = ctx.shift_x
    local outer_shift = ctx.outer_shift
    local b_rgb_str = ctx.b_rgb_str

    -- For TextBox: use actual content dimensions, not expanded page dimensions
    -- For regular content: use full page dimensions
    local content_width, content_height
    if page.is_textbox then
        content_width = (actual_cols > 0 and actual_cols or 1) * grid_width
        content_height = (actual_rows > 0 and actual_rows or 1) * grid_height
    else
        content_width = p_total_cols * grid_width
        content_height = line_limit * grid_height + b_padding_top + b_padding_bottom
    end
    local inner_width = content_width + border_thickness
    local inner_height = content_height + border_thickness

    -- Reserved columns (computed via engine_ctx helper function)
    local reserved_cols = grid.get_reserved_cols and grid.get_reserved_cols(p, p_total_cols) or {}

    -- Borders & Reserved Columns (Now handled by banxin plugin)

    if draw_border and p_total_cols > 0 then
        -- Column borders
        p_head = content.draw_column_borders(p_head, {
            total_cols = p_total_cols,
            grid_width = grid_width,
            grid_height = grid_height,
            line_limit = line_limit,
            border_thickness = border_thickness,
            b_padding_top = b_padding_top,
            b_padding_bottom = b_padding_bottom,
            shift_x = shift_x,
            outer_shift = outer_shift,
            border_rgb_str = b_rgb_str,
            banxin_cols = reserved_cols,
        })
    end

    -- Outer border
    if draw_outer_border and p_total_cols > 0 then
        p_head = content.draw_outer_border(p_head, {
            inner_width = inner_width,
            inner_height = inner_height,
            outer_border_thickness = ctx.ob_thickness_val,
            outer_border_sep = ctx.ob_sep_val,
            border_rgb_str = b_rgb_str,
        })
    end

    -- Colors & Background
    p_head = content.set_font_color(p_head, ctx.text_rgb_str)

    -- Special border shape decoration (rect / octagon / circle) for TextBox
    -- Use actual content size, not the expanded page dimensions
    local border_shape = ctx.border_shape
    local shape_width = actual_cols * grid_width
    local shape_height = actual_rows * grid_height

    -- Draw background: use shaped fill for octagon/circle, rectangular for others
    if border_shape == "octagon" and ctx.background_rgb_str then
        -- Octagon-shaped background
        local border_m = ctx.border_margin or 0
        p_head = content.draw_octagon_fill(p_head, {
            x = -border_m,
            y = border_m,
            width = shape_width + 2 * border_m,
            height = shape_height + 2 * border_m,
            color_str = ctx.background_rgb_str,
        })
    elseif border_shape == "circle" and ctx.background_rgb_str then
        -- Circle-shaped background
        local border_m = ctx.border_margin or 0
        p_head = content.draw_circle_fill(p_head, {
            cx = shape_width / 2,
            cy = -shape_height / 2,
            radius = math.max(shape_width, shape_height) / 2 + border_m,
            color_str = ctx.background_rgb_str,
        })
    else
        -- Rectangular background (default)
        p_head = page_mod.draw_background(p_head, {
            bg_rgb_str = ctx.background_rgb_str,
            inner_width = inner_width,
            inner_height = inner_height,
            outer_shift = outer_shift,
            is_textbox = page.is_textbox,
        })
    end

    -- Draw border frame
    if border_shape and border_shape ~= "none" then
        local border_color = ctx.border_color_str or ctx.b_rgb_str or "0 0 0"
        local border_w = ctx.border_width or (65536 * 0.4)
        local border_m = ctx.border_margin or 0

        if border_shape == "rect" then
            -- Rectangular frame: simple stroke rectangle
            p_head = content.draw_rect_frame(p_head, {
                x = -border_m,
                y = border_m,
                width = shape_width + 2 * border_m,
                height = shape_height + 2 * border_m,
                line_width = border_w,
                color_str = border_color,
            })
        elseif border_shape == "octagon" then
            p_head = content.draw_octagon_frame(p_head, {
                x = -border_m,
                y = border_m,
                width = shape_width + 2 * border_m,
                height = shape_height + 2 * border_m,
                line_width = border_w,
                color_str = border_color,
            })
        elseif border_shape == "circle" then
            p_head = content.draw_circle_frame(p_head, {
                cx = shape_width / 2,
                cy = -shape_height / 2,
                radius = math.max(shape_width, shape_height) / 2 + border_m,
                line_width = border_w,
                color_str = border_color,
            })
        end
    end

    -- Node positions
    -- Update context with page-specific total_cols
    local ctx_node = {}
    for k, v in pairs(ctx) do ctx_node[k] = v end
    ctx_node.p_total_cols = p_total_cols

    p_head = process_page_nodes(p_head, layout_map, params, ctx_node)

    -- Render Floating TextBoxes
    if plugins.floating_map then
        for _, item in ipairs(plugins.floating_map) do
            if item.page == p then
                p_head = textbox_mod.render_floating_box(p_head, item, params)
            end
        end
    end

    -- For TextBox: return actual content dimensions, not expanded page dimensions
    -- This ensures TextBox output box has correct dimensions in main document flow
    local return_cols = page.is_textbox and actual_cols or p_total_cols
    local return_rows = page.is_textbox and actual_rows or line_limit
    return D.tonode(p_head), return_cols, return_rows
end

_internal.render_single_page = render_single_page

-- @param head (node) 节点列表头部
-- @param layout_map (table) 从节点指针到 {col, row} 的映射
-- @param params (table) 渲染参数
-- @return (table) 页面信息数组 {head, cols}
local function apply_positions(head, layout_map, params)
    local d_head = D.todirect(head)

    local ctx = calculate_render_context(params)

    dbg.log(string.format("[render] apply_positions: border=%s, font=%s",
        tostring(params.border_rgb), tostring(params.font_rgb)))

    -- Group nodes by page
    local page_nodes = group_nodes_by_page(d_head, layout_map, params.total_pages)

    local result_pages = {}

    -- Process each page
    for p = 0, params.total_pages - 1 do
        local p_head = page_nodes[p].head
        local p_max_col = page_nodes[p].max_col
        local p_max_row = page_nodes[p].max_row
        local rendered_head, cols, rows = render_single_page(p_head, p_max_col, p_max_row, p, layout_map, params, ctx)
        if rendered_head then
            result_pages[p + 1] = { head = rendered_head, cols = cols, rows = rows }
        end
    end

    return result_pages
end

-- Create module table
local render = {
    apply_positions = apply_positions,
    _internal = _internal
}

-- Register module
package.loaded['core.luatex-cn-core-render-page'] = render
return render
