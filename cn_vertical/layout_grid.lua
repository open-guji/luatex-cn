-- ============================================================================
-- layout_grid.lua - 虚拟网格布局计算（第二阶段）
-- ============================================================================
-- 文件名: layout_grid.lua (原 layout.lua)
-- 层级: 第二阶段 - 布局层 (Stage 2: Layout Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责排版流水线的第二阶段，在不修改节点的情况下进行"虚拟布局模拟"：
--   1. 遍历节点流，计算每个节点应该出现在哪一页、哪一列、第几行
--   2. 处理自动换列、分页逻辑（当行数超过 line_limit 时）
--   3. 避让版心（banxin）列位置，确保不在版心列放置正文内容
--   4. 支持"分布模式"（distribute），在列内均匀分布字符（用于 textbox）
--   5. 维护占用地图（occupancy map），防止 textbox 块与其他内容重叠
--
-- 【术语对照 / Terminology】
--   layout_map        - 布局映射（节点指针 → 坐标位置）
--   cur_page/col/row  - 当前光标位置（页/列/行）
--   banxin            - 版心（古籍中间的分隔列）
--   occupancy         - 占用地图（记录已被使用的网格位置）
--   line_limit        - 每列最大行数
--   page_columns      - 每页最大列数
--   effective_limit   - 有效行数限制（考虑右缩进后）
--   col_buffer        - 列缓冲区（用于分布模式）
--   distribute        - 分布模式（均匀分布字符）
--
-- 【注意事项】
--   • 本模块只计算位置（layout_map），不修改节点本身
--   • 版心列由 n_column 参数控制：每 (n_column + 1) 列就是一个版心列
--   • 右缩进（r_indent）会缩短列的有效高度（effective_limit）
--   • Textbox 块（由 core_textbox.lua 处理生成）占用多个网格单元（width × height）
--   • Textbox 在外部布局中始终表现为一个 width=1 的块，高度由其内容决定
--   • Penalty≤-10000 会触发强制换列（由 flatten_nodes.lua 插入）
--
-- 【整体架构 / Architecture】
--   输入: 一维节点流 + grid_height + line_limit + n_column + page_columns
--      ↓
--   calculate_grid_positions()
--      ├─ 维护光标状态 (cur_page, cur_col, cur_row)
--      ├─ 遍历每个节点
--      │   ├─ 应用缩进逻辑（hanging indent）
--      │   ├─ 检查是否需要换列/分页
--      │   ├─ 跳过版心列和已占用位置
--      │   └─ 记录位置到 layout_map[node] = {page, col, row}
--      └─ Textbox 块额外标记 occupancy 地图
--      ↓
--   输出: layout_map (节点指针 → 坐标) + total_pages
--
-- Version: 0.4.0
-- Date: 2026-01-13
-- ============================================================================

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['base_constants'] or require('base_constants')
local D = constants.D
local utils = package.loaded['base_utils'] or require('base_utils')

-- @param page_columns (number) Total columns before a page break
-- @param params (table) Optional parameters:
--   - distribute (boolean) If true, distribute nodes evenly in columns
-- @return (table, number) layout_map (node_ptr -> {page, col, row}), total_pages
local function calculate_grid_positions(head, grid_height, line_limit, n_column, page_columns, params)
    local d_head = D.todirect(head)
    params = params or {}
    local distribute = params.distribute

    if line_limit < 1 then line_limit = 20 end

    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)
    if p_cols <= 0 then p_cols = 10000 end -- Safety

    -- Stateful cursor layout
    local cur_page = 0
    local cur_col = 0
    local cur_row = 0
    local cur_column_indent = 0
    local layout_map = {}
    
    -- Buffer for distribution mode
    local col_buffer = {}

    -- Occupancy map: occupancy[page][col][row] = true
    local occupancy = {}

    local function is_banxin_col(col)
        if interval <= 0 then return false end
        return (col % (interval + 1)) == interval
    end

    local function is_occupied(p, c, r)
        if not occupancy[p] then return false end
        if not occupancy[p][c] then return false end
        return occupancy[p][c][r] == true
    end

    local function mark_occupied(p, c, r)
        if not occupancy[p] then occupancy[p] = {} end
        if not occupancy[p][c] then occupancy[p][c] = {} end
        occupancy[p][c][r] = true
    end

    local function skip_banxin_and_occupied()
        local changed = true
        while changed do
            changed = false
            -- Skip Banxin
            while is_banxin_col(cur_col) do
                cur_col = cur_col + 1
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                changed = true
            end
            -- Skip Occupied
            if is_occupied(cur_page, cur_col, cur_row) then
                cur_row = cur_row + 1
                if cur_row >= line_limit then
                    cur_row = 0
                    cur_col = cur_col + 1
                    changed = true
                else
                    -- Check again if new row is banxin or occupied
                    changed = true
                end
            end
        end
    end

    local function flush_buffer()
        if #col_buffer == 0 then return end
        
        local N = #col_buffer
        local H = line_limit -- For inner layout, line_limit is total rows
        
        for i, entry in ipairs(col_buffer) do
            local row
            if distribute and N > 1 and N < H then
                -- Evenly distribute with sub-grid precision: Row = (i-1) * (H-1)/(N-1)
                row = (i-1) * (H-1) / (N-1)
            else
                row = entry.relative_row
            end
            
            layout_map[entry.node] = {
                page = entry.page, 
                col = entry.col, 
                row = row,
                is_block = entry.is_block,
                width = entry.width,
                height = entry.height
            }
        end
        col_buffer = {}
    end

    local t = d_head
    skip_banxin_and_occupied()

    while t do
        ::start_of_loop::
        local id = D.getid(t)
        local indent = D.get_attribute(t, constants.ATTR_INDENT) or 0
        local r_indent = D.get_attribute(t, constants.ATTR_RIGHT_INDENT) or 0
        
        -- Textbox attributes; ONLY treat HLIST/VLIST as blocks
        -- 这些属性由 textbox.lua 在 verticalize_inner_box 阶段设置
        local tb_w = 0
        local tb_h = 0
        if id == constants.HLIST or id == constants.VLIST then
            tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
            tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0
        end

        -- Hanging indent logic (applied to both glyphs and blocks)
        if cur_row < indent then cur_row = indent end
        if indent > cur_column_indent then cur_column_indent = indent end
        if cur_row < cur_column_indent then cur_row = cur_column_indent end

        local effective_limit = line_limit - r_indent
        if effective_limit < indent + 1 then effective_limit = indent + 1 end

        -- Check wrapping BEFORE placing
        if cur_row >= effective_limit then
            flush_buffer()
            cur_col = cur_col + 1
            cur_row = 0
            if cur_col >= p_cols then
                cur_col = 0
                cur_page = cur_page + 1
            end
            cur_column_indent = indent
            if cur_row < indent then cur_row = indent end
            skip_banxin_and_occupied()
        end

        local is_jiazhu = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
        if is_jiazhu then
            flush_buffer()
            -- Collect Jiazhu sequence
            local j_nodes = {}
            local temp_t = t
            while temp_t and D.get_attribute(temp_t, constants.ATTR_JIAZHU) == 1 do
                local tid = D.getid(temp_t)
                if tid == constants.GLYPH then
                    table.insert(j_nodes, temp_t)
                end
                temp_t = D.getnext(temp_t)
            end

            -- Ensure we have at least 2 rows available before starting a Jiazhu sequence
            -- This prevents "orphan" Jiazhu rows starting at the very bottom of a column.
            if effective_limit - cur_row < 2 then
                flush_buffer()
                cur_col = cur_col + 1
                cur_row = 0
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end

            -- Process via core_textflow
            local textflow = package.loaded['core_textflow'] or require('core_textflow')
            local chunks = textflow.process_jiazhu_sequence(j_nodes, effective_limit - cur_row, effective_limit)

            for i, chunk in ipairs(chunks) do
                -- If not the first chunk, move to next column
                if i > 1 then
                    cur_col = cur_col + 1
                    cur_row = 0
                    if cur_col >= p_cols then
                        cur_col = 0
                        cur_page = cur_page + 1
                    end
                    skip_banxin_and_occupied()
                end

                -- Record positions
                for _, node_info in ipairs(chunk.nodes) do
                    layout_map[node_info.node] = {
                        page = cur_page,
                        col = cur_col,
                        row = cur_row + node_info.relative_row,
                        sub_col = node_info.sub_col
                    }
                end
                
                cur_row = cur_row + chunk.rows_used
            end
            
            t = temp_t
            if not t then break end
            goto start_of_loop
        end

        if tb_w > 0 and tb_h > 0 then
            -- Handle Textbox Block
            if cur_row + tb_h > effective_limit then
                flush_buffer()
                cur_col = cur_col + 1
                cur_row = indent
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end
            
            local fits_width = true
            for c = cur_col, cur_col + tb_w - 1 do
                if is_banxin_col(c) or (c >= p_cols) then
                    fits_width = false
                    break
                end
            end
            
            if not fits_width then
                flush_buffer()
                cur_col = cur_col + 1
                cur_row = 0
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end

            for c = cur_col, cur_col + tb_w - 1 do
                for r = cur_row, cur_row + tb_h - 1 do
                    mark_occupied(cur_page, c, r)
                end
            end

            table.insert(col_buffer, {node=t, page=cur_page, col=cur_col, relative_row=cur_row, is_block=true, width=tb_w, height=tb_h})
            cur_row = cur_row + tb_h
            skip_banxin_and_occupied()

        elseif id == constants.GLYPH then
            table.insert(col_buffer, {node=t, page=cur_page, col=cur_col, relative_row=cur_row})
            cur_row = cur_row + 1
            skip_banxin_and_occupied()
        elseif id == constants.GLUE then
             -- Skip baseline/lineskip glues in grid layout as they interfere with discrete row placement
             -- These are especially common around font size changes (like Jiazhu)
             local subtype = D.getsubtype(t)
             if subtype == 0 then
                 -- User-inserted glue? Treat as something that might take space if we want.
                 -- For now, let's keep skipping to maintain strict grid.
             end
        elseif id == constants.PENALTY and D.getfield(t, "penalty") <= -10000 then
             flush_buffer()
             if cur_row > 0 then
                 cur_col = cur_col + 1
                 cur_row = 0
                 if cur_col >= p_cols then
                     cur_col = 0
                     cur_page = cur_page + 1
                 end
                 cur_column_indent = 0
                 skip_banxin_and_occupied()
             end
        end

        t = D.getnext(t)
        ::continue::
    end
    
    flush_buffer()

    local total_pages = cur_page + 1

    return layout_map, total_pages
end

-- Create module table
local layout = {
    calculate_grid_positions = calculate_grid_positions,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['layout_grid'] = layout

-- Return module exports
return layout
