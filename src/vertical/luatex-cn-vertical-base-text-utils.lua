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
-- base_text_utils.lua
-- ?????????????
--
-- ???: base_text_utils.lua
-- ??: ????? (Base Utilities Layer)
--
-- ????? / Module Purpose?
-- ??????????????,??????????????:
--   1. ?????(? CRLF ?? LF)
--   2. ?? BOM ??(Byte Order Mark)
--   3. ???????
--
-- ????? / Use Cases?
--   • ???????????????????
--   • ?????????????(??????)
--   • ?????????????????
--
-- ============================================================================

local text_utils = {}

--- ??????????
-- ????????? Unix ??? LF (\n)
-- ????:CRLF (\r\n) ? LF (\n)
--           CR (\r) ? LF (\n)
--
-- @param text (string) ????????????
-- @return (string) ??????????
function text_utils.normalize_line_endings(text)
    if not text or text == "" then
        return text
    end
    
    -- Replace CRLF with LF first (must be done before replacing standalone CR)
    text = text:gsub("\r\n", "\n")
    
    -- Replace any remaining CR with LF
    text = text:gsub("\r", "\n")
    
    return text
end

--- ???? UTF-8 BOM(??????),?????
-- ?? Windows ????? UTF-8 ????? BOM,?????????
--
-- @param text (string) ???? BOM ?????
-- @return (string) ?? BOM ????
function text_utils.remove_bom(text)
    if not text or text == "" then
        return text
    end
    
    -- UTF-8 BOM is EF BB BF (239 187 191 in decimal)
    local bom = string.char(0xEF, 0xBB, 0xBF)
    if text:sub(1, 3) == bom then
        return text:sub(4)
    end
    
    return text
end

--- ???????(????????????)
-- ????????
--
-- @param text (string) ?????????????
-- @param preserve_newlines (boolean) ??? true,??????
-- @return (string) ?????????
function text_utils.normalize_whitespace(text, preserve_newlines)
    if not text or text == "" then
        return text
    end
    
    if preserve_newlines then
        -- Normalize each line separately
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            -- Replace multiple spaces/tabs with single space
            line = line:gsub("%s+", " ")
            -- Trim leading/trailing whitespace
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            table.insert(lines, line)
        end
        return table.concat(lines, "\n")
    else
        -- Replace all whitespace (including newlines) with single space
        text = text:gsub("%s+", " ")
        -- Trim leading/trailing whitespace
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        return text
    end
end

--- ????????
-- ?????????,?????????
--
-- @param text (string) ??????
-- @param options (table) ????:
--   - remove_bom (boolean) ?? UTF-8 BOM,?? true
--   - normalize_line_endings (boolean) ??????,?? true
--   - normalize_whitespace (boolean) ???????,?? false
--   - preserve_newlines (boolean) ??????????,?? true
-- @return (string) ?????????
function text_utils.normalize_text(text, options)
    if not text or text == "" then
        return text
    end
    
    options = options or {}
    local remove_bom = options.remove_bom ~= false  -- default true
    local norm_line_endings = options.normalize_line_endings ~= false  -- default true
    local norm_whitespace = options.normalize_whitespace or false  -- default false
    local preserve_newlines = options.preserve_newlines ~= false  -- default true
    
    -- Step 1: Remove BOM
    if remove_bom then
        text = text_utils.remove_bom(text)
    end
    
    -- Step 2: Normalize line endings
    if norm_line_endings then
        text = text_utils.normalize_line_endings(text)
    end
    
    -- Step 3: Normalize whitespace (optional)
    if norm_whitespace then
        text = text_utils.normalize_whitespace(text, preserve_newlines)
    end
    
    return text
end

--- ????:???????????
-- ????????:????,??????
--
-- @param text (string) ????
-- @return (string) ?????????????
function text_utils.normalize_for_typesetting(text)
    return text_utils.normalize_text(text, {
        remove_bom = true,
        normalize_line_endings = true,
        normalize_whitespace = false,  -- Preserve all spacing
        preserve_newlines = true
    })
end

-- Register module
package.loaded['luatex-cn-vertical-base-text-utils'] = text_utils

return text_utils