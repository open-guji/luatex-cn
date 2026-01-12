-- cn_vertical.lua
-- Chinese vertical typesetting module for LuaTeX (Refactored Entry Point)
-- Uses native LuaTeX 'dir' primitives for RTT (Right-to-Left Top-to-Bottom) layout.
--
-- This is the main entry point that coordinates all submodules.
-- For detailed architecture, see ARCHITECTURE.md (if available) or README.md
--
-- Version: 0.3.0 (Modularized)
-- Date: 2026-01-12

-- Create module namespace
cn_vertical = cn_vertical or {}

-- Load submodules using Lua's require mechanism
local constants = require('cn_vertical_constants')
local flatten = require('cn_vertical_flatten')
local layout = require('cn_vertical_layout')
local render = require('cn_vertical_render')

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
-- @param border_padding (string) Border bottom padding (TeX dimension string)
-- @param vertical_align (string) Vertical alignment: "top", "center", or "bottom"
function cn_vertical.make_grid_box(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding, vertical_align)
    -- 1. Get box from TeX
    local box = tex.box[box_num]
    if not box then return end

    -- 2. Parse and validate parameters
    local g_width = constants.to_dimen(grid_width) or (65536 * 20)

    local list = box.list
    if not list then return end

    local g_height = constants.to_dimen(grid_height) or g_width

    -- Use grid_height (char height) as approximate char width for indent calculation
    -- For square Chinese characters, char_width ≈ char_height
    local char_width = g_height

    local h_dim = constants.to_dimen(height) or (65536 * 300)
    local b_padding = constants.to_dimen(border_padding) or 0

    local limit = tonumber(col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_debug = (debug_on == "true" or debug_on == true)
    local is_border = (border_on == "true" or border_on == true)

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
    local layout_map, total_cols = layout.calculate_grid_positions(list, g_height, limit)

    -- 5. Pipeline Stage 3: Apply positions and render
    local new_head = render.apply_positions(list, layout_map, g_width, g_height, total_cols, valign, is_debug, is_border, b_padding, limit)

    -- 6. Create new HLIST box for the result
    local cols = total_cols
    if cols == 0 then cols = 1 end
    local actual_rows = math.min(limit, total_cols * limit)
    if cols > 1 then actual_rows = limit end

    local new_box = node.new("hlist")
    new_box.dir = "TLT"
    new_box.list = new_head
    new_box.width = cols * g_width
    new_box.height = 0
    new_box.depth = actual_rows * g_height

    tex.box[box_num] = new_box
end

-- Return module
return cn_vertical
