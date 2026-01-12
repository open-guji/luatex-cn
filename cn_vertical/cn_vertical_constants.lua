-- cn_vertical_constants.lua
-- Chinese vertical typesetting module for LuaTeX - Constants and Utilities
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: constants
-- Purpose: Define all node type constants, custom attributes, and utility functions
-- Dependencies: node, luatexbase
-- Exports: Node type IDs, attributes, to_dimen utility
-- Version: 0.3.0
-- Date: 2026-01-12

-- Create module table
local constants = {}

-- Node.direct interface for performance
constants.D = node.direct

-- Node type IDs
constants.GLYPH = node.id("glyph")
constants.KERN = node.id("kern")
constants.HLIST = node.id("hlist")
constants.VLIST = node.id("vlist")
constants.WHATSIT = node.id("whatsit")
constants.GLUE = node.id("glue")
constants.PENALTY = node.id("penalty")
constants.LOCAL_PAR = node.id("local_par")

-- Custom attributes for indentation
-- Note: Attributes are registered in cn_vertical.sty via \newluatexattribute
constants.ATTR_INDENT = luatexbase.attributes.cnverticalindent or luatexbase.new_attribute("cnverticalindent")
constants.ATTR_RIGHT_INDENT = luatexbase.attributes.cnverticalrightindent or luatexbase.new_attribute("cnverticalrightindent")

--- Convert TeX dimension string to scaled points
-- @param dim_str (string) TeX dimension string (e.g., "20pt", "1.5em")
-- @return (number|nil) Dimension in scaled points, or nil if invalid/zero
-- @usage local sp = constants.to_dimen("20pt")
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" or dim_str == "0" or dim_str == "0pt" then
        return nil
    end
    local ok, res = pcall(tex.sp, dim_str)
    if ok then
        if res == 0 then return nil end
        return res
    else
        return nil
    end
end

constants.to_dimen = to_dimen

-- Return module
return constants
