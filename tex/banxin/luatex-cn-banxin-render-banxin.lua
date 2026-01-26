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
-- render_banxin.lua - 版心（鱼尾）绘制模块
-- ============================================================================
-- 文件名: render_banxin.lua (原 banxin.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
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
--      │   ├─ upper_height = total_height × upper_ratio
--      │   ├─ middle_height = total_height × middle_ratio
--      │   └─ 返回两条分隔线的 PDF literal
--      ├─ 插入分隔线节点
--      └─ 调用 text_position.create_vertical_text() 绘制文字
--      ↓
--   返回更新后的节点链（p_head）
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')
local text_position = package.loaded['vertical.luatex-cn-vertical-render-position'] or
    require('vertical.luatex-cn-vertical-render-position')
local yuwei = package.loaded['banxin.luatex-cn-banxin-render-yuwei'] or require('banxin.luatex-cn-banxin-render-yuwei')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

--- 绘制完整的版心列
-- 版心被分为 3 个区域，区域之间有水平分隔线
--
-- 区域布局（从上到下）:
-- ┌─────────────┐
-- │    Upper    │  (例如 65.8mm) - 包含版心文字（鱼尾文字）
-- ├─────────────┤  ← 分隔线 1
-- │   Middle    │  (例如 131.2mm)
-- ├─────────────┤  ← 分隔线 2
-- │    Lower    │  (例如 36.2mm)
-- └─────────────┘
--
-- @param params (table) 绘制参数:
--   - x (number) X 坐标 (sp, 左边缘)
--   - y (number) Y 坐标 (sp, 顶边缘，向下为负)
--   - width (number) 宽度 (sp)
--   - total_height (number) 总高度 (sp)
--   - upper_ratio (number) 第一区域高度比例 (例如 0.28)
--   - middle_ratio (number) 第二区域高度比例 (例如 0.56)
--   - lower_ratio (number) 第三区域高度比例 (例如 0.16)
--   - color_str (string) RGB 颜色字符串 (例如 "0.7 0.4 0.3")
--   - border_thickness (number) 边线厚度 (sp)
--   - book_name (string) 可选，在第一区域显示的文字（书名文字）
--   - font_size (number) 版心文字及其它信息的字体大小 (sp)
--   - shift_y (number) 定位用的垂直偏移（含内边距和外边框）
-- @return (table) 包含以下内容的表:
--   - literals: 包含线条 PDF literal 字符串的数组
--   - upper_height: 第一区域高度（用于文字定位）
local function draw_banxin(params)
    local x = params.x or 0
    local y = params.y or 0
    local width = params.width or 0
    local total_height = params.total_height or 0
    local r1 = params.upper_ratio or 0.28  -- 65.8 / 233.2 ≈ 0.28
    local r2 = params.middle_ratio or 0.56 -- 131.2 / 233.2 ≈ 0.56
    local r3 = 1 - r1 - r2
    local color_str = params.color_str or "0 0 0"
    local b_thickness = params.border_thickness or 26214 -- 0.4pt default
    local book_name = params.book_name or ""
    local font_size = params.font_size or 655360         -- 10pt default
    local shift_y = params.shift_y or 0
    local lower_yuwei_enabled = params.lower_yuwei
    if lower_yuwei_enabled == nil then lower_yuwei_enabled = true end -- Default to true

    -- Calculate section heights
    local upper_height = total_height * r1
    local middle_height = total_height * r2
    local lower_height = total_height * r3

    local literals = {}

    -- Convert to big points
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    local width_bp = width * sp_to_bp
    local b_thickness_bp = b_thickness * sp_to_bp

    -- Calculate Y positions for dividing lines (y is at top, going negative)
    local div1_y = y - upper_height
    local div2_y = div1_y - middle_height
    local div1_y_bp = div1_y * sp_to_bp
    local div2_y_bp = div2_y * sp_to_bp

    -- Draw horizontal dividing lines (only if enabled)
    if params.banxin_divider ~= false then
        -- Draw first horizontal dividing line (between upper and middle)
        local div1_line = string.format(
            "q %.2f w %s RG %.4f %.4f m %.4f %.4f l S Q",
            b_thickness_bp, color_str,
            x_bp, div1_y_bp,
            x_bp + width_bp, div1_y_bp
        )
        table.insert(literals, div1_line)

        -- Draw second horizontal dividing line (between middle and lower)
        local div2_line = string.format(
            "q %.2f w %s RG %.4f %.4f m %.4f %.4f l S Q",
            b_thickness_bp, color_str,
            x_bp, div2_y_bp,
            x_bp + width_bp, div2_y_bp
        )
        table.insert(literals, div2_line)
    end

    -- Yuwei dimensions:
    -- edge_height: height of the side edges (shorter)
    -- notch_height: distance from top to V-tip (longer, includes the V portion)
    local edge_h = width * 0.39
    local notch_h = width * 0.17
    local yuwei_gap = 65536 * 3.7 -- 10pt gap from dividing lines

    local yuwei_x = x             -- Left edge of column
    -- Draw upper yuwei (上鱼尾) in section 2 (if enabled)
    if params.upper_yuwei ~= false then
        local yuwei_y = div1_y - yuwei_gap -- 10pt below the first dividing line

        -- Upper yuwei (上鱼尾) - notch at bottom, opening downward
        local upper_yuwei = yuwei.draw_yuwei({
            x = yuwei_x,
            y = yuwei_y,
            width = width,
            edge_height = edge_h,
            notch_height = notch_h,
            style = "black",
            direction = 1,                  -- Notch at bottom (上鱼尾)
            color_str = color_str,
            extra_line = true,              -- Draw extra line below V-tip
            border_thickness = b_thickness, -- Use same thickness as border
        })
        table.insert(literals, upper_yuwei)
    end

    -- Lower yuwei (下鱼尾) - notch at top, opening upward (mirror of upper)
    -- Positioned at the bottom of section 2, 10pt above the second dividing line
    -- Only draw if enabled
    if lower_yuwei_enabled then
        local lower_yuwei_y = div2_y + notch_h + yuwei_gap -- 10pt above div2
        local lower_yuwei = yuwei.draw_yuwei({
            x = yuwei_x,
            y = lower_yuwei_y,
            width = width,
            edge_height = edge_h,
            notch_height = notch_h,
            style = "black",
            direction = -1,                 -- Notch at top (下鱼尾)
            color_str = color_str,
            extra_line = true,              -- Draw extra line above V-tip
            border_thickness = b_thickness, -- Use same thickness as border
        })
        table.insert(literals, lower_yuwei)
    end

    -- Return literals and upper_height for text placement
    return {
        literals = literals,
        upper_height = upper_height,
    }
end

-- Note: create_text_glyphs has been replaced by text_position.create_vertical_text

--- 绘制完整的版心列，包括边框、分隔线、鱼尾和文字
-- 这是绘制版心列的主入口函数
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - x: 列左边缘 X 坐标 (sp)
--   - y: 列顶边缘 Y 坐标 (sp)
--   - width: 列宽 (sp)
--   - height: 列高 (sp)
--   - border_thickness: 边线厚度 (sp)
--   - color_str: RGB 颜色字符串
--   - upper_ratio: 第一区域高度比例
--   - middle_ratio: 第二区域高度比例
--   - lower_ratio: 第三区域高度比例
--   - book_name: 第一区域显示的文字
--   - shift_y: 文字定位用的垂直偏移 (sp)
-- @return (node) 更新后的头部
local function draw_banxin_column(p_head, params)
    local x = params.x
    local y = params.y
    local width = params.width
    local height = params.height

    utils.debug_log(string.format("[banxin] input y=%.2f height=%.2f padding_top=%.2f draw_border=%s",
        y / 65536, height / 65536, (params.b_padding_top or 0) / 65536, tostring(params.draw_border)))
    local border_thickness = params.border_thickness
    local color_str = params.color_str or "0 0 0"
    local shift_y = params.shift_y or 0

    local sp_to_bp = 0.0000152018
    local b_thickness_bp = border_thickness * sp_to_bp

    if params.draw_border then
        -- Draw column border (rectangle)
        local x_bp = x * sp_to_bp
        local y_bp = y * sp_to_bp
        local width_bp = width * sp_to_bp
        local height_bp = -height * sp_to_bp -- Negative because Y goes downward

        local border_literal = string.format(
            "q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q",
            b_thickness_bp, color_str, x_bp, y_bp, width_bp, height_bp
        )
        local border_node = node.new("whatsit", "pdf_literal")
        border_node.data = border_literal
        border_node.mode = 0
        utils.debug_log(string.format("[banxin] Border literal: %s", border_literal))
        p_head = D.insert_before(p_head, p_head, D.todirect(border_node))
    end

    -- Draw banxin dividers and text
    local banxin_params = {
        x = x,
        y = y,
        width = width,
        total_height = height,
        upper_ratio = params.upper_ratio or 0.28,
        middle_ratio = params.middle_ratio or 0.56,
        lower_ratio = params.lower_ratio or 0.16, -- Corrected parameter name
        color_str = color_str,
        border_thickness = border_thickness,
        book_name = params.book_name or "",
        font_size = params.font_size or height / 20, -- Reasonable default
        shift_y = shift_y,
        lower_yuwei = params.lower_yuwei,
        upper_yuwei = params.upper_yuwei,
        banxin_divider = params.banxin_divider,
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
    local book_name = params.book_name or ""
    if book_name ~= "" then
        local b_padding_top = params.b_padding_top or 0
        local b_padding_bottom = params.b_padding_bottom or 0

        -- Available height in upper section after subtracting padding and borders
        local effective_b = params.draw_border and border_thickness or 0
        local adj_height = banxin_result.upper_height - effective_b - b_padding_top - b_padding_bottom

        -- Calculate total text height to center it as a block
        -- Parse UTF-8 characters to count them
        local num_chars = 0
        for _ in book_name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            num_chars = num_chars + 1
        end

        -- Get font size from params or calculate from height
        local f_size = params.font_size
        if not f_size or f_size <= 0 then
            f_size = height / 20
        end

        -- Use book_name_grid_height if provided
        local grid_h = constants.to_dimen(params.book_name_grid_height)
        local total_text_height
        if grid_h and grid_h > 0 then
            total_text_height = grid_h * num_chars
        else
            -- Cap font size if it's too large for the available space
            if num_chars * f_size > adj_height then
                f_size = adj_height / num_chars
            end
            total_text_height = num_chars * f_size
        end

        -- Start Y calculation based on alignment
        local effective_b = params.draw_border and border_thickness or 0
        local block_y_top = y - effective_b - b_padding_top
        local y_start
        if params.book_name_align == "top" then
            y_start = block_y_top
        else
            -- Default: center
            y_start = block_y_top - (adj_height - total_text_height) / 2
        end

        utils.debug_log(string.format("[banxin] BookName='%s' fsize=%.2f height=%.2f adj_h=%.2f y_start=%.2f",
            book_name, f_size / 65536, total_text_height / 65536, adj_height / 65536, y_start / 65536))

        local glyph_chain = text_position.create_vertical_text(book_name, {
            x = x,
            y_top = y_start,
            width = width,
            height = total_text_height,
            num_cells = num_chars,
            v_align = "center",
            h_align = "center",
            font_size = f_size,
        })
        if glyph_chain then
            utils.debug_log("[banxin] Book name glyph chain created and centered.")
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

    -- Insert chapter title in section 2 (between yuwei decorations)
    local chapter_title = params.chapter_title or ""
    if chapter_title ~= "" then
        local b_padding_top = params.b_padding_top or 0
        local chapter_top_margin = params.chapter_title_top_margin or (65536 * 40) -- 20pt default

        -- Middle section boundaries
        local upper_h = banxin_result.upper_height
        local middle_h = height * (params.middle_ratio or 0.56)

        -- Yuwei dimensions (same as in draw_banxin)
        local edge_h = width * 0.39
        local notch_h = width * 0.17
        local yuwei_gap = 65536 * 3.7 -- 10pt gap from dividing lines
        local upper_yuwei_total = params.upper_yuwei ~= false and (yuwei_gap + edge_h + notch_h) or 0
        local lower_yuwei_total = params.lower_yuwei ~= false and (yuwei_gap + edge_h + notch_h) or 0

        -- Available space for chapter title in middle section
        -- Y position: starts below upper section, below upper yuwei, below top margin
        local middle_y_top = y - upper_h
        local chapter_y_top = middle_y_top - upper_yuwei_total - chapter_top_margin

        -- Available height: middle section height minus upper yuwei, lower yuwei, and margins
        local available_height = middle_h - upper_yuwei_total - lower_yuwei_total - chapter_top_margin

        if available_height > 0 then
            -- Manual splitting by newline or TeX style \\
            local raw_title = (chapter_title or ""):gsub("\\\\", "\n")
            local parts = {}
            for s in raw_title:gmatch("[^\n]+") do
                table.insert(parts, s)
            end

            if #parts > 0 then
                local n_cols = math.max(#parts, params.chapter_title_cols or 1)
                local col_width = width / n_cols

                -- Title height and font size
                local title_height = constants.to_dimen(params.chapter_title_grid_height) or available_height
                local title_font_size = params.chapter_title_font_size
                local font_scale = nil
                if (not title_font_size or title_font_size == "") and n_cols > 1 then
                    font_scale = 0.7 -- Reduced scale to ensure centering is visible
                end

                for i, sub_text in ipairs(parts) do
                    local c = i - 1 -- Column index (first part is rightmost)
                    local sub_x = x + (n_cols - 1 - c) * col_width

                    -- Determine horizontal alignment for multi-column layout:
                    -- Right column (first part) aligns right (toward outer edge)
                    -- Left column (last part) aligns left (toward outer edge)
                    local col_h_align = "center"
                    if n_cols > 1 then
                        if i == 1 then
                            col_h_align = "right" -- Rightmost column: align right (toward outer edge)
                        elseif i == #parts then
                            col_h_align = "left"  -- Leftmost column: align left (toward outer edge)
                        end
                    end

                    local chapter_chain = text_position.create_vertical_text(sub_text, {
                        x = sub_x,
                        y_top = chapter_y_top,
                        width = col_width,
                        height = title_height,
                        v_align = "center", -- Each char centered in its cell
                        h_align = col_h_align,
                        font_size = title_font_size,
                        font_scale = font_scale,
                    })
                    if chapter_chain then
                        local chain_tail = chapter_chain
                        while D.getnext(chain_tail) do chain_tail = D.getnext(chain_tail) end
                        D.setlink(chain_tail, p_head)
                        p_head = chapter_chain
                    end
                end
            end
        end
    end

    -- Insert page number in section 2 (middle) bottom right
    if params.page_number then
        local page_str = utils.to_chinese_numeral(params.page_number)
        if page_str ~= "" then
            -- Middle section boundaries
            local upper_h = banxin_result.upper_height
            local middle_h = height * (params.middle_ratio or 0.56)

            -- Position at the bottom of the middle section
            local middle_y_bottom = y - upper_h - middle_h

            -- Decoration (yuwei) bottom position
            local edge_h = width * 0.39
            local notch_h = width * 0.17
            local yuwei_gap = 65536 * 3.7
            local upper_yuwei_total = params.upper_yuwei and (yuwei_gap + edge_h + notch_h) or 0
            local lower_yuwei_total = params.lower_yuwei and (yuwei_gap + edge_h + notch_h) or 0

            -- Margin settings for page number (版心页码边距)
            local page_right_margin = 65536 * 2                                -- 2pt small right margin
            local page_bottom_margin = params.b_padding_bottom or (65536 * 15) -- Use config or default 15pt

            -- Calculate number of characters in page string
            local num_chars = 0
            for _ in page_str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                num_chars = num_chars + 1
            end

            -- Determine grid height per character
            local grid_h = constants.to_dimen(params.page_number_grid_height)
            if not grid_h or grid_h <= 0 then
                -- Default logic: if no grid height specified, use font size * 1.2 or fixed fallback
                -- Previous default was fixed (65536 * 30) total, which is too small for multiple chars.
                -- Let's use font size or a reasonable default per char.
                local fs = params.page_number_font_size or (65536 * 15)
                grid_h = fs * 1.2  -- 1.2 spacing
            end

            -- Calculate total container height
            local container_height = grid_h * num_chars

            -- Available bottom-right position
            -- Determine y_top, alignment and orientation for page number
            local p_v_align = "bottom"
            local p_h_align = "right"
            -- Fix: create_vertical_text expects y_top as the TOP edge of the box.
            -- We want the BOTTOM of the box to be at (middle_y_bottom + lower_yuwei_total + page_bottom_margin).
            -- So we must ADD container_height to the calculated bottom position.
            local page_y_top = middle_y_bottom + lower_yuwei_total + page_bottom_margin + container_height

            if params.page_number_align == "center" then
                p_v_align = "center"
                p_h_align = "center"
                -- Center in the middle section (between yuwei/dividers)
                local available_middle_h = middle_h - upper_yuwei_total - lower_yuwei_total
                -- Center: middle point is (bottom + available/2).
                -- To center rect of height H at point P, Top = P + H/2.
                local center_y = middle_y_bottom + lower_yuwei_total + available_middle_h / 2
                page_y_top = center_y + container_height / 2
            elseif params.page_number_align == "bottom-center" then
                p_v_align = "bottom"
                p_h_align = "center"
                -- Stay in the lower section
                page_y_top = middle_y_bottom + lower_yuwei_total + page_bottom_margin + container_height
            end

            local page_chain = text_position.create_vertical_text(page_str, {
                x = x,
                y_top = page_y_top,
                width = width - (params.page_number_align == "center" and 0 or page_right_margin),
                height = container_height, -- Use consistent container height
                v_align = p_v_align,
                h_align = p_h_align,
                font_size = params.page_number_font_size or (65536 * 15),
            })
            if page_chain then
                local chain_tail = page_chain
                while D.getnext(chain_tail) do chain_tail = D.getnext(chain_tail) end
                D.setlink(chain_tail, p_head)
                p_head = page_chain
            end
        end
    end

    if _G.vertical and _G.vertical.debug and _G.vertical.debug.enabled then
        if _G.vertical.debug.show_banxin then
            -- Draw a green dashed rectangle for the banxin column area
            p_head = utils.draw_debug_rect(p_head, nil, x, y, width, -height, "0 1 0 RG [2 2] 0 d")
        end
        if _G.vertical.debug.show_boxes then
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
-- 注册模块到 package.loaded
package.loaded['banxin.luatex-cn-banxin-render-banxin'] = banxin

-- Return module exports
return banxin
