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

-- Character sets for punctuation processing
local SET_JU = {
    [0x3002] = true, -- 。
    [0xFF01] = true, -- ！
    [0xFF1F] = true, -- ？
}

local SET_DOU = {
    [0xFF0C] = true, -- ，
    [0xFF1A] = true, -- ：
    [0x3001] = true, -- 、
    [0xFF1B] = true, -- ；
}

local SET_CLOSE_QUOTE = {
    [0x201D] = true, -- ”
    [0x2019] = true, -- ’
    [0x300D] = true, -- 」
    [0x300F] = true, -- 』
}

local SET_OPEN_QUOTE = {
    [0x201C] = true, -- “
    [0x2018] = true, -- ‘
    [0x300C] = true, -- 「
    [0x300E] = true, -- 『
}

local REPLACEMENT_JU = 0x3002  -- 。
local REPLACEMENT_DOU = 0x3001 -- 、

--- Process node list for Punctuation modes
-- @param head (direct node) The node list head
-- @param params (table) Parameters containing punct_mode, etc.
-- @return (direct node) The modified head
function judou.process_judou(head, params)
    print("[LUA-DEBUG] Entering process_judou, mode: " .. tostring(params.punct_mode))
    local mode = params.punct_mode or "normal"
    if params.judou_on == "true" or params.judou_on == true then
        mode = "judou"
    end

    if mode == "normal" then
        return head
    end

    local t = head
    local last_visible = nil

    local user_defined_subtype = node.subtype("user_defined")

    while t do
        local next_node = D.getnext(t)
        local id = D.getid(t)

        if id == constants.GLYPH then
            local char = D.getfield(t, "char")
            if char > 32 then
                print(string.format("[LUA-DEBUG] Glyph char=%x", char))
            end
            local is_ju = SET_JU[char]
            local is_dou = SET_DOU[char]
            local is_close = SET_CLOSE_QUOTE[char]
            local is_open = SET_OPEN_QUOTE[char]

            if mode == "none" then
                if is_ju or is_dou or is_close or is_open then
                    head = D.remove(head, t)
                    node.flush_node(D.tonode(t))
                else
                    last_visible = t
                end
            elseif mode == "judou" then
                local replacement = nil
                local nodes_to_remove = { t }

                print(string.format("[LUA-DEBUG] Checking judou mode for %x: is_ju=%s, is_dou=%s", char, tostring(is_ju),
                    tostring(is_dou)))

                if is_ju then
                    replacement = REPLACEMENT_JU
                    print(string.format("[LUA-DEBUG] Identified JU replacement: %x", replacement))
                    -- Peek next for close quote
                    if next_node and D.getid(next_node) == constants.GLYPH then
                        local next_char = D.getfield(next_node, "char")
                        if SET_CLOSE_QUOTE[next_char] then
                            table.insert(nodes_to_remove, next_node)
                            -- Advance next_node because we're consuming it
                            next_node = D.getnext(next_node)
                        end
                    end
                elseif is_dou then
                    replacement = REPLACEMENT_DOU
                    print(string.format("[LUA-DEBUG] Identified DOU replacement: %x", replacement))
                    -- Peek next for open quote if char is ':'
                    if char == 0xFF1A and next_node and D.getid(next_node) == constants.GLYPH then
                        local next_char = D.getfield(next_node, "char")
                        if SET_OPEN_QUOTE[next_char] then
                            table.insert(nodes_to_remove, next_node)
                            next_node = D.getnext(next_node)
                        end
                    end
                elseif is_close or is_open then
                    print("[LUA-DEBUG] Removing quote node")
                    head = D.remove(head, t)
                    node.flush_node(D.tonode(t))
                end

                print(string.format("[LUA-DEBUG] Final replacement for %x: %s", char, tostring(replacement)))
                if replacement then
                    if last_visible then
                        local w = D.new(constants.WHATSIT, user_defined_subtype)
                        D.setfield(w, "user_id", constants.JUDOU_USER_ID)
                        D.setfield(w, "type", 100) -- value type
                        D.setfield(w, "value", replacement)

                        -- Store font ID and attributes from original glyph
                        local font_id = D.getfield(t, "font")
                        if font_id then
                            D.set_attribute(w, constants.ATTR_JUDOU_FONT, font_id)
                        end
                        local jiazhu_attr = D.get_attribute(t, constants.ATTR_JIAZHU)
                        if jiazhu_attr then
                            D.set_attribute(w, constants.ATTR_JIAZHU, jiazhu_attr)
                        end

                        D.insert_after(head, last_visible, w)
                        print(string.format("[LUA-DEBUG] Inserted JUDOU whatsit for char: %x after %s", char,
                            tostring(last_visible)))
                    else
                        print(string.format("[LUA-DEBUG] FAILED to insert JUDOU whatsit for char: %x (no last_visible)",
                            char))
                    end

                    -- Remove the processed glyphs
                    for _, n in ipairs(nodes_to_remove) do
                        head = D.remove(head, n)
                        node.flush_node(D.tonode(n))
                    end
                else
                    -- Not a replacement candidate, and not a quote to be removed?
                    if not (is_close or is_open) then
                        last_visible = t
                    end
                end
            else
                last_visible = t
            end
        elseif id == constants.HLIST or id == constants.VLIST then
            last_visible = t
        end
        t = next_node
    end

    return head
end

package.loaded['vertical.luatex-cn-vertical-judou'] = judou
return judou
