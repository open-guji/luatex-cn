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
-- judou.lua - 句读 (Judou) 处理模块
-- ============================================================================

local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')
local D = node.direct

local judou = {}

-- Punctuation mapping
-- U+FF0C (Fullwidth Comma) -> U+3001 (Ideographic Comma / 顿号)
-- U+3002 (Ideographic Period) -> U+3002 (Remains Period)
local PUNCT_MAP = {
    [0xFF0C] = 0x3001,
    [0x3002] = 0x3002,
}

--- Process node list for Judou mode
-- Converts commas and periods into whatsit anchors and removes them from flow
-- @param head (direct node) The node list head
-- @param params (table) Parameters containing judou_on, etc.
-- @return (direct node) The modified head
function judou.process_judou(head, params)
    if not (params.judou_on == "true" or params.judou_on == true) then
        return head
    end

    local t = head
    local last_visible = nil

    while t do
        local next_node = D.getnext(t)
        local id = D.getid(t)

        if id == constants.GLYPH then
            local char = D.getfield(t, "char")
            if PUNCT_MAP[char] then
                -- This is a target punctuation
                if last_visible then
                    utils.debug_log(string.format("[judou] Transforming char %x at node %s", char, tostring(t)))

                    -- Create whatsit anchor
                    local w = D.new(constants.WHATSIT, "user_defined")
                    D.setfield(w, "user_id", constants.JUDOU_USER_ID)
                    D.setfield(w, "type", 100) -- value type

                    -- Encode replacement character into value
                    D.setfield(w, "value", PUNCT_MAP[char])

                    -- Store font ID from original glyph
                    local font_id = D.getfield(t, "font")
                    if font_id then
                        D.set_attribute(w, constants.ATTR_JUDOU_FONT, font_id)
                    end

                    -- Carry over attributes (like Jiazhu) which might be important
                    -- Note: Attributes are stored on the node, but when we replace glyph with whatsit,
                    -- the whatsit should ideally inherit them.
                    local jiazhu_attr = D.get_attribute(t, constants.ATTR_JIAZHU)
                    if jiazhu_attr then
                        D.set_attribute(w, constants.ATTR_JIAZHU, jiazhu_attr)
                    end

                    -- Insert whatsit AFTER the previous character anchor
                    D.insert_after(head, last_visible, w)

                    -- Remove the original glyph from the list
                    head = D.remove(head, t)
                    node.flush_node(D.tonode(t))
                else
                    -- No preceding character (start of block)?
                    -- Keep it as is for now.
                end
            else
                -- Normal character, use as anchor
                last_visible = t
            end
        elseif id == constants.HLIST or id == constants.VLIST then
            -- Blocks act as anchors
            last_visible = t
        end
        t = next_node
    end

    return head
end

package.loaded['vertical.luatex-cn-vertical-judou'] = judou
return judou
