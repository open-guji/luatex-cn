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
        if texio and texio.write_nl then
            texio.write_nl("  [flatten] Appending Node=" .. tostring(n) .. " tid=" .. (D.getid(n) or "?"))
        end
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
    -- @param n_head (direct node) Head of node list to collect (WILL BE CONSUMED)
    -- @param indent_lvl (number) Current indent
    -- @param r_indent_lvl (number) Current right indent
    -- @return (boolean) True if any visible content (glyphs/textboxes) was collected
    local function collect_nodes(n_head, indent_lvl, r_indent_lvl)
        local t = n_head
        local running_indent = indent_lvl
        local running_r_indent = r_indent_lvl
        local has_content = false

        while t do
            local tid = D.getid(t)

            -- Check for Textbox Block attribute
            local tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
            local tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0

            if tb_w > 0 and tb_h > 0 then
                local copy = D.copy(t)
                -- Apply running indent (inherited from previous lines if needed)
                if running_indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, running_indent) end
                if running_r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, running_r_indent) end
                append_node(copy)
                has_content = true
            elseif tid == constants.HLIST or tid == constants.VLIST then
                -- Check for line-level indentation
                local inner = D.getfield(t, "list")
                local box_indent = running_indent
                local box_r_indent = running_r_indent

                -- Detect Shift on any box
                local shift = D.getfield(t, "shift") or 0
                if shift > 0 then
                    box_indent = math.max(box_indent, math.floor(shift / char_width + 0.5))
                end

                if tid == constants.HLIST then
                    -- Check for leftskip inside HLIST
                    local s = inner
                    while s do
                        local sid = D.getid(s)
                        if sid == constants.GLYPH then break end
                        if sid == constants.GLUE and D.getsubtype(s) == 8 then -- leftskip
                            local w = D.getfield(s, "width")
                            if w > 0 then
                                box_indent = math.max(box_indent, math.floor(w / char_width + 0.5))
                            end
                            break
                        end
                        s = D.getnext(s)
                    end
                end

                -- UPDATE running indent for siblings? 
                -- Only if this box seems to be a line (HLIST) or a significant block.
                if box_indent > running_indent then running_indent = box_indent end

                -- Recurse
                local inner_has_content = collect_nodes(inner, box_indent, box_r_indent)
                if inner_has_content then has_content = true end
                
                -- IMPORTANT: Only add penalty for HLIST lines that are part of 
                -- the main vertical flow, i.e., at the second recursion level.
                -- For simplicity, let's just add it if this HLIST had content.
                if tid == constants.HLIST and inner_has_content then
                    if texio and texio.write_nl then
                        texio.write_nl("  [flatten] Adding Column Break after Line=" .. tostring(t))
                    end
                    local p = D.new(constants.PENALTY)
                    D.setfield(p, "penalty", -10001)
                    append_node(p)
                end
            else
                local keep = false
                if tid == constants.GLYPH or tid == constants.KERN then
                    keep = true
                    if tid == constants.GLYPH then has_content = true end
                elseif tid == constants.GLUE then
                    local subtype = D.getsubtype(t)
                    if subtype == 0 or subtype == 13 or subtype == 14 then
                       keep = true
                    end
                elseif tid == constants.PENALTY then
                    keep = true
                end

                if keep then
                    local copy = D.copy(t)
                    if running_indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, running_indent) end
                    if running_r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, running_r_indent) end
                    
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_WIDTH, 0)
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_HEIGHT, 0)
                    
                    append_node(copy)
                end
            end
            t = D.getnext(t)
        end
        return has_content
    end

    collect_nodes(d_head, 0, 0)
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
