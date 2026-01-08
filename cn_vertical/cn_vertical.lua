-- cn_vertical.lua
-- Chinese vertical typesetting module for LuaTeX
-- This module implements vertical text layout for Chinese characters

-- Module initialization
if not luatexbase then
    texio.write_nl("term and log", "Package cn_vertical Warning: luatexbase not found")
end

-- Create module namespace
cn_vertical = cn_vertical or {}

-- Node type IDs (LuaTeX primitives)
local node_id = node.id
local GLYPH = node_id("glyph")
local HLIST = node_id("hlist")
local VLIST = node_id("vlist")
local GLUE  = node_id("glue")
local KERN  = node_id("kern")

-- Node manipulation functions
local copy_node = node.copy
local new_node = node.new
local insert_before = node.insert_before
local insert_after = node.insert_after
local remove_node = node.remove
local has_attribute = node.has_attribute
local set_attribute = node.set_attribute

-- Attribute for marking vertical text
cn_vertical.attr_vertical = luatexbase.new_attribute("cnvertical_vertical")

-- State variables
cn_vertical.vertical_mode = false

-- Check if a character is CJK
local function is_cjk_char(char)
    if not char then return false end

    -- CJK Unified Ideographs: U+4E00 to U+9FFF
    if char >= 0x4E00 and char <= 0x9FFF then
        return true
    end

    -- CJK Unified Ideographs Extension A: U+3400 to U+4DBF
    if char >= 0x3400 and char <= 0x4DBF then
        return true
    end

    -- CJK Compatibility Ideographs: U+F900 to U+FAFF
    if char >= 0xF900 and char <= 0xFAFF then
        return true
    end

    -- CJK Unified Ideographs Extension B and beyond: U+20000 to U+2A6DF
    if char >= 0x20000 and char <= 0x2A6DF then
        return true
    end

    return false
end

-- Check if a character is CJK punctuation
local function is_cjk_punctuation(char)
    if not char then return false end

    -- CJK Symbols and Punctuation: U+3000 to U+303F
    if char >= 0x3000 and char <= 0x303F then
        return true
    end

    -- Halfwidth and Fullwidth Forms punctuation: U+FF00 to U+FFEF
    if char >= 0xFF00 and char <= 0xFFEF then
        return true
    end

    return false
end

-- Process nodes for vertical typesetting
-- This is a basic implementation that will be enhanced later
local function process_vertical_nodes(head, is_vertical)
    if not head then return head end

    local current = head

    while current do
        -- Check if this node has the vertical attribute
        local attr_val = has_attribute(current, cn_vertical.attr_vertical)
        local should_be_vertical = (attr_val == 1) or is_vertical

        if current.id == GLYPH then
            local char = current.char

            if should_be_vertical and (is_cjk_char(char) or is_cjk_punctuation(char)) then
                -- Mark this glyph for vertical processing
                -- For now, we just set an attribute
                -- Real implementation will handle rotation and positioning
                set_attribute(current, cn_vertical.attr_vertical, 1)
            end

        elseif current.id == HLIST or current.id == VLIST then
            -- Recursively process nested lists
            if current.head then
                current.head = process_vertical_nodes(current.head, should_be_vertical)
            end
        end

        current = current.next
    end

    return head
end

-- Callback function for pre_linebreak_filter
function cn_vertical.pre_linebreak_filter(head, groupcode)
    return process_vertical_nodes(head, cn_vertical.vertical_mode)
end

-- Callback function for hpack_filter
function cn_vertical.hpack_filter(head, groupcode, size, packtype, direction)
    return process_vertical_nodes(head, cn_vertical.vertical_mode)
end

-- Initialize the module
function cn_vertical.init()
    -- Register callbacks
    if luatexbase then
        luatexbase.add_to_callback("pre_linebreak_filter",
            cn_vertical.pre_linebreak_filter,
            "cn_vertical.pre_linebreak_filter")

        luatexbase.add_to_callback("hpack_filter",
            cn_vertical.hpack_filter,
            "cn_vertical.hpack_filter")

        texio.write_nl("term and log", "cn_vertical: Callbacks registered")
    else
        texio.write_nl("term and log", "cn_vertical Warning: Cannot register callbacks without luatexbase")
    end
end

-- Enable vertical mode
function cn_vertical.begin_vertical()
    cn_vertical.vertical_mode = true
    texio.write_nl("term and log", "cn_vertical: Vertical mode enabled")
end

-- Disable vertical mode
function cn_vertical.end_vertical()
    cn_vertical.vertical_mode = false
    texio.write_nl("term and log", "cn_vertical: Vertical mode disabled")
end

-- Return module
return cn_vertical
