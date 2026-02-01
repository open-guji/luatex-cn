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
-- banxin_main.lua - 版心模块独立入口（注册钩子）
-- ============================================================================
-- 文件名: banxin_main.lua
-- 层级: 扩展层 (Extension Layer) - 古籍版心功能
--
-- 【模块功能 / Module Purpose】
-- 本模块作为 banxin 包的独立入口，负责：
--   1. 向 vertical.hooks 系统注册版心相关回调
--   2. 管理版心配置映射
--   3. 协调 banxin.render_banxin 和 banxin.render_yuwei 模块
--
-- 【设计原理】
-- banxin 作为一个可选插件，通过覆盖 vertical.hooks 接口实现其功能。
--
-- ============================================================================

-- Ensure core namespace exists (should be loaded by now)
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}

-- Create banxin namespace for our modules
_G.banxin = _G.banxin or {}
_G.banxin.enabled = _G.banxin.enabled or false

--- Setup global banxin parameters from TeX
-- Called by \banxinSetup to pre-set banxin state
-- @param params (table) Parameters from TeX keyvals
local function banxin_setup(params)
    params = params or {}
    if params.enabled ~= nil then
        _G.banxin.enabled = (params.enabled == true or params.enabled == "true")
    end
end

-- Export setup function for early access
_G.banxin.setup = banxin_setup

local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local D = node.direct

local dbg = debug.get_debugger('banxin')

-- =============================================================================
-- Direct TeX Variable Reading
-- =============================================================================
-- Read banxin parameters directly from TeX LaTeX3 variables
-- This eliminates the need to pass them through the params table

--- Read all banxin-related TeX variables
-- @return table A table containing all banxin configuration values
local function read_banxin_params()
    local get_tl = utils.get_tex_tl
    local get_bool = utils.get_tex_bool
    local get_int = utils.get_tex_int
    local parse_dim = utils.parse_dim_to_sp

    return {
        -- Layout ratios
        upper_ratio = tonumber(get_tl("l__luatexcn_banxin_upper_ratio_tl")) or 0.28,
        middle_ratio = tonumber(get_tl("l__luatexcn_banxin_middle_ratio_tl")) or 0.56,

        -- Padding
        padding_top = parse_dim(get_tl("l__luatexcn_banxin_padding_top_tl")),
        padding_bottom = parse_dim(get_tl("l__luatexcn_banxin_padding_bottom_tl")),

        -- Divider
        divider = get_bool("l__luatexcn_banxin_divider_bool"),

        -- Book name
        book_name = get_tl("l__luatexcn_banxin_book_name_tl") or "",
        book_name_font_size = parse_dim(get_tl("l__luatexcn_banxin_book_name_font_size_tl")),
        book_name_grid_height = parse_dim(get_tl("l__luatexcn_banxin_book_name_grid_height_tl")),
        book_name_align = get_tl("l__luatexcn_banxin_book_name_align_tl") or "center",

        -- Chapter title
        chapter_title = get_tl("l__luatexcn_banxin_chapter_title_tl") or "",
        chapter_title_top_margin = parse_dim(get_tl("l__luatexcn_banxin_chapter_title_top_margin_tl")),
        chapter_title_cols = get_int("l__luatexcn_banxin_chapter_title_cols_int"),
        chapter_title_font_size = parse_dim(get_tl("l__luatexcn_banxin_chapter_title_font_size_tl")),
        chapter_title_grid_height = parse_dim(get_tl("l__luatexcn_banxin_chapter_title_grid_height_tl")),

        -- Yuwei
        upper_yuwei = get_bool("l__luatexcn_banxin_upper_yuwei_bool"),
        lower_yuwei = get_bool("l__luatexcn_banxin_lower_yuwei_bool"),

        -- Page number
        page_number_align = get_tl("l__luatexcn_banxin_page_number_align_tl") or "right-bottom",
        page_number_font_size = parse_dim(get_tl("l__luatexcn_banxin_page_number_font_size_tl")),
        page_number_grid_height = parse_dim(get_tl("l__luatexcn_banxin_page_number_grid_height_tl")),

        -- Publisher
        publisher = get_tl("l__luatexcn_banxin_publisher_tl") or "",
        publisher_font_size = parse_dim(get_tl("l__luatexcn_banxin_publisher_font_size_tl")),
        publisher_grid_height = parse_dim(get_tl("l__luatexcn_banxin_publisher_grid_height_tl")),
        publisher_bottom_margin = parse_dim(get_tl("l__luatexcn_banxin_publisher_bottom_margin_tl")),
        publisher_align = get_tl("l__luatexcn_banxin_publisher_align_tl") or "right",
    }
end

-- 1. Load sub-modules using full namespaced paths
local render_banxin = package.loaded['banxin.luatex-cn-banxin-render-banxin'] or
    require('banxin.luatex-cn-banxin-render-banxin')
local banxin_layout = package.loaded['banxin.luatex-cn-banxin-layout'] or
    require('banxin.luatex-cn-banxin-layout')

-- 2. Export module table for TeX/other modules
local banxin_main = {}

--- Initialize Banxin Plugin
-- Captures banxin parameters early for use in layout and render stages
function banxin_main.initialize(params, engine_ctx)
    -- Read banxin_on directly from TeX variable
    local banxin_on = utils.get_tex_bool("l__luatexcn_banxin_on_bool")
    -- Banxin is active if banxin_on is true or implicitly via n_column
    local is_active = banxin_on or (tonumber(params.n_column) or 0) > 0

    if not is_active then
        dbg.log("Initialized. Active=false")
        return { active = false }
    end

    -- Capture banxin parameters early (moved from render stage)
    local bp = read_banxin_params()

    dbg.log(string.format("Initialized. Active=true, book_name='%s'", bp.book_name or ""))

    return {
        active = true,
        params = bp,           -- Store captured parameters
        layout_cache = {},     -- Will store per-page layout data
    }
end

--- Flatten hook (Not used by banxin)
function banxin_main.flatten(nodes, engine_ctx, context)
    return nodes
end

--- Layout hook for Banxin
-- Calculates layout data for all banxin columns across all pages
-- and stores in context.layout_cache for the render stage
function banxin_main.layout(list, layout_map, engine_ctx, context)
    if not (context and context.active) then return end
    if engine_ctx.n_column <= 0 then return end

    local total_pages = engine_ctx.total_pages or 0
    local p_cols = engine_ctx.page_columns or 0
    local bp = context.params

    dbg.log(string.format("Layout hook: calculating for %d pages, %d cols/page", total_pages, p_cols))

    -- Calculate layout for each page's reserved columns
    for page_idx = 0, total_pages - 1 do
        local reserved_cols = engine_ctx.get_reserved_cols(page_idx, p_cols)

        context.layout_cache[page_idx] = {}

        for col = 0, p_cols - 1 do
            if reserved_cols[col] then
                local coords = engine_ctx.get_reserved_column_coords(col, p_cols)

                -- Prepare layout params from captured context params
                local b_padding_top = bp.padding_top > 0 and bp.padding_top or engine_ctx.b_padding_top
                local b_padding_bottom = bp.padding_bottom > 0 and bp.padding_bottom or engine_ctx.b_padding_bottom

                local layout_params = {
                    x = coords.x,
                    y = coords.y,
                    width = coords.width,
                    height = coords.height,
                    border_thickness = engine_ctx.border_thickness,
                    color_str = engine_ctx.border_rgb_str,
                    draw_border = engine_ctx.draw_border,
                    upper_ratio = bp.upper_ratio,
                    middle_ratio = bp.middle_ratio,
                    book_name = bp.book_name,
                    book_name_font_size = bp.book_name_font_size > 0 and bp.book_name_font_size or nil,
                    book_name_grid_height = bp.book_name_grid_height > 0 and bp.book_name_grid_height or nil,
                    book_name_align = bp.book_name_align,
                    b_padding_top = b_padding_top,
                    b_padding_bottom = b_padding_bottom,
                    upper_yuwei = bp.upper_yuwei,
                    lower_yuwei = bp.lower_yuwei,
                    banxin_divider = bp.divider,
                    chapter_title = bp.chapter_title,
                    chapter_title_top_margin = bp.chapter_title_top_margin > 0 and bp.chapter_title_top_margin or (65536 * 20),
                    chapter_title_cols = bp.chapter_title_cols > 0 and bp.chapter_title_cols or 1,
                    chapter_title_font_size = bp.chapter_title_font_size > 0 and bp.chapter_title_font_size or nil,
                    chapter_title_grid_height = bp.chapter_title_grid_height > 0 and bp.chapter_title_grid_height or nil,
                    page_number_align = bp.page_number_align,
                    page_number_font_size = bp.page_number_font_size > 0 and bp.page_number_font_size or nil,
                    publisher = bp.publisher,
                    publisher_font_size = bp.publisher_font_size > 0 and bp.publisher_font_size or nil,
                    publisher_grid_height = bp.publisher_grid_height > 0 and bp.publisher_grid_height or nil,
                    publisher_bottom_margin = bp.publisher_bottom_margin > 0 and bp.publisher_bottom_margin or nil,
                    publisher_align = bp.publisher_align,
                    font_size = _G.content.font_size or 655360,
                }

                -- Calculate layout using the layout module
                local col_layout = banxin_layout.calculate_column_layout(layout_params)
                context.layout_cache[page_idx][col] = col_layout

                dbg.log(string.format("  Page %d, col %d: layout calculated", page_idx, col))
            end
        end
    end

    dbg.log(string.format("Layout hook completed: cached %d pages", total_pages))
end

--- Render hook for Banxin
-- Uses pre-calculated layout from layout stage and resolves runtime content
-- @param head (node) Page list head
-- @param layout_map (table) Main layout map
-- @param params (table) Render parameters
-- @param context (table) Plugin context (contains layout_cache)
-- @param page_idx (number) Current page index (0-based)
-- @param p_total_cols (number) Total columns on this page
function banxin_main.render(head, layout_map, params, context, engine_ctx, page_idx, _)
    if not (context and context.active) then return head end
    if engine_ctx.n_column <= 0 then return head end

    local page_layout = context.layout_cache and context.layout_cache[page_idx]
    if not page_layout then return head end

    local bp = context.params

    -- Resolve runtime content: chapter title (may vary per page)
    local chapter_title = bp.chapter_title
    if engine_ctx.page_chapter_titles and engine_ctx.page_chapter_titles[page_idx] then
        chapter_title = engine_ctx.page_chapter_titles[page_idx]
    end

    -- Resolve runtime content: page number
    local page_number = (params.start_page_number or 1) + page_idx

    local p_head = D.todirect(head)

    for _, col_layout in pairs(page_layout) do
        p_head = render_banxin.draw_from_layout(p_head, col_layout, {
            chapter_title = chapter_title,
            page_number = page_number,
        })
    end

    return D.tonode(p_head)
end

local banxin_plugin = {
    initialize = banxin_main.initialize,
    flatten = banxin_main.flatten,
    layout = banxin_main.layout,
    render = banxin_main.render,
    setup = banxin_setup,
}

-- Registry as plugin if core engine is present
if core and core.register_plugin then
    core.register_plugin("banxin", banxin_plugin)
end

package.loaded['banxin.luatex-cn-banxin-main'] = banxin_plugin

return banxin_plugin
