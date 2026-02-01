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
-- core_textbox.lua - 文本框（GridTextbox）处理模块
-- ============================================================================
-- 层级: 协调层 (Core/Coordinator Layer)
--
-- 【模块功能】
-- 处理"内嵌文本框"（GridTextbox）的竖排逻辑：
--   1. 接收 TeX 传递的盒子（hlist/vlist）
--   2. 将其视为一个"微型页面"，根据网格参数重新进行布局
--   3. 应用特殊的属性，使其能被外部布局识别
--   4. 处理缩进继承
--
-- 【整体架构】
--   process_inner_box(box_num, params)
--      ├─ get_current_indent() - 获取缩进
--      ├─ parse_column_aligns() - 解析列对齐
--      ├─ build_sub_params() - 构建子参数
--      ├─ execute_layout_pipeline() - 执行布局
--      └─ apply_result_attributes() - 应用属性
--
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local D = node.direct

local dbg = debug.get_debugger('textbox')

-- ============================================================================
-- Global State (全局状态)
-- ============================================================================
-- Initialize global textbox table (similar to _G.content)
_G.textbox = _G.textbox or {}
_G.textbox.column_aligns = _G.textbox.column_aligns or ""
_G.textbox.floating = _G.textbox.floating or false
_G.textbox.floating_x = _G.textbox.floating_x or 0
_G.textbox.floating_y = _G.textbox.floating_y or 0
_G.textbox.floating_paper_width = _G.textbox.floating_paper_width or 0
_G.textbox.outer_grid_height = _G.textbox.outer_grid_height or 0

--- Setup global textbox parameters from TeX
-- Called before process_inner_box() to pre-set per-textbox params
-- @param params (table) Parameters from TeX keyvals
local function textbox_setup(params)
    params = params or {}
    if params.column_aligns ~= nil then _G.textbox.column_aligns = params.column_aligns end
    if params.floating ~= nil then
        _G.textbox.floating = (params.floating == true or params.floating == "true")
    end
    if params.floating_x then _G.textbox.floating_x = constants.to_dimen(params.floating_x) or 0 end
    if params.floating_y then _G.textbox.floating_y = constants.to_dimen(params.floating_y) or 0 end
    if params.floating_paper_width then
        _G.textbox.floating_paper_width = constants.to_dimen(params.floating_paper_width) or 0
    end
    if params.outer_grid_height then
        _G.textbox.outer_grid_height = tonumber(params.outer_grid_height) or 0
    end
end

-- ============================================================================
-- Helper Functions (辅助函数)
-- ============================================================================

--- 解析高度参数为网格单位
-- @param height_raw (string|number) 高度参数
-- @param grid_height_raw (string|number) 网格高度（单格尺寸）
-- @return (number) 网格单位数
local function resolve_grid_height(height_raw, grid_height_raw)
    if not height_raw or height_raw == "" then return 0 end

    -- 如果是纯数字或数字字符串，视为网格单位
    if type(height_raw) == "number" or (type(height_raw) == "string" and height_raw:match("^%d+$")) then
        return tonumber(height_raw) or 0
    end

    -- 否则视为尺寸字符串，转换为 sp 后除以网格高度
    local h_sp = constants.to_dimen(height_raw)
    local gh_sp = constants.to_dimen(grid_height_raw) or (65536 * 12)

    if h_sp and type(h_sp) == "number" and gh_sp > 0 then
        return math.ceil(h_sp / gh_sp)
    end

    return 0
end

--- 解析列对齐字符串
-- @param column_aligns_str (string) 逗号分隔的对齐方式 (例如 "right,left")
-- @return (table) 索引从 0 开始的对齐方式表
local function parse_column_aligns(column_aligns_str)
    local col_aligns = {}
    if not column_aligns_str or column_aligns_str == "" then
        return col_aligns
    end

    local idx = 0
    for align in string.gmatch(column_aligns_str, '([^,]+)') do
        align = align:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
        col_aligns[idx] = align
        idx = idx + 1
    end
    return col_aligns
end

--- 获取有效的列数
-- @param n_cols (number|nil) 用户指定的列数
-- @return (number) 有效的列数
local function get_effective_n_cols(n_cols)
    local cols = tonumber(n_cols) or 0
    if cols <= 0 then
        return 100 -- Auto columns: large enough to accommodate any content
    end
    return cols
end

--- 获取当前缩进值
-- @param params (table) 参数表
-- @return (number) 缩进值（以网格为单位）
local function get_current_indent(params)
    local current_indent = 0

    -- 从属性获取缩进
    local ci = tex.attribute[constants.ATTR_INDENT]
    if ci and ci > -1 then
        current_indent = ci
    end

    -- 检查 TeX 的 leftskip（列表环境缩进）
    local char_height = constants.to_dimen(params.grid_height) or (65536 * 12)
    local ls_width = tex.leftskip.width
    if ls_width > 0 then
        local ls_indent = math.floor(ls_width / char_height + 0.5)
        current_indent = math.max(current_indent, ls_indent)
    end

    return current_indent
end

--- 构建子网格布局参数
-- @param params (table) 原始参数
-- @param col_aligns (table) 列对齐表 (parsed from _G.textbox.column_aligns)
-- @return (table) 子布局参数
local function build_sub_params(params, col_aligns)
    local ba = params.box_align or "top"
    local n_cols = get_effective_n_cols(params.n_cols)
    local height = resolve_grid_height(params.height, params.grid_height)

    -- height=0 means auto: use large limit to fit content
    local col_limit = (height > 0) and height or 1000

    return {
        n_cols = n_cols,
        page_columns = n_cols,
        col_limit = col_limit,
        height = params.height,
        grid_width = params.grid_width,
        grid_height = params.grid_height,
        box_align = params.box_align,
        column_aligns = col_aligns,
        border_on = (params.border == "true" or params.border == true),
        background_color = params.background_color,
        font_color = params.font_color,
        font_size = params.font_size,
        is_textbox = true,
        distribute = (ba == "fill"),
        border_color = params.border_color,
        -- floating* now in _G.textbox (read via plugin context in main.lua)
        -- judou params read directly from TeX vars by judou plugin
    }
end

--- 执行核心排版流水线
-- @param box_num (number) TeX 盒子编号
-- @param sub_params (table) 子布局参数
-- @param current_indent (number) 当前缩进
-- @return (node|nil) 渲染结果盒子
local function execute_layout_pipeline(box_num, sub_params, current_indent)
    local core = _G.core
    if not core or not core.typeset then
        dbg.log("Error: core.typeset not found")
        return nil
    end

    -- Temporary page buffering
    local saved_pages = _G.vertical_pending_pages
    _G.vertical_pending_pages = {}

    -- Save and clear indent state - Textbox should not inherit outer indent
    local saved_leftskip = tex.leftskip
    local saved_attr_indent = tex.attribute[constants.ATTR_INDENT]
    tex.leftskip = 0
    tex.attribute[constants.ATTR_INDENT] = -0x7FFFFFFF -- Unset attribute

    dbg.log(string.format("Processing inner box %d (indent=%d)", box_num, current_indent))

    -- 调用三阶段流水线
    core.typeset(box_num, sub_params)

    -- Restore indent state
    tex.leftskip = saved_leftskip
    tex.attribute[constants.ATTR_INDENT] = saved_attr_indent

    -- 获取渲染结果（应当只有 1 "页"）
    local res_box = _G.vertical_pending_pages[1]

    -- Flush any other pages produced
    for i = 2, #_G.vertical_pending_pages do
        if _G.vertical_pending_pages[i] then
            node.flush_list(_G.vertical_pending_pages[i])
        end
    end

    -- 恢复主文档分页缓存
    _G.vertical_pending_pages = saved_pages

    return res_box
end

--- 应用结果属性到盒子
-- @param res_box (node) 结果盒子
-- @param params (table) 原始参数
-- @param current_indent (number) 当前缩进
local function apply_result_attributes(res_box, params, current_indent)
    if not res_box then return end

    -- Determine total height in sp for external occupancy calculation
    local h_raw = params.height
    local inner_gh_sp = constants.to_dimen(params.grid_height) or (65536 * 12)
    -- Read outer_grid_height from _G.textbox (set by textbox.setup)
    local outer_gh_sp = _G.textbox.outer_grid_height
    if not outer_gh_sp or outer_gh_sp <= 0 then
        outer_gh_sp = inner_gh_sp
    end

    local h_sp = 0
    if type(h_raw) == "number" or (type(h_raw) == "string" and h_raw:match("^%d+$")) then
        -- Pure number: multiply by inner grid height
        h_sp = (tonumber(h_raw) or 0) * inner_gh_sp
    else
        -- Dimension string: convert to sp
        h_sp = constants.to_dimen(h_raw) or 0
    end

    local actual_cols = node.get_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH) or 1
    -- Occupancy in outer grid cells
    local height_val = math.ceil(h_sp / outer_gh_sp)

    node.set_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH, actual_cols)
    node.set_attribute(res_box, constants.ATTR_TEXTBOX_HEIGHT, height_val)

    -- 应用缩进属性
    if current_indent > 0 then
        node.set_attribute(res_box, constants.ATTR_INDENT, current_indent)
    end
end

-- ============================================================================
-- Floating Textbox Helpers (浮动文本框辅助函数)
-- ============================================================================

--- 创建浮动盒子锚点节点
-- @param id (number) 浮动盒子 ID
-- @return (node) whatsit 节点
local function create_floating_anchor(id)
    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.FLOATING_TEXTBOX_USER_ID
    n.type = 100 -- Integer type
    n.value = id
    return n
end

--- 遍历节点列表查找浮动盒子
-- @param list (node) 节点列表头
-- @param layout_map (table) 布局映射表
-- @param registry (table) 浮动盒子注册表
-- @return (table) 浮动盒子位置数组
local function find_floating_boxes(list, layout_map, registry)
    local floating_map = {}
    if not list then return floating_map end

    local t = D.todirect(list)
    local last_page = 0

    while t do
        local id = D.getid(t)
        if id == constants.WHATSIT then
            local uid = D.getfield(t, "user_id")
            if uid == constants.FLOATING_TEXTBOX_USER_ID then
                local fid = D.getfield(t, "value")
                local item = registry[fid]
                if item then
                    table.insert(floating_map, {
                        box = item.box,
                        page = last_page,
                        x = item.x,
                        y = item.y
                    })
                    dbg.log(string.format("Placed floating box %d on page %d", fid, last_page))
                end
            end
        else
            local pos = layout_map[t]
            if pos then
                last_page = pos.page or 0
            end
        end
        t = D.getnext(t)
    end

    return floating_map
end

-- ============================================================================
-- Module Table
-- ============================================================================

local textbox = {}

-- Registry for floating textboxes
textbox.floating_registry = {}
textbox.floating_counter = 0

-- Export setup function
textbox.setup = textbox_setup

-- ============================================================================
-- Plugin Standard API (插件标准接口)
-- ============================================================================

--- Initialize Textbox Plugin
-- @param params (table) Parameters from TeX
-- @param engine_ctx (table) Shared engine context
-- @return (table|nil) Plugin context or nil if disabled
function textbox.initialize(params, engine_ctx)
    -- Textbox plugin is always active (it manages floating boxes)
    -- Copy per-textbox params from _G.textbox to plugin context
    return {
        floating_map = nil, -- Will be populated in layout phase
        column_aligns = parse_column_aligns(_G.textbox.column_aligns or ""),
        floating = _G.textbox.floating or false,
        floating_x = _G.textbox.floating_x or 0,
        floating_y = _G.textbox.floating_y or 0,
        floating_paper_width = _G.textbox.floating_paper_width or 0,
        outer_grid_height = _G.textbox.outer_grid_height or 0,
    }
end

--- Flatten hook (not used by textbox)
-- @param head (node) Node list head
-- @param params (table) Parameters
-- @param ctx (table) Plugin context
-- @return (node) Unchanged head
function textbox.flatten(head, params, ctx)
    return head
end

--- Layout hook for Textbox
-- Calculate floating textbox positions based on layout_map
-- @param list (node) Node list
-- @param layout_map (table) Main layout map
-- @param engine_ctx (table) Engine context
-- @param ctx (table) Plugin context
function textbox.layout(list, layout_map, engine_ctx, ctx)
    if not ctx then return end
    -- Calculate floating positions and store in context
    ctx.floating_map = find_floating_boxes(list, layout_map, textbox.floating_registry)
end

--- Render hook for Textbox (currently unused - floating boxes rendered in render-page)
-- @param head (node) Page list head
-- @param layout_map (table) Main layout map
-- @param params (table) Render parameters
-- @param ctx (table) Plugin context
-- @param engine_ctx (table) Engine context
-- @param page_idx (number) Current page index (0-based)
-- @param p_total_cols (number) Total columns on this page
-- @return (node) Page head (unchanged)
function textbox.render(head, layout_map, params, ctx, engine_ctx, page_idx, p_total_cols)
    -- Floating box rendering is currently handled in render-page.lua
    -- This hook is reserved for future refactoring
    return head
end

-- ============================================================================
-- Public Functions (公开函数)
-- ============================================================================

--- 将一个 TeX 盒子转化为竖排网格文本框
-- @param box_num (number) TeX 盒子寄存器编号
-- @param params (table) 配置参数
function textbox.process_inner_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    -- dbg.log(string.format("process_inner_box: floating=%s", tostring(params.floating)))

    -- 1. Textbox should not inherit paragraph indent
    local current_indent = 0

    -- 2. 解析列对齐 (from _G.textbox set by textbox.setup)
    local col_aligns = parse_column_aligns(_G.textbox.column_aligns or "")

    -- 3. 构建子参数
    local sub_params = build_sub_params(params, col_aligns)

    -- 4. 执行布局流水线
    local res_box = execute_layout_pipeline(box_num, sub_params, current_indent)

    -- 5. 应用属性并写回
    if res_box then
        apply_result_attributes(res_box, params, current_indent)
        tex.box[box_num] = res_box
    end
end

--- Register a floating textbox from a TeX box
-- @param box_num (number) TeX box register number
-- @param params (table) { x = string/dim, y = string/dim }
function textbox.register_floating_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    textbox.floating_counter = textbox.floating_counter + 1
    local id = textbox.floating_counter

    -- Capture the box
    local b = node.copy_list(box)

    textbox.floating_registry[id] = {
        box = b,
        x = constants.to_dimen(params.x) or 0,
        y = constants.to_dimen(params.y) or 0
    }

    dbg.log(string.format("Registered floating box ID=%d at (%s, %s)",
        id, tostring(params.x), tostring(params.y)))

    -- Write anchor node
    node.write(create_floating_anchor(id))
end

--- Calculate positions for floating boxes
-- @param layout_map (table) Main layout map
-- @param params (table) { list = head_node }
-- @return (table) Array of floating box positions
function textbox.calculate_floating_positions(layout_map, params)
    return find_floating_boxes(params.list, layout_map, textbox.floating_registry)
end

--- Place a textbox node into the grid
-- @param ctx (table) Grid context
-- @param node (node) Textbox node
-- @param tb_w (number) Textbox width
-- @param tb_h (number) Textbox height
-- @param params (table) { effective_limit, p_cols, interval, grid_height, indent }
-- @param callbacks (table) { flush, wrap, is_reserved_col, mark_occupied, push_buffer, move_next }
function textbox.place_textbox_node(ctx, node, tb_w, tb_h, params, callbacks)
    -- Handle vertical overflow
    if ctx.cur_row + tb_h > params.effective_limit then
        callbacks.flush()
        callbacks.wrap(false, false) -- reset_indent=false, reset_content=false
        ctx.cur_row = params.indent  -- Textbox respects indent at start of new column
    end

    local fits_width = true
    for c = ctx.cur_col, ctx.cur_col + tb_w - 1 do
        if callbacks.is_reserved(c) or (c >= params.p_cols) then
            fits_width = false
            break
        end
    end

    if not fits_width then
        callbacks.flush()
        callbacks.wrap(false, false)
    end

    for c = ctx.cur_col, ctx.cur_col + tb_w - 1 do
        for r = ctx.cur_row, ctx.cur_row + tb_h - 1 do
            callbacks.mark_occupied(ctx.occupancy, ctx.cur_page, c, r)
        end
    end

    callbacks.push_buffer({
        node = node,
        page = ctx.cur_page,
        col = ctx.cur_col,
        relative_row = ctx.cur_row,
        is_block = true,
        width = tb_w,
        height = tb_h
    })
    ctx.cur_row = ctx.cur_row + tb_h
    callbacks.move_next()
end

--- Clear the floating textbox registry
function textbox.clear_registry()
    textbox.floating_registry = {}
    textbox.floating_counter = 0
end

-- ============================================================================
-- Module Export
-- ============================================================================

-- Internal functions exported for testing
textbox._internal = {
    parse_column_aligns = parse_column_aligns,
    get_effective_n_cols = get_effective_n_cols,
    get_current_indent = get_current_indent,
    build_sub_params = build_sub_params,
    execute_layout_pipeline = execute_layout_pipeline,
    apply_result_attributes = apply_result_attributes,
    create_floating_anchor = create_floating_anchor,
    find_floating_boxes = find_floating_boxes,
}

package.loaded['core.luatex-cn-core-textbox'] = textbox

--- 绘制数字（用于调试坐标显示）
-- @param num (number) 要绘制的数字
-- @param x (number) X 位置 (bp)
-- @param y (number) Y 位置 (bp)
-- @param scale (number) 缩放因子
-- @return (string) PDF 路径命令
local function draw_debug_number(num, x, y, scale)
    scale = scale or 0.7
    local str = tostring(num)
    local cmds = {}
    local digit_width = 3 * scale
    local digit_height = 5 * scale
    local spacing = 1.5 * scale

    -- 7段数字样式
    local segments = {
        [0] = {true, false, true, true, true, true, true},
        [1] = {false, false, false, false, true, false, true},
        [2] = {true, true, true, false, true, true, false},
        [3] = {true, true, true, false, true, false, true},
        [4] = {false, true, false, true, true, false, true},
        [5] = {true, true, true, true, false, false, true},
        [6] = {true, true, true, true, false, true, true},
        [7] = {true, false, false, false, true, false, true},
        [8] = {true, true, true, true, true, true, true},
        [9] = {true, true, true, true, true, false, true},
    }

    local digit_index = 0
    for i = 1, #str do
        local char = str:sub(i, i)
        local digit = tonumber(char)
        if digit ~= nil then
            local seg = segments[digit]
            if seg ~= nil then
                local dx = x + digit_index * (digit_width + spacing)
                local w_d, h_d, m = digit_width, digit_height, digit_height / 2

                if seg[1] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y + h_d, dx + w_d, y + h_d)) end
                if seg[2] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y + m, dx + w_d, y + m)) end
                if seg[3] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y, dx + w_d, y)) end
                if seg[4] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y + m, dx, y + h_d)) end
                if seg[5] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx + w_d, y + m, dx + w_d, y + h_d)) end
                if seg[6] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx, y, dx, y + m)) end
                if seg[7] then table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", dx + w_d, y, dx + w_d, y + m)) end
                digit_index = digit_index + 1
            end
        end
    end

    return table.concat(cmds, " "), digit_index * (digit_width + spacing)
end

--- 绘制浮动框调试标记（红色十字和坐标）- 相对定位版本
-- 使用 mode=0，坐标相对于当前位置，这样标记会跟随内容移动
-- @param item (table) 浮动盒子项 {x, y, ...}
-- @param box_height (number) 盒子高度 (sp)
-- @param shift (number) 盒子垂直偏移 (sp)
-- @return (node) PDF literal 节点
local function create_floating_debug_node_relative(item, box_height, shift)
    local sp_to_bp = 1 / 65536

    -- 调试节点插入在盒子之后，此时当前位置在盒子右边缘、基线位置
    -- 盒子的 shift 将内容向下移动了 shift 量
    -- 盒子顶部相对于基线的位置 = height - shift
    -- 需要向上移动到顶部
    local offset_x = 0  -- 已经在右边缘
    local offset_y = (box_height - shift) * sp_to_bp  -- 从基线移动到顶部

    -- 获取调试模块的度量单位设置
    local debug_mod = package.loaded['debug.luatex-cn-debug'] or _G.luatex_cn_debug
    local measure = (debug_mod and debug_mod.grid_measure) or "cm"

    -- 根据度量单位转换坐标
    local x_val, y_val
    if measure == "pt" then
        -- sp to pt: 1pt = 65536sp
        x_val = math.floor(item.x / 65536 + 0.5)
        y_val = math.floor(item.y / 65536 + 0.5)
    elseif measure == "mm" then
        -- sp to mm: 1mm ≈ 2.83465pt = 185771sp
        x_val = math.floor(item.x / 65536 / 2.83465 + 0.5)
        y_val = math.floor(item.y / 65536 / 2.83465 + 0.5)
    else
        -- sp to cm (default): 1cm ≈ 28.3465pt
        x_val = math.floor(item.x / 65536 / 28.3465 + 0.5)
        y_val = math.floor(item.y / 65536 / 28.3465 + 0.5)
    end

    local cmds = {}
    table.insert(cmds, "q")  -- 保存图形状态
    table.insert(cmds, "1 0 0 RG 0.8 w")  -- 红色，线宽 0.8

    -- 绘制红色十字标记（相对于当前位置）
    local cross_size = 4  -- bp
    local cx, cy = offset_x, offset_y
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S",
        cx - cross_size, cy, cx + cross_size, cy))
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S",
        cx, cy - cross_size, cx, cy + cross_size))

    -- 绘制红色坐标数字
    table.insert(cmds, "1 0 0 RG 0.5 w")  -- 稍细的线条用于数字

    -- X 坐标显示在十字标记右侧
    local x_num_cmds, x_width = draw_debug_number(x_val, cx + cross_size + 2, cy + 2, 0.8)
    table.insert(cmds, x_num_cmds)

    -- 绘制逗号分隔符
    local comma_x = cx + cross_size + 2 + x_width + 1
    local comma_y = cy + 2
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", comma_x, comma_y + 1, comma_x, comma_y + 2))
    table.insert(cmds, string.format("%.4f %.4f m %.4f %.4f l S", comma_x, comma_y + 1, comma_x - 0.5, comma_y - 1))

    local y_num_cmds, _ = draw_debug_number(y_val, comma_x + 2, cy + 2, 0.8)
    table.insert(cmds, y_num_cmds)

    table.insert(cmds, "Q")  -- 恢复图形状态

    -- 创建 PDF literal 节点
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local n = node.new(whatsit_id, pdf_literal_id)
    n.data = table.concat(cmds, " ")
    n.mode = 0  -- 相对坐标模式（跟随内容移动）

    return n
end

--- 定位并渲染浮动文本框
-- @param p_head (node) 页面列表头
-- @param item (table) 浮动盒子项 {box, x, y, page, ...}
-- @param params (table) 渲染参数
-- @return (node) 更新后的页面列表头
function textbox.render_floating_box(p_head, item, params)
    local curr = D.todirect(item.box)
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    -- Handle decoupled render_ctx or legacy params
    local page = params.page or params

    -- Get paper dimensions
    local splitpage_mod = _G.splitpage
    local full_paper_width = (_G.page and _G.page.paper_width and _G.page.paper_width > 0) and _G.page.paper_width or
        page.p_width or page.paper_width or page.width or 0
    local full_paper_height = (_G.page and _G.page.paper_height and _G.page.paper_height > 0) and _G.page.paper_height or
        page.p_height or page.paper_height or page.height or 0
    local logical_page_width = full_paper_width

    -- For split page: coordinates are relative to the logical page (half width)
    local split_page_offset = 0
    if splitpage_mod and splitpage_mod.enabled and splitpage_mod.target_width > 0 then
        logical_page_width = splitpage_mod.target_width
        -- For page 1 (right half), we need to offset content into the right half of physical page
        -- Split page will then apply -logical_width shift to make right half visible
        split_page_offset = logical_page_width
    end

    -- Get content area margins (geometry is 0, but splitpage adds these offsets during output)
    local m_top = (_G.page and _G.page.margin_top) or 0
    local m_left = (_G.page and _G.page.margin_left) or 0

    -- Position calculation:
    -- With geometry margins = 0, content origin is at paper edge (0, 0).
    -- But splitpage.output_pages adds margin offsets when shipping out the page.
    -- So the floating box (which is part of the content) will be shifted by (m_left, m_top).
    -- To compensate and keep the floating box at absolute paper coordinates,
    -- we SUBTRACT the margins from the position.
    --
    -- x is measured from the right edge of the logical page
    -- Position from logical page left = logical_page_width - x - box_width
    local position_from_logical_left = logical_page_width - item.x - w
    local rel_x = split_page_offset + position_from_logical_left - m_left

    -- For y: subtract m_top to compensate for the margin shift in splitpage output
    local rel_y = item.y - m_top

    -- Apply Kern & Shift
    local final_x = rel_x
    D.setfield(curr, "shift", rel_y + h)

    local k_pre = D.new(constants.KERN)
    D.setfield(k_pre, "kern", final_x)

    local k_post = D.new(constants.KERN)
    D.setfield(k_post, "kern", -(final_x + w))

    p_head = D.insert_before(p_head, p_head, k_pre)
    D.insert_after(p_head, k_pre, curr)
    D.insert_after(p_head, curr, k_post)

    -- If debug grid is enabled, draw coordinate marker at top-right corner
    -- Use mode=0 (relative to content) so marker only appears on the correct split page half
    local debug_mod = package.loaded['debug.luatex-cn-debug'] or _G.luatex_cn_debug
    if debug_mod and debug_mod.show_grid then
        -- Create debug marker that draws relative to box position
        -- Pass box height and shift value for correct positioning
        local box_shift = rel_y + h
        local debug_node = create_floating_debug_node_relative(item, h, box_shift)
        local debug_direct = D.todirect(debug_node)
        -- Insert debug marker right after the box (before k_post)
        D.insert_after(p_head, curr, debug_direct)
    end

    dbg.log(string.format(
        "[render] Floating Box at x=%.2fpt, y=%.2fpt (rel_x=%.2fpt, rel_y=%.2fpt)",
        item.x / 65536, item.y / 65536, rel_x / 65536, rel_y / 65536))
    return p_head
end

return textbox
