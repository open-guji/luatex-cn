-- cn_vertical_flatten.lua
-- Chinese vertical typesetting module for LuaTeX - VBox Flattening and Indent Detection
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: flatten
-- Purpose: Recursively traverse VBox structure, extract nodes, detect and mark indentation
-- Dependencies: cn_vertical_constants
-- Exports: flatten_vbox function
-- Version: 0.3.0
-- Date: 2026-01-12

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['constants'] or require('constants')
local D = constants.D

--- Flatten a vlist (from vbox) into a single list of nodes
-- Extracts indentation from line starts and applies it as attributes.
-- Also cleans up nodes (keeps valid glues/glyphs).
--
-- @param head (node) Head of the vlist
-- @param grid_width (number) Grid column width in scaled points
-- @param char_width (number) Character width for indent calculation (usually grid_height)
-- @return (node) Flattened node list with indent attributes
local function flatten_vbox(head, grid_width, char_width)
    local d_head = D.todirect(head)
    local result_head_d = nil
    local result_tail_d = nil

    --- Append a node to the result list
    -- @param n (direct node) Node to append
    local function append_node(n)
        if not n then return end
        D.setnext(n, nil)
        if not result_head_d then
            result_head_d = n
            result_tail_d = n
        else
            D.setlink(result_tail_d, n)
            result_tail_d = n
        end
    end

    --- Recursive node collector
    -- Traverses nested boxes and collects valid nodes
    --
    -- @param n_head (direct node) Head of node list to collect
    -- @param indent_level (number) Left indent level in characters
    -- @param right_indent_level (number) Right indent level in characters
    local function collect_nodes(n_head, indent_level, right_indent_level)
        local t = n_head
        while t do
            local tid = D.getid(t)

            if tid == constants.HLIST or tid == constants.VLIST then
                -- Check if this inner box is a Grid Textbox
                local tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
                local tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0

                if tb_w > 0 and tb_h > 0 then
                    -- This is a textbox block. Do NOT flatten its content.
                    local copy = D.copy(t)
                    append_node(copy)
                else
                    -- Recurse into boxes
                    local inner = D.getfield(t, "list")
                    collect_nodes(inner, indent_level, right_indent_level)
                end
            else
                local keep = false
                if tid == constants.GLYPH or tid == constants.KERN then
                    keep = true
                elseif tid == constants.GLUE then
                    local subtype = D.getsubtype(t)
                    -- Keep userskip (0), spaceskip (13), xspaceskip (14)
                    if subtype == 0 or subtype == 13 or subtype == 14 then
                       keep = true
                    end
                elseif tid == constants.PENALTY then
                    keep = true
                end

                if keep then
                    local copy = D.copy(t)
                    if indent_level > 0 then
                        D.set_attribute(copy, constants.ATTR_INDENT, indent_level)
                    end
                    if right_indent_level > 0 then
                        D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, right_indent_level)
                    end
                    
                    -- CRITICAL: Do NOT let individual glyphs inherit the textbox attribute!
                    -- This prevents the "scattered blocks" issue.
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_WIDTH, 0)
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_HEIGHT, 0)
                    
                    append_node(copy)
                end
            end
            t = D.getnext(t)
        end
    end

    -- Main loop: traverse vlist
    local curr = d_head
    while curr do
        local id = D.getid(curr)
        if id == constants.HLIST or id == constants.VLIST then
            -- Check if this box is a Grid Textbox
            local tb_w = D.get_attribute(curr, constants.ATTR_TEXTBOX_WIDTH) or 0
            local tb_h = D.get_attribute(curr, constants.ATTR_TEXTBOX_HEIGHT) or 0
            
            if tb_w > 0 and tb_h > 0 then
                -- This is a textbox block. Do NOT flatten its content.
                local copy = D.copy(curr)
                append_node(copy)
            else
                -- Traditional line handling or nested box flattening
                if id == constants.HLIST then
                    local line_head = D.getfield(curr, "list")
                    local indent = 0
                    local right_indent = 0

                    local shift = D.getfield(curr, "shift") or 0
                    if shift > 0 then
                        indent = math.floor(shift / char_width + 0.5)
                    end

                    local t_scan = line_head
                    while t_scan do
                        local tid = D.getid(t_scan)
                        if tid == constants.GLYPH then break end
                        if tid == constants.GLUE and D.getsubtype(t_scan) == 8 then -- leftskip
                            local w = D.getfield(t_scan, "width")
                            if w > 0 and indent == 0 then
                                indent = math.floor(w / char_width + 0.5)
                            end
                            break
                        end
                        t_scan = D.getnext(t_scan)
                    end

                    t_scan = line_head
                    while t_scan do
                        if D.getid(t_scan) == constants.GLUE and D.getsubtype(t_scan) == 9 then -- rightskip
                             local w = D.getfield(t_scan, "width")
                             if w > 0 then
                                 right_indent = math.floor((w / char_width) + 0.5)
                             end
                        end
                        t_scan = D.getnext(t_scan)
                    end

                    collect_nodes(line_head, indent, right_indent)

                    local p = D.new(constants.PENALTY)
                    D.setfield(p, "penalty", -10001)
                    append_node(p)
                else -- VLIST
                     local inner = D.getfield(curr, "list")
                     collect_nodes(inner, 0, 0)
                end
            end
        end
        curr = D.getnext(curr)
    end

    return D.tonode(result_head_d)
end

-- Create module table
local flatten = {
    flatten_vbox = flatten_vbox,
}

-- Register module in package.loaded for require() compatibility
package.loaded['flatten'] = flatten

-- Return module exports
return flatten
