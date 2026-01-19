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
-- flatten_nodes.lua - ?????????(????)
-- ============================================================================
-- ???: flatten_nodes.lua (? flatten.lua)
-- ??: ???? - ??? (Stage 1: Flatten Layer)
--
-- ????? / Module Purpose?
-- ???????????????,? TeX ?????????????????:
--   1. ???? VBox/HBox,??????????????
--   2. ???????????(leftskip glue?box shift)
--   3. ??????????????????(ATTR_INDENT)
--   4. ????????????(penalty -10001)
--   5. ??????(?? glyph?kern??? glue?textbox ?)
--
-- ????? / Terminology?
--   flatten         - ??(???????????)
--   indent          - ??(???????)
--   leftskip        - ????(TeX ????????)
--   shift           - ????(box.shift ??)
--   penalty         - ???(??????/??)
--   column break    - ???(-10001 ??????)
--   running_indent  - ??????(?????)
--   has_content     - ???????(??????)
--
-- ??????
--   • ?????? TeX ? \leftskip ? box.shift ??,????? itemize/enumerate
--   • "???"(penalty -10001)??? HLIST ?????,?? layout_grid.lua ??????
--   • ??:???????? TeX ?????,??????????(?????? Textbox),
--     ?????(leftskip)????????? TeX ???????????(??? \leavevmode)
--   • Textbox ????? ATTR_TEXTBOX_WIDTH/HEIGHT ??,??????
--   • ???(rightskip)???????????(???? layout ???)
--   • ??????(D.copy),?????????
--
-- ????? / Architecture?
--   ??: TeX VBox.list (??? vlist/hlist/glyph ?)
--      ?
--   flatten_vbox(head, grid_width, char_width)
--      +- collect_nodes() ????
--      ¦   +- ?? leftskip ? ?? indent
--      ¦   +- ?? shift ? ?? indent
--      ¦   +- ???????
--      +- ??????? ATTR_INDENT ??
--      +- ????? penalty -10001
--      ?
--   ??: ?????(glyph + kern + glue + penalty + textbox?)
--
-- ============================================================================

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')

--- ? vlist(?? vbox)?????????
-- ????????????????
-- ??????(???????/??)?
--
-- @param head (node) vlist ???
-- @param grid_width (number) ? SCALED POINTS ???????
-- @param char_width (number) ???????????(??? grid_height)
-- @return (node) ?????????????
local function flatten_vbox(head, grid_width, char_width)
    local d_head = D.todirect(head)
    local result_head_d = nil
    local result_tail_d = nil

    --- ???????????
    -- @param n (direct node) ??????
    local function append_node(n)
        if not n then return end
        -- if utils and utils.debug_log then
        --     utils.debug_log("  [flatten] Appending Node=" .. tostring(n) .. " tid=" .. (D.getid(n) or "?"))
        -- end
        D.setnext(n, nil)
        if not result_head_d then
            result_head_d = n
            result_tail_d = n
        else
            D.setlink(result_tail_d, n)
            result_tail_d = n
        end
    end

    --- ???????
    -- @param n_head (direct node) ??????????(????)
    -- @param indent_lvl (number) ????
    -- @param r_indent_lvl (number) ?????
    -- @return (boolean) ????????????(??/???),??? true
    local function collect_nodes(n_head, indent_lvl, r_indent_lvl)
        local t = n_head
        local running_indent = indent_lvl
        local running_r_indent = r_indent_lvl
        local has_content = false

        while t do
            local tid = D.getid(t)
            local subtype = D.getsubtype(t)
            -- print(string.format("[D-flatten] Node=%s ID=%d S=%d [p_indent=%d]", tostring(t), tid, subtype, indent_lvl))

            -- Check for Textbox Block attribute
            local tb_w = 0
            local tb_h = 0
            if tid == constants.HLIST or tid == constants.VLIST then
                tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
                tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0
            end

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
                            local st = D.getsubtype(s)
                            local w = D.getfield(s, "width")
                            if st == 8 then -- leftskip
                                box_indent = math.max(box_indent, math.floor(w / char_width + 0.5))
                            end
                            break
                        end
                        s = D.getnext(s)
                    end
                end

                -- Recurse
                local inner_has_content = collect_nodes(inner, box_indent, box_r_indent)
                if inner_has_content then has_content = true end
                
                -- IMPORTANT: Only add penalty for HLIST lines that are part of 
                -- the main vertical flow, i.e., at the second recursion level.
                -- For simplicity, let's just add it if this HLIST had content.
                if tid == constants.HLIST and inner_has_content then
                    if utils and utils.debug_log then
                        utils.debug_log("  [flatten] Adding Column Break after Line=" .. tostring(t))
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
                elseif tid == constants.GLUE or tid == constants.WHATSIT then
                    local subtype = D.getsubtype(t)
                    if tid == constants.WHATSIT or subtype == 0 or subtype == 13 or subtype == 14 then
                       keep = true
                       if tid == constants.WHATSIT then has_content = true end
                    end
                elseif tid == constants.PENALTY then
                    keep = true
                end

                if keep then
                    local copy = D.copy(t)
                    if running_indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, running_indent) end
                    if running_r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, running_r_indent) end

                    -- CRITICAL: Preserve jiazhu attributes (they are set by \jiazhu command)
                    local jiazhu_attr = D.get_attribute(t, constants.ATTR_JIAZHU)
                    if jiazhu_attr then
                        D.set_attribute(copy, constants.ATTR_JIAZHU, jiazhu_attr)
                    end
                    local jiazhu_sub_attr = D.get_attribute(t, constants.ATTR_JIAZHU_SUB)
                    if jiazhu_sub_attr then
                        D.set_attribute(copy, constants.ATTR_JIAZHU_SUB, jiazhu_sub_attr)
                    end
                    
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
-- ????? package.loaded
package.loaded['luatex-cn-vertical-flatten-nodes'] = flatten

-- Return module exports
return flatten