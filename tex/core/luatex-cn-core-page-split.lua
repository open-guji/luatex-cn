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
-- luatex-cn-core-page-split.lua - Page splitting for traditional Chinese books (筒子页)
-- Sub-module of luatex-cn-core-page, should only be called from page.lua/page.sty
-- ============================================================================

local split = {}

local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('page-split')

-- Initialize global state in _G.page.split
_G.page = _G.page or {}
_G.page.split = _G.page.split or {}
_G.page.split.enabled = _G.page.split.enabled or false
_G.page.split.right_first = (_G.page.split.right_first == nil) and true or _G.page.split.right_first

--- Configure split page parameters (called from TeX)
-- Reads from _G.page.split which is set by TeX keys
function split.configure()
    local sw = (_G.page and _G.page.paper_width) or 0
    local sh = (_G.page and _G.page.paper_height) or 0
    dbg.log(string.format("Configured: enabled=%s, right_first=%s, source=%.1fmm x %.1fmm, target=%.1fmm x %.1fmm",
        tostring(_G.page.split.enabled),
        tostring(_G.page.split.right_first),
        sw / 65536 / 72.27 * 25.4,
        sh / 65536 / 72.27 * 25.4,
        sw / 2 / 65536 / 72.27 * 25.4,
        sh / 65536 / 72.27 * 25.4))
end

--- Enable the split page feature and set TeX dimensions
function split.enable()
    local sw = (_G.page and _G.page.paper_width) or 0
    local sh = (_G.page and _G.page.paper_height) or 0
    if sw <= 0 or sh <= 0 then
        texio.write_nl("term and log", "[page-split] ERROR: Page dimensions not set (use pageSetup first)")
        return
    end

    _G.page.split.enabled = true
    dbg.log("Enabled - using page dimensions from _G.page")

    -- Set TeX dimensions: width is half of source, height stays same
    -- Must set both pagewidth/pageheight AND paperwidth/paperheight
    -- TikZ overlays (seals, backgrounds) use \paperwidth/\paperheight for positioning
    local target_w = split.get_target_width()
    local target_h = split.get_target_height()
    tex.set("pagewidth", target_w)
    tex.set("pageheight", target_h)
    tex.set("paperwidth", target_w)
    tex.set("paperheight", target_h)
end

--- Disable the split page feature and restore TeX dimensions
function split.disable()
    _G.page.split.enabled = false
    dbg.log("Disabled")

    -- Restore TeX dimensions to source values (both pagewidth/height and paperwidth/height)
    local sw = (_G.page and _G.page.paper_width) or 0
    local sh = (_G.page and _G.page.paper_height) or 0
    if sw > 0 then
        tex.set("pagewidth", sw)
        tex.set("paperwidth", sw)
    end
    if sh > 0 then
        tex.set("pageheight", sh)
        tex.set("paperheight", sh)
    end
end

--- Get target width (half of source)
function split.get_target_width()
    local sw = (_G.page and _G.page.paper_width) or 0
    return math.floor(sw / 2)
end

--- Get target height (same as source)
function split.get_target_height()
    return (_G.page and _G.page.paper_height) or 0
end

function split.is_enabled()
    return _G.page.split.enabled
end

function split.is_right_first()
    return _G.page.split.right_first
end

--- Check if current page is a right page (based on page number and right_first setting)
-- @param page_num The current page number (optional, defaults to current TeX page)
-- @return true if this is a right page, false if left page
function split.is_right_page(page_num)
    page_num = page_num or tex.count["c@page"]
    if _G.page.split.right_first then
        return (page_num % 2) == 1
    else
        return (page_num % 2) == 0
    end
end

--- Output pages in split mode (each page as two half-pages)
-- @param box_num The TeX box number
-- @param total_pages Total number of pages to output
function split.output_pages(box_num, total_pages)
    local target_w = split.get_target_width()
    local target_h = split.get_target_height()
    local right_first = split.is_right_first()

    -- Convert sp to pt for TeX
    local target_w_pt = target_w / 65536
    local target_h_pt = target_h / 65536

    -- Get margins (geometry is set to 0, we manually add margins here)
    local m_left = (_G.page and _G.page.margin_left) or 0
    local m_top = (_G.page and _G.page.margin_top) or 0
    local m_left_pt = m_left / 65536
    local m_top_pt = m_top / 65536

    for i = 0, total_pages - 1 do
        -- For split page, we need to output each page twice (left half and right half)
        local cmd_load = string.format("\\directlua{core.load_page(%d, %d, true)}", box_num, i)
        -- Must set both pagewidth/height AND paperwidth/height for TikZ overlays (seals, backgrounds)
        local cmd_dim = string.format("\\global\\pagewidth=%.5fpt\\global\\paperwidth=%.5fpt", target_w_pt, target_w_pt)
        local cmd_dim_h = string.format("\\global\\pageheight=%.5fpt\\global\\paperheight=%.5fpt", target_h_pt, target_h_pt)

        dbg.log("TeX CMD: " .. cmd_load)
        dbg.log("TeX CMD: " .. cmd_dim)

        tex.print(cmd_load)

        -- Set page dimensions to half width for first half
        tex.print(cmd_dim)
        tex.print(cmd_dim_h)

        -- Output first half (right side if right_first)
        tex.print("\\par\\nointerlineskip")
        if right_first then
            tex.print(string.format("\\noindent\\kern%.5fpt\\kern-%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, target_w_pt, m_top_pt, box_num))
        else
            tex.print(string.format("\\noindent\\kern%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, m_top_pt, box_num))
        end

        -- New page for second half
        tex.print("\\vfill\\penalty-10000\\allowbreak")
        tex.print(cmd_dim)
        tex.print(cmd_dim_h)

        -- Output second half
        tex.print("\\par\\nointerlineskip")
        if right_first then
            tex.print(string.format("\\noindent\\kern%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, m_top_pt, box_num))
        else
            tex.print(string.format("\\noindent\\kern%.5fpt\\kern-%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, target_w_pt, m_top_pt, box_num))
        end

        if i < total_pages - 1 then
            tex.print("\\vfill\\penalty-10000\\allowbreak")
        end
    end
end

-- Register module
package.loaded['core.luatex-cn-core-page-split'] = split

return split
