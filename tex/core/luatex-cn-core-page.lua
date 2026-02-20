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

_G.page = _G.page or {}
_G.page.current_page_number = _G.page.current_page_number or 1
_G.page.paper_height = _G.page.paper_height or 0
_G.page.paper_width = _G.page.paper_width or 0
_G.page.margin_top = _G.page.margin_top or 0
_G.page.margin_bottom = _G.page.margin_bottom or 0
_G.page.margin_left = _G.page.margin_left or 0
_G.page.margin_right = _G.page.margin_right or 0

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
    local bg_rgb_str = params.bg_rgb_str
    if not bg_rgb_str then
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
    -- Get margins (geometry is set to 0, we manually add margins here)
    local m_left = (_G.page and _G.page.margin_left) or 0
    local m_top = (_G.page and _G.page.margin_top) or 0
    local m_left_pt = m_left / 65536
    local m_top_pt = m_top / 65536

    for i = 0, total_pages - 1 do
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

-- Register module in package.loaded
package.loaded['core.luatex-cn-core-page'] = page

return page
