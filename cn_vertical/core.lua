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
    texio.write_nl("  package.loaded['constants'] = " .. tostring(package.loaded['constants']))
end

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
-- @param border_padding (string) Border bottom padding (TeX dimension string)
-- @param vertical_align (string) Vertical alignment: "top", "center", or "bottom"
function cn_vertical.make_grid_box(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding, vertical_align)
    -- 1. Get box from TeX
    local box = tex.box[box_num]
    if not box then return end

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
    
    -- Calculate precise box dimensions to avoid page overflow
    -- height covers upper border half, depth covers lower border half + padding
    local border_thickness = 26214 -- 0.4pt in sp
    local half_thickness = 13107   -- 0.2pt in sp

    local new_box = node.new("hlist")
    new_box.dir = "TLT"
    new_box.list = new_head
    new_box.width = cols * g_width
    new_box.height = limit * g_height + b_padding + border_thickness
    new_box.depth = 0

    tex.box[box_num] = new_box
end

-- CRITICAL: Update global variable with the local one that has the function
_G.cn_vertical = cn_vertical

-- Return module
return cn_vertical
