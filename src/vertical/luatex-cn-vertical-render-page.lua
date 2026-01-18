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
local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')
local hooks = package.loaded['luatex-cn-vertical-base-hooks'] or require('luatex-cn-vertical-base-hooks')
local border = package.loaded['luatex-cn-vertical-render-border'] or require('luatex-cn-vertical-render-border')
local background = package.loaded['luatex-cn-vertical-render-background'] or require('luatex-cn-vertical-render-background')
local text_position = package.loaded['luatex-cn-vertical-render-position'] or require('luatex-cn-vertical-render-position')



-- 辅助函数：处理单个字形的定位
local function handle_glyph_node(curr, p_head, pos, params, ctx)
    local vertical_align = params.vertical_align
    local d = D.getfield(curr, "depth") or 0
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    local h_align = "center"
    if params.column_aligns and params.column_aligns[pos.col] then
        h_align = params.column_aligns[pos.col]
    end

    local final_x, final_y = text_position.calc_grid_position(pos.col, pos.row, 
        { width = w, height = h, depth = d },
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
            jiazhu_align = ctx.jiazhu_align,
        }
    )
    D.setfield(curr, "xoffset", final_x)
    D.setfield(curr, "yoffset", final_y)
    
    if params.draw_debug then
        local font_id = D.getfield(curr, "font") or 0
        local font_data = font.getfont(font_id)
        local font_size = font_data and font_data.size or 0
        utils.debug_log(string.format("  [render] GLYPH char=%d [c:%.0f, r:%.2f, s:%s] xoff=%.2f yoff=%.2f w=%.2f h=%.2f fsize=%.2f",
            D.getfield(curr, "char"), pos.col, pos.row, tostring(pos.sub_col), final_x/65536, final_y/65536, w/65536, h/65536, font_size/65536))
    end
    
    local k = D.new(constants.KERN)
    D.setfield(k, "kern", -w)
    D.insert_after(p_head, curr, k)
    return p_head
end

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

-- 辅助函数：绘制调试网格/框
local function handle_debug_drawing(curr, p_head, pos, ctx)
    local show_me = false
    local color_str = "0 0 1 RG"
    if pos.is_block then
        if _G.vertical.debug.show_boxes then
            show_me = true
            color_str = "1 0 0 RG"
        end
    else
        if _G.vertical.debug.show_grid then
            show_me = true
        end
    end
    
    if show_me then
        local rtl_col_l = ctx.p_total_cols - (pos.col + (pos.width or 1))
        local tx_sp = (rtl_col_l * ctx.grid_width + ctx.half_thickness + ctx.shift_x)
        local ty_sp = (-pos.row * ctx.grid_height - ctx.shift_y)
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

-- 辅助函数：处理单个页面的所有节点
local function process_page_nodes(p_head, layout_map, params, ctx)
    local curr = p_head
    while curr do
        local next_curr = D.getnext(curr)
        local id = D.getid(curr)
        
        if id == constants.GLYPH or id == constants.HLIST or id == constants.VLIST then
            local pos = layout_map[curr]
            if pos then
                if not pos.col or pos.col < 0 then
                    if params.draw_debug then
                        utils.debug_log(string.format("  [render] SKIP Node=%s ID=%d (invalid col=%s)", tostring(curr), id, tostring(pos.col)))
                    end
                else
                    if id == constants.GLYPH then
                        p_head = handle_glyph_node(curr, p_head, pos, params, ctx)
                    else
                        p_head = handle_block_node(curr, p_head, pos, ctx)
                    end

                    if params.draw_debug then
                        p_head = handle_debug_drawing(curr, p_head, pos, ctx)
                    end
                end
            elseif params.draw_debug then
                -- CRITICAL DEBUG: If it has Jiazhu attribute but no pos, it's a bug!
                local has_jiazhu = (D.get_attribute(curr, constants.ATTR_JIAZHU) == 1)
                if has_jiazhu then
                    utils.debug_log(string.format("  [render] DISCARDED JIAZHU NODE=%s (not in layout_map!) char=%s", 
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
                local rtl_col = ctx.p_total_cols - 1 - pos.col
                local final_x = rtl_col * ctx.grid_width + ctx.half_thickness + ctx.shift_x
                local final_y = -pos.row * ctx.grid_height - ctx.shift_y
                
                -- Insert kern to move to correct position, then kern back
                local k_pre = D.new(constants.KERN)
                D.setfield(k_pre, "kern", final_x)
                local k_post = D.new(constants.KERN)
                D.setfield(k_post, "kern", -final_x)
                
                p_head = D.insert_before(p_head, curr, k_pre)
                D.insert_after(p_head, curr, k_post)
                
                if params.draw_debug then
                    utils.debug_log(string.format("  [render] GLUE (space) positioned at [c:%d, r:%.2f]", pos.col, pos.row))
                    p_head = handle_debug_drawing(curr, p_head, pos, ctx)
                end
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
            -- Keep WHATSIT nodes in the list for TikZ/other special content
            -- but REMOVE our internal anchors (Sidenote/FloatingBox) to avoid PDF errors
            local uid = D.getfield(curr, "user_id")
            if uid == constants.SIDENOTE_USER_ID or uid == constants.FLOATING_TEXTBOX_USER_ID then
                p_head = D.remove(p_head, curr)
                -- We don't need to free it here if D.remove doesn't, but let's be safe
                node.flush_node(D.tonode(curr))
            end
        end
        curr = next_curr
    end
    return p_head
end

-- 辅助函数：绘制侧批 (Sidenotes)
local function render_sidenotes(p_head, sidenote_nodes, params, ctx)
    if not sidenote_nodes then return p_head end
    
    local vertical_align = params.vertical_align
    
    -- Sidenote visual adjustments
    -- Shift relative to grid cell center?
    -- "Interval is equal to column width" -> Gap width = grid_width.
    -- We position in the gap.
    -- Calculating gap center:
    -- Gap between Col C and Col C+1 (Logical).
    -- If sidenote is at Col C (logical gap index):
    -- The gap is physically strictly between logical cols.
    
    -- In layout logic (sidenote.lua), we used the Gap Index.
    -- Gap[C] is between Col C and Col C+1? No, we used standard logic.
    -- Let's assume standard grid positioning first. 
    -- Sidenote.lua logic: `curr_c` was incremented. It treats cols as grid slots.
    -- So we just render at `pos.col` / `pos.row`.
    
    -- However, sidenotes are usually smaller and red.
    -- We need to ensure font color is set? 
    -- The \SidePizhu command already wraps content in \color{red}, so nodes have color attributes (if using color package) or just rely on state.
    -- But since we inject nodes into a list where color stack might be different...
    -- Actually, \whatsit color stack nodes are inside the list `sidenote.registry`.
    -- So they should carry their own color.
    
    -- Sidenote offset: In RTL vertical layout, columns go from right (col 0) to left
    -- The gap/margin between columns is on the RIGHT side of each column (higher x in physical coords)
    -- We shift sidenotes by a full grid_width to place them in the inter-column gap
    -- This effectively places the sidenote in the "gap column" to the right of the anchor column
    local sidenote_x_offset = ctx.grid_width * 0.9

    -- Iterate backwards to preserve order when using insert_before at head
    for i = #sidenote_nodes, 1, -1 do
        local item = sidenote_nodes[i]
        local curr = item.node
        -- Detach from old list to prevent side effects
        D.setnext(curr, nil)

        -- Insert at head of page list (simple, valid because positions are absolute)
        -- Note: this reverses list order relative to original string if we just prepend.
        -- But since we position absolutely, it only affects z-order.
        if not p_head then
            p_head = curr
        else
            p_head = D.insert_before(p_head, p_head, curr)
        end

        local pos = {
            col = item.col,
            row = item.row,
            sidenote_offset = sidenote_x_offset,  -- Additional x offset for gap positioning
        }
        
        -- Link node into list (insert at head or tail? List order matters for drawing order)
        -- Insert at head is safer for positioning calculations if we use absolute kerns.
        -- But background is at head. We should insert after background, or just use separate accumulator?
        -- `p_head` is the main list.
        
        local id = D.getid(curr)

        if id == constants.GLYPH then
            -- For sidenotes, we need to apply the offset
            -- Calculate position manually with offset
            local d = D.getfield(curr, "depth") or 0
            local h = D.getfield(curr, "height") or 0
            local w = D.getfield(curr, "width") or 0

            local rtl_col = ctx.p_total_cols - 1 - pos.col
            -- Position on the RIGHT boundary of the column (between pos.col and pos.col-1)
            -- Right boundary X = (rtl_col + 1) * grid_width
            -- We center the sidenote on this boundary
            local boundary_x = (rtl_col + 1) * ctx.grid_width + ctx.half_thickness + ctx.shift_x
            local final_x = boundary_x - (w / 2)

            local char_total_height = h + d
            local effective_grid_height = ctx.grid_height
            if item.metadata and item.metadata.grid_height then
                effective_grid_height = tonumber(item.metadata.grid_height) or ctx.grid_height
            end

            -- Use effective_grid_height for the cell height centering
            -- Note: pos.row is fractional main rows, so pos.row * ctx.grid_height gives absolute Y
            local final_y = -pos.row * ctx.grid_height - (effective_grid_height + char_total_height) / 2 + d - ctx.shift_y

            -- Apply user y-offset from metadata (REMOVED: Now handled in positioning stage)
            -- final_y = final_y - (item.metadata.yoffset or 0)

            D.setfield(curr, "xoffset", final_x)
            D.setfield(curr, "yoffset", final_y)

            local k = D.new(constants.KERN)
            D.setfield(k, "kern", -w)
            D.insert_after(p_head, curr, k)
        elseif id == constants.HLIST or id == constants.VLIST then
            p_head = handle_block_node(curr, p_head, pos, ctx)
        else
            -- Glue/Kern? Skip for sidenotes
            if id == constants.GLUE then
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)
            end
        end
        
        if params.draw_debug then
            p_head = handle_debug_drawing(curr, p_head, pos, ctx)
        end
    end
    
    return p_head
end
-- @param head (node) 节点列表头部
-- @param layout_map (table) 从节点指针到 {col, row} 的映射
-- @param params (table) 渲染参数
-- @return (table) 页面信息数组 {head, cols}
local function apply_positions(head, layout_map, params)
    local d_head = D.todirect(head)

    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local total_pages = params.total_pages
    local vertical_align = params.vertical_align
    local draw_debug = params.draw_debug
    local draw_border = params.draw_border
    local b_padding_top = params.b_padding_top
    local b_padding_bottom = params.b_padding_bottom
    local line_limit = params.line_limit
    local border_thickness = params.border_thickness
    local draw_outer_border = params.draw_outer_border
    local outer_border_thickness = params.outer_border_thickness
    local outer_border_sep = params.outer_border_sep
    local n_column = params.n_column
    local page_columns = params.page_columns
    local border_rgb = params.border_rgb
    local bg_rgb = params.bg_rgb
    local font_rgb = params.font_rgb

    local half_thickness = math.floor(border_thickness / 2)
    local ob_thickness_val = (outer_border_thickness or (65536 * 2))
    local ob_sep_val = (outer_border_sep or (65536 * 2))

    local outer_shift = draw_outer_border and (ob_thickness_val + ob_sep_val) or 0
    -- Only add border padding to shift_y when border is actually drawn
    local border_shift = draw_border and (border_thickness + b_padding_top) or 0
    local shift_x = (params.shift_x and params.shift_x ~= 0) and params.shift_x or outer_shift
    local shift_y = (params.shift_y and params.shift_y ~= 0) and params.shift_y or (outer_shift + border_shift)
    
    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)

    local b_rgb_str = utils.normalize_rgb(border_rgb) or "0.0000 0.0000 0.0000"
    local background_rgb_str = utils.normalize_rgb(bg_rgb)
    local text_rgb_str = utils.normalize_rgb(font_rgb)
    
    if draw_debug then
        utils.debug_log(string.format("[render] apply_positions: border_rgb=%s -> %s, font_size=%s", 
            tostring(border_rgb), tostring(b_rgb_str), tostring(params.font_size)))
    end

    -- Group nodes by page
    local page_nodes = {}
    for p = 0, total_pages - 1 do
        page_nodes[p] = { head = nil, tail = nil, max_col = 0 }
    end

    local t = d_head
    while t do
        local next_node = D.getnext(t)
        local pos = layout_map[t]
        D.setnext(t, nil)

        if pos then
            local p = pos.page or 0
            if page_nodes[p] then
                if not page_nodes[p].head then page_nodes[p].head = t
                else D.setnext(page_nodes[p].tail, t) end
                page_nodes[p].tail = t
                if pos.col > page_nodes[p].max_col then page_nodes[p].max_col = pos.col end
            end
        end
        t = next_node
    end

    local result_pages = {}

    -- Process each page
    for p = 0, total_pages - 1 do
        local p_head = page_nodes[p].head
        if p_head then
            local p_max_col = page_nodes[p].max_col
            local p_total_cols = p_max_col + 1
            if draw_border and p_total_cols < p_cols then p_total_cols = p_cols end


            local inner_width = p_total_cols * grid_width + border_thickness
            local inner_height = line_limit * grid_height + b_padding_top + b_padding_bottom + border_thickness

            -- Reserved columns (via hooks - e.g., banxin)
            local reserved_cols = {}
            local banxin_on = params.banxin_on
            if draw_debug then
                print(string.format(">>> LUA PAGE: interval=%d, p_total_cols=%d, banxin_on=%s", interval, p_total_cols, tostring(banxin_on)))
            end
            if banxin_on and interval > 0 then
                for col = 0, p_total_cols - 1 do
                    if _G.vertical.hooks.is_reserved_column(col, interval) then
                        reserved_cols[col] = true
                        if draw_debug then
                            print(string.format(">>> LUA RESERVED COL: %d", col))
                        end
                    end
                end
            end

            -- Borders & Reserved Columns
            if banxin_on and interval > 0 then
                for col = 0, p_total_cols - 1 do
                    if reserved_cols[col] then
                        local rtl_col = p_total_cols - 1 - col
                        local effective_half = draw_border and half_thickness or 0
                        local reserved_x = rtl_col * grid_width + effective_half + shift_x
                        local reserved_y = -(effective_half + outer_shift)
                        local reserved_height = line_limit * grid_height + b_padding_top + b_padding_bottom
                        
                        p_head = _G.vertical.hooks.render_reserved_column(p_head, {
                            x = reserved_x, y = reserved_y, width = grid_width, height = reserved_height,
                            border_thickness = border_thickness, color_str = b_rgb_str,
                            upper_ratio = params.banxin_upper_ratio or 0.28,
                            middle_ratio = params.banxin_middle_ratio or 0.56,
                            lower_ratio = params.banxin_lower_ratio or 0.16,
                            book_name = params.book_name or "", shift_y = shift_y,
                            vertical_align = vertical_align,
                            b_padding_top = params.banxin_padding_top or 0,
                            b_padding_bottom = params.banxin_padding_bottom or 0,
                            lower_yuwei = params.lower_yuwei,
                            chapter_title = params.chapter_title or "",
                            chapter_title_top_margin = params.chapter_title_top_margin or (65536 * 20),
                            chapter_title_cols = params.chapter_title_cols or 1,
                            chapter_title_font_size = params.chapter_title_font_size,
                            chapter_title_grid_height = params.chapter_title_grid_height,
                            book_name_grid_height = params.book_name_grid_height,
                            book_name_align = params.book_name_align,
                            upper_yuwei = params.upper_yuwei,
                            banxin_divider = params.banxin_divider,
                            page_number_align = params.page_number_align,
                            page_number_font_size = params.page_number_font_size,
                            page_number = (params.start_page_number or 1) + p,
                            grid_width = grid_width,
                            grid_height = grid_height,
                            font_size = params.font_size,
                            draw_border = draw_border,
                        })
                    end
                end
            end

            if draw_border and p_total_cols > 0 then
                -- Column borders
                p_head = border.draw_column_borders(p_head, {
                    total_cols = p_total_cols, grid_width = grid_width, grid_height = grid_height,
                    line_limit = line_limit, border_thickness = border_thickness,
                    b_padding_top = b_padding_top, b_padding_bottom = b_padding_bottom,
                    shift_x = shift_x, outer_shift = outer_shift,
                    border_rgb_str = b_rgb_str, banxin_cols = reserved_cols,
                })
            end

            -- Outer border
            if draw_outer_border and p_total_cols > 0 then
                p_head = border.draw_outer_border(p_head, {
                    inner_width = inner_width, inner_height = inner_height,
                    outer_border_thickness = ob_thickness_val, outer_border_sep = ob_sep_val,
                    border_rgb_str = b_rgb_str,
                })
            end

            -- Colors & Background
            p_head = background.set_font_color(p_head, text_rgb_str)
            p_head = background.draw_background(p_head, {
                bg_rgb_str = background_rgb_str, paper_width = params.paper_width,
                paper_height = params.paper_height, margin_left = params.margin_left,
                margin_top = params.margin_top, inner_width = inner_width,
                inner_height = inner_height, outer_shift = outer_shift,
                is_textbox = params.is_textbox,
            })

            -- Node positions
            local ctx = {
                grid_width = grid_width, grid_height = grid_height,
                p_total_cols = p_total_cols, shift_x = shift_x, shift_y = shift_y,
                half_thickness = half_thickness,
                jiazhu_align = params.jiazhu_align or "outward",
            }
            p_head = process_page_nodes(p_head, layout_map, params, ctx)
            
            -- Render Sidenotes
            if params.sidenote_map then
                local sidenote_for_page = {}
                -- Flatten map for this page
                for _, sn_list in pairs(params.sidenote_map) do
                    for _, node_info in ipairs(sn_list) do
                        if node_info.page == p then
                            table.insert(sidenote_for_page, node_info)
                        end
                    end
                end
                if #sidenote_for_page > 0 then
                    if draw_debug then utils.debug_log("[render] Drawing " .. #sidenote_for_page .. " sidenote nodes on page " .. p) end
                    p_head = render_sidenotes(p_head, sidenote_for_page, params, ctx)
                end
            end

            -- Render Floating TextBoxes
            if params.floating_map then
                for _, item in ipairs(params.floating_map) do
                    if item.page == p then
                        local curr = D.todirect(item.box)
                        
                        -- Position: x, y are absolute from top-left (or whatever origin we use)
                        -- In our system, (shift_x, shift_y) is the top-left of the border area.
                        -- But let's assume item.x and item.y are relative to the paper origin for now, 
                        -- or relative to the context (shift_x, shift_y).
                        -- Given the user's "不影响正文排版", absolute positioning makes sense.
                        
                        -- We use Kern + Shift to position the box
                        local h = D.getfield(curr, "height") or 0
                        local w = D.getfield(curr, "width") or 0
                        
                        -- final_x starts from left
                        local final_x = item.x
                        -- final_y starts from top (0) going down (negative)
                        local final_y_top = -item.y
                        
                        -- Apply shift to center/top align properly
                        D.setfield(curr, "shift", -final_y_top + h)
                        
                        local k_pre = D.new(constants.KERN)
                        D.setfield(k_pre, "kern", final_x)
                        
                        local k_post = D.new(constants.KERN)
                        D.setfield(k_post, "kern", -(final_x + w))
                        
                        p_head = D.insert_before(p_head, p_head, k_pre)
                        D.insert_after(p_head, k_pre, curr)
                        D.insert_after(p_head, curr, k_post)
                        
                        if draw_debug then
                            utils.debug_log(string.format("[render] Floating Box at x=%.2f, y=%.2f", item.x/65536, item.y/65536))
                        end
                    end
                end
            end

            
            result_pages[p+1] = { head = D.tonode(p_head), cols = p_total_cols }
        end
    end

    return result_pages
end

-- Create module table
local render = {
    apply_positions = apply_positions,
}

-- Register module
package.loaded['luatex-cn-vertical-render-page'] = render
return render
