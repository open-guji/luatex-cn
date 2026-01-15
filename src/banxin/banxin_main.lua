-- ============================================================================
-- banxin_main.lua - 版心模块主入口（注册钩子）
-- ============================================================================
-- 文件名: banxin_main.lua
-- 层级: 扩展层 (Extension Layer) - 古籍版心功能
--
-- 【模块功能 / Module Purpose】
-- 本模块是 banxin 包的主入口，负责：
--   1. 向 vertical 的 hooks 系统注册版心相关回调
--   2. 管理版心配置参数
--   3. 协调 render_banxin.lua 和 render_yuwei.lua 模块
--
-- 【设计原理 / Design Principle】
-- banxin 作为独立包，通过 vertical.hooks 接口与竖排引擎通信：
--   - is_reserved_column() - 告诉竖排引擎哪些列是版心列
--   - render_reserved_column() - 在版心列上绘制内容
--
-- Version: 1.0.0
-- Date: 2026-01-15
-- ============================================================================

-- Ensure vertical global namespace exists
_G.vertical = _G.vertical or {}
_G.vertical.hooks = _G.vertical.hooks or {}

-- Create banxin namespace
_G.banxin = _G.banxin or {}

-- Configuration storage
local config = {
    interval = 8,  -- Default: every 9th column (8+1) is a banxin column
    upper_ratio = 0.28,
    middle_ratio = 0.56,
    lower_ratio = 0.16,
    book_name = "",
    chapter_title = "",
    chapter_title_cols = 1,
    chapter_title_font_size = nil,
    chapter_title_grid_height = nil,
    chapter_title_top_margin = 65536 * 20, -- 20pt
    padding_top = 0,
    padding_bottom = 0,
    lower_yuwei = false,
    border_thickness = 65536 * 0.4, -- 0.4pt
    border_color = nil,
}

_G.banxin.config = config

-- Load render modules (relative path from banxin directory)
local banxin_render = nil
local function get_banxin_render()
    if not banxin_render then
        -- Try loading from banxin directory first
        local success, result = pcall(function()
            return dofile(kpse.find_file("banxin/render_banxin.lua") or "banxin/render_banxin.lua")
        end)
        if success then
            banxin_render = result
        else
            -- Fallback to vertical directory for backward compatibility
            banxin_render = package.loaded['render_banxin'] or require('render_banxin')
        end
    end
    return banxin_render
end

--- Check if a column is a banxin (reserved) column
-- @param col (number) Column index (0-based)
-- @param interval (number) The n_column parameter
-- @return (boolean) True if this is a banxin column
local function is_reserved_column(col, interval)
    local n = interval or config.interval
    if n <= 0 then return false end
    return (col % (n + 1)) == n
end

--- Render banxin content on a reserved column
-- @param p_head (node) Current page node list head
-- @param params (table) Rendering parameters
-- @return (node) Updated node list head
local function render_reserved_column(p_head, params)
    local render = get_banxin_render()
    if not render or not render.draw_banxin_column then
        return p_head
    end
    
    -- Merge config into params
    local full_params = {
        x = params.x,
        y = params.y,
        width = params.width,
        height = params.height,
        border_thickness = params.border_thickness or config.border_thickness,
        border_color = params.border_color or config.border_color,
        upper_ratio = params.upper_ratio or config.upper_ratio,
        middle_ratio = params.middle_ratio or config.middle_ratio,
        lower_ratio = params.lower_ratio or config.lower_ratio,
        book_name = params.book_name or config.book_name,
        chapter_title = params.chapter_title or config.chapter_title,
        chapter_title_cols = params.chapter_title_cols or config.chapter_title_cols,
        chapter_title_font_size = params.chapter_title_font_size or config.chapter_title_font_size,
        chapter_title_grid_height = params.chapter_title_grid_height or config.chapter_title_grid_height,
        chapter_title_top_margin = params.chapter_title_top_margin or config.chapter_title_top_margin,
        b_padding_top = params.b_padding_top or config.padding_top,
        b_padding_bottom = params.b_padding_bottom or config.padding_bottom,
        lower_yuwei = params.lower_yuwei ~= nil and params.lower_yuwei or config.lower_yuwei,
        -- Pass through other params
        grid_width = params.grid_width,
        grid_height = params.grid_height,
        page_number = params.page_number,
    }
    
    return render.draw_banxin_column(p_head, full_params)
end

--- Get reserved column configuration
-- @return (table) Configuration including interval
local function get_reserved_config()
    return {
        interval = config.interval,
    }
end

--- Update configuration
-- @param new_config (table) Configuration values to update
function _G.banxin.configure(new_config)
    for k, v in pairs(new_config) do
        if config[k] ~= nil then
            config[k] = v
        end
    end
end

-- Register hooks with vertical
_G.vertical.hooks.is_reserved_column = is_reserved_column
_G.vertical.hooks.render_reserved_column = render_reserved_column
_G.vertical.hooks.get_reserved_config = get_reserved_config

-- Export module
local banxin = {
    config = config,
    configure = _G.banxin.configure,
    is_reserved_column = is_reserved_column,
    render_reserved_column = render_reserved_column,
    get_reserved_config = get_reserved_config,
}

package.loaded['banxin_main'] = banxin

return banxin
