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
local constants = package.loaded['cn_vertical_constants'] or require('cn_vertical_constants')
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
                -- Recurse into boxes
                local inner = D.getfield(t, "list")
                collect_nodes(inner, indent_level, right_indent_level)
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
        if id == constants.HLIST then
            -- This looks like a line. Check for leftskip (indent)
            local line_head = D.getfield(curr, "list")
            local indent = 0
            local right_indent = 0

            -- Check HLIST itself for indent (shift field)
            -- This is where LaTeX stores indentation for list items
            local shift = D.getfield(curr, "shift") or 0
            if shift > 0 then
                -- Use char_width instead of grid_width for indent calculation
                -- This correctly handles nested lists where indent is in em units
                indent = math.floor(shift / char_width + 0.5)
            end

            -- Also check for leftskip glue (fallback for other indent methods)
            local t_scan = line_head
            while t_scan do
                local tid = D.getid(t_scan)
                if tid == constants.GLYPH then
                    -- Content started (glyph), stop looking
                    break
                elseif tid == constants.GLUE and D.getsubtype(t_scan) == 8 then -- leftskip
                    local w = D.getfield(t_scan, "width")
                    if w > 0 and indent == 0 then
                        -- Only use leftskip if we haven't already found shift-based indent
                        indent = math.floor(w / char_width + 0.5)
                    end
                    break
                end
                t_scan = D.getnext(t_scan)
            end

            -- Detect Right Indent (Rightskip) - scan entire list
            -- Note: LaTeX itemize doesn't always generate rightskip glue
            -- Instead, it may adjust line width. So rightmargin might not be detectable here.
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

            -- Collect content of this line, applying indent
            collect_nodes(line_head, indent, right_indent)

            -- Add break penalty (-10001 = column break)
            -- This forces EVERY LINE to start a new column.
            -- This is standard for ancient books where lines are columns.
            local p = D.new(constants.PENALTY)
            D.setfield(p, "penalty", -10001)
            append_node(p)

        elseif id == constants.VLIST then
             -- Recurse or treat as line?
             -- Treat as container.
             local inner = D.getfield(curr, "list")
             -- Flatten recursively
             collect_nodes(inner, 0, 0)
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
package.loaded['cn_vertical_flatten'] = flatten

-- Return module exports
return flatten
