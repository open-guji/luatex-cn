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

-- luatex-cn-core-running-header.lua
-- Running header (书眉) + page number for the modern vertical book classes
-- (ltc-cn-vbook / ltc-tw-vbook), drawn from the eso-pic shipout hook.
--
-- Sides are physical: vertical books bind on the right, so an odd page is the
-- LEFT page of a spread (spine on its right, outer edge on its left) and an
-- even page is the RIGHT page (outer edge on its right). twoside=false treats
-- every page as odd.
--
-- Two anchors (header-anchor):
--   paper   - positions measured from the paper edge (page-number-x,
--             page-number-y, header-y), as before issue #198
--   content - positions follow the content area: the header column stands
--             header-sep outside the content area's edge with its top on the
--             content top; the page number shares that column with its foot on
--             the content bottom. header-y / page-number-y, when set, become
--             offsets from those edges (issue #198).

local page = require('core.luatex-cn-core-page')

local running_header = {}

local function pt(sp)
    return string.format("%.5fpt", (sp or 0) / 65536)
end

--- Settings, read from _G.vbook (set from TeX).
local function settings()
    local v = _G.vbook or {}
    return {
        anchor = v.header_anchor or "paper",
        header_position = v.header_position or "outer",
        number_position = v.page_number_position or "outer",
        header_sep = v.header_sep or (6 * 186467), -- 6mm
        header_y_set = v.header_y_set or false,
        number_y_set = v.page_number_y_set or false,
    }
end

--- Whether a header/number on `position` sits on the page's left edge.
-- @param position "outer" | "inner"
-- @param pg (number) page number
function running_header.on_left(position, pg)
    -- The outer edge is on the left exactly when the spine is on the right.
    local outer_left = page.spine_on_right(pg)
    if position == "inner" then return not outer_left end
    return outer_left
end

--- Compute the TeX \put coordinates (dimension expressions) for one page.
-- Returns a table {header_x, header_y, number_x, number_y}: x is the left edge
-- of the 2em-wide parbox; header_y is the (negative) y from the page top
-- (\AtPageUpperLeft), number_y the y from the page bottom (\AtPageLowerLeft).
-- The picture \put parser takes plain dimension sums, not parentheses.
-- @param pg (number) page number
-- @param s (table, optional) settings override (for tests)
function running_header.positions(pg, s)
    s = s or settings()
    local pos = {}
    if s.anchor == "content" then
        local p = _G.page or {}
        local w = p.paper_width or 0
        local m_left, m_right = page.get_effective_margins(pg)
        local function column_x(left)
            if left then
                return pt(m_left - s.header_sep) .. "-1em"
            end
            return pt(w - m_right + s.header_sep) .. "-1em"
        end
        local top, bottom = p.margin_top or 0, p.margin_bottom or 0
        pos.header_x = column_x(running_header.on_left(s.header_position, pg))
        pos.header_y = pt(-top) .. (s.header_y_set and "-\\cnVbookHeaderY" or "")
        -- Hang the header from the top edge of its first glyph (not from its
        -- baseline) so it lines up with the content top.
        pos.header_hang = true
        local number_y_off = s.number_y_set and "+\\cnVbookPageNumY" or ""
        if s.number_position == "center" then
            pos.number_x = pt(m_left + (w - m_left - m_right) / 2) .. "-1em"
            pos.number_y = pt(bottom - s.header_sep) .. number_y_off
        else
            pos.number_x = column_x(running_header.on_left(s.number_position, pg))
            pos.number_y = pt(bottom) .. number_y_off
        end
        return pos
    end
    -- Paper anchor: unchanged expressions (default output identical to 0.4.3)
    local left_x = "\\cnVbookPageNumX"
    local right_x = "\\paperwidth-\\cnVbookPageNumX-2em"
    pos.header_x = running_header.on_left(s.header_position, pg) and left_x or right_x
    pos.header_y = "-\\cnVbookHeaderY"
    if s.number_position == "center" then
        pos.number_x = "0.5\\paperwidth-1em"
    else
        pos.number_x = running_header.on_left(s.number_position, pg) and left_x or right_x
    end
    pos.number_y = "\\cnVbookPageNumY"
    return pos
end

--- Shipout hook body: print the header and page number for the page in
-- \ShipoutBox (a 补页样式=空白 blank page, issue #176, gets neither).
-- @param shipout_box (node) the box being shipped out
function running_header.emit(shipout_box)
    if page.is_plain_blank_page(shipout_box) then
        _G.vbook_skip_header_page = false
        return
    end
    local pg = tex.count[0]
    local style = _G.page and _G.page.number_style or "none"
    local header_on = _G.page and _G.page.header_enabled or false
    local skip = _G.vbook_skip_header_page or false
    local show_number = (style ~= "none" and style ~= "")
    local show_header = header_on and not skip

    _G.vbook_skip_header_page = false

    if not show_number and not show_header then return end

    local header_text = ""
    if show_header then
        local book = _G.metadata and _G.metadata.book_name or ""
        local chapter = _G.metadata and _G.metadata.chapter_title or ""
        -- odd (left) page: chapter title; even (right) page: book name
        header_text = page.spine_on_right(pg) and chapter or book
        if header_text == "" then show_header = false end
    end

    local pos = running_header.positions(pg)
    if show_header then
        tex.sprint("\\AtPageUpperLeft{\\put(\\LenToUnit{" .. pos.header_x .. "},\\LenToUnit{"
            .. pos.header_y .. "}){\\parbox[t]{2em}{" .. (pos.header_hang and "\\vspace{0pt}" or "")
            .. "\\centering\\fontsize{\\cnVbookHeaderFontSize}{13pt}"
            .. "\\selectfont\\DrawVerticalText{" .. header_text .. "}}}}")
    end
    if show_number then
        tex.sprint("\\AtPageLowerLeft{\\put(\\LenToUnit{" .. pos.number_x .. "},\\LenToUnit{"
            .. pos.number_y .. "}){\\parbox[b]{2em}{\\centering\\fontsize{\\cnVbookPageNumFontSize}{13pt}"
            .. "\\selectfont\\DrawVerticalPageNumber}}}")
    end
end

return running_header
