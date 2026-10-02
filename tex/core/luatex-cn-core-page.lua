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
-- luatex-cn-core-page.lua - 页面级渲染工具集
-- ============================================================================

local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')

local page = {}

-- Load split sub-module
page.split = require('core.luatex-cn-core-page-split')

_G.page = _G.page or {}
_G.page.current_page_number = _G.page.current_page_number or 1
_G.page.paper_height = _G.page.paper_height or 0
_G.page.paper_width = _G.page.paper_width or 0
_G.page.margin_top = _G.page.margin_top or 0
_G.page.margin_bottom = _G.page.margin_bottom or 0
_G.page.margin_left = _G.page.margin_left or 0
_G.page.margin_right = _G.page.margin_right or 0
-- Two-side margin support
_G.page.twoside = _G.page.twoside or false
_G.page.margin_inner = _G.page.margin_inner or 0
_G.page.margin_outer = _G.page.margin_outer or 0

-- Stack for saving/restoring page settings
_G.page.saved_stack = _G.page.saved_stack or {}

--- Setup global page parameters from TeX
-- @param params (table) Parameters from TeX keyvals
function page.setup(params)
    params = params or {}
    if params.paper_width then _G.page.paper_width = constants.to_dimen(params.paper_width) end
    if params.paper_height then _G.page.paper_height = constants.to_dimen(params.paper_height) end
    if params.margin_top then _G.page.margin_top = constants.to_dimen(params.margin_top) end
    if params.margin_bottom then _G.page.margin_bottom = constants.to_dimen(params.margin_bottom) end
    if params.margin_left then _G.page.margin_left = constants.to_dimen(params.margin_left) end
    if params.margin_right then _G.page.margin_right = constants.to_dimen(params.margin_right) end
    -- Two-side margin support
    if params.twoside ~= nil then _G.page.twoside = params.twoside end
    if params.margin_inner then _G.page.margin_inner = constants.to_dimen(params.margin_inner) end
    if params.margin_outer then _G.page.margin_outer = constants.to_dimen(params.margin_outer) end
end

--- Save current page settings to stack
function page.save()
    local saved = {
        paper_width = _G.page.paper_width,
        paper_height = _G.page.paper_height,
        margin_top = _G.page.margin_top,
        margin_bottom = _G.page.margin_bottom,
        margin_left = _G.page.margin_left,
        margin_right = _G.page.margin_right,
        -- Two-side margin state
        twoside = _G.page.twoside,
        margin_inner = _G.page.margin_inner,
        margin_outer = _G.page.margin_outer,
        -- Split page state
        split_enabled = _G.page.split.enabled,
        split_right_first = _G.page.split.right_first,
    }
    table.insert(_G.page.saved_stack, saved)
end

--- Restore page settings from stack
-- Returns the restored values so TeX can sync token lists
function page.restore()
    local saved = table.remove(_G.page.saved_stack)
    if saved then
        _G.page.paper_width = saved.paper_width
        _G.page.paper_height = saved.paper_height
        _G.page.margin_top = saved.margin_top
        _G.page.margin_bottom = saved.margin_bottom
        _G.page.margin_left = saved.margin_left
        _G.page.margin_right = saved.margin_right
        -- Restore two-side margin state
        _G.page.twoside = saved.twoside
        _G.page.margin_inner = saved.margin_inner
        _G.page.margin_outer = saved.margin_outer
        -- Restore split page state
        _G.page.split.enabled = saved.split_enabled
        _G.page.split.right_first = saved.split_right_first
        -- Apply the restored split state
        if saved.split_enabled then
            page.split.enable()
        else
            page.split.disable()
        end
    end
end

--- Get effective left/right margins for a given page number.
-- When inner/outer margins are set, they take priority over left/right.
-- twoside controls whether odd/even pages swap inner/outer.
-- @param page_num (number, optional) Page number (defaults to current_page_number)
-- @return m_left, m_right (sp values)
function page.get_effective_margins(page_num)
    local m_left = _G.page.margin_left or 0
    local m_right = _G.page.margin_right or 0
    local m_inner = _G.page.margin_inner or 0
    local m_outer = _G.page.margin_outer or 0
    if m_inner > 0 or m_outer > 0 then
        if _G.page.twoside then
            local pn = page_num or _G.page.current_page_number or 1
            if pn % 2 == 1 then
                m_left = m_inner
                m_right = m_outer
            else
                m_left = m_outer
                m_right = m_inner
            end
        else
            m_left = m_inner
            m_right = m_outer
        end
    end
    return m_left, m_right
end

--- Get restored dimension as string for TeX
-- @param key The dimension key (paper_width, paper_height, etc.)
-- @return String representation of the dimension in pt
function page.get_dim_str(key)
    local val = _G.page[key] or 0
    return string.format("%.5fpt", val / 65536)
end

--- Get split state for TeX
-- @param key The split key (enabled, right_first)
-- @return "true" or "false" string
function page.get_split_str(key)
    if key == "enabled" then
        return _G.page.split.enabled and "true" or "false"
    elseif key == "right_first" then
        return _G.page.split.right_first and "true" or "false"
    end
    return "false"
end

--- 绘制背景色矩形
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   - bg_rgb_str: 归一化的 RGB 颜色字符串
--   - paper_width: 纸张宽度 (sp, 可选)
--   - paper_height: 纸张高度 (sp, 可选)
--   - margin_left: 左边距 (sp, 可选)
--   - margin_top: 上边距 (sp, 可选)
--   - inner_width: 内部内容宽度 (sp, 备选)
--   - inner_height: 内部内容高度 (sp, 备选)
--   - outer_shift: 外边框偏移 (sp, 备选)
--   - is_textbox: 是否为文本框
-- @return (node) 更新后的头部
function page.draw_background(p_head, params)
    params = params or {}
    local sp_to_bp = utils.sp_to_bp

    -- Resolve parameters: use provided params OR read from TeX variables (luatex-cn-core-page.sty)
    -- Background Color: resolve and normalize
    -- For textboxes: only use explicitly passed bg_rgb_str (no fallback to page background)
    -- This prevents TextBox backgrounds from inheriting the page background color,
    -- which would cover overlays like yinzhang (seals)
    local bg_rgb_str = params.bg_rgb_str
    if not bg_rgb_str and not params.is_textbox then
        local tex_bg = utils.get_tex_tl("l__luatexcn_page_background_color_tl")
        bg_rgb_str = utils.normalize_rgb(tex_bg)
    end

    if not bg_rgb_str then
        return p_head
    end

    -- Paper Size and Margins
    local p_width = params.paper_width
    if not p_width or p_width == 0 then
        p_width = (_G.page and _G.page.paper_width and _G.page.paper_width > 0) and _G.page.paper_width or
            utils.parse_dim_to_sp(utils.get_tex_tl("l__luatexcn_page_paper_width_tl")) or 0
    end

    local p_height = params.paper_height
    if not p_height or p_height == 0 then
        p_height = (_G.page and _G.page.paper_height and _G.page.paper_height > 0) and _G.page.paper_height or
            utils.parse_dim_to_sp(utils.get_tex_tl("l__luatexcn_page_paper_height_tl")) or 0
    end

    local m_left = params.margin_left
    if not m_left or m_left == 0 then
        m_left = (_G.page and _G.page.margin_left and _G.page.margin_left > 0) and _G.page.margin_left or
            utils.parse_dim_to_sp(utils.get_tex_tl("l__luatexcn_page_margin_left_tl")) or 0
    end

    local m_top = params.margin_top
    if not m_top or m_top == 0 then
        m_top = (_G.page and _G.page.margin_top and _G.page.margin_top > 0) and _G.page.margin_top or
            utils.parse_dim_to_sp(utils.get_tex_tl("l__luatexcn_page_margin_top_tl")) or 0
    end

    -- Skip background rectangle for full pages (handled by \pagecolor).
    -- Still draw for textboxes, but they should use their own inner dimensions.
    if not params.is_textbox and p_width > 0 then
        return p_head
    end

    local tx_bp, ty_bp, tw_bp, th_bp

    -- Use inner dimensions for textboxes OR if paper size is not provided/valid
    if not params.is_textbox and p_width > 0 and p_height > 0 then
        -- Background covers the entire page
        -- The origin (0,0) in our box is at (margin_left, paper_height - margin_top)
        tx_bp = -m_left * sp_to_bp
        ty_bp = m_top * sp_to_bp
        tw_bp = p_width * sp_to_bp
        th_bp = -p_height * sp_to_bp
    else
        -- Fallback to box-sized background if paper size is not provided
        local inner_width = params.inner_width or 0
        local inner_height = params.inner_height or 0
        local outer_shift = params.outer_shift or 0
        tx_bp = 0
        ty_bp = 0
        tw_bp = (inner_width + outer_shift * 2) * sp_to_bp
        th_bp = -(inner_height + outer_shift * 2) * sp_to_bp
    end


    -- Draw filled rectangle for background
    local literal = utils.create_fill_rect_literal(bg_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
    p_head = utils.insert_pdf_literal(p_head, literal)

    return p_head
end

--- Output pages in normal mode (pages as-is)
-- @param box_num The TeX box number
-- @param total_pages Total number of pages to output
function page.output_pages(box_num, total_pages)
    local m_top = (_G.page and _G.page.margin_top) or 0
    local m_top_pt = m_top / 65536

    for i = 0, total_pages - 1 do
        -- Get effective margins per page (may differ for twoside odd/even)
        local m_left = page.get_effective_margins(i + 1)
        local m_left_pt = m_left / 65536
        tex.print(string.format("\\directlua{core.load_page(%d, %d)}", box_num, i))
        -- Use \vbox with raised content to add top margin without affecting page breaks
        tex.print("\\par\\nointerlineskip")
        tex.print(string.format("\\noindent\\kern%.5fpt\\vbox to 0pt{\\kern%.5fpt\\box%d\\vss}",
            m_left_pt, m_top_pt, box_num))
        if i < total_pages - 1 then
            tex.print("\\vfill\\penalty-10000\\allowbreak")
        end
    end
end

-- ============================================================================
-- Facing pages / blank pages (issue #176)
-- ============================================================================

-- Accepted spellings of 补页样式. Anything that is not "plain" gets the normal
-- blank page (border + banxin + running header / page number).
local PLAIN_STYLE_NAMES = {
    ["blank"] = true, ["plain"] = true, ["empty"] = true, ["none"] = true,
    ["空白"] = true, ["全空白"] = true, ["空白頁"] = true, ["空白页"] = true,
}
local NORMAL_STYLE_NAMES = {
    [""] = true, ["normal"] = true, ["default"] = true, ["header"] = true,
    ["默认"] = true, ["默認"] = true, ["带页眉页码"] = true, ["帶頁眉頁碼"] = true,
    ["带页眉"] = true, ["帶頁眉"] = true,
}

--- Normalise a 补页样式 value.
-- @param value (string|nil)
-- @return (string) "normal" or "plain"
function page.normalize_blank_page_style(value)
    local v = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if PLAIN_STYLE_NAMES[v] then return "plain" end
    if not NORMAL_STYLE_NAMES[v] and texio and texio.write_nl then
        texio.write_nl("luatex-cn Warning: unknown 补页样式/blank-page-style '" .. v ..
            "', using the default (blank page with header and page number)")
    end
    return "normal"
end

--- 对页补页 switch (set from the 对页补页 / facing-pages page key).
function page.set_facing_pages(enabled)
    _G.page.facing_pages = (enabled == true or enabled == "true")
end

--- Default style of inserted blank pages (set from 补页样式 / blank-page-style).
function page.set_blank_page_style(value)
    _G.page.blank_page_style = page.normalize_blank_page_style(value)
end

--- Penalty value that inserts a blank page of the given style.
-- @param style (string|nil) empty/nil = the document default (补页样式 of \pageSetup)
-- @return (number) PENALTY_BLANK_PAGE or PENALTY_BLANK_PAGE_PLAIN
function page.blank_penalty_for(style)
    if style == nil or style == "" then
        style = _G.page.blank_page_style or "normal"
    else
        style = page.normalize_blank_page_style(style)
    end
    if style == "plain" then return constants.PENALTY_BLANK_PAGE_PLAIN end
    return constants.PENALTY_BLANK_PAGE
end

--- Does this page box carry the plain-blank-page mark?
-- Used by the shipout hook of the vertical-book classes: the page about to be
-- shipped is a 补页样式=空白 page, so no running header / page number.
-- @param box (node|nil) the shipout box
-- @return (boolean)
function page.is_plain_blank_page(box)
    -- Documents without plain blank pages (nearly all) never pay for the scan.
    if not box or not _G.page.plain_blank_used then return false end
    local attr = constants.ATTR_BLANK_PAGE
    local function scan(list, depth)
        for n in node.traverse(list) do
            if node.has_attribute(n, attr) then return true end
            if depth < 6 and (n.id == node.id("hlist") or n.id == node.id("vlist")) and n.list then
                if scan(n.list, depth + 1) then return true end
            end
        end
        return false
    end
    return scan(box.list, 0)
end

-- Register module in package.loaded
package.loaded['core.luatex-cn-core-page'] = page

return page
