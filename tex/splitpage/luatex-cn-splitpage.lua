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
-- luatex-cn-splitpage.lua - 筒子页自动裁剪模块
-- ============================================================================
--
-- 【工作原理 / How It Works】
-- 使用更简单的方法：不裁剪页面，而是：
-- 1. 保持原始页面内容不变
-- 2. 只修改 PDF 的 MediaBox 为半宽
-- 3. 内容自然超出页面边界的部分会被 PDF 查看器裁剪
--
-- 这种方法的问题是：第二半页需要单独输出
--
-- 最终方案：使用 PDF XObject 来复用页面内容
-- ============================================================================

local splitpage = {}

-- Module state
splitpage.enabled = false
splitpage.source_width = 0
splitpage.source_height = 0
splitpage.target_width = 0
splitpage.target_height = 0
splitpage.right_first = true
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('splitpage')

local to_sp = constants.to_dimen

-- Convert sp to bp

--- Configure split page parameters
function splitpage.configure(params)
    params = params or {}

    if params.source_width then
        splitpage.source_width = to_sp(params.source_width)
    end
    if params.source_height then
        splitpage.source_height = to_sp(params.source_height)
    end

    splitpage.target_width = math.floor(splitpage.source_width / 2)
    splitpage.target_height = splitpage.source_height

    if params.right_first ~= nil then
        splitpage.right_first = params.right_first
    end

    dbg.log(string.format("Configured: source=%.1fmm x %.1fmm, target=%.1fmm x %.1fmm",
        splitpage.source_width / 65536 / 72.27 * 25.4,
        splitpage.source_height / 65536 / 72.27 * 25.4,
        splitpage.target_width / 65536 / 72.27 * 25.4,
        splitpage.target_height / 65536 / 72.27 * 25.4))
end

--- Process a page - just pass through with modified dimensions
-- The actual splitting will happen via TeX commands
function splitpage.process_page(box)
    if not splitpage.enabled then
        return box
    end

    dbg.log("Processing page - passing through unchanged")

    -- Don't modify the box here - let TeX handle the splitting
    return box
end

--- Enable the split page feature
function splitpage.enable()
    if splitpage.enabled then
        dbg.log("Already enabled")
        return
    end

    if splitpage.source_width <= 0 or splitpage.source_height <= 0 then
        texio.write_nl("term and log", "[splitpage] ERROR: Must configure dimensions before enabling")
        return
    end

    splitpage.enabled = true
    dbg.log("Enabled - dimensions configured")
end

--- Disable the split page feature
function splitpage.disable()
    splitpage.enabled = false
    dbg.log("Disabled")
end

--- Get configuration for TeX
function splitpage.get_target_width()
    return splitpage.target_width
end

function splitpage.get_target_height()
    return splitpage.target_height
end

function splitpage.get_source_width()
    return splitpage.source_width
end

function splitpage.get_source_height()
    return splitpage.source_height
end

function splitpage.is_enabled()
    return splitpage.enabled
end

function splitpage.is_right_first()
    return splitpage.right_first
end

--- Check if current page is a right page (based on page number and right_first setting)
-- @param page_num The current page number
-- @return true if this is a right page, false if left page
function splitpage.is_right_page(page_num)
    if splitpage.right_first then
        -- right_first: odd pages are right, even pages are left
        return (page_num % 2) == 1
    else
        -- left_first: odd pages are left, even pages are right
        return (page_num % 2) == 0
    end
end

-- Dummy function for compatibility
function splitpage.flush_pending()
    -- No-op in this simplified version
end

--- Output pages in split mode (each page as two half-pages)
-- @param box_num The TeX box number
-- @param total_pages Total number of pages to output
function splitpage.output_pages(box_num, total_pages)
    local target_w = splitpage.get_target_width()
    local target_h = splitpage.get_target_height()
    local right_first = splitpage.is_right_first()

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
        -- First, load page into box (with copy=true so we can use it twice)
        local cmd_load = string.format("\\directlua{core.load_page(%d, %d, true)}", box_num, i)
        local cmd_dim = string.format("\\global\\pagewidth=%.5fpt", target_w_pt)
        local cmd_dim_h = string.format("\\global\\pageheight=%.5fpt", target_h_pt)

        dbg.log("TeX CMD: " .. cmd_load)
        dbg.log("TeX CMD: " .. cmd_dim)

        tex.print(cmd_load)

        -- Set page dimensions to half width for first half
        tex.print(cmd_dim)
        tex.print(cmd_dim_h)

        -- Output first half (right side if right_first)
        -- Use \vbox with raised content to add top margin without affecting page breaks
        -- The \vbox to 0pt ensures no height contribution to the page
        tex.print("\\par\\nointerlineskip")
        if right_first then
            -- 右半页：将内容左移 target_w (显示右半部分)，然后加上 margin_left
            tex.print(string.format("\\noindent\\kern%.5fpt\\kern-%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, target_w_pt, m_top_pt, box_num))
        else
            -- 左半页：只加 margin_left
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
            -- 左半页：只加 margin_left
            tex.print(string.format("\\noindent\\kern%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, m_top_pt, box_num))
        else
            -- 右半页：将内容左移 target_w，然后加上 margin_left
            tex.print(string.format("\\noindent\\kern%.5fpt\\kern-%.5fpt\\vbox to 0pt{\\kern%.5fpt\\hbox to 0pt{\\smash{\\copy%d}\\hss}\\vss}",
                m_left_pt, target_w_pt, m_top_pt, box_num))
        end

        if i < total_pages - 1 then
            tex.print("\\vfill\\penalty-10000\\allowbreak")
        end
    end
end

-- Register module
_G.splitpage = splitpage
package.loaded['splitpage.luatex-cn-splitpage'] = splitpage

return splitpage
