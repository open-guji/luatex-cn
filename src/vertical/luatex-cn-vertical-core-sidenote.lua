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
-- 文件名: core_sidenote.lua
-- 层级: 协调层 (Core Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责处理"侧批"（Side Pizhu）。
--   1. 提供 register_sidenote 供 TeX 层调用，将侧批内容注册为 Whatsit 节点
--   2. 提供 calculate_sidenote_positions 计算侧批在页面上的位置
--
-- 【术语对照 / Terminology】
--   Anchor            - 锚点，即正文中侧批依附的字符
--   Gap               - 列间距，侧批显示的区域
--
-- ============================================================================

local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')
local D = node.direct

local sidenote = {}

-- Registry to hold sidenote content
-- Key: integer ID, Value: head node of the sidenote content
sidenote.registry = {}
sidenote.registry_counter = 0

-- Simple table serialization for logging
local function serialize(t)
    if type(t) ~= "table" then return tostring(t) end
    local s = "{"
    for k, v in pairs(t) do
        s = s .. tostring(k) .. "=" .. tostring(v) .. ","
    end
    s = s .. "}"
    return s
end

--- Register a sidenote from a TeX box
-- @param box_num (number) TeX box register number containing the sidenote text
-- @param metadata (table, optional) Metadata { yoffset=number, ... }
function sidenote.register_sidenote(box_num, metadata)
    local box = tex.box[box_num]
    if not box then
        utils.debug_log("[sidenote] register_sidenote: box is nil!")
        return
    end

    sidenote.registry_counter = sidenote.registry_counter + 1
    local id = sidenote.registry_counter

    -- Copy the content
    local content_head = node.copy_list(box.list)
    sidenote.registry[id] = {
        head = content_head,
        metadata = metadata or {}
    }

    utils.debug_log(string.format("[sidenote] Registered sidenote ID=%d, metadata=%s", id, serialize(metadata or {})))

    -- Create user whatsit
    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.SIDENOTE_USER_ID
    n.type = 100 -- Custom subtype
    n.value = id

    node.write(n)
end

--- Calculate positions for sidenotes based on main layout
-- @param layout_map (table) The main text layout map (node -> {page, col, row})
-- @param params (table) Layout parameters
-- @return (table) sidenote_layout_map (id -> {page, col, row_start, content_head})
function sidenote.calculate_sidenote_positions(layout_map, params)
    local sidenote_map = {}
    local p_cols = params.page_columns or 10
    local line_limit = params.line_limit or 20

    utils.debug_log(string.format("[sidenote] calculate_sidenote_positions: registry has %d entries",
        sidenote.registry_counter))
    print(string.format("[SIDENOTE] calculate_sidenote_positions: registry has %d entries", sidenote.registry_counter))

    -- 1. Find all sidenote anchors and their positions
    -- We iterate the layout_map to find the nodes that *precede* a Sidenote Whatsit
    -- Actually, efficient way: Iterate the *original list*?
    -- But we need their layout positions.
    -- Better: Iterate layout_map? No, layout_map is un-ordered.
    -- We need to traverse the node list of each page?
    -- Wait, `core_main` has `list`. We can traverse `list`.

    -- However, `layout_map` keys are nodes.
    -- Let's iterate the original list `params.list` (we need to pass it).

    local list = params.list
    if not list then return {} end

    local t = D.todirect(list)

    -- Gap occupancy: gap_filled[page][col] = last_occupied_row
    local gap_filled = {}

    local function get_gap_filled(p, c)
        if not gap_filled[p] then gap_filled[p] = {} end
        return gap_filled[p][c] or -1
    end

    local function set_gap_filled(p, c, r)
        if not gap_filled[p] then gap_filled[p] = {} end
        gap_filled[p][c] = r
    end

    -- Helper to measure vertical height of sidenote content (in rows)
    local function measure_rows(head, g_height)
        local h = 0
        local temp = head -- direct node
        while temp do
            local id = D.getid(temp)
            if id == constants.GLYPH or id == constants.HLIST or id == constants.VLIST then
                h = h + 1 -- Simplified: assume 1 char = 1 row
            elseif id == constants.GLUE or id == constants.KERN then
                -- For strict grid, maybe counting glue?
                -- For now, sidenote is usually dense text.
                -- Let's start with counting "glyph-like" items + spacing?
                -- Better: use total height / grid_height
            end
            temp = D.getnext(temp)
        end
        -- Fallback: Use node dimensions?
        -- Since we detached it, we need to measure it properly or just verticalize it.
        -- Assuming `\SidePizhu` passes a VBOX, `head` is a list of lines.
        -- Actually, `\vbox` usually contains `hlist` (lines).
        -- We process it as vlist?
        -- Let's count the number of nodes in the list if it's a flat list of chars?
        -- User said "internal text size...".
        -- Let's count children.

        -- Refined: Traverse and count.
        local count = 0
        local temp = head
        while temp do
            local id = D.getid(temp)
            if id == constants.GLYPH or id == constants.BOX or id == constants.HLIST or id == constants.VLIST then
                count = count + 1
            end
            temp = D.getnext(temp)
        end
        return count
    end

    local last_node_pos = nil

    while t do
        local id = D.getid(t)

        if id == constants.WHATSIT then
            local subtype = D.getsubtype(t)
            print(string.format("[SIDENOTE] Found WHATSIT subtype=%d", subtype))
            -- Check user_defined (subtype may vary by LuaTeX version, try multiple)
            -- In LuaTeX 1.x, user_defined is typically subtype 8 or we can check field existence
            local uid = D.getfield(t, "user_id")
            if uid then
                print(string.format("[SIDENOTE] WHATSIT has user_id=%s", tostring(uid)))
            end
            if uid == constants.SIDENOTE_USER_ID then
                local sid = D.getfield(t, "value")
                local registry_item = sidenote.registry[sid]

                -- Registry item can be just head node (old format) or table {head=..., metadata=...}
                local content = nil
                local metadata = {}

                if type(registry_item) == "table" and registry_item.head then
                    content = registry_item.head
                    metadata = registry_item.metadata or {}
                else
                    content = registry_item
                end

                if content and sid and last_node_pos then
                    -- Found a sidenote!
                    local anchor_page = last_node_pos.page
                    local anchor_col = last_node_pos.col
                    local anchor_row = last_node_pos.row

                    -- Determine target column for sidenote (the gap)
                    local start_page = anchor_page
                    local start_col = anchor_col

                    -- Determine step size and yoffset in grid units
                    local sn_grid_height = metadata.grid_height
                    local main_grid_height = params.grid_height or (65536 * 20)     -- Default fallback

                    local yoffset_grid = (metadata.yoffset or 0) / main_grid_height
                    local padding_top_grid = (metadata.padding_top or 0) / main_grid_height
                    local padding_bottom_grid = (metadata.padding_bottom or 0) / main_grid_height

                    local start_row = math.max(anchor_row + 1, padding_top_grid) + yoffset_grid

                    -- Convert Userdata node to Direct for processing
                    local content_d = D.todirect(content)
                    local rows_needed = measure_rows(content_d)

                    -- Placement Logic
                    local placed_nodes = {}
                    local remaining_rows = rows_needed
                    local current_content_node = content_d

                    local step = 1
                    if sn_grid_height and sn_grid_height > 0 then
                        step = sn_grid_height / main_grid_height
                    end

                    local curr_p = start_page
                    local curr_c = start_col
                    -- Start at max(anchor, filled). Add small margin (0.5?) if overlapping.
                    local filled_r = get_gap_filled(curr_p, curr_c)
                    -- Ensure we start below the filled position
                    local curr_r = math.max(start_row, filled_r + 0.1)     -- +0.1 margin

                    while current_content_node do
                        -- Check bounds (approximate check using floor)
                        -- Wrap if current row + bottom padding exceeds line limit
                        if curr_r + padding_bottom_grid >= line_limit then
                            -- Wrap to next column gap
                            curr_c = curr_c + 1
                            -- Start from top padding in the new column
                            curr_r = padding_top_grid
                            if curr_c >= p_cols then
                                curr_c = 0
                                curr_p = curr_p + 1
                            end
                            -- Check gap usage in new column
                            local filled = get_gap_filled(curr_p, curr_c)
                            if curr_r <= filled then
                                curr_r = filled + 0.1
                            end
                        end

                        -- Record placement
                        table.insert(placed_nodes, {
                            node = current_content_node,
                            page = curr_p,
                            col = curr_c,
                            row = curr_r,
                            metadata = metadata
                        })

                        -- Update occupancy
                        set_gap_filled(curr_p, curr_c, curr_r)

                        -- Only increment step for visible content nodes
                        local nid = D.getid(current_content_node)
                        if nid == constants.GLYPH or nid == constants.HLIST or nid == constants.VLIST or nid == constants.RULE then
                            curr_r = curr_r + step
                        end

                        current_content_node = D.getnext(current_content_node)
                    end

                    sidenote_map[sid] = placed_nodes
                    print(string.format("[SIDENOTE] Placed sidenote sid=%d with %d nodes", sid, #placed_nodes))
                end
            end
        else
            -- If this node is in layout_map, update last_node_pos
            if layout_map[t] then
                last_node_pos = layout_map[t]
            end
        end
        t = D.getnext(t)
    end

    return sidenote_map
end

package.loaded['luatex-cn-vertical-core-sidenote'] = sidenote
return sidenote
