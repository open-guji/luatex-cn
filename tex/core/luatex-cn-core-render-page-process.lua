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
-- render_page_process.lua - 节点处理子模块（从 render_page.lua 拆分）
-- ============================================================================
-- 文件名: luatex-cn-core-render-page-process.lua
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责单个页面中各节点的坐标赋值和渲染处理：
--   1. handle_glyph_node: 字形节点定位（xoffset/yoffset, 旋转, 缩放）
--   2. handle_block_node: 块级节点定位（kern + shift）
--   3. handle_debug_drawing: 调试网格绘制
--   4. process_page_nodes: 遍历页面所有节点并分发处理
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('luatex-cn-render-position')
local decorate_mod = package.loaded['decorate.luatex-cn-decorate'] or
    require('decorate.luatex-cn-decorate')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local helpers = package.loaded['core.luatex-cn-layout-grid-helpers'] or
    require('core.luatex-cn-layout-grid-helpers')
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')
local setting_stack = package.loaded['util.luatex-cn-setting-stack'] or
    require('util.luatex-cn-setting-stack')

local dbg = debug.get_debugger('render')

-- ============================================================================
-- Node Handling Functions
-- ============================================================================

-- Reusable template tables for calc_grid_position (created once per page in process_page_nodes)
-- glyph_dims: per-glyph dimensions (width, height, depth, char, font)
-- glyph_params: page-constant fields pre-filled, per-glyph fields overwritten each call
local glyph_dims = {}
local glyph_params = {}

-- 中横排组的渲染偏移缓存：组首前扫时为全组写入 {s, x, y}，组员处理到时
-- 取走即删（键是 direct 节点索引，会跨页复用，不能留存）
local tcy_render_cache = {}

--- clreq 挤压方向：把「缩短的字幅」还原成「字面该放在哪」。
--
-- 上下文相关挤压把标点的字面空白收回，缩短的字幅只用于列内排版算术；
-- 字面位置必须按**空白原本在哪一侧**还原：按原始满幅定位，再按始端收回量
-- 上移。于是收回末端空白时字面原地不动（后一个符号上移），收回始端空白时
-- 字面才向后贴紧被夹注的内容。若把收回量当作对称缩短，居中逻辑会让句号
-- 向上飘半个收回量、紧贴前字。
--
-- @param cell_height (number|nil) 排版用字幅（已扣收回量，sp）
-- @param y_sp (number) 字幅起点（sp）
-- @param squeeze_attr (number|nil) ATTR_PUNCT_SQUEEZE：1 + 总收回量千分比
-- @param head_attr (number|nil) ATTR_PUNCT_SQUEEZE_HEAD：1 + 始端收回量千分比
-- @param em (number|nil) 该字形的字号（sp）
-- @param pos (table|nil) layout_map 条目；自然模式下带 punct_squeeze_sp /
--   punct_head_sp（sp），是行内调整求解器算出的实际收回量，优先于属性——
--   属性只记 flatten 阶段按相邻上下文预判的那一份（设计 §4）
-- @return (number|nil, number) 定位用字幅（原始满幅）、定位用起点
local function punct_ink_placement(cell_height, y_sp, squeeze_attr, head_attr, em, pos)
    if type(cell_height) ~= "number" then return cell_height, y_sp end
    if pos and pos.punct_squeeze_sp then
        return cell_height + pos.punct_squeeze_sp,
               y_sp - (pos.punct_head_sp or 0)
    end
    if not (squeeze_attr and squeeze_attr > 1) then return cell_height, y_sp end
    if not em then return cell_height, y_sp end
    local head = (head_attr and head_attr > 1) and (head_attr - 1) / 1000 or 0
    return cell_height + (squeeze_attr - 1) / 1000 * em, y_sp - head * em
end

-- 辅助函数：处理单个字形的定位
local function handle_glyph_node(curr, p_head, pos, params, ctx)
    -- vertical_align now comes from ctx (read from _G.content or params in calculate_render_context)
    local vertical_align = ctx.vertical_align or "center"
    local d = D.getfield(curr, "depth") or 0
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    local v_scale = pos.v_scale or 1.0
    -- Per-glyph horizontal scale: squeeze when char is wider than border available width
    local h_scale = 1.0
    local avail_w = ctx.border_avail_width or 0
    if avail_w > 0 and w > avail_w then
        h_scale = avail_w / w
    end

    -- column_aligns is textbox-specific, still comes from params.visual
    local h_align = "center"
    local visual = params.visual
    if visual and visual.column_aligns and visual.column_aligns[pos.col] then
        h_align = visual.column_aligns[pos.col]
    end

    -- Per-glyph h_align override (e.g. footnote markers use right-align)
    local halign_attr = D.get_attribute(curr, constants.ATTR_HALIGN)
    if halign_attr and halign_attr > 0 then
        if halign_attr == 1 then h_align = "left"
        elseif halign_attr == 3 then h_align = "right"
        end
    end

    -- Fill per-glyph fields into reusable templates (page-constant fields set in process_page_nodes)
    glyph_dims.width = w
    glyph_dims.height = h * v_scale
    glyph_dims.depth = d * v_scale
    glyph_dims.char = D.getfield(curr, "char")
    glyph_dims.font = D.getfield(curr, "font")
    glyph_dims.v_scale = v_scale
    -- em 框居中（固定基线）只用于普通文字；标点依赖墨迹居中把圈点放在
    -- 格中央，旋转字形的旋转中心也按墨迹计算，两者保持旧行为
    glyph_dims.em_center = (D.get_attribute(curr, constants.ATTR_PUNCT_TYPE) == nil)
        and (D.get_attribute(curr, constants.ATTR_VERT_ROTATE) ~= 1)

    -- P1: read style fields from style_registry, not layout_map
    local glyph_style_id = D.get_attribute(curr, constants.ATTR_STYLE_REG_ID)
    local glyph_style = glyph_style_id and style_registry.get(glyph_style_id)

    glyph_params.v_align = vertical_align
    glyph_params.h_align = h_align
    glyph_params.sub_col = pos.sub_col
    glyph_params.textflow_align = (glyph_style and glyph_style.textflow_align) or ctx.textflow_align
    glyph_params.cell_width = pos.cell_width

    local fdata = font.getfont(glyph_dims.font)
    local ink_h, ink_y = punct_ink_placement(
        pos.cell_height, pos.y_sp,
        D.get_attribute(curr, constants.ATTR_PUNCT_SQUEEZE),
        D.get_attribute(curr, constants.ATTR_PUNCT_SQUEEZE_HEAD),
        fdata and fdata.size, pos)
    glyph_params.cell_height = ink_h
    glyph_params.y_sp = ink_y
    glyph_params.band_y_offset_sp = pos.band_y_offset_sp or 0
    -- RTL pos.x from layout_map (nil triggers legacy fallback in calc_grid_position)
    glyph_params.pos_x = pos.x
    -- Per-entry col_width from layout_map (set for variable-width columns: Free Mode, TitlePage)
    glyph_params.pos_col_width = pos.col_width
    -- Per-entry content_width override (sum of col_widths for variable-width pages)
    if pos.content_width then
        glyph_params.content_width = pos.content_width
    end

    local final_x, final_y = text_position.calc_grid_position(pos.col, glyph_dims, glyph_params)
    if glyph_style then
        if glyph_style.xshift then
            local xs = constants.resolve_dimen(glyph_style.xshift, ctx.body_font_size or 655360)
            if xs then final_x = final_x - xs end
        end
        if glyph_style.yshift then
            local ys = constants.resolve_dimen(glyph_style.yshift, ctx.body_font_size or 655360)
            if ys then final_y = final_y - ys end
        end
    end

    -- Check if glyph needs vertical rotation (font lacks vertical form)
    local needs_rotate = D.get_attribute(curr, constants.ATTR_VERT_ROTATE) == 1

    -- 连排破折号：把墨迹沿列方向拉满整个字幅。字体给 ︱ 的墨迹通常够不到
    -- 字幅两端（TW-Kai 约 0.9 em），连排时两段之间就露出断口；layout 已把
    -- 单元内部字距归零，字幅之间严丝合缝，缺的只是这一段墨迹。只缩放列方向，
    -- 横向不动，笔画粗细仍是字体自己的。
    -- @return (number|nil) 缩放系数；不需要拉伸时为 nil
    local dash_scale = nil
    if D.get_attribute(curr, constants.ATTR_DASH_RUN) == 1 then
        local fsize = fdata and fdata.size
        local target = pos.cell_height
        if fsize and fsize > 0 and type(target) == "number" and target > 0 then
            local a, b
            if needs_rotate then
                a, b = helpers.glyph_ink_hspan(curr)   -- 旋转后横向跨度即列方向
            else
                b, a = helpers.glyph_ink_span(curr)    -- top, bottom → a=bottom
            end
            local ink = (b - a) * fsize
            if ink > 0 and target > ink then
                dash_scale = target / ink
            end
        end
    end

    local sideways = D.get_attribute(curr, constants.ATTR_SIDEWAYS) == 1
    local tcy_val = D.get_attribute(curr, constants.ATTR_TCY)

    if tcy_val and tcy_val > 0 then
        -- 中横排（\中横排，clreq 直排中西混排之「横排入一个字格」）。
        -- layout 已让整组只占组首那一个字幅（组内字幅/字距归零），这里把
        -- 组员横排进这一格：以组首的格与列心为锚，逐字沿横向排开；总宽
        -- 超过 1em 时只做横向压缩（字高与笔画竖向粗细不变，同 JIS 縦中横
        -- 的通行做法），竖向按字体升降部把基线居中于格。组首一次前扫算出
        -- 全组偏移（组员的 layout 位置是列方向的零宽占位，不可用）。
        local info = tcy_render_cache[curr]
        if not info then
            local run, run_w = { curr }, w
            local nx = D.getnext(curr)
            while nx do
                local id = D.getid(nx)
                if id == constants.GLYPH then
                    if D.get_attribute(nx, constants.ATTR_TCY) == tcy_val then
                        run[#run + 1] = nx
                        run_w = run_w + (D.getfield(nx, "width") or 0)
                    else
                        break
                    end
                elseif id == constants.HLIST or id == constants.VLIST then
                    break
                end
                nx = D.getnext(nx)
            end
            local fsize = (fdata and fdata.size) or 655360
            local s = (run_w > fsize and run_w > 0) and (fsize / run_w) or 1
            local pms = fdata and fdata.parameters
            local asc = (pms and pms.ascender) or math.floor(fsize * 0.8)
            local desc = math.abs((pms and pms.descender)
                or math.floor(fsize * 0.2))
            local cell = (type(pos.cell_height) == "number"
                and pos.cell_height > 0) and pos.cell_height or fsize
            local top = -(pos.y_sp + (pos.band_y_offset_sp or 0)) - ctx.shift_y
            local base_y = top - cell / 2 - (asc - desc) / 2
            local gx = final_x + w / 2 - (run_w * s) / 2
            for _, g in ipairs(run) do
                tcy_render_cache[g] = { s = s, x = gx, y = base_y }
                gx = gx + (D.getfield(g, "width") or 0) * s
            end
            info = tcy_render_cache[curr]
        end
        tcy_render_cache[curr] = nil
        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)
        local n_start = utils.create_pdf_literal(string.format(
            "q %.4f 0 0 1 %.4f %.4f cm", info.s,
            info.x * utils.sp_to_bp, info.y * utils.sp_to_bp))
        local n_end = utils.create_pdf_literal(
            utils.create_graphics_state_end())
        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    elseif sideways then
        -- 横置西文（\横置，clreq 直排中西混排之「顺时针旋转 90°」）。
        -- 与 needs_rotate（缺字旋转）不同：那是单字绕墨心旋转、字幅仍一格；
        -- 这里整串字母连排成词（字幅 = advance、串内字距 0），各字形必须
        -- 共用同一条竖直基线——锚点用字体级的升降部（按逐字 h/d 或墨心
        -- 会左右摇摆）。矩阵 [0 −1 1 0 e f]：(x,y) → (y+e, −x+f)，字形
        -- 基线原点 → (e, f)；advance 方向转为沿列向下，升部指向列右。
        -- f 锚在字幅顶（cell_height = advance，字幅顶正是本字基线起点）；
        -- e 令 [−desc, +asc] 的横向跨度居中于列。
        local sp2bp = utils.sp_to_bp
        local fsize = (fdata and fdata.size) or 655360
        local pms = fdata and fdata.parameters
        local asc = (pms and pms.ascender) or math.floor(fsize * 0.8)
        local desc = math.abs((pms and pms.descender) or math.floor(fsize * 0.2))
        local col_center = final_x + w / 2
        local e = (col_center - (asc - desc) / 2) * sp2bp
        local f = (-(pos.y_sp + (pos.band_y_offset_sp or 0)) - ctx.shift_y)
            * sp2bp
        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)
        local n_start = utils.create_pdf_literal(
            string.format("q 0 -1 1 0 %.4f %.4f cm", e, f))
        local n_end = utils.create_pdf_literal(
            utils.create_graphics_state_end())
        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    elseif needs_rotate then
        -- Rotate 90° CW and translate glyph to its grid position.
        -- The glyph is at text-space origin (xoffset=yoffset=0).
        -- Mode 0 pdf_literal wraps with T(node)/T(-node), so our matrix
        -- operates in node-relative space.
        -- We need matrix M = [0 -1 1 0 e f] such that glyph center
        -- (gc_x, gc_y) maps to intended center (fx+gc_x, fy+gc_y):
        --   e = fx + gc_x - gc_y
        --   f = fy + gc_x + gc_y
        local sp2bp = utils.sp_to_bp
        local fx = final_x * sp2bp
        local fy = final_y * sp2bp
        local gc_x = (w / 2) * sp2bp           -- glyph center x (from reference point)
        local gc_y = ((h - d) / 2) * sp2bp     -- glyph center y (from reference point)

        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)

        -- 连排破折号的旋转回退：沿字形自身 x 轴（旋转后即列方向）拉伸墨迹。
        -- 矩阵 [0 −s 1 0 e f] 把 (x,y) 映到 (y+e, −s·x+f)，笔画粗细（字形 y
        -- 方向）不受影响；绕墨迹中心 cx 缩放，位置与不拉伸时一致。
        local s = 1
        local cx = gc_x
        if dash_scale then
            local ix1, ix2 = helpers.glyph_ink_hspan(curr)
            s = dash_scale
            cx = (ix1 + ix2) / 2 * ((fdata and fdata.size) or 0) * sp2bp
        end

        local e = fx + gc_x - gc_y
        local f = fy + gc_y + s * cx
        local literal_str = string.format(
            "q 0 %.4f 1 0 %.4f %.4f cm", -s, e, f
        )
        local n_start = utils.create_pdf_literal(literal_str)
        local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())

        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    elseif dash_scale then
        -- 竖排形 ︱：只沿 y 拉伸，绕墨迹中心缩放 —— y' = s·y + cy·(1−s)，
        -- 字面中心不动（标点本就按墨迹居中放进格里）
        local top, bot = helpers.glyph_ink_span(curr)
        local cy = (top + bot) / 2 * ((fdata and fdata.size) or 0)
        local sp2bp = utils.sp_to_bp
        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)
        local literal_str = string.format("q 1 0 0 %.4f %.4f %.4f cm",
            dash_scale, final_x * sp2bp,
            (final_y + cy * (1 - dash_scale)) * sp2bp)
        local n_start = utils.create_pdf_literal(literal_str)
        local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())
        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    elseif v_scale == 1.0 and h_scale == 1.0 then
        D.setfield(curr, "xoffset", final_x)
        D.setfield(curr, "yoffset", final_y)
    else
        -- Squeeze using PDF matrix: [h_scale 0 0 v_scale x y]
        -- When h_scale < 1, shift x to center the squeezed glyph within its cell
        local h_center_offset = (h_scale < 1.0) and (w * (1.0 - h_scale) / 2) or 0
        local x_bp = (final_x + h_center_offset) * utils.sp_to_bp
        local y_bp = final_y * utils.sp_to_bp
        D.setfield(curr, "xoffset", 0)
        D.setfield(curr, "yoffset", 0)

        local literal_str = string.format("q %.4f 0 0 %.4f %.4f %.4f cm", h_scale, v_scale, x_bp, y_bp)
        local n_start = utils.create_pdf_literal(literal_str)
        local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())

        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, curr, n_end)
    end

    -- Insert negative kern to keep baseline position correct for next nodes
    local k = D.new(constants.KERN)
    D.setfield(k, "kern", -w)
    D.insert_after(p_head, curr, k)

    -- Apply font_color from style_registry (P1: read style directly, not from layout_map)
    -- Skip wrapping when font_color matches the page-level default (avoids redundant
    -- q/Q pairs that introduce ET/cm/BT coordinate transforms and float precision loss)
    local style_id = D.get_attribute(curr, constants.ATTR_STYLE_REG_ID)
    local font_color = style_id and style_registry.get_font_color(style_id)
    if font_color and font_color ~= "" then
        local rgb_str = utils.normalize_rgb(font_color)
        -- Only wrap if color differs from page default (both must be non-nil and different)
        if rgb_str and ctx.text_rgb_str and rgb_str ~= ctx.text_rgb_str then
            -- Different from page default: wrap with q/Q for color isolation
            local color_cmd = utils.create_color_literal(rgb_str, false) -- false = fill color (rg)
            local color_push = utils.create_pdf_literal("q " .. color_cmd)
            local color_pop = utils.create_pdf_literal("Q")
            p_head = D.insert_before(p_head, curr, color_push)
            D.insert_after(p_head, k, color_pop) -- Insert after the kern
        elseif not ctx.text_rgb_str and rgb_str then
            -- No page-level color but char has color: must wrap
            local color_cmd = utils.create_color_literal(rgb_str, false)
            local color_push = utils.create_pdf_literal("q " .. color_cmd)
            local color_pop = utils.create_pdf_literal("Q")
            p_head = D.insert_before(p_head, curr, color_push)
            D.insert_after(p_head, k, color_pop)
        end
        -- When rgb_str == ctx.text_rgb_str: page-level rg already set, no wrapping needed
    end

    return p_head
end

-- 辅助函数：处理 HLIST/VLIST（块）的定位
local function handle_block_node(curr, p_head, pos, ctx)
    local h = D.getfield(curr, "height") or 0
    local w = D.getfield(curr, "width") or 0

    local col_width = text_position.get_column_width(pos.col, ctx.col_geom)
    local block_width_sp = (pos.width or 1) * col_width

    local final_x
    if pos.x and (glyph_params.content_width or 0) > 0 then
        -- RTL pos.x path: pos.x is right edge of block, block extends left by block_width_sp
        local shift_x_base = glyph_params.shift_x_base or ctx.shift_x
        final_x = shift_x_base + glyph_params.content_width - pos.x - block_width_sp + ctx.half_thickness
    else
        -- Legacy RTL path
        local rtl_col_left = ctx.p_total_cols - (pos.col + (pos.width or 1))
        final_x = text_position.get_column_x(rtl_col_left, ctx.col_geom)
            + ctx.half_thickness + ctx.shift_x
    end

    -- Sub-column support: textbox inside textflow uses sub-column positioning
    local sub_col = pos.sub_col
    if sub_col and sub_col > 0 then
        -- Recompute base_x using column width (not block_width_sp) to match glyph path
        local base_x
        if pos.x and (glyph_params.content_width or 0) > 0 then
            local shift_x_base = glyph_params.shift_x_base or ctx.shift_x
            base_x = shift_x_base + glyph_params.content_width - pos.x - col_width + ctx.half_thickness
        else
            local rtl_col = ctx.p_total_cols - 1 - pos.col
            base_x = text_position.get_column_x(rtl_col, ctx.col_geom)
                + ctx.half_thickness + ctx.shift_x
        end
        -- Verified via node inspection: textbox vbox has margin_left = 0,
        -- i.e. the inner content (char) sits at vbox.left. So the textbox
        -- position needs to match calculate_sub_column_x_offset's return
        -- value directly (which is where small chars are placed).
        local half_width = col_width / 2
        local inner_padding = half_width * 0.05  -- matches calculate_sub_column_x_offset
        local tb_w_attr = D.get_attribute(curr, constants.ATTR_TEXTBOX_WIDTH)
        local tb_grid_w = D.get_attribute(curr, constants.ATTR_TEXTBOX_GRID_WIDTH)
        local inner_grid_total = (tb_w_attr and tb_w_attr > 0 and tb_grid_w and tb_grid_w > 0)
            and (tb_w_attr * tb_grid_w) or w
        if sub_col == 1 then
            -- sub_col=1 + inward = left align in sub-col: vbox.left at column_center + inner_padding
            final_x = base_x + half_width + inner_padding
        else
            -- sub_col=2 + inward = right align in sub-col: content.right at column_center - inner_padding
            -- content.right = vbox.left + inner_grid_total (since margin_left=0)
            final_x = base_x + half_width - inner_grid_total - inner_padding
        end
    else
        -- Center TextBox grid area within outer column.
        local tb_w_attr = D.get_attribute(curr, constants.ATTR_TEXTBOX_WIDTH)
        if tb_w_attr and tb_w_attr > 0 then
            local tb_content_width = block_width_sp
            local tb_grid_w = D.get_attribute(curr, constants.ATTR_TEXTBOX_GRID_WIDTH)
            if tb_grid_w and tb_grid_w > 0 and tb_grid_w < col_width then
                local inner_grid_total = tb_w_attr * tb_grid_w
                local centering = math.floor((tb_content_width - inner_grid_total) / 2)
                final_x = final_x + centering
            elseif w < tb_content_width then
                local centering = math.floor((tb_content_width - w) / 2)
                final_x = final_x + centering
            end
        end
    end

    -- Apply xshift from sidenote metadata (positive = rightward in page coordinates)
    if pos.xshift and pos.xshift ~= 0 then
        final_x = final_x + pos.xshift
    end

    local final_y_top = -pos.y_sp - (pos.band_y_offset_sp or 0) - ctx.shift_y
    D.setfield(curr, "shift", -final_y_top + h)

    local k_pre = D.new(constants.KERN)
    D.setfield(k_pre, "kern", final_x)

    local k_post = D.new(constants.KERN)
    D.setfield(k_post, "kern", -(final_x + w))

    p_head = D.insert_before(p_head, curr, k_pre)
    D.insert_after(p_head, curr, k_post)
    return p_head
end

-- 辅助函数：绘制调试网格/框
-- 通过 setting_stack 中的 debug 标志控制
local function handle_debug_drawing(curr, p_head, pos, ctx)
    local show_me = setting_stack.get("debug")

    local color_str = pos.is_block and "1 0 0 RG" or "0 0 1 RG"

    if show_me then
        local col_widths = glyph_params.col_widths
        local tx_sp, tw_sp
        -- X: compute column left edge (LTR) and width
        if glyph_params.content_width and glyph_params.content_width > 0 and pos.x then
            -- RTL pos.x path: convert to LTR
            local shift_x_base = glyph_params.shift_x_base or ctx.shift_x
            if col_widths and #col_widths > 0 then
                tw_sp = text_position.get_column_width_var(pos.col, col_widths)
            else
                tw_sp = text_position.get_column_width(pos.col, ctx.col_geom)
            end
            tx_sp = shift_x_base + glyph_params.content_width - pos.x - tw_sp + (ctx.half_thickness or 0)
            if col_widths and #col_widths > 0 then
                local sp_bottom = glyph_params.col_spacing_bottom and glyph_params.col_spacing_bottom[pos.col + 1] or 0
                local sp_top = glyph_params.col_spacing_top and glyph_params.col_spacing_top[pos.col + 1] or 0
                if sp_bottom > 0 or sp_top > 0 then
                    tx_sp = tx_sp + sp_bottom
                    tw_sp = tw_sp - sp_bottom - sp_top
                end
            end
        elseif col_widths and #col_widths > 0 then
            -- Legacy variable-width columns
            local total_cols = ctx.p_total_cols
            local rtl_col = total_cols - 1 - pos.col
            tx_sp = text_position.get_column_x_var(rtl_col, col_widths, total_cols)
                + (ctx.half_thickness or 0) + (ctx.shift_x or 0)
            tw_sp = text_position.get_column_width_var(pos.col, col_widths)
            local sp_bottom = glyph_params.col_spacing_bottom and glyph_params.col_spacing_bottom[pos.col + 1] or 0
            local sp_top = glyph_params.col_spacing_top and glyph_params.col_spacing_top[pos.col + 1] or 0
            if sp_bottom > 0 or sp_top > 0 then
                tx_sp = tx_sp + sp_bottom
                tw_sp = tw_sp - sp_bottom - sp_top
            end
        else
            -- Legacy uniform-width columns
            _, tx_sp = text_position.calculate_rtl_position(pos.col, ctx.p_total_cols, ctx.col_geom,
                ctx.half_thickness, ctx.shift_x)
            tw_sp = text_position.get_column_width(pos.col, ctx.col_geom)
        end
        -- P2: pos.y = y_sp + band_y_offset_sp + shift_y (Y has no p_total_cols issue)
        local ty_sp = -(pos.y)
        local th_sp = -(pos.cell_height or ctx.grid_height)

        if pos.sub_col and pos.sub_col > 0 then
            tw_sp = ctx.col_geom.grid_width / 2
            if pos.sub_col == 1 then
                tx_sp = tx_sp + tw_sp
            end
        end

        if pos.is_block then
            tw_sp = pos.width * ctx.col_geom.grid_width
            th_sp = -pos.height * ctx.grid_height
        end
        return utils.draw_debug_rect(p_head, curr, tx_sp, ty_sp, tw_sp, th_sp, color_str)
    end
    return p_head
end

-- 辅助函数：处理单个页面的所有节点
local function process_page_nodes(p_head, layout_map, params, ctx)
    local curr = p_head
    -- Initialize last_font_id with current fallback font
    ctx.last_font_id = ctx.last_font_id or params.font_id or font.current()
    -- Initialize line mark collection for this page
    ctx.line_mark_entries = ctx.line_mark_entries or {}

    -- Initialize page-constant fields in glyph_params template (per-glyph fields set in handle_glyph_node)
    glyph_params.total_cols = ctx.p_total_cols
    glyph_params.shift_x = ctx.shift_x
    glyph_params.shift_y = ctx.shift_y
    glyph_params.half_thickness = ctx.half_thickness
    glyph_params.col_geom = ctx.col_geom
    glyph_params.body_font_size = ctx.body_font_size
    -- P2: col_widths from col_widths_sp (Free Mode / TitlePage \行[width=...])
    -- TextBox has its own grid_width; never use outer content's col_widths
    if ctx.is_textbox then
        glyph_params.col_widths = nil
    else
        glyph_params.col_widths = ctx.page_col_widths_sp
    end
    -- RTL pos.x support: content_width and shift_x_base for coordinate conversion.
    -- All pages (uniform, Free Mode, TitlePage) use pos_x path.
    glyph_params.content_width = ctx.content_width
    glyph_params.shift_x_base = ctx.shift_x_base
    -- Column spacing for glyph offset within columns that have spacing
    glyph_params.col_spacing_top = ctx.page_col_spacing_top_sp
    glyph_params.col_spacing_bottom = ctx.page_col_spacing_bottom_sp

    while curr do
        local next_curr = D.getnext(curr)
        local id = D.getid(curr)

        if id == constants.GLYPH or id == constants.HLIST or id == constants.VLIST then
            local pos = layout_map[curr]
            if pos then
                if not pos.col or pos.col < 0 then
                    dbg.log(string.format("  [render] SKIP Node=%s ID=%d (invalid col=%s)", tostring(curr),
                        id, tostring(pos.col)))
                else
                    if id == constants.GLYPH then
                        local dec_id = D.get_attribute(curr, constants.ATTR_DECORATE_ID)
                        if dec_id and dec_id > 0 then
                            -- Dispatch by decoration type
                            local dec_reg = _G.decorate_registry and _G.decorate_registry[dec_id]
                            if dec_reg and dec_reg.type == "side_text" then
                                p_head = decorate_mod.handle_side_text_node(curr, p_head, pos, params, ctx, dec_id)
                            else
                                p_head = decorate_mod.handle_node(curr, p_head, pos, params, ctx, dec_id)
                            end
                            -- Remove the original marker node to prevent ghost rendering at (0,0)
                            p_head = D.remove(p_head, curr)
                            node.flush_node(D.tonode(curr))
                        else
                            -- Track the font from regular glyphs for decoration fallback
                            ctx.last_font_id = D.getfield(curr, "font")
                            p_head = handle_glyph_node(curr, p_head, pos, params, ctx)
                            p_head = handle_debug_drawing(curr, p_head, pos, ctx)
                            -- Collect line mark entries for batch rendering
                            if pos.line_mark_id then
                                -- Always use glyph's actual positioned center
                                -- (handles Free Mode, variable-width columns, sub-columns, etc.)
                                local gw = D.getfield(curr, "width") or 0
                                local gx = D.getfield(curr, "xoffset") or 0
                                local x_center = gx + gw / 2
                                -- P1: read font_size from style_registry, not layout_map
                                local lm_style_id = D.get_attribute(curr, constants.ATTR_STYLE_REG_ID)
                                local lm_font_size = lm_style_id and style_registry.get_font_size(lm_style_id)
                                ctx.line_mark_entries[#ctx.line_mark_entries + 1] =
                                    helpers.create_linemark_entry({
                                        group_id = pos.line_mark_id,
                                        col = pos.col,
                                        y_sp = pos.y_sp,
                                        cell_height = pos.cell_height,
                                        font_size = lm_font_size,
                                        sub_col = pos.sub_col,
                                        x_center_sp = x_center,
                                    })
                            end
                        end
                    else
                        p_head = handle_block_node(curr, p_head, pos, ctx)
                        p_head = handle_debug_drawing(curr, p_head, pos, ctx)
                    end
                end
            else
                -- CRITICAL DEBUG: If it has Jiazhu attribute but no pos, it's a bug!
                if setting_stack.get("debug") then
                    local has_jiazhu = (D.get_attribute(curr, constants.ATTR_JIAZHU) == 1)
                    if has_jiazhu then
                        dbg.log(string.format("  [render] DISCARDED JIAZHU NODE=%s (not in layout_map!) char=%s",
                            tostring(curr), (id == constants.GLYPH and tostring(D.getfield(curr, "char")) or "N/A")))
                    end
                end
            end
        elseif id == constants.GLUE then
            local pos = layout_map[curr]
            if pos and pos.col and pos.col >= 0 then
                -- This is a positioned space (user glue with width)
                -- Zero out the natural glue width and insert kern for positioning
                local glue_width = D.getfield(curr, "width") or 0
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)

                -- Calculate grid position via calc_grid_position (same RTL→LTR as glyph)
                local glue_dims = { width = glue_width, height = 0, depth = 0 }
                local glue_p = {
                    total_cols = ctx.p_total_cols,
                    shift_x = ctx.shift_x,
                    shift_y = ctx.shift_y,
                    half_thickness = ctx.half_thickness,
                    col_geom = ctx.col_geom,
                    h_align = "left",
                    v_align = "top",
                    y_sp = pos.y_sp,
                    band_y_offset_sp = pos.band_y_offset_sp or 0,
                    pos_x = pos.x,
                    pos_col_width = pos.col_width,
                    content_width = pos.content_width or glyph_params.content_width,
                    shift_x_base = glyph_params.shift_x_base,
                    col_widths = glyph_params.col_widths,
                }
                local final_x, final_y = text_position.calc_grid_position(pos.col, glue_dims, glue_p)

                -- Insert kern to move to correct position, then kern back
                local k_pre = D.new(constants.KERN)
                D.setfield(k_pre, "kern", final_x)
                local k_post = D.new(constants.KERN)
                D.setfield(k_post, "kern", -final_x)

                p_head = D.insert_before(p_head, curr, k_pre)
                D.insert_after(p_head, curr, k_post)

                dbg.log(string.format("  [render] GLUE (space) [c:%d, y_sp:%.0f]", pos.col, pos.y_sp or 0))
                p_head = handle_debug_drawing(curr, p_head, pos, ctx)
            else
                -- Not positioned - zero out (baseline/lineskip glue)
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)
            end
        elseif id == constants.KERN then
            local subtype = D.getfield(curr, "subtype")
            if subtype ~= 1 then
                D.setfield(curr, "kern", 0)
            end
        elseif id == constants.WHATSIT then
            local uid = D.getfield(curr, "user_id")
            if uid == constants.SIDENOTE_USER_ID or uid == constants.FLOATING_TEXTBOX_USER_ID then
                p_head = D.remove(p_head, curr)
                node.flush_node(D.tonode(curr))
            end
        end
        curr = next_curr
    end

    return p_head
end

-- ============================================================================
-- Module Export
-- ============================================================================

local M = {
    handle_glyph_node = handle_glyph_node,
    handle_block_node = handle_block_node,
    handle_debug_drawing = handle_debug_drawing,
    handle_decorate_node = decorate_mod.handle_node,
    process_page_nodes = process_page_nodes,
    -- 纯函数，供单元测试直接调用
    punct_ink_placement = punct_ink_placement,
}

package.loaded['core.luatex-cn-core-render-page-process'] = M
return M
