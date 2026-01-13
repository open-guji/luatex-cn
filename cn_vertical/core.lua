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
-- Coordinates the entire vertical typesetting pipeline:
-- 1. Parameter parsing and validation
-- 2. VBox flattening (if needed)
-- 3. Grid layout calculation
-- 4. Position application and rendering
-- 5. Box reconstruction
--
-- @param box_num (number) TeX box register number
-- @param height (string) Total height (TeX dimension string)
-- @param grid_width (string) Column width (TeX dimension string)
-- @param grid_height (string) Row height (TeX dimension string)
-- @param col_limit (number) Max rows per column (0 = auto-calculate)
-- @param debug_on (string|boolean) Enable debug grid ("true"/true)
-- @param border_on (string|boolean) Enable column borders ("true"/true)
-- @param border_padding_top (string) Top padding
-- @param border_padding_bottom (string) Bottom padding
-- @param vertical_align (string) Vertical alignment
-- @param border_thickness (string) Column border thickness
-- @param outer_border_on (string) Whether to draw outer border
-- @param outer_border_thickness (string) Outer border thickness
-- @param outer_border_sep (string) Gap between outer and inner borders
-- @param n_column (number) Number of columns per page
-- @param page_columns (number) Total columns per page
-- @return (number) Total pages generated
function cn_vertical.prepare_grid(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding_top, border_padding_bottom, vertical_align, border_thickness, outer_border_on, outer_border_thickness, outer_border_sep, n_column, page_columns)
    -- 1. Get box from TeX
    local box = tex.box[box_num]
    if not box then return end

    local list = box.list
    local g_width = constants.to_dimen(grid_width) or (65536 * 20)
    local g_height = constants.to_dimen(grid_height) or g_width

    -- Use grid_height (char height) as approximate char width for indent calculation
    -- For square Chinese characters, char_width ≈ char_height
    local char_width = g_height

    local h_dim = constants.to_dimen(height) or (65536 * 300)
    local b_padding_top = constants.to_dimen(border_padding_top) or 0
    local b_padding_bottom = constants.to_dimen(border_padding_bottom) or 0
    local b_thickness = constants.to_dimen(border_thickness) or 26214 -- 0.4pt
    local ob_thickness = constants.to_dimen(outer_border_thickness) or (65536 * 2) -- 2pt default
    local ob_sep = constants.to_dimen(outer_border_sep) or (65536 * 2) -- 2pt default
    local b_interval = tonumber(string.match(tostring(n_column), "[%d%.]+")) or 8
    local p_cols = tonumber(string.match(tostring(page_columns), "[%d%.]+")) or (2 * b_interval + 1)

    local limit = tonumber(col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_debug = (debug_on == "true" or debug_on == true)
    local is_border = (border_on == "true" or border_on == true)
    local is_outer_border = (outer_border_on == "true" or outer_border_on == true)

    if texio and texio.write_nl then
        texio.write_nl(string.format("core.lua: prepare_grid. is_outer_border=%s, border_on=%s, padding_top=%d, padding_bottom=%d, n_column=%d, page_columns=%d", tostring(is_outer_border), tostring(is_border), b_padding_top, b_padding_bottom, b_interval, p_cols))
    end

    -- Parse vertical alignment (default: center)
    local valign = vertical_align or "center"
    if valign ~= "top" and valign ~= "center" and valign ~= "bottom" then
        valign = "center"
    end

    -- 3. Pipeline Stage 1: Flatten VBox (if needed)
    -- If captured as VBOX, flatten it first
    if box.id == 1 then
        list = flatten.flatten_vbox(list, g_width, char_width)
    end

    -- 4. Pipeline Stage 2: Calculate grid layout
    local layout_map, total_pages = layout.calculate_grid_positions(list, g_height, limit, b_interval, p_cols)

    -- 5. Pipeline Stage 3: Apply positions and render
    local rendered_pages = render.apply_positions(list, layout_map, g_width, g_height, total_pages, valign, is_debug, is_border, b_padding_top, b_padding_bottom, limit, b_thickness, is_outer_border, ob_thickness, ob_sep, b_interval, p_cols)

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
function cn_vertical.process_from_tex(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding_top, border_padding_bottom, vertical_align, border_thickness, outer_border_on, outer_border_thickness, outer_border_sep, n_column, page_columns)
    local total_pages = cn_vertical.prepare_grid(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding_top, border_padding_bottom, vertical_align, border_thickness, outer_border_on, outer_border_thickness, outer_border_sep, n_column, page_columns)
    
    for i = 0, total_pages - 1 do
        tex.print(string.format("\\directlua{cn_vertical.load_page(%d, %d)}", box_num, i))
        tex.print("\\par\\nointerlineskip")
        tex.print(string.format("\\noindent\\hfill\\smash{\\box % d}", box_num))
        if i < total_pages - 1 then
            tex.print("\\newpage")
        end
    end
end

-- CRITICAL: Update global variable with the local one that has the function
_G.cn_vertical = cn_vertical

-- Return module
return cn_vertical
