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

--- Store pre-rendered upper section box from TeX
-- Called by \__luatexcn_banxin_typeset_sections: in banxin.sty
-- @param box_num (number) TeX box register number
local function store_upper_section_box(box_num)
    local box = tex.box[box_num]
    if box then
        _G.banxin.upper_section_box = node.copy_list(box)
    else
        _G.banxin.upper_section_box = nil
    end
end

local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')
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

        -- Padding (from upper-section and page-number sub-namespaces)
        padding_top = parse_dim(get_tl("l__luatexcn_banxin_upper_section_top_padding_tl")),
        padding_bottom = parse_dim(get_tl("l__luatexcn_banxin_page_number_bottom_padding_tl")),

        -- Divider
        divider = get_bool("l__luatexcn_banxin_divider_bool"),

        -- Upper section
        upper_section_text = get_tl("l__luatexcn_banxin_upper_section_text_tl") or "",
        upper_section_font_size = parse_dim(get_tl("l__luatexcn_banxin_upper_section_font_size_tl")),
        upper_section_grid_height = parse_dim(get_tl("l__luatexcn_banxin_upper_section_grid_height_tl")),
        upper_section_align = get_tl("l__luatexcn_banxin_upper_section_align_tl") or "center",
        upper_section_bottom_padding = parse_dim(get_tl("l__luatexcn_banxin_upper_section_bottom_padding_tl")),
        upper_section_bg_color = get_tl("l__luatexcn_banxin_upper_section_bg_color_tl") or "",
        upper_section_font_color = get_tl("l__luatexcn_banxin_upper_section_font_color_tl") or "",

        -- Middle section
        middle_section_text = get_tl("l__luatexcn_banxin_middle_section_text_tl") or "",
        middle_section_top_margin = parse_dim(get_tl("l__luatexcn_banxin_middle_section_top_margin_tl")),
        middle_section_cols = get_int("l__luatexcn_banxin_middle_section_cols_int"),
        middle_section_font_size = parse_dim(get_tl("l__luatexcn_banxin_middle_section_font_size_tl")),
        middle_section_grid_height = parse_dim(get_tl("l__luatexcn_banxin_middle_section_grid_height_tl")),
        middle_section_align = get_tl("l__luatexcn_banxin_middle_section_align_tl") or "center",
        middle_section_bg_color = get_tl("l__luatexcn_banxin_middle_section_bg_color_tl") or "",
        middle_section_font_color = get_tl("l__luatexcn_banxin_middle_section_font_color_tl") or "",

        -- Yuwei
        upper_yuwei = get_bool("l__luatexcn_banxin_upper_yuwei_bool"),
        lower_yuwei = get_bool("l__luatexcn_banxin_lower_yuwei_bool"),

        -- Page number
        page_number_align = get_tl("l__luatexcn_banxin_page_number_align_tl") or "right-bottom",
        page_number_font_size = parse_dim(get_tl("l__luatexcn_banxin_page_number_font_size_tl")),
        page_number_grid_height = parse_dim(get_tl("l__luatexcn_banxin_page_number_grid_height_tl")),

        -- Lower section
        lower_section_text = get_tl("l__luatexcn_banxin_lower_section_text_tl") or "",
        lower_section_font_size = parse_dim(get_tl("l__luatexcn_banxin_lower_section_font_size_tl")),
        lower_section_grid_height = parse_dim(get_tl("l__luatexcn_banxin_lower_section_grid_height_tl")),
        lower_section_bottom_margin = parse_dim(get_tl("l__luatexcn_banxin_lower_section_bottom_margin_tl")),
        lower_section_align = get_tl("l__luatexcn_banxin_lower_section_align_tl") or "right",
        lower_section_bg_color = get_tl("l__luatexcn_banxin_lower_section_bg_color_tl") or "",
        lower_section_font_color = get_tl("l__luatexcn_banxin_lower_section_font_color_tl") or "",

        -- Banxin-level style overrides
        style_font_size = get_tl("l__luatexcn_banxin_style_font_size_tl") or "",
        style_font_color = get_tl("l__luatexcn_banxin_style_font_color_tl") or "",
        style_font = get_tl("l__luatexcn_banxin_style_font_tl") or "",
        style_grid_height = get_tl("l__luatexcn_banxin_style_grid_height_tl") or "",
        style_grid_width = get_tl("l__luatexcn_banxin_style_grid_width_tl") or "",
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

    dbg.log(string.format("Initialized. Active=true, upper_section='%s'", bp.upper_section_text or ""))

    -- Build banxin style overrides for push/pop in layout/render
    local banxin_style = {}
    if bp.style_font_size ~= "" then
        banxin_style.font_size = constants.to_dimen(bp.style_font_size)
    end
    if bp.style_font_color ~= "" then
        banxin_style.font_color = bp.style_font_color
    end
    if bp.style_font ~= "" then
        banxin_style.font = bp.style_font
    end
    if bp.style_grid_height ~= "" then
        banxin_style.grid_height = constants.to_dimen(bp.style_grid_height)
    end
    if bp.style_grid_width ~= "" then
        banxin_style.grid_width = constants.to_dimen(bp.style_grid_width)
    end

    return {
        active = true,
        params = bp,           -- Store captured parameters
        layout_cache = {},     -- Will store per-page layout data
        banxin_style = next(banxin_style) and banxin_style or nil,
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

    -- Push banxin style overrides onto style stack (temporary layer for layout)
    if context.banxin_style then
        style_registry.push(context.banxin_style)
    end

    -- Calculate layout for each page's reserved columns
    for page_idx = 0, total_pages - 1 do
        local reserved_cols = engine_ctx.get_reserved_cols(page_idx, p_cols)

        context.layout_cache[page_idx] = {}

        for col = 0, p_cols - 1 do
            if reserved_cols[col] then
                local coords = engine_ctx.get_reserved_column_coords(col, p_cols)

                -- Prepare layout params from captured context params
                local c_padding_top = bp.padding_top > 0 and bp.padding_top or engine_ctx.c_padding_top
                local c_padding_bottom = bp.padding_bottom > 0 and bp.padding_bottom or engine_ctx.c_padding_bottom

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
                    upper_section_text = bp.upper_section_text,
                    upper_section_font_size = bp.upper_section_font_size > 0 and bp.upper_section_font_size or nil,
                    upper_section_grid_height = bp.upper_section_grid_height > 0 and bp.upper_section_grid_height or nil,
                    upper_section_align = bp.upper_section_align,
                    upper_section_bottom_padding = bp.upper_section_bottom_padding > 0 and bp.upper_section_bottom_padding or nil,
                    upper_section_bg_color = bp.upper_section_bg_color,
                    upper_section_font_color = bp.upper_section_font_color,
                    c_padding_top = c_padding_top,
                    c_padding_bottom = c_padding_bottom,
                    upper_yuwei = bp.upper_yuwei,
                    lower_yuwei = bp.lower_yuwei,
                    banxin_divider = bp.divider,
                    middle_section_text = bp.middle_section_text,
                    middle_section_top_margin = bp.middle_section_top_margin > 0 and bp.middle_section_top_margin or (65536 * 20),
                    middle_section_cols = bp.middle_section_cols > 0 and bp.middle_section_cols or 1,
                    middle_section_font_size = bp.middle_section_font_size > 0 and bp.middle_section_font_size or nil,
                    middle_section_grid_height = bp.middle_section_grid_height > 0 and bp.middle_section_grid_height or nil,
                    middle_section_align = bp.middle_section_align,
                    middle_section_bg_color = bp.middle_section_bg_color,
                    middle_section_font_color = bp.middle_section_font_color,
                    page_number_align = bp.page_number_align,
                    page_number_font_size = bp.page_number_font_size > 0 and bp.page_number_font_size or nil,
                    lower_section_text = bp.lower_section_text,
                    lower_section_font_size = bp.lower_section_font_size > 0 and bp.lower_section_font_size or nil,
                    lower_section_grid_height = bp.lower_section_grid_height > 0 and bp.lower_section_grid_height or nil,
                    lower_section_bottom_margin = bp.lower_section_bottom_margin > 0 and bp.lower_section_bottom_margin or nil,
                    lower_section_align = bp.lower_section_align,
                    lower_section_bg_color = bp.lower_section_bg_color,
                    lower_section_font_color = bp.lower_section_font_color,
                    -- Get font_size from style stack (falls back to default if not set)
                    font_size = style_registry.get_font_size(style_registry.current_id()) or 655360,
                }

                -- Calculate layout using the layout module
                local col_layout = banxin_layout.calculate_column_layout(layout_params)
                context.layout_cache[page_idx][col] = col_layout

                dbg.log(string.format("  Page %d, col %d: layout calculated", page_idx, col))
            end
        end
    end

    -- Pop banxin style layer (restore style stack)
    if context.banxin_style then
        style_registry.pop()
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

    -- Resolve runtime content: middle section text (may vary per page)
    -- Only update when \chapter markers exist; walk back to find most recent marker.
    local middle_section_text = bp.middle_section_text
    local page_resets = engine_ctx.page_resets
    if page_resets and next(page_resets) and engine_ctx.page_chapter_titles then
        for p = page_idx, 0, -1 do
            if page_resets[p] then
                local t = engine_ctx.page_chapter_titles[p]
                if t and t ~= "" then
                    middle_section_text = t
                end
                break
            end
        end
    end

    -- Resolve runtime content: page number
    -- Support explicit page number string (for digital mode)
    -- When \chapter resets page number, compute relative page number from last reset.
    local page_number
    if page_resets and next(page_resets) then
        local last_reset_page = -1
        for p = page_idx, 0, -1 do
            if page_resets[p] then
                last_reset_page = p
                break
            end
        end
        if last_reset_page >= 0 then
            page_number = 1 + (page_idx - last_reset_page)
        else
            page_number = (params.start_page_number or 1) + page_idx
        end
    else
        page_number = (params.start_page_number or 1) + page_idx
    end
    local explicit_page_number = _G.banxin and _G.banxin.explicit_page_number or nil

    local p_head = D.todirect(head)

    -- Push banxin style layer for render stage
    if context.banxin_style then
        style_registry.push(context.banxin_style)
    end

    for _, col_layout in pairs(page_layout) do
        p_head = render_banxin.draw_from_layout(p_head, col_layout, {
            middle_section_text = middle_section_text,
            page_number = page_number,
            explicit_page_number = explicit_page_number,
        })
    end

    -- Pop banxin style layer
    if context.banxin_style then
        style_registry.pop()
    end

    return D.tonode(p_head)
end

local banxin_plugin = {
    initialize = banxin_main.initialize,
    flatten = banxin_main.flatten,
    layout = banxin_main.layout,
    render = banxin_main.render,
    setup = banxin_setup,
    store_upper_section_box = store_upper_section_box,
}

-- Registry as plugin if core engine is present
if core and core.register_plugin then
    core.register_plugin("banxin", banxin_plugin)
end

package.loaded['banxin.luatex-cn-banxin-main'] = banxin_plugin

return banxin_plugin
