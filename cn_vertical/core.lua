-- cn_vertical.lua
-- Chinese vertical typesetting module for LuaTeX (Refactored Entry Point)
-- Uses native LuaTeX 'dir' primitives for RTT (Right-to-Left Top-to-Bottom) layout.
--
-- This is the main entry point that coordinates all submodules.
-- For detailed architecture, see ARCHITECTURE.md (if available) or README.md
--
-- Version: 0.3.0 (Modularized)
-- Date: 2026-01-12

-- Debug: Output status at module load time
if texio and texio.write_nl then
    texio.write_nl("core.lua: Starting to load...")
end

-- Pending pages store
_G.cn_vertical_pending_pages = {}

-- Create module namespace - MUST use _G to ensure global scope
_G.cn_vertical = _G.cn_vertical or {}
local cn_vertical = _G.cn_vertical

-- Load submodules using Lua's require mechanism
-- Check if already loaded via dofile (package.loaded set manually by each module)
local constants = package.loaded['constants'] or require('constants')
local flatten = package.loaded['flatten'] or require('flatten')
local layout = package.loaded['layout'] or require('layout')
local render = package.loaded['render'] or require('render')

if texio and texio.write_nl then
    texio.write_nl("core.lua: Submodules loaded successfully")
    texio.write_nl("  constants = " .. tostring(constants))
    texio.write_nl("  flatten = " .. tostring(flatten))
end

--- Main entry point called from TeX
-- @param box_num (number) TeX box register number
-- @param params (table) Parameter table
-- @return (number) Total pages generated
function cn_vertical.prepare_grid(box_num, params)
    -- 1. Get box from TeX
    local box = tex.box[box_num]
    if not box then return end

    local list = box.list
    local g_width = constants.to_dimen(params.grid_width) or (65536 * 20)
    local g_height = constants.to_dimen(params.grid_height) or g_width

    -- Use grid_height (char height) as approximate char width for indent calculation
    local char_width = g_height

    local h_dim = constants.to_dimen(params.height) or (65536 * 300)
    local b_padding_top = constants.to_dimen(params.border_padding_top) or 0
    local b_padding_bottom = constants.to_dimen(params.border_padding_bottom) or 0
    local b_thickness = constants.to_dimen(params.border_thickness) or 26214 -- 0.4pt
    local ob_thickness = constants.to_dimen(params.outer_border_thickness) or (65536 * 2)
    local ob_sep = constants.to_dimen(params.outer_border_sep) or (65536 * 2)
    local b_interval = tonumber(params.n_column) or 8
    local p_cols = tonumber(params.page_columns) or (2 * b_interval + 1)

    local p_width = constants.to_dimen(params.paper_width) or 0
    local p_height = constants.to_dimen(params.paper_height) or 0
    local m_top = constants.to_dimen(params.margin_top) or 0
    local m_bottom = constants.to_dimen(params.margin_bottom) or 0
    local m_left = constants.to_dimen(params.margin_left) or 0
    local m_right = constants.to_dimen(params.margin_right) or 0

    local limit = tonumber(params.col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_debug = (params.debug_on == "true" or params.debug_on == true)
    local is_border = (params.border_on == "true" or params.border_on == true)
    local is_outer_border = (params.outer_border_on == "true" or params.outer_border_on == true)

    local valign = params.vertical_align or "center"
    if valign ~= "top" and valign ~= "center" and valign ~= "bottom" then
        valign = "center"
    end

    -- 3. Pipeline Stage 1: Flatten VBox (if needed)
    if box.id == 1 then
        list = flatten.flatten_vbox(list, g_width, char_width)
    end

    -- 4. Pipeline Stage 2: Calculate grid layout
    local layout_map, total_pages = layout.calculate_grid_positions(list, g_height, limit, b_interval, p_cols)

    -- 5. Pipeline Stage 3: Apply positions and render
    -- Build rendering params
    local r_params = {
        grid_width = g_width,
        grid_height = g_height,
        total_pages = total_pages,
        vertical_align = valign,
        draw_debug = is_debug,
        draw_border = is_border,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        line_limit = limit,
        border_thickness = b_thickness,
        draw_outer_border = is_outer_border,
        outer_border_thickness = ob_thickness,
        outer_border_sep = ob_sep,
        n_column = b_interval,
        page_columns = p_cols,
        border_rgb = params.border_color,
        bg_rgb = params.background_color,
        font_rgb = params.font_color,
        paper_width = p_width,
        paper_height = p_height,
        margin_top = m_top,
        margin_bottom = m_bottom,
        margin_left = m_left,
        margin_right = m_right,
        banxin_s1_ratio = tonumber(params.banxin_s1_ratio) or 0.28,
        banxin_s2_ratio = tonumber(params.banxin_s2_ratio) or 0.56,
        banxin_s3_ratio = tonumber(params.banxin_s3_ratio) or 0.16,
        banxin_text = params.banxin_text or ""
    }
    local rendered_pages = render.apply_positions(list, layout_map, r_params)

    -- 6. Store pages and return count
    _G.cn_vertical_pending_pages = {}
    
    local outer_shift = is_outer_border and (ob_thickness + ob_sep) or 0
    local char_grid_height = limit * g_height
    local total_v_depth = char_grid_height + b_padding_top + b_padding_bottom + b_thickness + outer_shift * 2

    for i, page_info in ipairs(rendered_pages) do
        local new_box = node.new("hlist")
        new_box.dir = "TLT"
        new_box.list = page_info.head
        new_box.width = page_info.cols * g_width + b_thickness + outer_shift * 2
        new_box.height = 0
        new_box.depth = total_v_depth
        _G.cn_vertical_pending_pages[i] = new_box
    end

    return #_G.cn_vertical_pending_pages
end

--- Load a prepared page into a TeX box register
-- @param box_num (number) TeX box register
-- @param index (number) Page index (0-based from TeX loop)
function cn_vertical.load_page(box_num, index)
    local box = _G.cn_vertical_pending_pages[index + 1]
    if box then
        tex.box[box_num] = box
        -- Clear from storage to avoid memory leaks if called multiple times
        -- Actually, we might need it for re-rendering, so keep it for now
        -- Or clear it on the last page.
    end
end

--- Interface for TeX to call to process and output pages
function cn_vertical.process_from_tex(box_num, params)
    local total_pages = cn_vertical.prepare_grid(box_num, params)
    
    for i = 0, total_pages - 1 do
        tex.print(string.format("\\directlua{cn_vertical.load_page(%d, %d)}", box_num, i))
        tex.print("\\par\\nointerlineskip")
        tex.print(string.format("\\noindent\\hfill\\smash{\\box%d}", box_num))
        if i < total_pages - 1 then
            tex.print("\\newpage")
        end
    end
end

-- CRITICAL: Update global variable with the local one that has the function
_G.cn_vertical = cn_vertical

-- Return module
return cn_vertical
