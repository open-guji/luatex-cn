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
-- render_page_process.lua - 节点处理子模块（从 render_page.lua 拆分）
-- ============================================================================
-- 文件名: luatex-cn-core-render-page-process.lua
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责单个页面中各节点的坐标赋值和渲染处理：
--   1. handle_glyph_node: 字形节点定位（xoffset/yoffset, 旋转, 缩放）
--   2. handle_block_node: 块级节点定位（kern + shift）
--   3. handle_debug_drawing: 调试网格绘制
--   4. process_page_nodes: 遍历页面所有节点并分发处理
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('luatex-cn-render-position')
local decorate_mod = package.loaded['decorate.luatex-cn-decorate'] or
    require('decorate.luatex-cn-decorate')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local helpers = package.loaded['core.luatex-cn-layout-grid-helpers'] or
    require('core.luatex-cn-layout-grid-helpers')

local dbg = debug.get_debugger('render')

-- ============================================================================
-- Node Handling Functions
-- ============================================================================

-- Reusable template tables for calc_grid_position (created once per page in process_page_nodes)
-- glyph_dims: per-glyph dimensions (width, height, depth, char, font)
-- glyph_params: page-constant fields pre-filled, per-glyph fields overwritten each call
local glyph_dims = {}
local glyph_params = {}

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

    -- Per-glyph h_align override (e.g. footnote markers use right-align)
    local halign_attr = D.get_attribute(curr, constants.ATTR_HALIGN)
    if halign_attr and halign_attr > 0 then
        if halign_attr == 1 then h_align = "left"
        elseif halign_attr == 3 then h_align = "right"
        end
    end

    -- Fill per-glyph fields into reusable templates (page-constant fields set in process_page_nodes)
    glyph_dims.width = w
    glyph_dims.height = h * v_scale
    glyph_dims.depth = d * v_scale
    glyph_dims.char = D.getfield(curr, "char")
    glyph_dims.font = D.getfield(curr, "font")

    glyph_params.v_align = vertical_align
    glyph_params.h_align = h_align
    glyph_params.sub_col = pos.sub_col
    glyph_params.textflow_align = pos.textflow_align or ctx.textflow_align
    glyph_params.cell_height = pos.cell_height
    glyph_params.cell_width = pos.cell_width
    glyph_params.y_sp = pos.y_sp

    local final_x, final_y = text_position.calc_grid_position(pos.col, glyph_dims, glyph_params)

    -- Check if glyph needs vertical rotation (font lacks vertical form)
    local needs_rotate = D.get_attribute(curr, constants.ATTR_VERT_ROTATE) == 1

    if needs_rotate then
        -- Rotate 90° CW and translate glyph to its grid position.
        -- The glyph is at text-space origin (xoffset=yoffset=0).
        -- Mode 0 pdf_literal wraps with T(node)/T(-node), so our matrix
        -- operates in node-relative space.
        -- We need matrix M = [0 -1 1 0 e f] such that glyph center
        -- (gc_x, gc_y) maps to intended center (fx+gc_x, fy+gc_y):
        --   e = fx + gc_x - gc_y
        --   f = fy + gc_x + gc_y
        local sp2bp = utils.sp_to_bp
        local fx = final_x * sp2bp
        local fy = final_y * sp2bp
        local gc_x = (w / 2) * sp2bp           -- glyph center x (from reference point)
        local gc_y = ((h - d) / 2) * sp2bp     -- glyph center y (from reference point)

        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)

        local e = fx + gc_x - gc_y
        local f = fy + gc_x + gc_y
        local literal_str = string.format(
            "q 0 -1 1 0 %.4f %.4f cm", e, f
        )
        local n_start = utils.create_pdf_literal(literal_str)
        local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())

        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    elseif v_scale == 1.0 then
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
        local color_cmd = utils.create_color_literal(rgb_str, false) -- false = fill color (rg)
        local color_push = utils.create_pdf_literal("q " .. color_cmd)
        local color_pop = utils.create_pdf_literal("Q")

        p_head = D.insert_before(p_head, curr, color_push)
        D.insert_after(p_head, k, color_pop) -- Insert after the kern
    end

    return p_head
end

-- 辅助函数：处理 HLIST/VLIST（块）的定位
local function handle_block_node(curr, p_head, pos, ctx)
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    local rtl_col_left = ctx.p_total_cols - (pos.col + (pos.width or 1))
    local final_x = text_position.get_column_x(rtl_col_left, ctx.col_geom)
        + ctx.half_thickness + ctx.shift_x

    local final_y_top = -pos.y_sp - ctx.shift_y
    D.setfield(curr, "shift", -final_y_top + h)

    local k_pre = D.new(constants.KERN)
    D.setfield(k_pre, "kern", final_x)

    local k_post = D.new(constants.KERN)
    D.setfield(k_post, "kern", -(final_x + w))

    p_head = D.insert_before(p_head, curr, k_pre)
    D.insert_after(p_head, curr, k_post)
    return p_head
end

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
        local _, tx_sp = text_position.calculate_rtl_position(pos.col, ctx.p_total_cols, ctx.col_geom,
            ctx.half_thickness, ctx.shift_x)
        local ty_sp = -pos.y_sp - (ctx.shift_y or 0)
        local tw_sp = text_position.get_column_width(pos.col, ctx.col_geom)
        local th_sp = -(pos.cell_height or ctx.grid_height)

        if pos.sub_col and pos.sub_col > 0 then
            tw_sp = ctx.col_geom.grid_width / 2
            if pos.sub_col == 1 then
                tx_sp = tx_sp + tw_sp
            end
        end

        if pos.is_block then
            tw_sp = pos.width * ctx.col_geom.grid_width
            th_sp = -pos.height * ctx.grid_height
        end
        return utils.draw_debug_rect(p_head, curr, tx_sp, ty_sp, tw_sp, th_sp, color_str)
    end
    return p_head
end

-- 辅助函数：处理单个页面的所有节点
local function process_page_nodes(p_head, layout_map, params, ctx)
    local curr = p_head
    -- Initialize last_font_id with current fallback font
    ctx.last_font_id = ctx.last_font_id or params.font_id or font.current()
    -- Initialize line mark collection for this page
    ctx.line_mark_entries = ctx.line_mark_entries or {}

    -- Initialize page-constant fields in glyph_params template (per-glyph fields set in handle_glyph_node)
    glyph_params.total_cols = ctx.p_total_cols
    glyph_params.shift_x = ctx.shift_x
    glyph_params.shift_y = ctx.shift_y
    glyph_params.half_thickness = ctx.half_thickness
    glyph_params.col_geom = ctx.col_geom
    glyph_params.body_font_size = ctx.body_font_size
    -- Phase 2.4: Prefer Free Mode col_widths_sp[page], fall back to TitlePage col_widths
    glyph_params.col_widths = ctx.page_col_widths_sp or (_G.content and _G.content.col_widths)

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
                            -- Collect line mark entries for batch rendering
                            if pos.line_mark_id then
                                local x_center
                                if pos.sub_col and pos.sub_col > 0 then
                                    local gw = D.getfield(curr, "width") or 0
                                    local gx = D.getfield(curr, "xoffset") or 0
                                    x_center = gx + gw / 2
                                end
                                ctx.line_mark_entries[#ctx.line_mark_entries + 1] =
                                    helpers.create_linemark_entry({
                                        group_id = pos.line_mark_id,
                                        col = pos.col,
                                        y_sp = pos.y_sp,
                                        cell_height = pos.cell_height,
                                        font_size = pos.font_size,
                                        sub_col = pos.sub_col,
                                        x_center_sp = x_center,
                                    })
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
                local final_x
                local cw = _G.content and _G.content.col_widths
                if cw and #cw > 0 then
                    local rtl_col = ctx.p_total_cols - 1 - pos.col
                    final_x = text_position.get_column_x_var(rtl_col, cw, ctx.p_total_cols)
                        + (ctx.half_thickness or 0) + (ctx.shift_x or 0)
                else
                    _, final_x = text_position.calculate_rtl_position(pos.col, ctx.p_total_cols, ctx.col_geom,
                        ctx.half_thickness, ctx.shift_x)
                end
                local final_y = -pos.y_sp - (ctx.shift_y or 0)

                -- Insert kern to move to correct position, then kern back
                local k_pre = D.new(constants.KERN)
                D.setfield(k_pre, "kern", final_x)
                local k_post = D.new(constants.KERN)
                D.setfield(k_post, "kern", -final_x)

                p_head = D.insert_before(p_head, curr, k_pre)
                D.insert_after(p_head, curr, k_post)

                dbg.log(string.format("  [render] GLUE (space) [c:%d, y_sp:%.0f]", pos.col, pos.y_sp or 0))
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

-- ============================================================================
-- Module Export
-- ============================================================================

local M = {
    handle_glyph_node = handle_glyph_node,
    handle_block_node = handle_block_node,
    handle_debug_drawing = handle_debug_drawing,
    handle_decorate_node = decorate_mod.handle_node,
    process_page_nodes = process_page_nodes,
}

package.loaded['core.luatex-cn-core-render-page-process'] = M
return M
