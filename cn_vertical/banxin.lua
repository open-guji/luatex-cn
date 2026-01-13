-- banxin.lua
-- Chinese vertical typesetting module for LuaTeX - Banxin (版心) Drawing
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: banxin
-- Purpose: Draw the Banxin (center column/版心) with section dividers
-- Dependencies: none
-- Version: 0.1.0
-- Date: 2026-01-13

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

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
-- @return (table) Table with:
--   - literals: Array of PDF literal strings for lines
--   - text_nodes: Array of text node data for section 1 text
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

    -- Calculate section heights
    local section1_height = total_height * r1
    local section2_height = total_height * r2
    local section3_height = total_height * r3

    local literals = {}
    local text_nodes = {}
    
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

    -- Process banxin text for section 1
    -- Note: Text rendering needs to be done via glyph nodes in render.lua
    -- We just store the character data here
    if banxin_text and banxin_text ~= "" then
        -- Convert text to UTF-8 characters array
        local chars = {}
        for char in banxin_text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            table.insert(chars, char)
        end

        local num_chars = #chars
        if num_chars > 0 then
            -- Calculate character height to fit all characters in section1
            local char_height = section1_height / num_chars
            -- Calculate font size: 90% of char_height to leave some margin
            local actual_font_size = char_height * 0.9

            -- Position characters vertically in section 1
            for i, char in ipairs(chars) do
                -- Calculate Y position for this character
                -- Center each character in its allocated space
                local char_y = y - (i - 0.5) * char_height

                -- Store text node data
                table.insert(text_nodes, {
                    char = char,
                    x = x + width / 2,  -- Center horizontally in the column
                    y = char_y,
                    font_size = actual_font_size
                })
            end
        end
    end

    return {
        literals = literals,
        text_nodes = text_nodes
    }
end

-- Create module table
local banxin = {
    draw_banxin = draw_banxin,
}

-- Register module in package.loaded for require() compatibility
package.loaded['banxin'] = banxin

-- Return module exports
return banxin
