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
    modules = {}
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

-- ============================================================================
-- Page Grid Drawing (origin at top-right corner)
-- ============================================================================

debug.show_grid = false
debug.grid_callback_registered = false

-- Conversion factor: sp to bp
local SP_TO_BP = 1 / 65536

--- Draw a number at given position using simple rectangles as digits
-- @param num (number) The number to draw
-- @param x (number) X position in bp
-- @param y (number) Y position in bp (bottom of digits)
-- @param scale (number) Scale factor
-- @return (string) PDF path commands
local function draw_number(num, x, y, scale)
    scale = scale or 0.7
    local str = tostring(num)
    local cmds = {}
    local digit_width = 3 * scale
    local digit_height = 5 * scale
    local spacing = 1.5 * scale

    -- Simple 7-segment style digits using lines
    local segments = {
        --     top,  mid,  bot,  tl,   tr,   bl,   br
        [0] = {true, false, true, true, true, true, true},
        [1] = {false, false, false, false, true, false, true},
        [2] = {true, true, true, false, true, true, false},
        [3] = {true, true, true, false, true, false, true},
        [4] = {false, true, false, true, true, false, true},
        [5] = {true, true, true, true, false, false, true},
        [6] = {true, true, true, true, false, true, true},
        [7] = {true, false, false, false, true, false, true},
        [8] = {true, true, true, true, true, true, true},
        [9] = {true, true, true, true, true, false, true},
    }

    local digit_index = 0
    for i = 1, #str do
        local char = str:sub(i, i)
        local digit = tonumber(char)
        if digit ~= nil then
            local seg = segments[digit]
            if seg ~= nil then
                local dx = x + digit_index * (digit_width + spacing)
                local w, h, m = digit_width, digit_height, digit_height / 2

                -- Draw segments as lines
                if seg[1] then -- top
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y + h, dx + w, y + h))
                end
                if seg[2] then -- middle
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y + m, dx + w, y + m))
                end
                if seg[3] then -- bottom
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y, dx + w, y))
                end
                if seg[4] then -- top-left
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y + m, dx, y + h))
                end
                if seg[5] then -- top-right
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx + w, y + m, dx + w, y + h))
                end
                if seg[6] then -- bottom-left
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y, dx, y + m))
                end
                if seg[7] then -- bottom-right
                    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx + w, y, dx + w, y + m))
                end
                digit_index = digit_index + 1
            end
        elseif char == "." then
            -- Draw decimal point as a small filled circle
            local dx = x + digit_index * (digit_width + spacing)
            local dot_radius = 0.8 * scale
            local dot_x = dx + digit_width / 2
            local dot_y = y + dot_radius
            local k = 0.5522847498
            table.insert(cmds, string.format("%.4f %.4f m", dot_x + dot_radius, dot_y))
            table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
                dot_x + dot_radius, dot_y + k * dot_radius, dot_x + k * dot_radius, dot_y + dot_radius, dot_x, dot_y + dot_radius))
            table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
                dot_x - k * dot_radius, dot_y + dot_radius, dot_x - dot_radius, dot_y + k * dot_radius, dot_x - dot_radius, dot_y))
            table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
                dot_x - dot_radius, dot_y - k * dot_radius, dot_x - k * dot_radius, dot_y - dot_radius, dot_x, dot_y - dot_radius))
            table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
                dot_x + k * dot_radius, dot_y - dot_radius, dot_x + dot_radius, dot_y - k * dot_radius, dot_x + dot_radius, dot_y))
            table.insert(cmds, "f")
            digit_index = digit_index + 1
        elseif char == "-" then
            -- Draw minus sign as a horizontal bar
            local dx = x + digit_index * (digit_width + spacing)
            local bar_y = y + digit_height / 2
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, bar_y, dx + digit_width, bar_y))
            digit_index = digit_index + 1
        end
    end

    return table.concat(cmds, " "), digit_index * (digit_width + spacing)
end

--- Draw a single letter at given position
-- @param letter (string) Single character to draw
-- @param x (number) X position in bp
-- @param y (number) Y position in bp
-- @param scale (number) Scale factor
-- @return (string) PDF path commands, (number) width of letter
local function draw_letter(letter, x, y, scale)
    scale = scale or 1.0
    local cmds = {}
    local w, h = 3 * scale, 5 * scale

    if letter == "c" then
        -- Draw 'c' - open curve on right
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + w, y + h, x, y + h))  -- top
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y + h, x, y))          -- left
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y, x + w, y))          -- bottom
        return table.concat(cmds, " "), w + 2 * scale
    elseif letter == "m" then
        -- Draw 'm' - two humps
        local mw = 4.5 * scale
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y, x, y + h))                    -- left stem
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y + h, x + mw/2, y + h))         -- top left
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + mw/2, y + h, x + mw/2, y))      -- middle stem
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + mw/2, y + h, x + mw, y + h))    -- top right
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + mw, y + h, x + mw, y))          -- right stem
        return table.concat(cmds, " "), mw + 2 * scale
    elseif letter == "p" then
        -- Draw 'p' - stem with top loop
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y - h * 0.4, x, y + h))          -- stem (extends below)
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y + h, x + w, y + h))            -- top
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + w, y + h, x + w, y + h/2))      -- right top
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + w, y + h/2, x, y + h/2))        -- middle
        return table.concat(cmds, " "), w + 2 * scale
    elseif letter == "t" then
        -- Draw 't' - cross shape
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x + w/2, y, x + w/2, y + h))        -- stem
        table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", x, y + h * 0.7, x + w, y + h * 0.7)) -- cross bar
        return table.concat(cmds, " "), w + 2 * scale
    end

    return "", 0
end

--- Draw unit text (e.g., "cm", "pt", "mm") at given position
-- @param unit (string) Unit string to draw
-- @param x (number) X position in bp
-- @param y (number) Y position in bp
-- @param scale (number) Scale factor
-- @return (string) PDF path commands
local function draw_unit_text(unit, x, y, scale)
    scale = scale or 1.0
    local cmds = {}
    local current_x = x

    for i = 1, #unit do
        local letter = unit:sub(i, i)
        local letter_cmds, letter_width = draw_letter(letter, current_x, y, scale)
        if letter_cmds ~= "" then
            table.insert(cmds, letter_cmds)
            current_x = current_x + letter_width
        end
    end

    return table.concat(cmds, " ")
end

-- Unit presets: conversion to bp and grid step sizes
local UNIT_PRESETS = {
    cm = {
        to_bp = 72 / 2.54,       -- 1cm = 28.3465 bp
        small_step = 1,          -- 1cm small grid
        large_step = 5,          -- 5cm large grid
        label = "cm"
    },
    pt = {
        to_bp = 1,               -- 1pt = 1bp (approximately, 72.27pt = 72bp)
        small_step = 50,         -- 50pt small grid
        large_step = 250,        -- 250pt large grid
        label = "pt"
    },
    mm = {
        to_bp = 72 / 25.4,       -- 1mm = 2.8346 bp
        small_step = 10,         -- 10mm small grid
        large_step = 50,         -- 50mm large grid
        label = "mm"
    }
}

--- Generate PDF literal for grid lines and labels (pure PDF, no TikZ/fonts)
-- Origin is at top-right corner: X increases leftward, Y increases downward
-- Flexible unit support: cm, pt, mm
-- @param paper_width_sp (number) Paper width in scaled points
-- @param paper_height_sp (number) Paper height in scaled points
-- @param x_offset_unit (number) X offset in the specified unit (for split page support)
-- @param unit (string) Unit type: "cm", "pt", or "mm" (default: "cm")
-- @return (string) PDF literal commands
local function generate_grid_pdf(paper_width_sp, paper_height_sp, x_offset_unit, unit)
    local W = paper_width_sp * SP_TO_BP  -- width in bp
    local H = paper_height_sp * SP_TO_BP -- height in bp

    -- Get unit preset (default to cm)
    unit = unit or "cm"
    local preset = UNIT_PRESETS[unit] or UNIT_PRESETS.cm
    local unit_to_bp = preset.to_bp
    local small_step = preset.small_step
    local large_step = preset.large_step
    local unit_label = preset.label

    x_offset_unit = x_offset_unit or 0

    local cmds = {}
    table.insert(cmds, "q")  -- save graphics state

    -- Small grid (light blue)
    table.insert(cmds, "0.8 0.85 0.95 RG 0.3 w")  -- light blue
    local step_small_bp = small_step * unit_to_bp
    -- Vertical lines (from right to left)
    for x = 0, W, step_small_bp do
        local pdf_x = W - x  -- PDF coordinate (origin at left)
        table.insert(cmds, string.format("%.4f 0 m %.4f %.4f l S", pdf_x, pdf_x, H))
    end
    -- Horizontal lines (from top to bottom)
    for y = 0, H, step_small_bp do
        local pdf_y = H - y  -- PDF coordinate (origin at bottom)
        table.insert(cmds, string.format("0 %.4f m %.4f %.4f l S", pdf_y, W, pdf_y))
    end

    -- Large grid (darker blue, slightly thicker)
    table.insert(cmds, "0.5 0.65 0.85 RG 0.6 w")
    local step_large_bp = large_step * unit_to_bp
    -- Vertical lines
    for x = 0, W, step_large_bp do
        local pdf_x = W - x
        table.insert(cmds, string.format("%.4f 0 m %.4f %.4f l S", pdf_x, pdf_x, H))
    end
    -- Horizontal lines
    for y = 0, H, step_large_bp do
        local pdf_y = H - y
        table.insert(cmds, string.format("0 %.4f m %.4f %.4f l S", pdf_y, W, pdf_y))
    end

    -- Coordinate labels using vector strokes (no font needed)
    local label_scale = 1.2  -- larger numbers

    -- X-axis labels (inside top edge, every small_step)
    for x = 0, W - 5, step_small_bp do
        local label_val = math.floor(x / unit_to_bp + 0.5 + x_offset_unit)  -- in unit, with offset (integer)
        local is_large_mark = (label_val % large_step == 0)

        -- Use different colors for large vs small marks
        if is_large_mark then
            table.insert(cmds, "0.2 0.35 0.6 RG 0.7 w")  -- darker blue for large
        else
            table.insert(cmds, "0.4 0.55 0.8 RG 0.5 w")  -- lighter blue for small
        end

        local num_width = #tostring(label_val) * 4 * label_scale
        local pdf_x = W - x - num_width - 2
        local pdf_y = H - 12

        local num_cmds = draw_number(label_val, pdf_x, pdf_y, label_scale)
        table.insert(cmds, num_cmds)

        -- Add unit label for large marks
        if is_large_mark then
            local unit_x = pdf_x + num_width + 2
            table.insert(cmds, draw_unit_text(unit_label, unit_x, pdf_y, label_scale * 0.7))
        end
    end

    -- Y-axis labels (inside right edge, every small_step)
    for y = 0, H - 5, step_small_bp do
        local label_val = math.floor(y / unit_to_bp + 0.5)  -- in unit
        local is_large_mark = (label_val % large_step == 0)

        if is_large_mark then
            table.insert(cmds, "0.2 0.35 0.6 RG 0.7 w")
        else
            table.insert(cmds, "0.4 0.55 0.8 RG 0.5 w")
        end

        local num_width = #tostring(label_val) * 4 * label_scale
        local pdf_x = W - num_width - 3
        local pdf_y = H - y - 4

        local num_cmds = draw_number(label_val, pdf_x, pdf_y, label_scale)
        table.insert(cmds, num_cmds)

        -- Add unit label for large marks
        if is_large_mark then
            local unit_x = pdf_x + num_width + 2
            table.insert(cmds, draw_unit_text(unit_label, unit_x, pdf_y, label_scale * 0.7))
        end
    end

    -- Origin marker (red circle at top-right)
    table.insert(cmds, "1 0 0 RG 1 0 0 rg")
    local ox, oy = W, H  -- top-right in PDF coordinates
    local r = 2          -- radius in bp
    -- Draw filled circle using bezier curves
    local k = 0.5522847498  -- magic number for circle approximation
    table.insert(cmds, string.format("%.4f %.4f m", ox + r, oy))
    table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
        ox + r, oy + k * r, ox + k * r, oy + r, ox, oy + r))
    table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
        ox - k * r, oy + r, ox - r, oy + k * r, ox - r, oy))
    table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
        ox - r, oy - k * r, ox - k * r, oy - r, ox, oy - r))
    table.insert(cmds, string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
        ox + k * r, oy - r, ox + r, oy - k * r, ox + r, oy))
    table.insert(cmds, "f")

    table.insert(cmds, "Q")  -- restore graphics state

    return table.concat(cmds, " ")
end

debug.generate_grid_pdf = generate_grid_pdf

-- Track current page for split page offset calculation
debug.current_page = 0
-- Current grid measure unit (cm, pt, mm)
debug.grid_measure = "cm"

--- Create PDF literal node for grid
-- @return (node) PDF literal whatsit node
local function create_grid_node()
    local paper_width = tex.pagewidth or tex.dimen.pagewidth or tex.dimen[0]
    local paper_height = tex.pageheight or tex.dimen.pageheight or tex.dimen[1]

    -- Fallback to A4 if dimensions not available
    if not paper_width or paper_width <= 0 then
        paper_width = 210 * 65536 * 72.27 / 25.4  -- 210mm in sp
    end
    if not paper_height or paper_height <= 0 then
        paper_height = 297 * 65536 * 72.27 / 25.4  -- 297mm in sp
    end

    -- Get current unit preset
    local unit = debug.grid_measure or "cm"
    local preset = UNIT_PRESETS[unit] or UNIT_PRESETS.cm
    local unit_to_bp = preset.to_bp

    -- Calculate X offset for split page support (in the current unit)
    local x_offset_unit = 0
    local page_mod = package.loaded['core.luatex-cn-core-page']
    local split_mod = page_mod and page_mod.split
    if split_mod and split_mod.is_enabled and split_mod.is_enabled() then
        debug.current_page = debug.current_page + 1
        local page_num = debug.current_page
        local is_right_first = split_mod.is_right_first and split_mod.is_right_first()

        -- Calculate offset based on page number and right_first setting
        -- Convert page width to the current unit
        local half_width_unit = (paper_width * SP_TO_BP) / unit_to_bp

        if is_right_first then
            -- Right first: page 1=right(0), page 2=left(half_width)
            if page_num % 2 == 0 then
                x_offset_unit = half_width_unit
            end
        else
            -- Left first: page 1=left(half_width), page 2=right(0)
            if page_num % 2 == 1 then
                x_offset_unit = half_width_unit
            end
        end
    end

    local literal_str = generate_grid_pdf(paper_width, paper_height, x_offset_unit, unit)

    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local n = node.new(whatsit_id, pdf_literal_id)
    n.data = literal_str
    n.mode = 1  -- mode 1: page coordinates (origin at lower-left of page)

    return n
end

--- Pre-shipout callback to add grid to each page
-- The head is typically a vlist box; we need to insert into its content list
local function pre_shipout_grid_callback(head)
    if not debug.show_grid then
        return head
    end

    -- head is typically a vbox (vlist); get its list content
    local id = node.id("vlist")
    if head.id == id then
        -- Strategy: wrap all existing content in q/Q (save/restore graphics state),
        -- then append grid AFTER Q. This ensures:
        -- 1. Grid renders on top of all content (including backgrounds)
        -- 2. Q restores CTM to page origin, so grid coordinates are correct
        local grid_node = create_grid_node()
        local content = head.list
        if content then
            -- Create q (save) and Q (restore) pdf_literal nodes
            local whatsit_id = node.id("whatsit")
            local pdf_literal_id = node.subtype("pdf_literal")
            local q_save = node.new(whatsit_id, pdf_literal_id)
            q_save.data = "q"
            q_save.mode = 2
            local q_restore = node.new(whatsit_id, pdf_literal_id)
            q_restore.data = "Q"
            q_restore.mode = 2

            -- Insert q at beginning
            q_save.next = content
            content.prev = q_save
            head.list = q_save

            -- Find tail and append Q then grid
            local tail = content
            while tail.next do
                tail = tail.next
            end
            tail.next = q_restore
            q_restore.prev = tail
            q_restore.next = grid_node
            grid_node.prev = q_restore
        else
            head.list = grid_node
        end
    end

    return head
end

--- Enable grid display
-- @param measure (string) Optional unit: "cm", "pt", or "mm" (default: "cm")
function debug.enable_grid(measure)
    debug.show_grid = true
    -- Update measure if specified
    if measure and (measure == "cm" or measure == "pt" or measure == "mm") then
        debug.grid_measure = measure
    end

    if not debug.grid_callback_registered then
        luatexbase.add_to_callback("pre_shipout_filter", pre_shipout_grid_callback, "luatex-cn-debug-grid")
        debug.grid_callback_registered = true
    end
end

--- Set grid measure unit without enabling/disabling
-- @param measure (string) Unit: "cm", "pt", or "mm"
function debug.set_grid_measure(measure)
    if measure and (measure == "cm" or measure == "pt" or measure == "mm") then
        debug.grid_measure = measure
    end
end

--- Disable grid display
function debug.disable_grid()
    debug.show_grid = false
    -- Note: We don't remove the callback; it will just be a no-op when show_grid is false
end

-- ============================================================================
-- Floating Box Debug Marker
-- ============================================================================

--- Format coordinate value based on unit with appropriate decimal places
-- @param value_sp (number) Value in scaled points
-- @param measure (string) Unit: "cm", "pt", or "mm"
-- @return (string) Formatted value string
function debug.format_coordinate(value_sp, measure)
    measure = measure or debug.grid_measure or "cm"
    if measure == "pt" then
        -- sp to pt: 1pt = 65536sp
        return string.format("%.1f", value_sp / 65536)
    elseif measure == "mm" then
        -- sp to mm: 1mm ≈ 2.83465pt
        return string.format("%.1f", value_sp / 65536 / 2.83465)
    else
        -- sp to cm (default): 1cm ≈ 28.3465pt
        return string.format("%.1f", value_sp / 65536 / 28.3465)
    end
end

--- Create floating box debug marker node (red cross and coordinates)
-- Uses mode=0 (relative coordinates) so marker follows content
-- @param item (table) Floating box item {x, y, ...} in sp
-- @param box_height (number) Box height in sp
-- @param shift (number) Box vertical shift in sp
-- @return (node) PDF literal node
function debug.create_floating_debug_node(item, box_height, shift)
    local sp_to_bp = 1 / 65536

    -- Debug node is inserted after the box, current position is at box right edge, baseline
    -- Box shift moves content down by shift amount
    -- Box top relative to baseline = height - shift
    -- When outer border exists, shift marker to outer border's top-right corner
    local ob_ext = (item.ob_extension or 0) * sp_to_bp
    local offset_x = ob_ext  -- Shift right to outer border edge
    local offset_y = (box_height - shift) * sp_to_bp + ob_ext  -- Move up to outer border top

    -- Get coordinate values formatted according to current measure
    local x_val = debug.format_coordinate(item.x)
    local y_val = debug.format_coordinate(item.y)

    local cmds = {}
    table.insert(cmds, "q")  -- Save graphics state
    table.insert(cmds, "1 0 0 RG 0.8 w")  -- Red color, line width 0.8

    -- Draw red cross marker (relative to current position)
    local cross_size = 4  -- bp
    local cx, cy = offset_x, offset_y
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S",
        cx - cross_size, cy, cx + cross_size, cy))
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S",
        cx, cy - cross_size, cx, cy + cross_size))

    -- Draw red coordinate numbers
    table.insert(cmds, "1 0 0 RG 0.5 w")  -- Thinner lines for numbers

    -- X coordinate displayed to the right of cross marker
    local x_num_cmds, x_width = draw_number(x_val, cx + cross_size + 2, cy + 2, 0.8)
    table.insert(cmds, x_num_cmds)

    -- Draw comma separator
    local comma_x = cx + cross_size + 2 + x_width + 1
    local comma_y = cy + 2
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", comma_x, comma_y + 1, comma_x, comma_y + 2))
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", comma_x, comma_y + 1, comma_x - 0.5, comma_y - 1))

    -- Y coordinate after comma
    local y_num_cmds, _ = draw_number(y_val, comma_x + 2, cy + 2, 0.8)
    table.insert(cmds, y_num_cmds)

    table.insert(cmds, "Q")  -- Restore graphics state

    -- Create PDF literal node
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local n = node.new(whatsit_id, pdf_literal_id)
    n.data = table.concat(cmds, " ")
    n.mode = 0  -- Relative coordinate mode (follows content)

    return n
end

-- Export draw_number for external use
debug.draw_number = draw_number

-- ============================================================================
-- Table Cell Debug Drawing
-- ============================================================================

--- Draw a coordinate pair label with x and y stacked vertically
-- Line 1 (top): x value
-- Line 2 (bottom): y value
-- @param x_val (string) Formatted X coordinate value
-- @param y_val (string) Formatted Y coordinate value
-- @param px (number) Drawing X position in bp (left edge)
-- @param py (number) Drawing Y position in bp (top of upper line)
-- @param scale (number) Scale factor
-- @return (string) PDF path commands, (number) max width, (number) total height
local function draw_coordinate_pair(x_val, y_val, px, py, scale)
    scale = scale or 0.7
    local cmds = {}
    local line_height = 6 * scale  -- height per line including gap

    -- Line 1: X value (upper)
    local x_cmds, x_width = draw_number(x_val, px, py, scale)
    if x_cmds ~= "" then table.insert(cmds, x_cmds) end

    -- Line 2: Y value (below)
    local y_cmds, y_width = draw_number(y_val, px, py - line_height, scale)
    if y_cmds ~= "" then table.insert(cmds, y_cmds) end

    local max_w = math.max(x_width, y_width)
    return table.concat(cmds, " "), max_w, line_height * 2
end

--- Draw debug overlay for table cells: rectangles, corner coordinates, dimensions
-- Called from render_single_page when debug is enabled and table exists on page.
-- Uses mode=0 (relative to content origin at hlist start).
-- @param p_head (direct node) Page node list head
-- @param ptb (table) Page table bands data from page_table_bands[p]
-- @param params (table) Render context:
--   - total_cols: Total columns on page
--   - shift_x: X offset in sp (includes margins, borders, right-alignment)
--   - shift_y: Y offset in sp (includes outer_shift, border_thickness, padding)
--   - half_thickness: Border half-thickness in sp
--   - col_geom: Column geometry { grid_width, banxin_width, interval }
-- @return (direct node) Updated head
function debug.draw_table_cells_debug(p_head, ptb, params)
    local D = node.direct
    local sp_to_bp = SP_TO_BP
    local text_position = package.loaded['core.luatex-cn-render-position'] or
        require('core.luatex-cn-render-position')

    local total_cols = params.total_cols
    local shift_x = params.shift_x
    local shift_y = params.shift_y
    local half_thickness = params.half_thickness or 0
    local col_geom = params.col_geom
    local grid_width = col_geom.grid_width

    local col_groups = ptb.col_groups or {}
    local n_bands = ptb.n_bands or 1
    local band_heights_sp = ptb.band_heights_sp or {}
    local band_y_offsets_sp = ptb.band_y_offsets_sp or {}
    local table_start_col = ptb.table_start_col or 0
    local n_columns = ptb.n_columns or total_cols

    local measure = debug.grid_measure or "pt"
    local label_scale = 0.75  -- 1.5x base size for readability
    local cmds = {}
    table.insert(cmds, "q")  -- save graphics state

    for band = 0, n_bands - 1 do
        local band_cols = col_groups[band] or {}
        local cum_cols = 0  -- cumulative column offset within band

        -- Determine number of cells in this band
        local n_cells = #band_cols
        if n_cells == 0 then goto continue_band end

        for cell_idx = 1, n_cells do
            local cell_width_cols = band_cols[cell_idx]
            if cell_width_cols == nil then break end

            -- Unlimited cell (0) fills remaining columns
            local actual_cell_cols = cell_width_cols
            if actual_cell_cols == 0 then
                actual_cell_cols = n_columns - cum_cols
                if actual_cell_cols <= 0 then break end
            end

            -- Cell's logical column range
            local start_col = table_start_col + cum_cols
            local end_col = start_col + actual_cell_cols - 1

            -- X positions (in sp, from left edge of hlist box)
            local rtl_left = total_cols - 1 - end_col   -- leftmost visual column
            local rtl_right = total_cols - 1 - start_col -- rightmost visual column
            local x_left_sp = text_position.get_column_x(rtl_left, col_geom)
                + half_thickness + shift_x
            local x_right_sp = text_position.get_column_x(rtl_right, col_geom)
                + text_position.get_column_width(start_col, col_geom)
                + half_thickness + shift_x

            -- Y positions (in sp, mode=0: positive up, negative down from origin)
            local y_top_sp = -(shift_y + (band_y_offsets_sp[band] or 0))
            local y_bottom_sp = -(shift_y + (band_y_offsets_sp[band] or 0) + (band_heights_sp[band] or 0))

            -- Cell dimensions in sp
            local cell_w_sp = x_right_sp - x_left_sp
            local cell_h_sp = band_heights_sp[band] or 0

            -- Convert to bp for PDF drawing
            local xl = x_left_sp * sp_to_bp
            local xr = x_right_sp * sp_to_bp
            local yt = y_top_sp * sp_to_bp
            local yb = y_bottom_sp * sp_to_bp
            local wb = (xr - xl)
            local hb = (yt - yb)  -- positive (top > bottom in PDF coords)

            -- Format coordinate values for labels (content-relative: from content top-left)
            -- X from left edge of content area (remove shift_x and half_thickness)
            local cx_left = debug.format_coordinate(x_left_sp - half_thickness - shift_x, measure)
            local cx_right = debug.format_coordinate(x_right_sp - half_thickness - shift_x, measure)
            -- Y from top of content area (positive downward)
            local cy_top = debug.format_coordinate(band_y_offsets_sp[band] or 0, measure)
            local cy_bottom = debug.format_coordinate((band_y_offsets_sp[band] or 0) + (band_heights_sp[band] or 0), measure)
            -- Dimensions
            local cw = debug.format_coordinate(cell_w_sp, measure)
            local ch = debug.format_coordinate(cell_h_sp, measure)

            -- 1. Draw green rectangle outline
            table.insert(cmds, "0 0.7 0 RG 0.6 w")  -- green, 0.6pt line width
            table.insert(cmds, string.format("%.4f %.4f %.4f %.4f re S", xl, yb, wb, hb))

            -- 2. Draw small cross markers at 4 corners
            local cross = 3  -- cross arm length in bp
            table.insert(cmds, "0 0.7 0 RG 0.5 w")
            -- Top-left
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xl - cross, yt, xl + cross, yt))
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xl, yt - cross, xl, yt + cross))
            -- Top-right
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xr - cross, yt, xr + cross, yt))
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xr, yt - cross, xr, yt + cross))
            -- Bottom-left
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xl - cross, yb, xl + cross, yb))
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xl, yb - cross, xl, yb + cross))
            -- Bottom-right
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xr - cross, yb, xr + cross, yb))
            table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", xr, yb - cross, xr, yb + cross))

            -- 3. Draw coordinate labels at each corner (x/y stacked vertically)
            table.insert(cmds, "0 0.5 0 RG 0.4 w")  -- darker green for labels
            local lo = 3  -- label offset from corner in bp
            local line_h = 6 * label_scale  -- height of one text line

            -- Top-left corner: label inside (right and below)
            local tl_cmds = draw_coordinate_pair(cx_left, cy_top,
                xl + lo, yt - lo, label_scale)
            if tl_cmds ~= "" then table.insert(cmds, tl_cmds) end

            -- Top-right corner: label inside (left and below)
            local _, tr_w = draw_coordinate_pair(cx_right, cy_top, 0, 0, label_scale)
            local tr_cmds = draw_coordinate_pair(cx_right, cy_top,
                xr - lo - tr_w, yt - lo, label_scale)
            if tr_cmds ~= "" then table.insert(cmds, tr_cmds) end

            -- Bottom-left corner: label inside (right and above)
            local bl_cmds = draw_coordinate_pair(cx_left, cy_bottom,
                xl + lo, yb + lo + line_h, label_scale)
            if bl_cmds ~= "" then table.insert(cmds, bl_cmds) end

            -- Bottom-right corner: label inside (left and above)
            local _, br_w = draw_coordinate_pair(cx_right, cy_bottom, 0, 0, label_scale)
            local br_cmds = draw_coordinate_pair(cx_right, cy_bottom,
                xr - lo - br_w, yb + lo + line_h, label_scale)
            if br_cmds ~= "" then table.insert(cmds, br_cmds) end

            -- 4. Draw width label (centered on top edge, above the line)
            table.insert(cmds, "0.8 0.4 0 RG 0.4 w")  -- orange for dimensions
            local _, w_w = draw_number(cw, 0, 0, label_scale)
            local w_cmds = draw_number(cw,
                xl + (wb - w_w) / 2, yt + 2, label_scale)
            if w_cmds ~= "" then table.insert(cmds, w_cmds) end

            -- 5. Draw height label (centered on right edge)
            local _, h_w = draw_number(ch, 0, 0, label_scale)
            local h_cmds = draw_number(ch,
                xr + 3, yb + (hb - 5 * label_scale) / 2, label_scale)
            if h_cmds ~= "" then table.insert(cmds, h_cmds) end

            -- 6. Log output
            debug.log("table", string.format(
                "Cell [band=%d, cell=%d]: cols=%d-%d, x=(%s..%s), y=(%s..%s), w=%s, h=%s %s",
                band, cell_idx - 1, start_col, end_col,
                cx_left, cx_right, cy_top, cy_bottom,
                cw, ch, measure))

            cum_cols = cum_cols + actual_cell_cols
        end

        ::continue_band::
    end

    table.insert(cmds, "Q")  -- restore graphics state

    -- Create single PDF literal node and insert at head
    local literal = table.concat(cmds, " ")
    local whatsit_id_val = node.id("whatsit")
    local pdf_literal_id_val = node.subtype("pdf_literal")
    local nn = D.new(whatsit_id_val, pdf_literal_id_val)
    D.setfield(nn, "data", literal)
    D.setfield(nn, "mode", 0)  -- mode 0: relative to content origin

    p_head = D.insert_before(p_head, p_head, nn)

    return p_head
end

return debug
