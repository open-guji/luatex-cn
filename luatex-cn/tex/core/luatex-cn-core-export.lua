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
-- core_export.lua - 排版结果 JSON 导出模块
-- ============================================================================
-- 在排版完成后，将每个字符的位置、页面信息、列信息、夹注子列、侧批等
-- 数据以 JSON 格式导出到文件。
--
-- 【功能】
--   1. 收集 layout_map 中每个字符的位置信息
--   2. 收集 sidenote（侧批）的位置和字符
--   3. 将数据序列化为 JSON 并写入文件
--
-- 【使用方式】
--   在 TeX 文档中调用 \开启排版导出 或 \enableLayoutExport
--   文档结束后自动输出 jobname-layout.json
-- ============================================================================

local export = {}

-- sp to pt conversion factor
local SP_TO_PT = 1 / 65536

-- Internal state
local enabled = false
local output_filename = nil
local collected_data = {} -- Each typeset() call appends one batch

-- ============================================================================
-- JSON Serializer
-- ============================================================================

--- Escape a string for JSON output
-- @param s (string) Input string
-- @return (string) JSON-safe escaped string
local function json_escape_string(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    -- Escape control characters (0x00-0x1F) except those already handled
    s = s:gsub("[\x00-\x08\x0b\x0c\x0e-\x1f]", function(c)
        return string.format("\\u%04x", string.byte(c))
    end)
    return s
end

--- Check if a table is an array (sequential integer keys starting from 1)
-- @param t (table) Table to check
-- @return (boolean) True if array-like
local function is_array(t)
    if #t > 0 then return true end
    return next(t) == nil -- empty table → treat as empty array
end

--- Encode a Lua value to a JSON string
-- @param value (any) Value to encode
-- @param indent (string) Indentation string (default "  ")
-- @param current_indent (string) Current indentation level
-- @return (string) JSON string
local function json_encode(value, indent, current_indent)
    indent = indent or "  "
    current_indent = current_indent or ""
    local next_indent = current_indent .. indent
    local t = type(value)

    if value == nil then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        if value ~= value then return "null" end -- NaN
        if value == math.huge or value == -math.huge then return "null" end
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        else
            return string.format("%.2f", value)
        end
    elseif t == "string" then
        return '"' .. json_escape_string(value) .. '"'
    elseif t == "table" then
        if is_array(value) then
            local items = {}
            for i, v in ipairs(value) do
                items[i] = next_indent .. json_encode(v, indent, next_indent)
            end
            if #items == 0 then return "[]" end
            return "[\n" .. table.concat(items, ",\n") .. "\n" .. current_indent .. "]"
        else
            local items = {}
            -- Sort keys for reproducible output
            local keys = {}
            for k in pairs(value) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                local v = value[k]
                table.insert(items, next_indent .. '"' .. tostring(k) .. '": '
                    .. json_encode(v, indent, next_indent))
            end
            if #items == 0 then return "{}" end
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. current_indent .. "}"
        end
    else
        return "null"
    end
end

-- ============================================================================
-- Page Summary Builder
-- ============================================================================

--- Build a simplified column representation from a column's characters.
-- Scans characters in order, detecting transitions between normal text and
-- jiazhu (annotated) segments. Returns either a plain string (pure normal)
-- or an array of segments where each segment is a string (normal) or
-- a 2-element array [right_sub_col, left_sub_col] (jiazhu).
-- @param characters (table) Array of character entries from a column
-- @return (string|table) Simplified column representation
local function build_col_summary(characters)
    if #characters == 0 then return "" end

    local segments = {}
    local has_jiazhu = false

    -- Current segment accumulation
    local cur_type = nil  -- "normal" or "jiazhu"
    local normal_buf = {}
    local sub1_buf = {}  -- right sub-column (sub_col=1)
    local sub2_buf = {}  -- left sub-column (sub_col=2)

    local function flush_segment()
        if cur_type == "normal" and #normal_buf > 0 then
            table.insert(segments, table.concat(normal_buf))
            normal_buf = {}
        elseif cur_type == "jiazhu" and (#sub1_buf > 0 or #sub2_buf > 0) then
            has_jiazhu = true
            table.insert(segments, {table.concat(sub1_buf), table.concat(sub2_buf)})
            sub1_buf = {}
            sub2_buf = {}
        end
        cur_type = nil
    end

    for _, ch in ipairs(characters) do
        local is_jz = (ch.type == "jiazhu" and ch.jiazhu)
        local new_type = is_jz and "jiazhu" or "normal"

        if new_type ~= cur_type then
            flush_segment()
            cur_type = new_type
        end

        if is_jz then
            if ch.jiazhu.sub_col == 2 then
                table.insert(sub2_buf, ch.char)
            else
                table.insert(sub1_buf, ch.char)
            end
        else
            table.insert(normal_buf, ch.char)
        end
    end
    flush_segment()

    -- Pure normal column: simplify to plain string
    if not has_jiazhu then
        -- All segments are strings; concat them (usually just one)
        local parts = {}
        for _, seg in ipairs(segments) do
            table.insert(parts, seg)
        end
        return table.concat(parts)
    end

    return segments
end

--- Build simplified page summary from pages array.
-- Each page contains: page index, page type, and columns as simplified text.
-- @param pages_array (table) Array of page data (columns already sorted)
-- @return (table) Array of {page=N, type="single"|"spread", cols={...}}
--
-- Page types:
--   - "single": 单页（非筒子页）
--   - "spread": 筒子页（对开页，未裁剪）
--              裁剪信息（左/右）存储在 split_info 中
local function build_page_summary(pages_array)
    local summary = {}
    for _, page_data in ipairs(pages_array) do
        -- Determine page type
        local page_type = "single"
        local si = page_data.split_info
        if si then
            -- 有 split_info 表示这是筒子页（对开页）
            page_type = "spread"
        end

        local page_entry = {
            page = page_data.page_index,
            type = page_type,
            cols = {},
        }

        -- Build col_by_index map to detect gaps (empty columns)
        local max_col_index = -1
        local col_by_index = {}
        for _, col_data in ipairs(page_data.columns) do
            col_by_index[col_data.col_index] = col_data
            if col_data.col_index > max_col_index then
                max_col_index = col_data.col_index
            end
        end

        -- Iterate all columns from 0 to max, filling gaps with ""
        for ci = 0, max_col_index do
            local col_data = col_by_index[ci]
            if not col_data or #col_data.characters == 0 then
                table.insert(page_entry.cols, "")
            else
                table.insert(page_entry.cols, build_col_summary(col_data.characters))
            end
        end

        table.insert(summary, page_entry)
    end
    return summary
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Enable layout export
-- @param params (table|nil) Optional parameters { filename = "..." }
function export.enable(params)
    enabled = true
    _G.export = _G.export or {}
    _G.export.enabled = true
    if params and params.filename and params.filename ~= "" then
        output_filename = params.filename
    end
end

--- Check if export is enabled
-- @return (boolean)
function export.is_enabled()
    return enabled
end

--- Collect layout data from one typeset() call
-- Called from core-main.lua after layout and render stages complete.
-- @param list (node) Head of the flattened node list
-- @param layout_results (table) { layout_map, total_pages, ... }
-- @param engine_ctx (table) Engine context with grid params
-- @param plugin_contexts (table) Plugin contexts including sidenote
-- @param p_info (table) Page info { p_width, p_height, m_*, is_textbox, ... }
function export.collect(list, layout_results, engine_ctx, plugin_contexts, p_info)
    if not enabled then return end

    local constants = package.loaded['core.luatex-cn-constants'] or
        require('core.luatex-cn-constants')
    local D = constants.D
    local text_position = package.loaded['core.luatex-cn-render-position'] or
        require('core.luatex-cn-render-position')
    local style_registry = package.loaded['util.luatex-cn-style-registry'] or
        require('util.luatex-cn-style-registry')
    local layout_map = layout_results.layout_map
    local total_pages = layout_results.total_pages

    local g_width = engine_ctx.g_width or 0
    local g_height = engine_ctx.g_height or 0
    local p_cols = engine_ctx.page_columns or 1
    local col_geom = engine_ctx.col_geom or { grid_width = g_width, banxin_width = 0, interval = 0 }
    local line_limit = engine_ctx.line_limit or 0
    local shift_x = engine_ctx.shift_x or 0
    local shift_y = engine_ctx.shift_y or 0
    local half_thickness = engine_ctx.half_thickness or 0

    -- Check for split page mode
    local split_enabled = _G.page and _G.page.split and _G.page.split.enabled or false
    local split_right_first = _G.page and _G.page.split and _G.page.split.right_first
    if split_right_first == nil then split_right_first = true end

    -- 1. Document-level info
    local doc_info = {
        page_width_pt = (p_info.p_width or 0) * SP_TO_PT,
        page_height_pt = (p_info.p_height or 0) * SP_TO_PT,
        total_pages = total_pages,
        grid_width_pt = g_width * SP_TO_PT,
        grid_height_pt = g_height * SP_TO_PT,
        line_limit = line_limit,
        columns_count = p_cols,
    }

    if split_enabled then
        doc_info.split_page = {
            enabled = true,
            right_first = split_right_first,
            logical_page_width_pt = (p_info.p_width or 0) / 2 * SP_TO_PT,
        }
    else
        doc_info.split_page = {
            enabled = false,
        }
    end

    -- 2. Initialize per-page structures
    local pages = {}
    for pg = 0, total_pages - 1 do
        local page_data = {
            page_index = pg,
            margins = {
                top_pt = (p_info.m_top or 0) * SP_TO_PT,
                bottom_pt = (p_info.m_bottom or 0) * SP_TO_PT,
                left_pt = (p_info.m_left or 0) * SP_TO_PT,
                right_pt = (p_info.m_right or 0) * SP_TO_PT,
            },
            columns_count = p_cols,
            columns = {},  -- col_index → column data
            sidenotes = {},
        }
        if split_enabled then
            local phys_page = math.floor(pg / 2)
            local leaf
            if split_right_first then
                leaf = (pg % 2 == 0) and "right" or "left"
            else
                leaf = (pg % 2 == 0) and "left" or "right"
            end
            page_data.split_info = {
                physical_page = phys_page,
                leaf = leaf,
            }
        end
        pages[pg] = page_data
    end

    -- 3. Traverse node list and extract character positions
    local t = D.todirect(list)
    while t do
        local pos = layout_map[t]
        if pos then
            local id = D.getid(t)
            if id == constants.GLYPH then
                local dec_id = D.get_attribute(t, constants.ATTR_DECORATE_ID)
                if not dec_id or dec_id == 0 then
                    local char_code = D.getfield(t, "char")
                    local pg = pos.page or 0
                    local col = pos.col or 0
                    local y_sp = pos.y_sp or 0
                    local cell_h = pos.cell_height or g_height

                    -- Compute absolute X coordinate (RTL conversion)
                    local rtl_col = p_cols - 1 - col
                    local col_x_sp = text_position.get_column_x(rtl_col, col_geom)
                    local abs_x_sp = col_x_sp + shift_x + half_thickness

                    -- Compute absolute Y coordinate
                    local abs_y_sp = y_sp + shift_y

                    -- Compute row index from y_sp (0-indexed)
                    local row_index = 0
                    if g_height > 0 then
                        row_index = math.floor(y_sp / g_height + 0.5)
                    end

                    -- Compute position: {x, y_top, y_bottom}
                    local abs_x_pt = abs_x_sp * SP_TO_PT
                    local abs_y_pt = abs_y_sp * SP_TO_PT
                    local cell_h_pt = cell_h * SP_TO_PT

                    -- Build character entry (PageLayout-compatible)
                    local char_entry = {
                        char = utf8.char(char_code),
                        unicode = char_code,
                        row_index = row_index,
                        position = {
                            x = abs_x_pt,
                            y_top = abs_y_pt,
                            y_bottom = abs_y_pt + cell_h_pt,
                        },
                        confidence = 1.0,
                    }

                    -- Type and jiazhu info
                    if pos.sub_col then
                        char_entry.type = "jiazhu"
                        char_entry.jiazhu = { sub_col = pos.sub_col }
                    else
                        char_entry.type = "normal"
                    end

                    -- Style: font size and color (P1: read from style_registry, not layout_map)
                    local has_style = false
                    local style = {}
                    local exp_style_id = D.get_attribute(t, constants.ATTR_STYLE_REG_ID)
                    local exp_font_size = exp_style_id and style_registry.get_font_size(exp_style_id)
                    local exp_font_color = exp_style_id and style_registry.get_font_color(exp_style_id)
                    if exp_font_size then
                        style.font_size_pt = exp_font_size * SP_TO_PT
                        has_style = true
                    end
                    if exp_font_color then
                        style.font_color = exp_font_color
                        has_style = true
                    end
                    if has_style then
                        char_entry.style = style
                    end

                    -- Initialize column structure if needed
                    if pages[pg] then
                        if not pages[pg].columns[col] then
                            pages[pg].columns[col] = {
                                col_index = col,
                                position = {
                                    left_x = abs_x_pt,
                                    right_x = abs_x_pt,
                                },
                                characters = {},
                            }
                        end
                        table.insert(pages[pg].columns[col].characters, char_entry)
                    end
                end
            end
        end
        t = D.getnext(t)
    end

    -- 4. Collect sidenote data
    local sn_ctx = plugin_contexts and plugin_contexts["sidenote"]
    if sn_ctx and sn_ctx.map then
        for sid, sn_nodes in pairs(sn_ctx.map) do
            if #sn_nodes > 0 then
                local first_node = sn_nodes[1]
                local pg = first_node.page or 0
                local anchor_col = first_node.col or 0
                local anchor_y_sp = first_node.y_sp or 0

                local spans = false
                local sn_chars = {}

                for _, item in ipairs(sn_nodes) do
                    if item.col ~= anchor_col or item.page ~= pg then
                        spans = true
                    end
                    local nid = D.getid(item.node)
                    if nid == constants.GLYPH then
                        local cc = D.getfield(item.node, "char")
                        if cc then
                            table.insert(sn_chars, {
                                char = utf8.char(cc),
                                unicode = cc,
                                page = item.page,
                                col = item.col,
                                y_pt = (item.y_sp or 0) * SP_TO_PT,
                                cell_height_pt = (item.cell_height or g_height) * SP_TO_PT,
                            })
                        end
                    end
                end

                -- Get font size from metadata if available
                local sn_font_size_pt = nil
                if first_node.metadata and first_node.metadata.font_size then
                    local fs = first_node.metadata.font_size
                    if type(fs) == "number" and fs > 0 then
                        sn_font_size_pt = fs * SP_TO_PT
                    end
                end

                local sn_entry = {
                    sidenote_id = sid,
                    anchor_col = anchor_col,
                    anchor_y_pt = anchor_y_sp * SP_TO_PT,
                    font_size_pt = sn_font_size_pt,
                    spans_columns = spans,
                    characters = sn_chars,
                }

                if pages[pg] then
                    table.insert(pages[pg].sidenotes, sn_entry)
                end
            end
        end
    end

    -- 5. Build page summary (simplified per-page/per-column text content)
    -- Must be done BEFORE converting columns to sorted array, because we need
    -- the col_index information which is preserved in both representations.
    -- Actually we do it AFTER the sorted array conversion (step 5b) so we can
    -- iterate columns in order. See step 5b below.

    -- 5a. Convert pages from 0-indexed map to sorted array
    local pages_array = {}
    for pg = 0, total_pages - 1 do
        local page_data = pages[pg]
        if page_data then
            -- Convert columns from map to sorted array, filling gaps with empty columns
            local cols_array = {}
            local max_col_index = -1

            -- First pass: find the maximum column index that actually has content
            for col_idx, _ in pairs(page_data.columns) do
                if col_idx > max_col_index then
                    max_col_index = col_idx
                end
            end

            -- Second pass: build array from 0 to max_col_index, filling gaps
            for col_idx = 0, max_col_index do
                local col_data = page_data.columns[col_idx]
                if col_data then
                    table.insert(cols_array, col_data)
                else
                    -- Empty column: create a placeholder with correct x position
                    local rtl_col = p_cols - 1 - col_idx
                    local col_x_sp = text_position.get_column_x(rtl_col, col_geom)
                    local abs_x_sp = col_x_sp + shift_x + half_thickness
                    local abs_x_pt = abs_x_sp * SP_TO_PT

                    table.insert(cols_array, {
                        col_index = col_idx,
                        position = {
                            left_x = abs_x_pt,
                            right_x = abs_x_pt,
                        },
                        characters = {},
                    })
                end
            end

            page_data.columns = cols_array
            table.insert(pages_array, page_data)
        end
    end

    -- 5b. Build page_summary from pages_array
    local page_summary = build_page_summary(pages_array)

    -- 6. Append to collected data
    table.insert(collected_data, {
        document = doc_info,
        page_summary = page_summary,
        pages = pages_array,
    })
end

--- Write collected data to JSON file
-- Called at end of document via \AddToHook{enddocument/afterlastpage}
function export.write_json()
    if not enabled or #collected_data == 0 then return end

    -- Get source file modification time
    local source_mtime = nil
    if tex and tex.jobname then
        local tex_file = tex.jobname .. ".tex"
        local lfs = require("lfs")
        local attr = lfs.attributes(tex_file)
        if attr then
            source_mtime = attr.modification
        end
    end

    -- Merge multiple typeset batches
    local final = {
        version = "1.0",
        generator = "luatex-cn",
        source_file = tex and tex.jobname and (tex.jobname .. ".tex") or nil,
        source_mtime = source_mtime,
        document = collected_data[#collected_data].document,
        page_summary = {},
        pages = {},
    }

    -- Update total_pages to reflect actual merged count
    -- and correct page_index across batches
    local total = 0
    for _, batch in ipairs(collected_data) do
        for _, pg in ipairs(batch.pages) do
            -- Correct page_index: add offset from previous batches
            pg.page_index = total
            table.insert(final.pages, pg)
            total = total + 1
        end
        if batch.page_summary then
            for _, ps in ipairs(batch.page_summary) do
                -- Correct page in page_summary
                ps.page = total - #batch.pages + (ps.page or 0)
                -- Note: ps.page might be the old incorrect value,
                -- we'll recalculate it properly below
                table.insert(final.page_summary, ps)
            end
        end
    end
    final.document.total_pages = total

    -- Recalculate page_summary.page to match corrected page_index
    for i, ps in ipairs(final.page_summary) do
        ps.page = i - 1  -- 0-indexed, matching array index
    end

    -- Determine output filename
    local filename = output_filename
    if not filename or filename == "" then
        -- tex.jobname is available in LuaTeX
        local jobname = tex and tex.jobname or "output"
        filename = jobname .. "-layout.json"
    end

    -- Prepend output_dir if set (passed from TeX layer)
    if export._output_dir and export._output_dir ~= "" then
        if not filename:match("^/") and not filename:match("^%a:") then
            filename = export._output_dir .. "/" .. filename
        end
    end

    -- Serialize and write
    local json_str = json_encode(final)
    local f = io.open(filename, "w")
    if f then
        f:write(json_str)
        f:write("\n")
        f:close()
        if texio and texio.write_nl then
            texio.write_nl("term and log",
                string.format("[export] Layout exported to %s (%d pages)", filename, total))
        end
    else
        if texio and texio.write_nl then
            texio.write_nl("term and log",
                string.format("[export] ERROR: Cannot write to %s", filename))
        end
    end
end

--- Reset internal state (for testing)
function export.reset()
    enabled = false
    output_filename = nil
    collected_data = {}
    if _G.export then
        _G.export.enabled = false
    end
end

-- Export _internal for unit testing
export._internal = {
    json_encode = json_encode,
    json_escape_string = json_escape_string,
    is_array = is_array,
    SP_TO_PT = SP_TO_PT,
    build_col_summary = build_col_summary,
    build_page_summary = build_page_summary,
}

-- Register module
package.loaded['core.luatex-cn-core-export'] = export

return export
