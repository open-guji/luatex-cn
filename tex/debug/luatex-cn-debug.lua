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
-- luatex-cn-debug.lua - Centralized debugging console
-- ============================================================================

_G.luatex_cn_debug = _G.luatex_cn_debug or {
    global_enabled = false,
    modules = {},
    measure = "mm"  -- Default unit: "mm" or "pt"
}

local debug = _G.luatex_cn_debug

-- ANSI Color Codes for terminal output
local COLORS = {
    reset = "\27[0m",
    bold = "\27[1m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m"
}

-- Default module configuration
local DEFAULT_MODULE_CONFIG = {
    enabled = true,
    color = "cyan"
}

--- Register a module for debugging
-- @param name (string) Module name (e.g., "vertical", "banxin")
-- @param config (table) Optional configuration { enabled, color }
function debug.register_module(name, config)
    config = config or {}
    debug.modules[name] = {
        enabled = config.enabled ~= false,
        color = config.color or DEFAULT_MODULE_CONFIG.color
    }
end

--- Set global debugging status
-- @param status (boolean)
function debug.set_global_status(status)
    debug.global_enabled = (status == true or status == "true")
end

--- Set module-specific debugging status
-- @param name (string) Module name
-- @param status (boolean)
function debug.set_module_status(name, status)
    if debug.modules[name] then
        debug.modules[name].enabled = (status == true or status == "true")
    else
        -- Auto-register if not exists
        debug.register_module(name, { enabled = (status == true or status == "true") })
    end
end

--- Log a message to the terminal if debugging is enabled
-- @param module_name (string)
-- @param msg (string)
function debug.log(module_name, msg)
    if not debug.global_enabled then return end

    local mod = debug.modules[module_name]
    -- If module is not registered, we allow logging by default if global is on,
    -- but we won't have custom color.
    if mod and not mod.enabled then return end

    local color_code = mod and COLORS[mod.color] or COLORS.white
    local prefix = string.format("%s[%s]%s", color_code, module_name, COLORS.reset)

    -- Use texio.write_nl to ensure it goes to transcript and console
    if texio and texio.write_nl then
        texio.write_nl("term and log", string.format("%s %s", prefix, msg))
    else
        print(string.format("%s %s", prefix, msg))
    end
end

--- Check if debugging is enabled for a module
-- @param module_name (string)
-- @return (boolean)
function debug.is_enabled(module_name)
    if not debug.global_enabled then return false end
    local mod = debug.modules[module_name]
    return mod == nil or mod.enabled
end

--- Get a debugger instance for a specific module
-- @param module_name (string)
-- @return (table) Debugger instance with .log(msg) and .is_enabled()
function debug.get_debugger(module_name)
    -- Auto-register if not exists
    if not debug.modules[module_name] then
        debug.register_module(module_name)
    end

    return {
        log = function(msg)
            debug.log(module_name, msg)
        end,
        is_enabled = function()
            return debug.is_enabled(module_name)
        end
    }
end

--- Set the measurement unit for rulers
-- @param unit (string) "mm" or "pt"
function debug.set_measure(unit)
    if unit == "mm" or unit == "pt" then
        debug.measure = unit
    end
end

--- Get the current measurement unit
-- @return (string) "mm" or "pt"
function debug.get_measure()
    return debug.measure or "mm"
end

-- ============================================================================
-- Ruler Drawing Functions
-- ============================================================================

-- Conversion constants
local SP_PER_PT = 65536
local SP_PER_BP = 65781.76  -- 1bp = 65781.76sp (for PDF coordinates)
local SP_PER_MM = 186467.98  -- 1mm = 2.845275591pt × 65536sp/pt ≈ 186467.98sp

--- Draw rulers on the page (origin at top-right corner)
-- Rulers show measurements from the top-right corner
-- @param p_head (node) Page head node (direct)
-- @param params (table) Parameters:
--   - paper_width: Paper width in sp
--   - paper_height: Paper height in sp
--   - margin_left: Left margin in sp (content origin X)
--   - margin_top: Top margin in sp (content origin Y from top)
--   - unit: "mm" or "pt" (optional, defaults to debug.measure)
--   - color: Ruler color string (optional, defaults to gray)
--   - tick_interval: Interval between major ticks (optional)
-- @return (node) Updated head node
function debug.draw_ruler(p_head, params)
    if not debug.global_enabled then return p_head end

    params = params or {}
    local paper_w = params.paper_width or (_G.page and _G.page.paper_width) or 0
    local paper_h = params.paper_height or (_G.page and _G.page.paper_height) or 0
    local margin_l = params.margin_left or (_G.page and _G.page.margin_left) or 0
    local margin_t = params.margin_top or (_G.page and _G.page.margin_top) or 0

    if paper_w <= 0 or paper_h <= 0 then return p_head end

    local unit = params.unit or debug.measure or "mm"
    local color = params.color or "0.5 0.5 0.5"  -- Gray

    -- Calculate ruler parameters based on unit
    local sp_per_unit, major_tick, minor_tick
    if unit == "mm" then
        sp_per_unit = SP_PER_MM
        major_tick = 10  -- Major tick every 10mm (1cm)
        minor_tick = 1   -- Minor tick every 1mm
    else
        sp_per_unit = SP_PER_PT
        major_tick = 72  -- Major tick every 72pt (1 inch)
        minor_tick = 10  -- Minor tick every 10pt
    end

    -- Ruler dimensions
    local ruler_width_sp = 8 * SP_PER_PT  -- 8pt wide ruler bar
    local major_tick_len = 6 * SP_PER_PT  -- 6pt long major ticks
    local minor_tick_len = 3 * SP_PER_PT  -- 3pt long minor ticks
    local line_width_bp = 0.3  -- Line width in bp

    -- sp to bp conversion for PDF coordinates
    local function sp_to_bp(sp)
        return sp / SP_PER_BP
    end

    -- Build PDF literal for rulers
    -- Origin in our coordinate system: (margin_left, 0) is top-left of content area
    -- Content box origin is at (margin_left from page left, margin_top from page top)
    -- PDF literal origin is at current position

    -- We need to draw:
    -- 1. Horizontal ruler along the top (showing distance from right edge)
    -- 2. Vertical ruler along the right (showing distance from top edge)

    local pdf_commands = {}
    table.insert(pdf_commands, "q")  -- Save graphics state
    table.insert(pdf_commands, string.format("%.2f w", line_width_bp))  -- Line width
    table.insert(pdf_commands, string.format("%s RG", color))  -- Stroke color
    table.insert(pdf_commands, string.format("%s rg", color))  -- Fill color

    -- Calculate page dimensions in bp
    local page_w_bp = sp_to_bp(paper_w)
    local page_h_bp = sp_to_bp(paper_h)
    local margin_l_bp = sp_to_bp(margin_l)
    local margin_t_bp = sp_to_bp(margin_t)
    local ruler_w_bp = sp_to_bp(ruler_width_sp)
    local major_len_bp = sp_to_bp(major_tick_len)
    local minor_len_bp = sp_to_bp(minor_tick_len)

    -- Current position origin: (0, 0) at content box origin
    -- Content box is at (margin_l, margin_t) from page top-left
    -- For horizontal ruler: draw at top of page (y = margin_t from content origin)
    -- For vertical ruler: draw at right edge of page (x = paper_w - margin_l from content origin)

    -- Horizontal ruler (along top, right-to-left from right edge)
    local h_ruler_y = margin_t_bp  -- Distance above content origin
    local h_ruler_x_start = page_w_bp - margin_l_bp  -- Right edge of page (relative to content origin)

    -- Draw horizontal ruler background
    table.insert(pdf_commands, string.format("%.4f %.4f %.4f %.4f re S",
        -margin_l_bp, h_ruler_y, page_w_bp, ruler_w_bp))

    -- Draw horizontal ticks (from right to left, measuring from right edge)
    local h_max_units = math.floor(paper_w / sp_per_unit)
    for i = 0, h_max_units do
        local x_sp = i * sp_per_unit
        local x_bp = h_ruler_x_start - sp_to_bp(x_sp)

        if i % major_tick == 0 then
            -- Major tick
            table.insert(pdf_commands, string.format("%.4f %.4f m %.4f %.4f l S",
                x_bp, h_ruler_y, x_bp, h_ruler_y + major_len_bp))
        elseif i % minor_tick == 0 then
            -- Minor tick
            table.insert(pdf_commands, string.format("%.4f %.4f m %.4f %.4f l S",
                x_bp, h_ruler_y, x_bp, h_ruler_y + minor_len_bp))
        end
    end

    -- Vertical ruler (along right side, top-to-bottom from top edge)
    local v_ruler_x = page_w_bp - margin_l_bp  -- Right edge of page
    local v_ruler_y_start = margin_t_bp  -- Top edge

    -- Draw vertical ruler background
    table.insert(pdf_commands, string.format("%.4f %.4f %.4f %.4f re S",
        v_ruler_x, v_ruler_y_start, ruler_w_bp, -page_h_bp))

    -- Draw vertical ticks (from top to bottom, measuring from top edge)
    local v_max_units = math.floor(paper_h / sp_per_unit)
    for i = 0, v_max_units do
        local y_sp = i * sp_per_unit
        local y_bp = v_ruler_y_start - sp_to_bp(y_sp)

        if i % major_tick == 0 then
            -- Major tick
            table.insert(pdf_commands, string.format("%.4f %.4f m %.4f %.4f l S",
                v_ruler_x, y_bp, v_ruler_x + major_len_bp, y_bp))
        elseif i % minor_tick == 0 then
            -- Minor tick
            table.insert(pdf_commands, string.format("%.4f %.4f m %.4f %.4f l S",
                v_ruler_x, y_bp, v_ruler_x + minor_len_bp, y_bp))
        end
    end

    -- Draw corner marker at origin (top-right)
    local corner_size_bp = sp_to_bp(4 * SP_PER_PT)
    table.insert(pdf_commands, string.format("1 0 0 RG"))  -- Red for origin marker
    table.insert(pdf_commands, string.format("%.4f %.4f m %.4f %.4f l S",
        h_ruler_x_start - corner_size_bp, h_ruler_y, h_ruler_x_start, h_ruler_y))
    table.insert(pdf_commands, string.format("%.4f %.4f m %.4f %.4f l S",
        h_ruler_x_start, h_ruler_y, h_ruler_x_start, h_ruler_y - corner_size_bp))

    table.insert(pdf_commands, "Q")  -- Restore graphics state

    -- Create PDF literal node
    local literal_str = table.concat(pdf_commands, " ")
    local D = node.direct
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = D.new(whatsit_id, pdf_literal_id)
    D.setfield(nn, "data", literal_str)
    D.setfield(nn, "mode", 0)

    -- Insert at head (will be rendered on top of everything)
    return D.insert_before(p_head, p_head, nn)
end

return debug
