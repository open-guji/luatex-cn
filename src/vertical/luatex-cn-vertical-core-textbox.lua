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
-- core_textbox.lua - ???(GridTextbox)????
-- ============================================================================
-- ???: core_textbox.lua (? textbox.lua)
-- ??: ??? (Core/Coordinator Layer)
--
-- ????? / Module Purpose?
-- ???????"?????"(GridTextbox)?????????????:
--   1. ?? TeX ?????(hlist/vlist)
--   2. ??????"????",????????????
--   3. ???????(ATTR_TEXTBOX_WIDTH/HEIGHT),??????????
--   4. ??????(???????? \leftskip)
--
-- ????? / Terminology?
--   process_inner_box   - ??????(?????)
--   GridTextbox         - ?????(TeX ??????)
--   ATTR_TEXTBOX_*      - ???????(??/??,?????)
--   distribute          - ????(?????????)
--
-- ????????
--   process_inner_box(box_num, params)
--      - box_num: TeX ????
--      - params: ?????????????????????????
--
-- ??????
--   • ????????????? 1 ???(???),??????????
--   • ?? distribute=true,????????????????
--   • ???? baseline ?????? TeX ?? \leavevmode ??
--
-- ============================================================================

local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')
local D = node.direct

local textbox = {}

--- ??? TeX ????????????
-- @param box_num (number) TeX ???????
-- @param params (table) ????
--    - n_cols (number): ?????
--    - height (number): ?????(??????)
--    - grid_width (string/number): ??????
--    - grid_height (string/number): ??????
--    - box_align (string): ???????? ("top", "bottom", "fill")
--    - debug (boolean/string): ????????
--    - border (boolean/string): ????????
function textbox.process_inner_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    -- 1. ????????????
    local current_indent = 0
    local ci = tex.attribute[constants.ATTR_INDENT]
    if ci and ci > -1 then
        current_indent = ci
    end

    -- ?? TeX ? leftskip(??????)
    local char_height = constants.to_dimen(params.grid_height) or (65536 * 12)
    local ls_width = tex.leftskip.width
    if ls_width > 0 then
        local ls_indent = math.floor(ls_width / char_height + 0.5)
        current_indent = math.max(current_indent, ls_indent)
    end

    -- 2. ?????????
    -- ??????? (?? "right,left")
    local col_aligns = {}
    if params.column_aligns then
        local idx = 0
        for align in string.gmatch(params.column_aligns, '([^,]+)') do
            -- Trim whitespace
            align = align:gsub("^%s*(.-)%s*$", "%1")
            col_aligns[idx] = align
            idx = idx + 1
        end
    end

    -- ???????????????????"??"
    local ba = params.box_align or "top"
    local n_cols = tonumber(params.n_cols) or 0
    if n_cols <= 0 then
        -- Auto columns: set to a large enough value to accommodate any content
        -- without triggering a page break in the layout engine.
        n_cols = 100
    end

    local sub_params = {
        n_cols = n_cols,
        page_columns = n_cols,
        col_limit = tonumber(params.height) or 6,
        grid_width = params.grid_width,
        grid_height = params.grid_height,
        box_align = params.box_align,
        column_aligns = col_aligns,
        debug_on = (params.debug == "true" or params.debug == true) or (_G.vertical and _G.vertical.debug and _G.vertical.debug.enabled),
        border_on = (params.border == "true" or params.border == true),
        background_color = params.background_color,
        font_color = params.font_color,
        font_size = params.font_size,
        is_textbox = true,
        distribute = (ba == "fill"),
        border_color = params.border_color,
    }

    -- 3. ?????????
    -- ??:???????? core ??? prepare_grid ??
    -- ????????,?????? _G.vertical ??
    local vertical = _G.vertical
    if not vertical or not vertical.prepare_grid then
        utils.debug_log("[textbox] Error: vertical.prepare_grid not found")
        return
    end

    -- ???????????????
    local saved_pages = _G.vertical_pending_pages
    _G.vertical_pending_pages = {}

    utils.debug_log("--- textbox.process_inner_box: START (box=" .. box_num .. ", indent=" .. tostring(current_indent) .. ") ---")

    -- ????????
    vertical.prepare_grid(box_num, sub_params)

    -- ??????(???? 1 "?")
    local res_box = _G.vertical_pending_pages[1]

    -- ?????????
    _G.vertical_pending_pages = saved_pages

    if res_box then
        -- 4. ??????,????????????
        -- ?????????
        -- For textboxes, we store the ACTUAL column count as the width attribute
        -- so that the outer layout can eventually handle wide blocks.
        local actual_cols = node.get_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH) or 1
        node.set_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH, actual_cols)
        node.set_attribute(res_box, constants.ATTR_TEXTBOX_HEIGHT, tonumber(params.height) or 1)
        
        -- ??????,???????????????
        if current_indent > 0 then
            node.set_attribute(res_box, constants.ATTR_INDENT, current_indent)
        end
        
        -- ????????? TeX
        tex.box[box_num] = res_box
    end
end

-- Registry for floating textboxes
textbox.floating_registry = {}
textbox.floating_counter = 0

--- Register a floating textbox from a TeX box
-- @param box_num (number) TeX box register number
-- @param params (table) { x = string/dim, y = string/dim }
function textbox.register_floating_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    textbox.floating_counter = textbox.floating_counter + 1
    local id = textbox.floating_counter

    -- Capture the box (already processed by process_inner_box)
    local b = node.copy_list(box)
    
    textbox.floating_registry[id] = {
        box = b,
        x = constants.to_dimen(params.x) or 0,
        y = constants.to_dimen(params.y) or 0
    }

    utils.debug_log(string.format("[textbox] Registered floating box ID=%d at (%s, %s)", id, tostring(params.x), tostring(params.y)))

    -- Create user whatsit anchor
    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.FLOATING_TEXTBOX_USER_ID
    n.type = 100 -- Integer type
    n.value = id

    node.write(n)
end

--- Calculate positions for floating boxes
-- @param layout_map (table) Main layout map
-- @param params (table) { list = head_node }
function textbox.calculate_floating_positions(layout_map, params)
    local floating_map = {}
    local list = params.list
    if not list then return {} end

    local t = D.todirect(list)
    local last_page = 0
    
    while t do
        local id = D.getid(t)
        if id == constants.WHATSIT then
            local uid = D.getfield(t, "user_id")
            if uid == constants.FLOATING_TEXTBOX_USER_ID then
                local fid = D.getfield(t, "value")
                local item = textbox.floating_registry[fid]
                if item then
                    -- Use the last seen page from layout_map nodes
                    table.insert(floating_map, {
                        box = item.box,
                        page = last_page,
                        x = item.x,
                        y = item.y
                    })
                    utils.debug_log(string.format("[textbox] Placed floating box %d on page %d", fid, last_page))
                end
            end
        else
            local pos = layout_map[t]
            if pos then
                last_page = pos.page or 0
            end
        end
        t = D.getnext(t)
    end
    return floating_map
end

-- Register module in package.loaded for require() compatibility
-- ????? package.loaded
package.loaded['luatex-cn-vertical-core-textbox'] = textbox

return textbox