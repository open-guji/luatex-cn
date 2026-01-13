-- ============================================================================
-- render.lua - 坐标应用与视觉渲染（第三阶段）
-- ============================================================================
--
-- 【模块功能】
-- 本模块负责排版流水线的第三阶段，将虚拟坐标应用到实际节点并绘制视觉元素：
--   1. 根据 layout_map 为每个节点设置 xoffset/yoffset（文字）或 kern/shift（块）
--   2. 插入负 kern 以抵消 TLT 方向盒子的水平推进
--   3. 调用子模块绘制边框（border.lua）、版心（banxin.lua）、背景（background.lua）
--   4. 按页拆分节点流，生成多个独立的页面盒子
--   5. 可选绘制调试网格（蓝色框显示字符位置，红色框显示 textbox 块）
--
-- 【注意事项】
--   • Glyph 节点使用 xoffset/yoffset 定位，块级节点（HLIST/VLIST）使用 Kern+Shift
--   • RTL 列序转换：物理列号 = total_cols - 1 - 逻辑列号
--   • 绘制顺序严格控制：背景最底层 → 边框 → 版心 → 文字（通过 insert_before 实现）
--   • 所有 PDF 绘图指令使用 pdf_literal 节点（mode=0，用户坐标系）
--   • Kern 的 subtype=1 表示"显式 kern"，不会被后续清零（用于保护版心等特殊位置）
--
-- 【整体架构】
--   输入: 节点流 + layout_map + 渲染参数（颜色、边框、页边距等）
--      ↓
--   apply_positions()
--      ├─ 按页分组节点（遍历 layout_map，根据 page 分组）
--      ├─ 对每一页：
--      │   ├─ 绘制背景色（background.draw_background）
--      │   ├─ 设置字体颜色（background.set_font_color）
--      │   ├─ 绘制外边框（border.draw_outer_border）
--      │   ├─ 绘制列边框（border.draw_column_borders，跳过版心列）
--      │   ├─ 绘制版心列（banxin.draw_banxin_column，含分隔线和文字）
--      │   ├─ 应用节点坐标
--      │   │   ├─ Glyph: 调用 text_position.calc_grid_position()
--      │   │   └─ Block: 使用 Kern 包裹 + Shift
--      │   └─ 可选：绘制调试网格
--      └─ 返回 result_pages[{head, cols}]
--      ↓
--   输出: 多个渲染好的页面（每页是一个 HLIST，dir=TLT）
--
-- Version: 0.3.0
-- Date: 2026-01-12
-- ============================================================================

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['constants'] or require('constants')
local D = constants.D
local utils = package.loaded['utils'] or require('utils')
local border = package.loaded['border'] or require('border')
local banxin = package.loaded['banxin'] or require('banxin')
local background = package.loaded['background'] or require('background')
local text_position = package.loaded['text_position'] or require('text_position')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

--- Apply grid positions to nodes and render visual aids
-- Performs second-pass coordinate application, sets xoffset/yoffset for each glyph,
-- inserts negative kerns to fix PDF text selection, and draws debug grid/borders.
--
-- @param head (node) Head of node list
-- @param layout_map (table) Mapping from node pointer to {col, row}
-- @param grid_width (number) Grid column width in scaled points
-- @param grid_height (number) Grid row height in scaled points
-- @param total_cols (number) Total number of columns
-- @param vertical_align (string) Vertical alignment: "top", "center", or "bottom"
-- @param draw_debug (boolean) Whether to draw blue debug grid
-- @param draw_border (boolean) Whether to draw black column borders
-- @param b_padding_top (number) Extra padding at top of border in scaled points
-- @param b_padding_bottom (number) Extra padding at bottom of border in scaled points
-- @param line_limit (number) Maximum rows per column
-- @param n_column (number) Number of columns per page
-- @param page_columns (number) Total columns before a page break
-- @param border_rgb (string) RGB color for borders (e.g., "0 0 0")
-- @param bg_rgb (string) RGB color for background (e.g., "1 1 1")
-- @return (table) Array of page info {head, cols}
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

    -- Cached conversion factors for PDF literals
    local w_bp = grid_width * sp_to_bp
    local h_bp = -grid_height * sp_to_bp
    local border_thickness_val = tonumber(border_thickness) or 0
    local b_thickness_bp = border_thickness_val * sp_to_bp
    local half_thickness = math.floor(border_thickness_val / 2)
    
    local ob_thickness_val = (outer_border_thickness or (65536 * 2))
    local ob_thickness_bp = ob_thickness_val * sp_to_bp
    local ob_sep_val = (outer_border_sep or (65536 * 2))
    
    -- Global shift for all inner content
    local outer_shift = draw_outer_border and (ob_thickness_val + ob_sep_val) or 0
    local shift_x = outer_shift
    local shift_y = outer_shift + b_padding_top
    
    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)

    -- Normalize colors using utils module
    local b_rgb_str = utils.normalize_rgb(border_rgb) or "0.0000 0.0000 0.0000"
    local background_rgb_str = utils.normalize_rgb(bg_rgb)
    local text_rgb_str = utils.normalize_rgb(font_rgb)

    -- Group nodes by page
    local page_nodes = {}
    for p = 0, total_pages - 1 do
        page_nodes[p] = { head = nil, tail = nil, max_col = 0 }
    end

    local t = d_head
    while t do
        local next_node = D.getnext(t)
        local id = D.getid(t)
        
        -- Detach node from stream
        D.setnext(t, nil)
        
        local pos = layout_map[t]
        if pos then
            local p = pos.page or 0
            local col = pos.col
            
            if page_nodes[p] then
                if not page_nodes[p].head then
                    page_nodes[p].head = t
                else
                    D.setnext(page_nodes[p].tail, t)
                end
                page_nodes[p].tail = t
                if col > page_nodes[p].max_col then page_nodes[p].max_col = col end
            end
        else
            -- If node has no position (e.g. glue that was zeroed), discard it
            -- or we could attach it to page 0. Let's discard to be safe.
            -- node.flush_node(D.tonode(t))
        end
        
        t = next_node
    end

    local result_pages = {}

    -- Process each page
    for p = 0, total_pages - 1 do
        local p_head = page_nodes[p].head
        if not p_head then
            -- Create empty head if needed?
        else
            local p_max_col = page_nodes[p].max_col
            local p_total_cols = p_max_col + 1
            -- Ensure we have at least the minimum number of columns for a page if border is on
            if draw_border and p_total_cols < p_cols then p_total_cols = p_cols end

            local inner_width = p_total_cols * grid_width + border_thickness
            local inner_height = line_limit * grid_height + b_padding_top + b_padding_bottom + border_thickness

            -- Determine which columns are banxin columns
            local banxin_cols = {}
            if interval > 0 then
                for col = 0, p_total_cols - 1 do
                    if (col % (interval + 1)) == interval then
                        banxin_cols[col] = true
                    end
                end
            end

            -- Draw banxin columns using banxin module
            if draw_border and p_total_cols > 0 and interval > 0 then
                local half_thickness = math.floor(border_thickness / 2)
                for col = 0, p_total_cols - 1 do
                    if banxin_cols[col] then
                        local rtl_col = p_total_cols - 1 - col
                        local banxin_x = rtl_col * grid_width + half_thickness + shift_x
                        local banxin_y = -(half_thickness + outer_shift)
                        local banxin_height = line_limit * grid_height + b_padding_top + b_padding_bottom

                        p_head = banxin.draw_banxin_column(p_head, {
                            x = banxin_x,
                            y = banxin_y,
                            width = grid_width,
                            height = banxin_height,
                            border_thickness = border_thickness,
                            color_str = b_rgb_str,
                            section1_ratio = params.banxin_s1_ratio or 0.28,
                            section2_ratio = params.banxin_s2_ratio or 0.56,
                            section3_ratio = params.banxin_s3_ratio or 0.16,
                            banxin_text = params.banxin_text or "",
                            shift_y = shift_y,
                        })
                    end
                end
            end

            -- Draw regular column borders using border module (skip banxin columns)
            if draw_border and p_total_cols > 0 then
                p_head = border.draw_column_borders(p_head, {
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
                    banxin_cols = banxin_cols,
                })
            end

            -- Draw outer border using border module
            if draw_outer_border and p_total_cols > 0 then
                p_head = border.draw_outer_border(p_head, {
                    inner_width = inner_width,
                    inner_height = inner_height,
                    outer_border_thickness = ob_thickness_val,
                    outer_border_sep = ob_sep_val,
                    border_rgb_str = b_rgb_str,
                })
            end

            -- --- BOTTOM LAYER (Drawn first) ---
            -- Insert these last so they become the first in the stream

            -- Set Font Color using background module
            p_head = background.set_font_color(p_head, text_rgb_str)

            -- Draw background color using background module
            p_head = background.draw_background(p_head, {
                bg_rgb_str = background_rgb_str,
                paper_width = params.paper_width,
                paper_height = params.paper_height,
                margin_left = params.margin_left,
                margin_top = params.margin_top,
                inner_width = inner_width,
                inner_height = inner_height,
                outer_shift = outer_shift,
            })

            -- Apply positions to glyphs on this page
            local curr = p_head
            while curr do
                local next_curr = D.getnext(curr)
                local id = D.getid(curr)
                if id == constants.GLYPH or id == constants.HLIST or id == constants.VLIST then
                        local pos = layout_map[curr]
                        if pos then
                            local col = pos.col
                            local row = pos.row
                            local d = D.getfield(curr, "depth") or 0
                            local h = D.getfield(curr, "height") or 0
                            local w = D.getfield(curr, "width") or 0

                            if texio and texio.write_nl and draw_debug then
                                local type_str = (id == constants.GLYPH and "GLYPH" or "BLOCK")
                                texio.write_nl("  [render] Node=" .. tostring(curr) .. " " .. type_str .. " at p=" .. (pos.page or 0) .. " c=" .. col .. " r=" .. row .. " w=" .. (pos.width or 0) .. " h=" .. (pos.height or 0))
                            end
                        
                        if id == constants.GLYPH then
                            -- Use unified position calculation for glyphs (centering)
                            local final_x, final_y = text_position.calc_grid_position(col, row, 
                                { width = w, height = h, depth = d },
                                {
                                    grid_width = grid_width,
                                    grid_height = grid_height,
                                    total_cols = p_total_cols,
                                    shift_x = shift_x,
                                    shift_y = shift_y,
                                    v_align = vertical_align,
                                    half_thickness = half_thickness,
                                }
                            )
                            D.setfield(curr, "xoffset", final_x)
                            D.setfield(curr, "yoffset", final_y)
                            
                            -- Add negative kern to reset horizontal cursor for TLT parent
                            local k = D.new(constants.KERN)
                            D.setfield(k, "kern", -w)
                            D.insert_after(p_head, curr, k)
                        else
                            -- For HLIST/VLIST (Blocks), we use Kern (X) and Shift (Y)
                            -- xoffset/yoffset are NOT supported for blocks.
                            -- RTL column calculation for blocks:
                            -- Left edge of a block covering cols [col, col+width-1]
                            local rtl_col_left = p_total_cols - (pos.col + (pos.width or 1))
                            local final_x = rtl_col_left * grid_width + half_thickness + shift_x
                            
                            -- Top edge of the box should be at -row*grid_height - shift_y
                            -- In TLT box, baseline is at 0. Shift moves it down.
                            -- Baseline should be at -final_y + h
                            local final_y_top = -row * grid_height - shift_y
                            D.setfield(curr, "shift", -final_y_top + h)
                            
                            -- Position horizontally using Kern Wrap
                            local k_pre = D.new(constants.KERN)
                            D.setfield(k_pre, "kern", final_x)
                            
                            local k_post = D.new(constants.KERN)
                            -- Reset cursor to 0 for next node
                            D.setfield(k_post, "kern", -(final_x + w))
                            
                            -- Insert into list and update page head if needed
                            p_head = D.insert_before(p_head, curr, k_pre)
                            D.insert_after(p_head, curr, k_post)
                            -- next_curr remains the same (it's after k_post now)
                        end

                        if draw_debug then
                            local rtl_col_l = p_total_cols - (pos.col + (pos.width or 1))
                            local tx_bp = (rtl_col_l * grid_width + half_thickness + shift_x) * sp_to_bp
                            local ty_bp = (-row * grid_height - shift_y) * sp_to_bp
                            local dbg_w = w_bp
                            local dbg_h = h_bp
                            if pos.is_block then
                                dbg_w = pos.width * grid_width * sp_to_bp
                                dbg_h = -pos.height * grid_height * sp_to_bp
                            end
                            local color_str = pos.is_block and "1 0 0 RG" or "0 0 1 RG"
                            local literal = string.format("q 0.5 w %s 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q", color_str, tx_bp, ty_bp, dbg_w, dbg_h)
                            local nn = node.new("whatsit", "pdf_literal")
                            nn.data = literal
                            nn.mode = 0
                            p_head = D.insert_before(p_head, curr, D.todirect(nn))
                        end
                    end
                elseif id == constants.GLUE then
                    D.setfield(curr, "width", 0)
                    D.setfield(curr, "stretch", 0)
                    D.setfield(curr, "shrink", 0)
                elseif id == constants.KERN then
                    -- Skip explicit kerns (subtype 1) - these are protected (e.g., from banxin module)
                    local subtype = D.getfield(curr, "subtype")
                    if subtype ~= 1 then
                        D.setfield(curr, "kern", 0)
                    end
                end
                curr = next_curr
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

-- Register module in package.loaded for require() compatibility
package.loaded['render'] = render

-- Return module exports
return render
