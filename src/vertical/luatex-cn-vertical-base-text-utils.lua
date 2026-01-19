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
-- 跨平台文本规范化工具函数库
--
-- 文件名: base_text_utils.lua
-- 层级: 基础工具层 (Base Utilities Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块提供跨平台文本处理工具，确保在不同操作系统上的一致性：
--   1. 统一换行符（将 CRLF 转为 LF）
--   2. 去除 BOM 标记（Byte Order Mark）
--   3. 规范化空白字符
--
-- 【使用场景 / Use Cases】
--   • 在处理用户输入的文本内容之前进行预处理
--   • 确保字符串定位算法的准确性（夹注、鱼尾等）
--   • 防止因换行符差异导致的坐标计算偏移
--
-- ============================================================================

local text_utils = {}

--- 规范化文本中的换行符
-- 将所有换行符转换为 Unix 风格的 LF (\n)
-- 处理情况：CRLF (\r\n) → LF (\n)
--           CR (\r) → LF (\n)
--
-- @param text (string) 具有混合换行符的输入文本
-- @return (string) 换行符规范化后的文本
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

--- 如果存在 UTF-8 BOM（字节顺序标记），则将其移除
-- 某些 Windows 编辑器会在 UTF-8 文件中添加 BOM，这可能导致解析问题
--
-- @param text (string) 可能包含 BOM 的输入文本
-- @return (string) 移除 BOM 后的文本
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

--- 规范化空白字符（将连续空白转换为单个空格）
-- 用于清理用户输入
--
-- @param text (string) 具有混合空白字符的输入文本
-- @param preserve_newlines (boolean) 如果为 true，则保留换行符
-- @return (string) 规范化空白后的文本
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

--- 全文规范化流水线
-- 结合多个规范化步骤，用于健壮的文本处理
--
-- @param text (string) 原始输入文本
-- @param options (table) 可选参数:
--   - remove_bom (boolean) 移除 UTF-8 BOM，默认 true
--   - normalize_line_endings (boolean) 规范化换行符，默认 true
--   - normalize_whitespace (boolean) 规范化空白字符，默认 false
--   - preserve_newlines (boolean) 规范化空白时保留换行，默认 true
-- @return (string) 完全规范化后的文本
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

--- 快速助手：针对古籍排版进行规范化
-- 预设用于竖排模块：保留结构，仅修复换行符
--
-- @param text (string) 输入文本
-- @return (string) 准备好进行排版的规范化文本
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
