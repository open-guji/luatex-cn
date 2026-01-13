-- cn_vertical_utils.lua
-- Chinese vertical typesetting module for LuaTeX - Utility Functions
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: utils
-- Purpose: Utility functions for color conversion and other helpers
-- Dependencies: none
-- Exports: normalize_rgb, sp_to_bp
-- Version: 0.3.0
-- Date: 2026-01-12

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

--- Normalize RGB color string
-- Converts various RGB formats to normalized 0-1 range
-- Accepts formats:
--   - "r,g,b" or "r g b" where values are 0-1 or 0-255
--   - Automatically detects and converts 0-255 range to 0-1
--
-- @param s (string|nil) RGB color string
-- @return (string|nil) Normalized "r g b" string or nil
local function normalize_rgb(s)
    if s == nil then return nil end
    s = tostring(s)
    if s == "nil" or s == "" then return nil end

    -- Replace commas with spaces
    s = s:gsub(",", " ")

    -- Extract RGB values
    local r, g, b = s:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
    if not r then return s end

    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r or not g or not b then return s end

    -- Convert 0-255 range to 0-1 range
    if r > 1 or g > 1 or b > 1 then
        return string.format("%.4f %.4f %.4f", r/255, g/255, b/255)
    end

    return string.format("%.4f %.4f %.4f", r, g, b)
end

-- Create module table
local utils = {
    normalize_rgb = normalize_rgb,
    sp_to_bp = sp_to_bp,
}

-- Register module in package.loaded for require() compatibility
package.loaded['utils'] = utils

-- Return module exports
return utils
