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

--- Get the type of punctuation for a given character
-- @param char (number) Unicode character code
-- @return (string|nil) 'ju', 'dou', 'close', 'open', or nil
function judou.get_punctuation_type(char)
    if SET_JU[char] then return "ju" end
    if SET_DOU[char] then return "dou" end
    if SET_CLOSE_QUOTE[char] then return "close" end
    if SET_OPEN_QUOTE[char] then return "open" end
    return nil
end

--- Create a JUDOU whatsit node
-- @param replacement (number) Unicode character code for replacement
-- @param font_id (number) Font ID to use
-- @param jiazhu_attr (number|nil) Jiazhu attribute value
-- @return (direct node) The created whatsit node
function judou.create_judou_whatsit(replacement, font_id, jiazhu_attr)
    local user_defined_subtype = node.subtype("user_defined")
    local w = D.new(constants.WHATSIT, user_defined_subtype)
    D.setfield(w, "user_id", constants.JUDOU_USER_ID)
    D.setfield(w, "type", 100) -- value type
    D.setfield(w, "value", replacement)

    if font_id then
        D.set_attribute(w, constants.ATTR_JUDOU_FONT, font_id)
    end
    if jiazhu_attr then
        D.set_attribute(w, constants.ATTR_JIAZHU, jiazhu_attr)
    end
    return w
end

--- Handle punctuation removal in 'none' mode
-- @param head (direct node) Node list head
-- @param t (direct node) Current glyph node
-- @param ptype (string) Punctuation type ('ju', 'dou', 'close', 'open')
-- @return (direct node, direct node|nil) New head, and the next node to process
function judou.handle_none_mode(head, t, ptype)
    if ptype then
        local next_node = D.getnext(t)
        head = D.remove(head, t)
        node.flush_node(D.tonode(t))
        return head, next_node
    end
    return head, D.getnext(t), t -- Return t as last_visible if not ptype
end

--- Handle punctuation replacement in 'judou' mode
-- @param head (direct node) Node list head
-- @param t (direct node) Current glyph node
-- @param ptype (string) Punctuation type ('ju', 'dou', 'close', 'open')
-- @param last_visible (direct node|nil) Last visible non-punctuation node
-- @return (direct node, direct node|nil, direct node|nil) New head, next node, and updated last_visible
function judou.handle_judou_mode(head, t, ptype, last_visible)
    local char = D.getfield(t, "char")
    local next_node = D.getnext(t)
    local nodes_to_remove = { t }
    local replacement = nil

    print(string.format("[LUA-DEBUG] Checking judou mode for %x: ptype=%s", char, tostring(ptype)))

    if ptype == "ju" then
        replacement = REPLACEMENT_JU
        -- Peek next for close quote
        if next_node and D.getid(next_node) == constants.GLYPH then
            local next_char = D.getfield(next_node, "char")
            if SET_CLOSE_QUOTE[next_char] then
                table.insert(nodes_to_remove, next_node)
                next_node = D.getnext(next_node)
            end
        end
    elseif ptype == "dou" then
        replacement = REPLACEMENT_DOU
        -- Peek next for open quote if char is ':'
        if char == 0xFF1A and next_node and D.getid(next_node) == constants.GLYPH then
            local next_char = D.getfield(next_node, "char")
            if SET_OPEN_QUOTE[next_char] then
                table.insert(nodes_to_remove, next_node)
                next_node = D.getnext(next_node)
            end
        end
    elseif ptype == "close" or ptype == "open" then
        print("[LUA-DEBUG] Removing quote node")
        head = D.remove(head, t)
        node.flush_node(D.tonode(t))
        return head, next_node, last_visible
    end

    if replacement then
        if last_visible then
            local font_id = D.getfield(t, "font")
            local jiazhu_attr = D.get_attribute(t, constants.ATTR_JIAZHU)
            local w = judou.create_judou_whatsit(replacement, font_id, jiazhu_attr)

            D.insert_after(head, last_visible, w)
            print(string.format("[LUA-DEBUG] Inserted JUDOU whatsit for char: %x after %s", char, tostring(last_visible)))
        else
            print(string.format("[LUA-DEBUG] FAILED to insert JUDOU whatsit for char: %x (no last_visible)", char))
        end

        -- Remove the processed glyphs
        for _, n in ipairs(nodes_to_remove) do
            head = D.remove(head, n)
            node.flush_node(D.tonode(n))
        end
        return head, next_node, last_visible
    end

    return head, next_node, t -- Not a replacement candidate, treat as last_visible
end

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

    while t do
        local id = D.getid(t)
        local next_node = D.getnext(t)

        if id == constants.GLYPH then
            local char = D.getfield(t, "char")
            if char > 32 then
                print(string.format("[LUA-DEBUG] Glyph char=%x", char))
            end

            local ptype = judou.get_punctuation_type(char)

            if mode == "none" then
                head, next_node, last_visible = judou.handle_none_mode(head, t, ptype)
                if not last_visible then
                    -- If handle_none_mode didn't return last_visible, keep the old one
                    last_visible = last_visible
                end
            elseif mode == "judou" then
                head, next_node, last_visible = judou.handle_judou_mode(head, t, ptype, last_visible)
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
