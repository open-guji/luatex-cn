-- ============================================================================
-- base_text_utils.lua - Cross-Platform Text Normalization Utilities
-- ============================================================================
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
-- Version: 1.0.0
-- Date: 2026-01-14
-- ============================================================================

local text_utils = {}

--- Normalize line endings in text
-- Converts all line endings to Unix-style LF (\n)
-- Handles: CRLF (\r\n) → LF (\n)
--          CR (\r) → LF (\n)
--
-- @param text (string) Input text with mixed line endings
-- @return (string) Text with normalized line endings
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

--- Remove UTF-8 BOM (Byte Order Mark) if present
-- Some Windows editors add BOM to UTF-8 files, which can cause issues
--
-- @param text (string) Input text that may contain BOM
-- @return (string) Text with BOM removed
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

--- Normalize whitespace (convert all whitespace to single space)
-- Useful for cleaning up user input
--
-- @param text (string) Input text with mixed whitespace
-- @param preserve_newlines (boolean) If true, preserve line breaks
-- @return (string) Text with normalized whitespace
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

--- Full text normalization pipeline
-- Combines all normalization steps for robust text processing
--
-- @param text (string) Raw input text
-- @param options (table) Optional parameters:
--   - remove_bom (boolean) Remove UTF-8 BOM, default: true
--   - normalize_line_endings (boolean) Normalize line endings, default: true
--   - normalize_whitespace (boolean) Normalize whitespace, default: false
--   - preserve_newlines (boolean) Preserve newlines when normalizing whitespace, default: true
-- @return (string) Fully normalized text
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

--- Quick helper: Normalize for ancient book typesetting
-- Preset for cn_vertical module: preserve structure, only fix line endings
--
-- @param text (string) Input text
-- @return (string) Normalized text ready for typesetting
function text_utils.normalize_for_typesetting(text)
    return text_utils.normalize_text(text, {
        remove_bom = true,
        normalize_line_endings = true,
        normalize_whitespace = false,  -- Preserve all spacing
        preserve_newlines = true
    })
end

-- Register module
package.loaded['base_text_utils'] = text_utils

return text_utils
