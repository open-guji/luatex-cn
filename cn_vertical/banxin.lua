-- ============================================================================
-- banxin.lua - 版心（鱼尾）绘制模块
-- ============================================================================
--
-- 【模块功能】
-- 本模块负责绘制古籍排版中的"版心"（中间的分隔列），包括：
--   1. 绘制版心列的边框（与普通列边框样式相同）
--   2. 在版心内绘制两条水平分隔线，将版心分为三个区域
--   3. 在版心第一区域绘制竖排文字（鱼尾文字，如书名、卷号等）
--   4. 支持自定义三个区域的高度比例（默认 0.28:0.56:0.16）
--
-- 【注意事项】
--   • 版心位置由 layout.lua 控制（每 n_column+1 列为版心）
--   • 版心文字使用 text_position.create_vertical_text 创建，确保与正文对齐一致
--   • 分隔线使用 PDF 的 moveto/lineto 指令（m/l/S）绘制
--   • 版心文字的 Y 坐标需要减去 shift_y（边框/外边框的累积偏移）
--
-- 【整体架构】
--   draw_banxin_column(p_head, params)
--      ├─ 绘制版心列边框（矩形）
--      ├─ 调用 draw_banxin() 计算分隔线位置
--      │   ├─ section1_height = total_height × ratio1
--      │   ├─ section2_height = total_height × ratio2
--      │   └─ 返回两条分隔线的 PDF literal
--      ├─ 插入分隔线节点
--      └─ 调用 text_position.create_vertical_text() 绘制文字
--      ↓
--   返回更新后的节点链（p_head）
--
-- Version: 0.2.0
-- Date: 2026-01-13
-- ============================================================================

-- Load dependencies
local constants = package.loaded['constants'] or require('constants')
local D = constants.D
local utils = package.loaded['utils'] or require('utils')
local text_position = package.loaded['text_position'] or require('text_position')
local yuwei = package.loaded['yuwei'] or require('yuwei')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

--- Draw the complete Banxin (版心) column
-- The Banxin is divided into 3 sections with horizontal lines between them
--
-- Section layout (top to bottom):
-- ┌─────────────┐
-- │  Section 1  │  (e.g., 65.8mm / 6.14cm) - Contains Banxin text (鱼尾文字)
-- ├─────────────┤  ← dividing line 1
-- │  Section 2  │  (e.g., 131.2mm / 12.25cm)
-- ├─────────────┤  ← dividing line 2
-- │  Section 3  │  (e.g., 36.2mm / 3.38cm)
-- └─────────────┘
--
-- @param params (table) Parameters for drawing:
--   - x (number) X position in scaled points (left edge)
--   - y (number) Y position in scaled points (top edge, going negative downward)
--   - width (number) Width in scaled points
--   - total_height (number) Total height in scaled points
--   - section1_ratio (number) Ratio for section 1 height (e.g., 0.28)
--   - section2_ratio (number) Ratio for section 2 height (e.g., 0.56)
--   - section3_ratio (number) Ratio for section 3 height (e.g., 0.16)
--   - color_str (string) RGB color string (e.g., "0.7 0.4 0.3")
--   - border_thickness (number) Border line thickness in scaled points
--   - banxin_text (string) Optional text to display in section 1 (鱼尾文字)
--   - font_size (number) Font size in scaled points for banxin text
--   - shift_y (number) Vertical shift for positioning (includes padding and outer border)
-- @return (table) Table with:
--   - literals: Array of PDF literal strings for lines
--   - section1_height: Height of section 1 (for text placement)
local function draw_banxin(params)
    local x = params.x or 0
    local y = params.y or 0
    local width = params.width or 0
    local total_height = params.total_height or 0
    local r1 = params.section1_ratio or 0.28  -- 65.8 / 233.2 ≈ 0.28
    local r2 = params.section2_ratio or 0.56  -- 131.2 / 233.2 ≈ 0.56
    local r3 = params.section3_ratio or 0.16  -- 36.2 / 233.2 ≈ 0.16
    local color_str = params.color_str or "0 0 0"
    local b_thickness = params.border_thickness or 26214 -- 0.4pt default
    local banxin_text = params.banxin_text or ""
    local font_size = params.font_size or 655360 -- 10pt default
    local shift_y = params.shift_y or 0

    -- Calculate section heights
    local section1_height = total_height * r1
    local section2_height = total_height * r2
    local section3_height = total_height * r3

    local literals = {}
    
    -- Convert to big points
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    local width_bp = width * sp_to_bp
    local b_thickness_bp = b_thickness * sp_to_bp
    
    -- Calculate Y positions for dividing lines (y is at top, going negative)
    local div1_y = y - section1_height
    local div2_y = div1_y - section2_height
    local div1_y_bp = div1_y * sp_to_bp
    local div2_y_bp = div2_y * sp_to_bp
    
    -- Draw first horizontal dividing line (between section 1 and 2)
    local div1_line = string.format(
        "q %.2f w %s RG %.4f %.4f m %.4f %.4f l S Q",
        b_thickness_bp, color_str,
        x_bp, div1_y_bp,
        x_bp + width_bp, div1_y_bp
    )
    table.insert(literals, div1_line)
    
    -- Draw second horizontal dividing line (between section 2 and 3)
    local div2_line = string.format(
        "q %.2f w %s RG %.4f %.4f m %.4f %.4f l S Q",
        b_thickness_bp, color_str,
        x_bp, div2_y_bp,
        x_bp + width_bp, div2_y_bp
    )
    table.insert(literals, div2_line)

    -- Draw upper yuwei (上鱼尾) in section 2
    -- The yuwei fills the entire column width and is placed at the top of section 2
    local yuwei_x = x                 -- Left edge of column
    local yuwei_gap = 65536 * 3.7      -- 10pt gap from dividing lines
    local yuwei_y = div1_y - yuwei_gap  -- 10pt below the first dividing line
    
    -- Yuwei dimensions:
    -- edge_height: height of the side edges (shorter)
    -- notch_height: distance from top to V-tip (longer, includes the V portion)
    local edge_h = width * 0.39   
    local notch_h = width * 0.17  
    
    -- Upper yuwei (上鱼尾) - notch at bottom, opening downward
    local upper_yuwei = yuwei.draw_yuwei({
        x = yuwei_x,
        y = yuwei_y,
        width = width,
        edge_height = edge_h,
        notch_height = notch_h,
        style = "black",
        direction = 1,                -- Notch at bottom (上鱼尾)
        color_str = color_str,
        extra_line = true,            -- Draw extra line below V-tip
        border_thickness = b_thickness, -- Use same thickness as border
    })
    table.insert(literals, upper_yuwei)
    
    -- Lower yuwei (下鱼尾) - notch at top, opening upward (mirror of upper)
    -- Positioned at the bottom of section 2, 10pt above the second dividing line
    local lower_yuwei_y = div2_y + notch_h + yuwei_gap  -- 10pt above div2
    local lower_yuwei = yuwei.draw_yuwei({
        x = yuwei_x,
        y = lower_yuwei_y,
        width = width,
        edge_height = edge_h,
        notch_height = notch_h,
        style = "black",
        direction = -1,               -- Notch at top (下鱼尾)
        color_str = color_str,
        extra_line = true,            -- Draw extra line above V-tip
        border_thickness = b_thickness, -- Use same thickness as border
    })
    table.insert(literals, lower_yuwei)

    -- Return literals and section1_height for text placement
    return {
        literals = literals,
        section1_height = section1_height,
    }
end

-- Note: create_text_glyphs has been replaced by text_position.create_vertical_text

--- Draw complete banxin column including border, dividers, and text
-- This is the main entry point for drawing a banxin column
-- @param p_head (node) Direct node head
-- @param params (table) Parameters:
--   - x: X position of column left edge (sp)
--   - y: Y position of column top edge (sp)
--   - width: Column width (sp)
--   - height: Column height (sp)
--   - border_thickness: Border line thickness (sp)
--   - color_str: RGB color string
--   - section1_ratio: Section 1 height ratio
--   - section2_ratio: Section 2 height ratio
--   - section3_ratio: Section 3 height ratio
--   - banxin_text: Text to display in section 1
--   - shift_y: Vertical shift for text positioning (sp)
-- @return (node) Updated head
local function draw_banxin_column(p_head, params)
    local x = params.x
    local y = params.y
    local width = params.width
    local height = params.height
    local border_thickness = params.border_thickness
    local color_str = params.color_str or "0 0 0"
    local shift_y = params.shift_y or 0

    local sp_to_bp = 0.0000152018
    local b_thickness_bp = border_thickness * sp_to_bp

    -- Draw column border (rectangle)
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    local width_bp = width * sp_to_bp
    local height_bp = -height * sp_to_bp  -- Negative because Y goes downward

    local border_literal = string.format(
        "q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q",
        b_thickness_bp, color_str, x_bp, y_bp, width_bp, height_bp
    )
    local border_node = node.new("whatsit", "pdf_literal")
    border_node.data = border_literal
    border_node.mode = 0
    p_head = D.insert_before(p_head, p_head, D.todirect(border_node))

    -- Draw banxin dividers and text
    local banxin_params = {
        x = x,
        y = y,
        width = width,
        total_height = height,
        section1_ratio = params.section1_ratio or 0.28,
        section2_ratio = params.section2_ratio or 0.56,
        section3_ratio = params.section3_ratio or 0.16,
        color_str = color_str,
        border_thickness = border_thickness,
        banxin_text = params.banxin_text or "",
        font_size = params.font_size or height / 20,  -- Reasonable default
        shift_y = shift_y,
    }
    local banxin_result = draw_banxin(banxin_params)

    -- Insert dividing lines
    for _, lit in ipairs(banxin_result.literals) do
        local lit_node = node.new("whatsit", "pdf_literal")
        lit_node.data = lit
        lit_node.mode = 0
        p_head = D.insert_before(p_head, p_head, D.todirect(lit_node))
    end

    -- Insert text using unified text_position module
    local banxin_text = params.banxin_text or ""
    if banxin_text ~= "" then
        local b_padding_top = params.b_padding_top or 0
        local b_padding_bottom = params.b_padding_bottom or 0
        local half_thickness = math.floor(border_thickness / 2)
        
        -- Available height in section 1 after subtracting padding and borders
        local adj_height = banxin_result.section1_height - border_thickness - b_padding_top - b_padding_bottom 
        
        local glyph_chain = text_position.create_vertical_text(banxin_text, {
            x = x,
            y_top = y - border_thickness - b_padding_top, -- Match main text shift
            width = width,
            height = adj_height,
            v_align = params.vertical_align or "top", -- Inherit alignment from document
            h_align = "center",
        })
        if glyph_chain then
            -- Find the tail of the glyph chain
            local chain_tail = glyph_chain
            while D.getnext(chain_tail) do
                chain_tail = D.getnext(chain_tail)
            end
            -- Insert the entire chain at the beginning
            D.setlink(chain_tail, p_head)
            p_head = glyph_chain
        end
    end

    if _G.cn_vertical and _G.cn_vertical.debug and _G.cn_vertical.debug.enabled then
        if _G.cn_vertical.debug.show_banxin then
            -- Draw a green dashed rectangle for the banxin column area
            p_head = utils.draw_debug_rect(p_head, nil, x, y, width, -height, "0 1 0 RG [2 2] 0 d")
        end
        if _G.cn_vertical.debug.show_boxes then
            -- Draw a red rectangle for the banxin column block
            p_head = utils.draw_debug_rect(p_head, nil, x, y, width, -height, "1 0 0 RG")
        end
    end

    return p_head
end

-- Create module table
local banxin = {
    draw_banxin = draw_banxin,
    draw_banxin_column = draw_banxin_column,
    -- Note: Text positioning is now handled by text_position module
}

-- Register module in package.loaded for require() compatibility
package.loaded['banxin'] = banxin

-- Return module exports
return banxin
