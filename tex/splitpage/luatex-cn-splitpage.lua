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
-- Convert sp to bp
local function sp_to_bp(sp)
    return sp / 65536 / 72.27 * 72
end

-- Convert dimension string to sp
local function to_sp(dim_str)
    if type(dim_str) == "number" then return dim_str end
    if type(dim_str) ~= "string" then return 0 end

    local num, unit = dim_str:match("^([%d%.]+)(%a+)$")
    if not num then return 0 end
    num = tonumber(num)
    if not num then return 0 end

    local factors = {
        pt = 65536,
        bp = 65536 * 72.27 / 72,
        mm = 65536 * 72.27 / 25.4,
        cm = 65536 * 72.27 / 2.54,
        ["in"] = 65536 * 72.27,
        sp = 1,
    }
    return math.floor(num * (factors[unit] or 65536))
end

-- Register splitpage module if debug module is available
if _G.luatex_cn_debug then
    _G.luatex_cn_debug.register_module("splitpage", { color = "green" })
end

local function debug_log(msg)
    if _G.luatex_cn_debug then
        _G.luatex_cn_debug.log("splitpage", msg)
    end
end

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

    debug_log(string.format("Configured: source=%.1fmm x %.1fmm, target=%.1fmm x %.1fmm",
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

    debug_log("Processing page - passing through unchanged")

    -- Don't modify the box here - let TeX handle the splitting
    return box
end

--- Enable the split page feature
function splitpage.enable()
    if splitpage.enabled then
        debug_log("Already enabled")
        return
    end

    if splitpage.source_width <= 0 or splitpage.source_height <= 0 then
        texio.write_nl("term and log", "[splitpage] ERROR: Must configure dimensions before enabling")
        return
    end

    splitpage.enabled = true
    debug_log("Enabled - dimensions configured")
end

--- Disable the split page feature
function splitpage.disable()
    splitpage.enabled = false
    debug_log("Disabled")
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

-- Register module
_G.splitpage = splitpage
package.loaded['splitpage.luatex-cn-splitpage'] = splitpage

return splitpage
