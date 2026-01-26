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

local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')
local D = node.direct

local sidenote = {}

-- Registry to hold sidenote content
sidenote.registry = {}
sidenote.registry_counter = 0

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
    return _G.vertical.hooks.is_reserved_column(col, interval)
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

local function calculate_start_position(anchor_row, metadata, main_grid_height)
    local yoffset_grid = (metadata.yoffset or 0) / main_grid_height
    local padding_top_grid = (metadata.padding_top or 0) / main_grid_height
    return math.max(anchor_row + 1, padding_top_grid) + yoffset_grid
end

local function calculate_next_node_pos(curr_p, curr_c, curr_r, node_id, config)
    local next_p, next_c, next_r = curr_p, curr_c, curr_r

    -- Determine if this node consumes a row
    if node_id == constants.GLYPH or node_id == constants.HLIST or
        node_id == constants.VLIST or node_id == constants.RULE then
        next_r = curr_r + config.step
    end

    -- Handle overflow
    if next_r + config.padding_bottom_grid >= config.line_limit then
        next_c = curr_c + 1
        next_r = config.padding_top_grid
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
        padding_top_grid = (metadata.padding_top or 0) / main_grid_height,
        padding_bottom_grid = (metadata.padding_bottom or 0) / main_grid_height,
        step = step,
        tracker = tracker
    }

    local curr_p, curr_c = last_node_pos.page, last_node_pos.col
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
            if uid == constants.SIDENOTE_USER_ID then
                local sid = D.getfield(t, "value")
                on_sidenote_found(sid, last_node_pos)
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
        utils.debug_log("[sidenote] register_sidenote: box is nil!")
        return
    end

    sidenote.registry_counter = sidenote.registry_counter + 1
    local id = sidenote.registry_counter

    local content_head = node.copy_list(box.list)
    sidenote.registry[id] = {
        head = content_head,
        metadata = metadata or {}
    }

    utils.debug_log(string.format("[sidenote] Registered sidenote ID=%d, metadata=%s", id, serialize(metadata or {})))

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
            utils.debug_log(string.format("[sidenote] Placed sidenote sid=%d with %d nodes", sid, #placed_nodes))
        end
    end)

    return sidenote_map
end

--- Clear the sidenote registry to free node memory
function sidenote.clear_registry()
    sidenote.registry = {}
    sidenote.registry_counter = 0
end

package.loaded['vertical.luatex-cn-vertical-core-sidenote'] = sidenote
return sidenote
