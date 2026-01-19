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
-- base_utils.lua - ???????
-- ============================================================================
-- ???: base_utils.lua (? utils.lua)
-- ??: ??? (Base Layer)
--
-- ????? / Module Purpose?
-- ???????????????,??????????:
--   1. normalize_rgb: ??? RGB ??(0-1 ? 0-255)???? PDF ????
--   2. sp_to_bp: scaled points ? PDF big points ?????
--   3. debug_log: ??????? .log ??
--   4. draw_debug_rect: ??????????
--
-- ????? / Terminology?
--   sp_to_bp            - scaled points ? big points ??(1bp = 65536sp)
--   normalize_rgb       - RGB ?????(??? PDF ???? "r g b")
--   pdf_literal         - PDF ????(?????? PDF ??)
--   rg/RG               - PDF ???/?????(??=fill,??=stroke)
--   whatsit             - TeX ??????(?????????)
--
-- ??????
--   • normalize_rgb ??????? 0-255 ??? 0-1 ??
--   • ?????????? RGB ?("255,0,0" ? "1.0 0 0")
--   • ????????? "r g b"(????,?? 4 ???)
--   • ????PDF ??????????(? "0 0 0 rg"),
--     ???? "black" ??? PDF ?????????
--   • sp_to_bp = 1/65536 ˜ 0.0000152018(TeX ????? PDF ??)
--
-- ????? / Architecture?
--   normalize_rgb(rgb_str)
--      +- ???????
--      +- ?? r?g?b ??
--      +- ????? > 1,??? 255
--      +- ???????? "r.rrrr g.gggg b.bbbb"
--
-- ============================================================================

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

--- ??? RGB ?????
-- ??? RGB ????????? 0-1 ??
-- ???????:
--   - "r,g,b" ? "r g b",????? 0-1 ? 0-255
--   - ??????? 0-255 ??? 0-1
--   - ???????(black, white, red ?)??? RGB
--
-- @param s (string|nil) RGB ?????
-- @return (string|nil) ???? "r g b" ???? nil
local function normalize_rgb(s)
    if s == nil then return nil end
    s = tostring(s)
    if s == "nil" or s == "" then return nil end

    -- Map basic color names
    local color_map = {
        black = "0.0000 0.0000 0.0000",
        white = "1.0000 1.0000 1.0000",
        red   = "1.0000 0.0000 0.0000",
        green = "0.0000 1.0000 0.0000",
        blue  = "0.0000 0.0000 1.0000",
        yellow = "1.0000 1.0000 0.0000",
        gray  = "0.5000 0.5000 0.5000",
    }
    local mapped = color_map[s:lower()]
    if mapped then return mapped end

    -- Replace commas with spaces and strip braces/brackets
    s = s:gsub(",", " "):gsub("[{}%[%]]", "")

    -- Extract RGB values
    local r, g, b = s:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
    if not r then 
        -- If it's not a numeric RGB, return nil instead of the original string
        -- to avoid injecting invalid PDF literal commands
        return nil 
    end

    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r or not g or not b then return nil end

    -- Convert 0-255 range to 0-1 range
    if r > 1 or g > 1 or b > 1 then
        return string.format("%.4f %.4f %.4f", r/255, g/255, b/255)
    end

    return string.format("%.4f %.4f %.4f", r, g, b)
end

--- ????? verbose_log,??????????
-- @param message string ??????
local function debug_log(message)
    if _G.vertical and _G.vertical.debug and _G.vertical.debug.verbose_log then
        if texio and texio.write_nl then
            texio.write_nl("log", "[Guji-Debug] " .. message)
        end
    end
end

--- ?? PDF literal ??????
-- @param head node ??????(????)
-- @param anchor node ?????????(????)???? nil,???????
-- @param x_sp number X ????? (sp)
-- @param y_sp number Y ????? (sp, ???)
-- @param w_sp number ?? (sp)
-- @param h_sp number ?? (sp, ????)
-- @param color_cmd string PDF ????(?? "1 0 0 RG")
-- @return node ??????
local function draw_debug_rect(head, anchor, x_sp, y_sp, w_sp, h_sp, color_cmd)
    local tx_bp = x_sp * sp_to_bp
    local ty_bp = y_sp * sp_to_bp
    local tw_bp = w_sp * sp_to_bp
    local th_bp = h_sp * sp_to_bp
    
    -- literal for rectangle: q (save state) 0.5 w (line width) <color> 1 0 0 1 <x> <y> cm (move) 0 0 <w> <h> re (rect) S (stroke) Q (restore)
    local literal = string.format("q 0.5 w %s 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q", color_cmd, tx_bp, ty_bp, tw_bp, th_bp)
    
    -- Use more robust node creation
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = node.direct.new(whatsit_id, pdf_literal_id)
    node.direct.setfield(nn, "data", literal)
    node.direct.setfield(nn, "mode", 0)
    
    if anchor then
        return node.direct.insert_before(head, anchor, nn)
    else
        return node.direct.insert_before(head, head, nn)
    end
end

--- ????????? PDF literal ??
-- @param literal_str string PDF literal ???(?? "q 0.5 w 0 0 0 RG ... Q")
-- @param mode number ????(?? 0: ????????)
-- @return node ?????? (pdf_literal whatsit)
local function create_pdf_literal(literal_str, mode)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal_str
    n_node.mode = mode or 0
    return n_node
end

--- ????????? PDF literal ??
-- @param head node ???????
-- @param literal_str string PDF literal ???
-- @return node ??????(??????)
local function insert_pdf_literal(head, literal_str)
    local n_node = create_pdf_literal(literal_str)
    return node.direct.insert_before(head, head, node.direct.todirect(n_node))
end

--- ????????????????
-- ??:1 -> "?", 10 -> "?", 21 -> "???"
-- @param n number ??????
-- @return string ???????
local function to_chinese_numeral(n)
    if not n or n <= 0 then return "" end
    local digits = {"?", "?", "?", "?", "?", "?", "?", "?", "?"}
    if n < 10 then
        return digits[n]
    elseif n == 10 then
        return "?"
    elseif n < 20 then
        return "?" .. digits[n - 10]
    elseif n < 100 then
        local tens = math.floor(n / 10)
        local ones = n % 10
        local s = digits[tens] .. "?"
        if ones > 0 then
            s = s .. digits[ones]
        end
        return s
    else
        -- Simple support up to 999 for now
        local hundreds = math.floor(n / 100)
        local rest = n % 100
        local s = digits[hundreds] .. "?"
        if rest > 0 then
            if rest < 10 then
                s = s .. "?" .. digits[rest]
            else
                s = s .. to_chinese_numeral(rest)
            end
        end
        return s
    end
end

-- Create module table
-- ?????
local utils = {
    normalize_rgb = normalize_rgb,
    sp_to_bp = sp_to_bp,
    debug_log = debug_log,
    draw_debug_rect = draw_debug_rect,
    create_pdf_literal = create_pdf_literal,
    insert_pdf_literal = insert_pdf_literal,
    to_chinese_numeral = to_chinese_numeral,
}

-- Register module in package.loaded for require() compatibility
-- ????? package.loaded
package.loaded['luatex-cn-vertical-base-utils'] = utils

-- Return module exports
return utils