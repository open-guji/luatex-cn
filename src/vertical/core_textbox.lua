-- ============================================================================
-- core_textbox.lua - 文本框（GridTextbox）处理模块
-- ============================================================================
-- 文件名: core_textbox.lua (原 textbox.lua)
-- 层级: 协调层 (Core/Coordinator Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责处理"内嵌文本框"（GridTextbox）的竖排逻辑。其核心功能包括：
--   1. 接收 TeX 传递的盒子（hlist/vlist）
--   2. 将其视为一个"微型页面"，根据网格参数重新进行布局
--   3. 应用特殊的属性（ATTR_TEXTBOX_WIDTH/HEIGHT），使其能被外部布局识别
--   4. 处理缩进继承（从列表环境等继承 \leftskip）
--
-- 【术语对照 / Terminology】
--   process_inner_box   - 处理内嵌盒子（主入口函数）
--   GridTextbox         - 网格文本框（TeX 层的环境名称）
--   ATTR_TEXTBOX_*      - 文本框尺寸属性（宽度/高度，以网格数计）
--   distribute          - 分布模式（在列内均匀分布字符）
--
-- 【主要功能函数】
--   process_inner_box(box_num, params)
--      - box_num: TeX 盒子编号
--      - params: 包含高度、列数、网格宽高、对齐方式、分布模式等参数
--
-- 【注意事项】
--   • 文本框在外部布局中始终占用 1 列宽度（逻辑列），但内部可以有多个子列
--   • 如果 distribute=true，内部字符会均匀分布在可用的网格中
--   • 文本框的 baseline 处理需要配合 TeX 层的 \leavevmode 使用
--
-- ============================================================================

local constants = package.loaded['base_constants'] or require('base_constants')
local utils = package.loaded['base_utils'] or require('base_utils')
local D = node.direct

local textbox = {}

--- 将一个 TeX 盒子转化为竖排网格文本框
-- @param box_num (number) TeX 盒子寄存器编号
-- @param params (table) 配置参数
--    - n_cols (number): 内部子列数
--    - height (number): 文本框高度（以网格为单位）
--    - grid_width (string/number): 内部网格宽度
--    - grid_height (string/number): 内部网格高度
--    - box_align (string): 盒子内部对齐方式 ("top", "bottom", "fill")
--    - debug (boolean/string): 是否开启调试边框
--    - border (boolean/string): 是否开启显示边框
function textbox.process_inner_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    -- 1. 获取缩进及其它上下文环境
    local current_indent = 0
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

    -- 2. 准备子网格布局参数
    -- 解析列对齐方式 (例如 "right,left")
    local col_aligns = {}
    if params.column_aligns then
        local idx = 0
        for align in string.gmatch(params.column_aligns, '([^,]+)') do
            -- Trim whitespace
            align = align:gsub("^%s*(.-)%s*$", "%1")
            col_aligns[idx] = align
            idx = idx + 1
        end
    end

    -- 我们将文本框模拟为一个恰好等于其尺寸的"页面"
    local ba = params.box_align or "top"
    local sub_params = {
        grid_width = params.grid_width,
        grid_height = params.grid_height,
        col_limit = tonumber(params.height) or 1,
        page_columns = tonumber(params.n_cols) or 1,
        border_on = (params.border == "true" or params.border == true),
        debug_on = (params.debug == "true" or params.debug == true) or (_G.vertical and _G.vertical.debug and _G.vertical.debug.enabled),
        v_align = (ba == "bottom") and "bottom" or "top",
        distribute = (ba == "fill"),
        height = params.grid_height, -- 给定足够的高度
        column_aligns = col_aligns,
        is_textbox = true,
    }

    -- 3. 执行核心排版流水线
    -- 注意：我们需要使用全局 core 模块的 prepare_grid 函数
    -- 为了避免循环依赖，我们通过全局 _G.vertical 访问
    local vertical = _G.vertical
    if not vertical or not vertical.prepare_grid then
        utils.debug_log("[textbox] Error: vertical.prepare_grid not found")
        return
    end

    -- 临时保存并清空主文档的分页缓存
    local saved_pages = _G.vertical_pending_pages
    _G.vertical_pending_pages = {}

    utils.debug_log("--- textbox.process_inner_box: START (box=" .. box_num .. ", indent=" .. tostring(current_indent) .. ") ---")

    -- 调用三阶段流水线
    vertical.prepare_grid(box_num, sub_params)

    -- 获取渲染结果（应当只有 1 "页"）
    local res_box = _G.vertical_pending_pages[1]

    -- 恢复主文档分页缓存
    _G.vertical_pending_pages = saved_pages

    if res_box then
        -- 4. 设置关键属性，使外部布局能正确识别该块
        -- 外部布局中，文本框始终占用 1 个逻辑列宽
        node.set_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH, 1)
        node.set_attribute(res_box, constants.ATTR_TEXTBOX_HEIGHT, tonumber(params.height) or 1)
        
        -- 应用缩进属性，确保在下一列继续时保持正确位移
        if current_indent > 0 then
            node.set_attribute(res_box, constants.ATTR_INDENT, current_indent)
        end
        
        -- 将渲染好的盒子写回 TeX
        tex.box[box_num] = res_box
    end
end

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['core_textbox'] = textbox

return textbox
