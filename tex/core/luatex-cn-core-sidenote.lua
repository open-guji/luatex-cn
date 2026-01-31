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
-- core_sidenote.lua - 侧批（Side Annotation）处理模块
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local D = node.direct

local dbg = debug.get_debugger('sidenote')

local sidenote = {}

-- Registry to hold sidenote content
sidenote.registry = {}
sidenote.registry_counter = 0

-- ============================================================================
-- Plugin Standard API
-- ============================================================================

--- Initialize Sidenote Plugin
-- @param params (table) Parameters from TeX
-- @param engine_ctx (table) Shared engine context
-- @return (table|nil) Plugin context or nil if disabled
function sidenote.initialize(params, engine_ctx)
    -- Sidenotes are currently always active if the module is loaded,
    -- but we could add a 'sidenote_on' parameter check here later.
    return {
        map = {} -- This will store the results of calculate_sidenote_positions
    }
end

--- Plugin integration for layout stage
function sidenote.layout(list, layout_map, engine_ctx, context)
    if not context then return end

    local sidenote_map = sidenote.calculate_sidenote_positions(layout_map, {
        list = list,
        page_columns = engine_ctx.page_columns,
        line_limit = engine_ctx.line_limit,
        n_column = engine_ctx.n_column,
        banxin_on = engine_ctx.banxin_on,
        grid_height = engine_ctx.g_height
    })

    context.map = sidenote_map
end

--- Plugin integration for render stage
function sidenote.render(head, layout_map, params, context, engine_ctx, page_idx, p_total_cols)
    if not (context and context.map) then return head end

    local sidenote_for_page = {}
    for sid, sn_list in pairs(context.map) do
        for _, node_info in ipairs(sn_list) do
            if node_info.page == page_idx then
                table.insert(sidenote_for_page, node_info)
            end
        end
    end

    if #sidenote_for_page == 0 then return head end

    dbg.log(string.format("Rendering %d nodes on page %d", #sidenote_for_page, page_idx))

    local d_head = D.todirect(head)

    local render_page = package.loaded['core.luatex-cn-core-render-page'] or
        require('core.luatex-cn-core-render-page')

    local sidenote_x_offset = engine_ctx.g_width * 0.9

    for i = #sidenote_for_page, 1, -1 do
        local item = sidenote_for_page[i]
        local curr = item.node
        D.setnext(curr, nil)

        if not d_head then
            d_head = curr
        else
            d_head = D.insert_before(d_head, d_head, curr)
        end

        local pos = {
            col = item.col,
            row = item.row,
            sidenote_offset = sidenote_x_offset,
        }

        local id = D.getid(curr)
        if id == constants.GLYPH then
            local d = D.getfield(curr, "depth") or 0
            local h = D.getfield(curr, "height") or 0
            local w = D.getfield(curr, "width") or 0

            local rtl_col = p_total_cols - 1 - pos.col
            local boundary_x = (rtl_col + 1) * engine_ctx.g_width + engine_ctx.half_thickness + engine_ctx.shift_x
            local final_x = boundary_x - (w / 2)

            local char_total_height = h + d
            local effective_grid_height = engine_ctx.g_height
            if item.metadata and item.metadata.grid_height then
                effective_grid_height = tonumber(item.metadata.grid_height) or engine_ctx.g_height
            end

            local final_y = -pos.row * engine_ctx.g_height - (effective_grid_height + char_total_height) / 2 + d -
                engine_ctx.shift_y

            D.setfield(curr, "xoffset", final_x)
            D.setfield(curr, "yoffset", final_y)

            local k = D.new(constants.KERN)
            D.setfield(k, "kern", -w)
            D.insert_after(d_head, curr, k)
        elseif id == constants.HLIST or id == constants.VLIST then
            d_head = render_page._internal.handle_block_node(curr, d_head, pos, engine_ctx)
        else
            if id == constants.GLUE then
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)
            end
        end

        if dbg.is_enabled() then
            d_head = render_page._internal.handle_debug_drawing(curr, d_head, pos, engine_ctx)
        end
    end

    return D.tonode(d_head)
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

local function serialize(t)
    if type(t) ~= "table" then return tostring(t) end
    local s = "{"
    for k, v in pairs(t) do
        s = s .. tostring(k) .. "=" .. tostring(v) .. ","
    end
    s = s .. "}"
    return s
end

local function create_gap_tracker()
    local gap_filled = {}
    return {
        get = function(p, c)
            if not gap_filled[p] then gap_filled[p] = {} end
            return gap_filled[p][c] or -1
        end,
        set = function(p, c, r)
            if not gap_filled[p] then gap_filled[p] = {} end
            gap_filled[p][c] = r
        end
    }
end

local function is_reserved_column(col, banxin_on, interval)
    if not banxin_on then return false end
    if interval <= 0 then return false end
    local hooks = package.loaded['core.luatex-cn-hooks'] or
        require('core.luatex-cn-hooks')
    return hooks.is_reserved_column(col, interval)
end

local function skip_to_valid_column(p, c, p_cols, banxin_on, interval)
    while is_reserved_column(c, banxin_on, interval) or
        is_reserved_column(c - 1, banxin_on, interval) or
        (c >= p_cols) do
        if c >= p_cols then
            c = 0
            p = p + 1
        else
            c = c + 1
        end
    end
    return p, c
end

local function extract_registry_content(registry_item)
    local content = nil
    local metadata = {}

    if type(registry_item) == "table" and registry_item.head then
        content = registry_item.head
        metadata = registry_item.metadata or {}
    else
        content = registry_item
    end
    return content, metadata
end

-- Safely resolve dimension value that may be a table (em unit) or number
local function safe_resolve(val, font_size_sp)
    if type(val) == "table" and val.unit == "em" then
        return math.floor((val.value or 0) * (font_size_sp or 655360) + 0.5)
    end
    return tonumber(val) or 0
end

local function calculate_start_position(anchor_row, metadata, main_grid_height)
    local yoffset_grid = safe_resolve(metadata.yoffset, main_grid_height) / main_grid_height
    local padding_top_grid = safe_resolve(metadata.padding_top, main_grid_height) / main_grid_height
    return math.max(anchor_row, padding_top_grid) + yoffset_grid
end

local function calculate_next_node_pos(curr_p, curr_c, curr_r, node_id, config)
    local next_p, next_c, next_r = curr_p, curr_c, curr_r

    -- Determine if this node consumes a row
    if node_id == constants.GLYPH or node_id == constants.HLIST or
        node_id == constants.VLIST or node_id == constants.RULE or
        node_id == constants.GLUE then
        next_r = curr_r + config.step
    end

    -- Handle overflow
    if next_r + config.padding_bottom_grid >= config.line_limit then
        next_c = curr_c + 1
        -- Reset to base_indent instead of just padding_top
        next_r = math.max(config.base_indent, config.padding_top_grid)
        next_p, next_c = skip_to_valid_column(next_p, next_c, config.p_cols, config.banxin_on, config.interval)

        local filled = config.tracker.get(next_p, next_c)
        if next_r <= filled then
            next_r = filled + 0.1
        end
    end

    return next_p, next_c, next_r
end

local function place_individual_sidenote(sid, registry_item, last_node_pos, params, tracker)
    local content, metadata = extract_registry_content(registry_item)
    if not (content and sid and last_node_pos) then return nil end

    local p_cols = params.page_columns or 10
    local line_limit = params.line_limit or 20
    local main_grid_height = params.grid_height or (65536 * 20)
    local step = 1
    if metadata.grid_height and metadata.grid_height > 0 then
        step = metadata.grid_height / main_grid_height
    end

    local config = {
        p_cols = p_cols,
        line_limit = line_limit,
        banxin_on = params.banxin_on,
        interval = params.n_column or 0,
        padding_top_grid = safe_resolve(metadata.padding_top, main_grid_height) / main_grid_height,
        padding_bottom_grid = safe_resolve(metadata.padding_bottom, main_grid_height) / main_grid_height,
        step = step,
        tracker = tracker,
        base_indent = last_node_pos.indent or 0
    }

    local curr_p, curr_c = last_node_pos.page, last_node_pos.col
    local base_indent = last_node_pos.indent or 0
    dbg.log(string.format("Placing sid=%d at p=%d, c=%d, anchor_r=%.2f, indent=%d",
        sid, curr_p, curr_c, last_node_pos.row, base_indent))

    curr_p, curr_c = skip_to_valid_column(curr_p, curr_c, p_cols, config.banxin_on, config.interval)

    local curr_r = calculate_start_position(last_node_pos.row, metadata, main_grid_height)
    local filled_r = tracker.get(curr_p, curr_c)
    if curr_r <= filled_r then
        curr_r = filled_r + 0.1
    end

    local placed_nodes = {}
    local current_content_node = D.todirect(content)

    while current_content_node do
        table.insert(placed_nodes, {
            node = current_content_node,
            page = curr_p,
            col = curr_c,
            row = curr_r,
            metadata = metadata
        })

        tracker.set(curr_p, curr_c, curr_r)

        local nid = D.getid(current_content_node)
        curr_p, curr_c, curr_r = calculate_next_node_pos(curr_p, curr_c, curr_r, nid, config)
        current_content_node = D.getnext(current_content_node)
    end

    return placed_nodes
end

local function find_sidenote_anchors(head, layout_map, on_sidenote_found)
    local t = head
    local last_node_pos = nil
    while t do
        local id = D.getid(t)
        if id == constants.WHATSIT then
            local uid = D.getfield(t, "user_id")
            -- dbg.log("Found whatsit, uid=" .. tostring(uid))
            if uid == constants.SIDENOTE_USER_ID then
                local sid = D.getfield(t, "value")
                local indent = D.get_attribute(t, constants.ATTR_INDENT) or 0
                local pos = layout_map[t]
                if pos then
                    local anchor_pos = {
                        page = pos.page,
                        col = pos.col,
                        row = pos.row,
                        indent = indent
                    }
                    on_sidenote_found(sid, anchor_pos)
                else
                    -- Fallback to last node if whatsit not in layout map
                    on_sidenote_found(sid, last_node_pos)
                end
            end
        else
            if layout_map[t] then
                last_node_pos = layout_map[t]
            end
        end
        t = D.getnext(t)
    end
end

-- Expose internal functions for unit testing
sidenote._internal = {
    serialize = serialize,
    create_gap_tracker = create_gap_tracker,
    is_reserved_column = is_reserved_column,
    skip_to_valid_column = skip_to_valid_column,
    extract_registry_content = extract_registry_content,
    calculate_start_position = calculate_start_position,
    calculate_next_node_pos = calculate_next_node_pos,
    place_individual_sidenote = place_individual_sidenote,
    find_sidenote_anchors = find_sidenote_anchors
}

-- ============================================================================
-- Public API
-- ============================================================================

--- Register a sidenote from a TeX box
function sidenote.register_sidenote(box_num, metadata)
    local box = tex.box[box_num]
    if not box then
        dbg.log("register_sidenote: box is nil!")
        return
    end

    sidenote.registry_counter = sidenote.registry_counter + 1
    local id = sidenote.registry_counter

    local content_head = node.copy_list(box.list)
    sidenote.registry[id] = {
        head = content_head,
        metadata = metadata or {}
    }

    dbg.log(string.format("Registered sidenote ID=%d, metadata=%s", id, serialize(metadata or {})))

    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.SIDENOTE_USER_ID
    n.type = 100
    n.value = id
    node.write(n)
end

--- Calculate positions for sidenotes based on main layout
function sidenote.calculate_sidenote_positions(layout_map, params)
    local sidenote_map = {}
    local list = params.list
    if not list then return {} end

    local tracker = create_gap_tracker()
    local t = D.todirect(list)

    find_sidenote_anchors(t, layout_map, function(sid, last_node_pos)
        local registry_item = sidenote.registry[sid]
        local placed_nodes = place_individual_sidenote(sid, registry_item, last_node_pos, params, tracker)
        if placed_nodes then
            sidenote_map[sid] = placed_nodes
            dbg.log(string.format("Placed sidenote sid=%d with %d nodes", sid, #placed_nodes))
        end
    end)

    return sidenote_map
end

--- Clear the sidenote registry to free node memory
function sidenote.clear_registry()
    sidenote.registry = {}
    sidenote.registry_counter = 0
end

package.loaded['core.luatex-cn-core-sidenote'] = sidenote
return sidenote
