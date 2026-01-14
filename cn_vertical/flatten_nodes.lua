-- ============================================================================
-- flatten_nodes.lua - 盒子展平与缩进提取（第一阶段）
-- ============================================================================
-- 文件名: flatten_nodes.lua (原 flatten.lua)
-- 层级: 第一阶段 - 展平层 (Stage 1: Flatten Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责排版流水线的第一阶段，将 TeX 复杂的嵌套盒子结构转化为一维节点流：
--   1. 递归遍历 VBox/HBox，将多层嵌套展平为线性节点列表
--   2. 自动检测并提取缩进信息（leftskip glue、box shift）
--   3. 将缩进值转换为字符数并附加为节点属性（ATTR_INDENT）
--   4. 在适当位置插入列中断标记（penalty -10001）
--   5. 过滤无用节点（保留 glyph、kern、特定 glue、textbox 块）
--
-- 【术语对照 / Terminology】
--   flatten         - 展平（将嵌套结构转为线性结构）
--   indent          - 缩进（首行或悬挂缩进）
--   leftskip        - 左侧跳过（TeX 的段落左缩进机制）
--   shift           - 盒子偏移（box.shift 属性）
--   penalty         - 惩罚值（用于控制换行/换列）
--   column break    - 列中断（-10001 触发强制换列）
--   running_indent  - 当前累积缩进（随遍历更新）
--   has_content     - 是否有可见内容（字形或文本框）
--
-- 【注意事项】
--   • 缩进检测依赖 TeX 的 \leftskip 和 box.shift 机制，支持标准的 itemize/enumerate
--   • "列中断"（penalty -10001）在每个 HLIST 行之后插入，用于 layout_grid.lua 识别强制换列
--   • 重点：展平算法高度依赖 TeX 的段落构建，若节点在垂直模式输出（如列表开头的 Textbox），
--     其缩进属性（leftskip）将无法被检测。因此 TeX 端必须确保进入水平模式（如使用 \leavevmode）
--   • Textbox 块通过属性 ATTR_TEXTBOX_WIDTH/HEIGHT 识别，会被完整保留
--   • 右缩进（rightskip）功能已预留但未完全实现（当前只在 layout 中使用）
--   • 节点会被复制（D.copy），原始盒子不会被修改
--
-- 【整体架构 / Architecture】
--   输入: TeX VBox.list (嵌套的 vlist/hlist/glyph 树)
--      ↓
--   flatten_vbox(head, grid_width, char_width)
--      ├─ collect_nodes() 递归遍历
--      │   ├─ 检测 leftskip → 更新 indent
--      │   ├─ 检测 shift → 更新 indent
--      │   └─ 递归处理子盒子
--      ├─ 为每个节点附加 ATTR_INDENT 属性
--      └─ 在行尾插入 penalty -10001
--      ↓
--   输出: 一维节点流（glyph + kern + glue + penalty + textbox块）
--
-- Version: 0.4.0
-- Date: 2026-01-13
-- ============================================================================

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['base_constants'] or require('base_constants')
local D = constants.D
local utils = package.loaded['base_utils'] or require('base_utils')

--- Flatten a vlist (from vbox) into a single list of nodes
-- Extracts indentation from line starts and applies it as attributes.
-- Also cleans up nodes (keeps valid glues/glyphs).
--
-- @param head (node) Head of the vlist
-- @param grid_width (number) Grid column width in scaled points
-- @param char_width (number) Character width for indent calculation (usually grid_height)
-- @return (node) Flattened node list with indent attributes
local function flatten_vbox(head, grid_width, char_width)
    local d_head = D.todirect(head)
    local result_head_d = nil
    local result_tail_d = nil

    --- Append a node to the result list
    -- @param n (direct node) Node to append
    local function append_node(n)
        if not n then return end
        -- if utils and utils.debug_log then
        --     utils.debug_log("  [flatten] Appending Node=" .. tostring(n) .. " tid=" .. (D.getid(n) or "?"))
        -- end
        D.setnext(n, nil)
        if not result_head_d then
            result_head_d = n
            result_tail_d = n
        else
            D.setlink(result_tail_d, n)
            result_tail_d = n
        end
    end

    --- Recursive node collector
    -- @param n_head (direct node) Head of node list to collect (WILL BE CONSUMED)
    -- @param indent_lvl (number) Current indent
    -- @param r_indent_lvl (number) Current right indent
    -- @return (boolean) True if any visible content (glyphs/textboxes) was collected
    local function collect_nodes(n_head, indent_lvl, r_indent_lvl)
        local t = n_head
        local running_indent = indent_lvl
        local running_r_indent = r_indent_lvl
        local has_content = false

        while t do
            local tid = D.getid(t)

            -- Check for Textbox Block attribute
            local tb_w = 0
            local tb_h = 0
            if tid == constants.HLIST or tid == constants.VLIST then
                tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
                tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0
            end

            if tb_w > 0 and tb_h > 0 then
                local copy = D.copy(t)
                -- Apply running indent (inherited from previous lines if needed)
                if running_indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, running_indent) end
                if running_r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, running_r_indent) end
                append_node(copy)
                has_content = true
            elseif tid == constants.HLIST or tid == constants.VLIST then
                -- Check for line-level indentation
                local inner = D.getfield(t, "list")
                local box_indent = running_indent
                local box_r_indent = running_r_indent

                -- Detect Shift on any box
                local shift = D.getfield(t, "shift") or 0
                if shift > 0 then
                    box_indent = math.max(box_indent, math.floor(shift / char_width + 0.5))
                end

                if tid == constants.HLIST then
                    -- Check for leftskip inside HLIST
                    local s = inner
                    while s do
                        local sid = D.getid(s)
                        if sid == constants.GLYPH then break end
                        if sid == constants.GLUE and D.getsubtype(s) == 8 then -- leftskip
                            if st == 8 then -- leftskip
                                box_indent = math.max(box_indent, math.floor(w / char_width + 0.5))
                            end
                            break
                        end
                        s = D.getnext(s)
                    end
                end

                -- Recurse
                local inner_has_content = collect_nodes(inner, box_indent, box_r_indent)
                if inner_has_content then has_content = true end
                
                -- IMPORTANT: Only add penalty for HLIST lines that are part of 
                -- the main vertical flow, i.e., at the second recursion level.
                -- For simplicity, let's just add it if this HLIST had content.
                if tid == constants.HLIST and inner_has_content then
                    if utils and utils.debug_log then
                        utils.debug_log("  [flatten] Adding Column Break after Line=" .. tostring(t))
                    end
                    local p = D.new(constants.PENALTY)
                    D.setfield(p, "penalty", -10001)
                    append_node(p)
                end
            else
                local keep = false
                if tid == constants.GLYPH or tid == constants.KERN then
                    keep = true
                    if tid == constants.GLYPH then has_content = true end
                elseif tid == constants.GLUE then
                    local subtype = D.getsubtype(t)
                    if subtype == 0 or subtype == 13 or subtype == 14 then
                       keep = true
                    end
                elseif tid == constants.PENALTY then
                    keep = true
                end

                if keep then
                    local copy = D.copy(t)
                    if running_indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, running_indent) end
                    if running_r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, running_r_indent) end
                    
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_WIDTH, 0)
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_HEIGHT, 0)
                    
                    append_node(copy)
                end
            end
            t = D.getnext(t)
        end
        return has_content
    end

    collect_nodes(d_head, 0, 0)
    return D.tonode(result_head_d)
end

-- Create module table
local flatten = {
    flatten_vbox = flatten_vbox,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['flatten_nodes'] = flatten

-- Return module exports
return flatten
