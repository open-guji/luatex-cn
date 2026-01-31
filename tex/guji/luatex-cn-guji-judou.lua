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
-- judou.lua - 句读 (Judou) 处理模块 (Refactored to use Decorate Mechanism)
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = node.direct
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('judou')

local judou = {}

-- =============================================================================
-- Global State (全局状态)
-- =============================================================================
-- Initialize global judou table
_G.judou = _G.judou or {}
_G.judou.enabled = _G.judou.enabled or false
_G.judou.punct_mode = _G.judou.punct_mode or "normal"
_G.judou.pos = _G.judou.pos or "right-bottom"
_G.judou.size = _G.judou.size or "1em"
_G.judou.color = _G.judou.color or "red"

--- Setup global judou parameters from TeX
-- @param params (table) Parameters from TeX keyvals
local function setup(params)
    params = params or {}
    if params.enabled ~= nil then
        _G.judou.enabled = (params.enabled == true or params.enabled == "true")
    end
    if params.punct_mode and params.punct_mode ~= "" then
        _G.judou.punct_mode = params.punct_mode
    end
    if params.pos and params.pos ~= "" then
        _G.judou.pos = params.pos
    end
    if params.size and params.size ~= "" then
        _G.judou.size = params.size
    end
    if params.color and params.color ~= "" then
        _G.judou.color = params.color
    end
end

judou.setup = setup

-- =============================================================================
-- Parameter Reading (from _G.judou global)
-- =============================================================================

--- Read judou-related parameters from global state
-- @return table A table containing judou configuration values
local function read_judou_params()
    return {
        judou_on = _G.judou.enabled or false,
        punct_mode = _G.judou.punct_mode or "normal",
        judou_pos = _G.judou.pos or "right-bottom",
        judou_size = _G.judou.size or "1em",
        judou_color = _G.judou.color or "red",
    }
end

-- ============================================================================
-- Plugin Standard API
-- ============================================================================

--- Initialize Judou Plugin
-- @param params (table) Parameters from TeX (no longer used for judou settings)
-- @param engine_ctx (table) Shared engine context
-- @return (table|nil) Plugin context or nil if disabled
function judou.initialize(params, engine_ctx)
    -- Read judou parameters directly from TeX variables
    local jp = read_judou_params()

    local mode = jp.punct_mode
    if jp.judou_on then
        mode = "judou"
    end

    if mode == "normal" then
        return nil -- Plugin disabled for this run
    end

    return { mode = mode }
end

--- Process node list for Punctuation modes (Plugin Interface)
-- @param head (direct node) The node list head
-- @param params (table) Parameters containing punct_mode, etc.
-- @param ctx (table) Plugin context
-- @return (direct node) The modified head
function judou.flatten(head, params, ctx)
    if not ctx or not ctx.mode or ctx.mode == "normal" then
        return head -- Return the node as is
    end

    local mode = ctx.mode
    local d_head = D.todirect(head)
    local t = d_head
    local last_visible = nil

    while t do
        local id = D.getid(t)
        local next_node = D.getnext(t)

        if id == constants.GLYPH then
            local char = D.getfield(t, "char")
            local ptype = judou.get_punctuation_type(char)

            if mode == "none" then
                d_head, next_node, last_visible = judou.handle_none_mode(d_head, t, ptype, last_visible)
            elseif mode == "judou" then
                d_head, next_node, last_visible = judou.handle_judou_mode(d_head, t, ptype, last_visible)
            else
                last_visible = t
            end
        elseif id == constants.HLIST or id == constants.VLIST then
            last_visible = t
        end
        t = next_node
    end

    return D.tonode(d_head)
end

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
    [0xFF09] = true, -- ）
    [0x3009] = true, -- 〉
    [0x300B] = true, -- 》
    [0x3011] = true, -- 】
    [0x3015] = true, -- 〕
}

local SET_OPEN_QUOTE = {
    [0x201C] = true, -- “
    [0x2018] = true, -- ‘
    [0x300C] = true, -- 「
    [0x300E] = true, -- 『
    [0xFF08] = true, -- （
    [0x3008] = true, -- 〈
    [0x300A] = true, -- 《
    [0x3010] = true, -- 【
    [0x3014] = true, -- 〔
}

local REPLACEMENT_JU = 0x3002  -- 。
local REPLACEMENT_DOU = 0x3001 -- 、

local ju_id = nil
local dou_id = nil

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

--- Initialize Judou styles in Decorate Registry
local function ensure_judou_styles()
    if ju_id and dou_id then return end

    -- Register default styles for Judou
    -- Position is calculated from the character's bottom edge (not grid center)
    -- X offset: positive = move left, negative = move right
    -- Y offset: positive = move down (from character bottom)
    -- Small Y offset since we're starting from character bottom, not grid center
    ju_id = constants.register_decorate("。", "-0.6em", "0.5em", nil, "red", nil, 1.2)
    dou_id = constants.register_decorate("、", "-0.6em", "0.5em", nil, "red", nil, 1.2)
end

--- Create a JUDOU Decorate Marker node (GLYPH with ATTR_DECORATE_ID)
-- replaces the old create_judou_whatsit
-- @param char_code (number) REPLACEMENT_JU or REPLACEMENT_DOU
-- @param font_id (number) Font ID to use for the marker
-- @return (direct node) The created glyph node
function judou.create_judou_decorate_marker(char_code, font_id)
    ensure_judou_styles()

    local dec_id
    if char_code == REPLACEMENT_JU then
        dec_id = ju_id
    elseif char_code == REPLACEMENT_DOU then
        dec_id = dou_id
    else
        return nil
    end

    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 63)                        -- Dummy char, render_page uses registry char
    D.setfield(g, "font", font_id or font.current()) -- Set valid font
    D.setfield(g, "width", 0)
    D.setfield(g, "height", 0)
    D.setfield(g, "depth", 0)

    if constants.ATTR_DECORATE_ID then
        D.set_attribute(g, constants.ATTR_DECORATE_ID, dec_id)
    end
    if constants.ATTR_DECORATE_FONT and font_id then
        D.set_attribute(g, constants.ATTR_DECORATE_FONT, font_id)
    end

    return g
end

--- Handle punctuation removal in 'none' mode
-- @param head (direct node) Node list head
-- @param t (direct node) Current glyph node
-- @param ptype (string) Punctuation type ('ju', 'dou', 'close', 'open')
-- @return (direct node, direct node|nil) New head, and the next node to process
function judou.handle_none_mode(head, t, ptype, last_visible)
    if ptype then
        local next_node = D.getnext(t)
        head = D.remove(head, t)
        node.flush_node(D.tonode(t))
        return head, next_node, last_visible
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
    if not ptype then
        -- Regular character: Update last_visible as the anchor for future marks
        return head, D.getnext(t), t
    end

    -- CRITICAL: If this glyph already has an ATTR_DECORATE_ID,
    -- it's a custom decoration (e.g. from \改 command).
    -- We MUST NOT replace it or override its settings.
    if constants.ATTR_DECORATE_ID and D.get_attribute(t, constants.ATTR_DECORATE_ID) then
        return head, D.getnext(t), t
    end

    local char = D.getfield(t, "char")
    local next_node = D.getnext(t)
    local nodes_to_remove = { t }
    local replacement_code = nil

    if ptype == "ju" then
        replacement_code = REPLACEMENT_JU
        -- Peek next for close quote
        if next_node and D.getid(next_node) == constants.GLYPH then
            local next_char = D.getfield(next_node, "char")
            if SET_CLOSE_QUOTE[next_char] then
                table.insert(nodes_to_remove, next_node)
                next_node = D.getnext(next_node)
            end
        end
    elseif ptype == "dou" then
        replacement_code = REPLACEMENT_DOU
        -- Peek next for open quote if char is ':'
        if char == 0xFF1A and next_node and D.getid(next_node) == constants.GLYPH then
            local next_char = D.getfield(next_node, "char")
            if SET_OPEN_QUOTE[next_char] then
                table.insert(nodes_to_remove, next_node)
                next_node = D.getnext(next_node)
            end
        end
    elseif ptype == "close" or ptype == "open" then
        head = D.remove(head, t)
        node.flush_node(D.tonode(t))
        return head, next_node, last_visible
    end

    if replacement_code then
        if last_visible then
            -- Insert Decorate Marker instead of Judou Whatsit
            local font_id = D.getfield(t, "font")
            local marker = judou.create_judou_decorate_marker(replacement_code, font_id)

            if marker then
                D.insert_after(head, last_visible, marker)
                dbg.log(string.format("Added mark %s after anchor node %s",
                    (replacement_code == REPLACEMENT_JU and "JU" or "DOU"), tostring(last_visible)))
            end

            -- Remove the processed glyphs
            for _, n in ipairs(nodes_to_remove) do
                head = D.remove(head, n)
                node.flush_node(D.tonode(n))
            end
            return head, next_node, last_visible
        else
            -- No visible character before punctuation - keep punctuation to avoid data loss
            dbg.log(string.format("SKIP replacement for char %d: no last_visible anchor", char))
            return head, next_node, t -- Keep t as last_visible
        end
    end

    return head, next_node, t -- Not a replacement candidate, treat as last_visible
end

-- Backward compatibility
judou.process_judou = function(head, params)
    local ctx = judou.initialize(params, {})
    if ctx then
        return judou.flatten(head, params, ctx)
    end
    return head
end

package.loaded['guji.luatex-cn-guji-judou'] = judou
return judou
