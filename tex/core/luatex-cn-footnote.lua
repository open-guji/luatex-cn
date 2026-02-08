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
-- luatex-cn-footnote.lua - Footnote/Jiaokan Plugin
-- ============================================================================
-- Mode 1 (endnote): TeX handles everything via expl3 sequences
-- Mode 2 (page footnote): Uses WHATSIT anchors + per-page collection + render
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local D = node.direct

local dbg = debug.get_debugger('footnote')

local footnote = {}

-- Registry to hold footnote content (Mode 2)
footnote.registry = {}
footnote.registry_counter = 0

-- ============================================================================
-- Plugin Standard API
-- ============================================================================

--- Initialize plugin context
-- @param params (table) Parameters from TeX
-- @param engine_ctx (table) Engine context
-- @return (table) Plugin context
function footnote.initialize(params, engine_ctx)
    local mode = _G.footnote and _G.footnote.mode or "endnote"
    return {
        mode = mode,
        map = {} -- Per-page footnote positions for Mode 2
    }
end

--- Flatten stage: Collect footnote anchors (Mode 2 only)
-- @param head (node) Node list head
-- @param params (table) Parameters
-- @param ctx (table) Plugin context
-- @return (node) Processed node list
function footnote.flatten(head, params, ctx)
    if not ctx or ctx.mode ~= "page" then return head end
    -- Mode 2: WHATSIT anchors are automatically in the stream from register_footnote
    -- No processing needed here - layout stage will handle anchor detection
    return head
end

--- Layout stage: Calculate per-page footnote positions
-- @param list (node) Node list
-- @param layout_map (table) Layout mapping
-- @param engine_ctx (table) Engine context
-- @param ctx (table) Plugin context
function footnote.layout(list, layout_map, engine_ctx, ctx)
    if not ctx or ctx.mode ~= "page" then return end

    local footnote_map = footnote.calculate_footnote_positions(layout_map, {
        list = list,
        page_columns = engine_ctx.page_columns,
        line_limit = engine_ctx.line_limit,
        grid_height = engine_ctx.g_height
    })

    ctx.map = footnote_map
end

--- Render stage: Draw footnotes at page bottom/left
-- @param head (node) Page head node
-- @param layout_map (table) Layout mapping
-- @param render_ctx (table) Render context
-- @param ctx (table) Plugin context
-- @param engine_ctx (table) Engine context
-- @param page_idx (number) Page index (0-based)
-- @param p_total_cols (number) Total columns on page
-- @return (node) Processed page head
function footnote.render(head, layout_map, render_ctx, ctx, engine_ctx, page_idx, p_total_cols)
    if not ctx or ctx.mode ~= "page" then return head end
    if not ctx.map then return head end

    -- Initialize carryover storage for cross-page footnotes
    ctx.carryover = ctx.carryover or {}

    -- Collect footnotes for this page (including carryover from previous page)
    local footnotes_for_page = {}

    -- Add carryover footnotes from previous page first
    if ctx.carryover[page_idx] then
        for _, fn_info in ipairs(ctx.carryover[page_idx]) do
            table.insert(footnotes_for_page, fn_info)
        end
    end

    -- Add new footnotes anchored on this page
    for fid, fn_list in pairs(ctx.map) do
        for _, node_info in ipairs(fn_list) do
            if node_info.page == page_idx then
                table.insert(footnotes_for_page, {
                    fid = fid,
                    row = node_info.anchor_row,
                    content = footnote.registry[fid],
                    is_continuation = false
                })
            end
        end
    end

    if #footnotes_for_page == 0 then return head end

    -- Sort by row order (carryover footnotes have row = -1, so they come first)
    table.sort(footnotes_for_page, function(a, b) return (a.row or 0) < (b.row or 0) end)

    dbg.log(string.format("Rendering %d footnotes on page %d", #footnotes_for_page, page_idx))

    local d_head = D.todirect(head)

    -- Calculate footnote column position (leftmost column)
    local fn_col = p_total_cols - 1           -- Rightmost in RTL = leftmost visually
    local rtl_col = p_total_cols - 1 - fn_col -- = 0 (leftmost in LTR coords)

    local fn_x = rtl_col * engine_ctx.g_width + engine_ctx.half_thickness + engine_ctx.shift_x
    local sep_x = fn_x + engine_ctx.g_width + 10 * 65536 -- Separator 10pt to the right

    -- Draw vertical separator line
    local sep_y_top = -engine_ctx.shift_y
    local sep_y_bottom = -(engine_ctx.line_limit * engine_ctx.g_height + engine_ctx.shift_y)
    local sep_literal = string.format(
        "q 0.4 w 0.5 0.5 0.5 RG %.4f %.4f m %.4f %.4f l S Q",
        sep_x * utils.sp_to_bp, sep_y_top * utils.sp_to_bp,
        sep_x * utils.sp_to_bp, sep_y_bottom * utils.sp_to_bp
    )
    local sep_node = utils.create_pdf_literal(sep_literal)
    d_head = D.insert_before(d_head, d_head, sep_node)

    -- Render each footnote with overflow detection
    local current_row = 0
    local line_limit = engine_ctx.line_limit or 20
    local overflow_footnotes = {}

    for i, fn_info in ipairs(footnotes_for_page) do
        local content = fn_info.content
        if content and content.head then
            -- Check if we have room on this page
            if current_row >= line_limit - 2 then
                -- Not enough room, carry over to next page
                table.insert(overflow_footnotes, {
                    fid = fn_info.fid,
                    row = -1, -- Will be sorted first on next page
                    content = content,
                    is_continuation = true
                })
                dbg.log(string.format("Footnote %d overflows to next page", fn_info.fid))
            else
                -- Render footnote on this page
                local node_head = D.todirect(content.head)
                local fn_row = current_row
                local node_count = 0

                while node_head do
                    -- Check for page overflow mid-footnote
                    if fn_row >= line_limit - 1 then
                        -- Mid-footnote overflow: remaining content goes to next page
                        local remaining_head = node_head
                        if remaining_head then
                            table.insert(overflow_footnotes, {
                                fid = fn_info.fid,
                                row = -1,
                                content = { head = D.tonode(remaining_head) },
                                is_continuation = true
                            })
                            dbg.log(string.format("Footnote %d split across pages at row %d", fn_info.fid, fn_row))
                        end
                        break
                    end

                    local nid = D.getid(node_head)
                    if nid == constants.GLYPH then
                        local h = D.getfield(node_head, "height") or 0
                        local d = D.getfield(node_head, "depth") or 0
                        local w = D.getfield(node_head, "width") or 0

                        local final_x = fn_x
                        local final_y = -(fn_row * engine_ctx.g_height + (engine_ctx.g_height + h + d) / 2 - d + engine_ctx.shift_y)

                        D.setfield(node_head, "xoffset", final_x)
                        D.setfield(node_head, "yoffset", final_y)

                        -- Insert kern to cancel width
                        local k = D.new(constants.KERN)
                        D.setfield(k, "kern", -w)

                        fn_row = fn_row + 1
                        node_count = node_count + 1
                    end
                    node_head = D.getnext(node_head)
                end

                current_row = fn_row + 1 -- Add spacing between footnotes
            end
        end
    end

    -- Store overflow footnotes for next page
    if #overflow_footnotes > 0 then
        ctx.carryover[page_idx + 1] = overflow_footnotes
        dbg.log(string.format("Stored %d footnotes for carryover to page %d", #overflow_footnotes, page_idx + 1))
    end

    return D.tonode(d_head)
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Register a footnote from TeX (Mode 2)
-- @param box_num (number) TeX box register containing footnote content
-- @param marker_num (number) The footnote number for marker
function footnote.register_footnote(box_num, marker_num)
    local box = tex.box[box_num]
    if not box then
        dbg.log("register_footnote: box is nil!")
        return
    end

    footnote.registry_counter = footnote.registry_counter + 1
    local id = footnote.registry_counter

    local content_head = node.copy_list(box.list)

    footnote.registry[id] = {
        head = content_head,
        marker_num = marker_num or id
    }

    dbg.log(string.format("Registered footnote ID=%d", id))

    -- Create WHATSIT anchor node
    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.FOOTNOTE_USER_ID
    n.type = 100
    n.value = id
    node.write(n)
end

--- Calculate positions for Mode 2 footnotes
function footnote.calculate_footnote_positions(layout_map, params)
    local footnote_map = {}
    local list = params.list
    if not list then return {} end

    local t = D.todirect(list)

    -- Find footnote anchors
    while t do
        local id = D.getid(t)
        if id == constants.WHATSIT then
            local uid = D.getfield(t, "user_id")
            if uid == constants.FOOTNOTE_USER_ID then
                local fid = D.getfield(t, "value")
                local pos = layout_map[t]
                if pos then
                    if not footnote_map[fid] then
                        footnote_map[fid] = {}
                    end
                    table.insert(footnote_map[fid], {
                        page = pos.page,
                        anchor_row = pos.row
                    })
                    dbg.log(string.format("Found footnote anchor fid=%d at page=%d, row=%.2f",
                        fid, pos.page, pos.row))
                end
            end
        end
        t = D.getnext(t)
    end

    return footnote_map
end

--- Clear the footnote registry
function footnote.clear_registry()
    footnote.registry = {}
    footnote.registry_counter = 0
end

-- Register module
package.loaded['core.luatex-cn-footnote'] = footnote
return footnote
