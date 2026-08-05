-- Unit tests for core.luatex-cn-layout-grid (smoke tests)
-- The full calculate_grid_positions function has many dependencies,
-- so we test _internal helpers that are more isolated.
local test_utils = require("test.test_utils")

-- Mock hooks module
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}
_G.core.hooks.is_reserved_column = function(col, interval)
    return col % (interval + 1) == interval
end
package.loaded['core.luatex-cn-hooks'] = {
    is_reserved_column = _G.core.hooks.is_reserved_column,
    get_plugins = function() return {} end,
}

-- Mock textflow module
package.loaded['core.luatex-cn-textflow'] = package.loaded['core.luatex-cn-textflow'] or {
    calculate_sub_column_x_offset = function(base_x) return base_x end,
}

local layout_grid = require("core.luatex-cn-layout-grid")
local constants = require("core.luatex-cn-constants")
local D = node.direct

-- Helper: create a minimal ctx for penalty break tests that call wrap_to_next_column
local function make_penalty_ctx(overrides)
    local ctx = {
        cur_row = 3,
        cur_col = 0,
        cur_page = 1,
        cur_y_sp = 65536 * 60,
        page_has_content = true,
        cur_column_indent = 0,
        occupancy = {},
        just_wrapped_column = false,
        col_widths_sp = {},
        banxin_registry = {},
        p_cols = 10,
        n_bands = 1,
        params = { banxin_on = false },
    }
    if overrides then
        for k, v in pairs(overrides) do ctx[k] = v end
    end
    _G.page = _G.page or {}
    _G.content = _G.content or {}
    return ctx
end

-- ============================================================================
-- Module loads successfully
-- ============================================================================

test_utils.run_test("layout_grid: module loads", function()
    test_utils.assert_type(layout_grid, "table")
    test_utils.assert_type(layout_grid.calculate_grid_positions, "function")
end)

test_utils.run_test("layout_grid: _internal exported", function()
    test_utils.assert_type(layout_grid._internal, "table")
end)

-- ============================================================================
-- _internal.accumulate_spacing
-- ============================================================================

test_utils.run_test("accumulate_spacing: single glue", function()
    local glue = D.new(constants.GLUE)
    D.setfield(glue, "width", 65536 * 10)
    local total, next_node = layout_grid._internal.accumulate_spacing(glue)
    test_utils.assert_eq(total, 65536 * 10)
end)

test_utils.run_test("accumulate_spacing: glue followed by glyph", function()
    local glue = D.new(constants.GLUE)
    D.setfield(glue, "width", 65536 * 5)
    local glyph = D.new(constants.GLYPH)
    D.setfield(glyph, "char", 0x4E00)
    D.setlink(glue, glyph)
    local total, next_node = layout_grid._internal.accumulate_spacing(glue)
    test_utils.assert_eq(total, 65536 * 5)
    test_utils.assert_eq(next_node, glyph)
end)

test_utils.run_test("accumulate_spacing: consecutive glues", function()
    local g1 = D.new(constants.GLUE)
    D.setfield(g1, "width", 65536 * 3)
    local g2 = D.new(constants.GLUE)
    D.setfield(g2, "width", 65536 * 7)
    D.setlink(g1, g2)
    local total, next_node = layout_grid._internal.accumulate_spacing(g1)
    test_utils.assert_eq(total, 65536 * 10)
end)

test_utils.run_test("accumulate_spacing: kern node", function()
    local kern = D.new(constants.KERN)
    D.setfield(kern, "kern", 65536 * 2)
    local total, next_node = layout_grid._internal.accumulate_spacing(kern)
    test_utils.assert_eq(total, 65536 * 2)
end)

-- ============================================================================
-- _internal.handle_penalty_breaks (smoke test)
-- ============================================================================

test_utils.run_test("handle_penalty_breaks: non-break penalty returns false", function()
    local ctx = {
        cur_row = 3,
        cur_col = 0,
        cur_page = 1,
        cur_y_sp = 0,
        page_has_content = true,
        cur_column_indent = 0,
    }
    local flush = function() end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", 0)
    local handled = layout_grid._internal.handle_penalty_breaks(
        0, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, false)
end)

test_utils.run_test("handle_penalty_breaks: PENALTY_FORCE_COLUMN handled", function()
    local ctx = make_penalty_ctx()
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_FORCE_COLUMN)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_FORCE_COLUMN, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
end)

test_utils.run_test("handle_penalty_breaks: PENALTY_TAITOU sets taitou scope", function()
    local ctx = make_penalty_ctx()
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_TAITOU)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_TAITOU, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
    -- PENALTY_TAITOU should record the taitou target column
    test_utils.assert_eq(ctx.taitou_col, ctx.cur_col)
    test_utils.assert_eq(ctx.taitou_page, ctx.cur_page)
end)

test_utils.run_test("handle_penalty_breaks: PENALTY_FORCE_COLUMN does NOT set taitou scope", function()
    local ctx = make_penalty_ctx()
    local flush = function() end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_FORCE_COLUMN)
    layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_FORCE_COLUMN, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    -- PENALTY_FORCE_COLUMN should NOT touch taitou scope
    test_utils.assert_eq(ctx.taitou_col, nil)
    test_utils.assert_eq(ctx.taitou_page, nil)
end)

-- ============================================================================
-- wrap_to_next_column: taitou scope preserved for resolve_node_indent
-- ============================================================================

test_utils.run_test("wrap_to_next_column: preserves taitou scope for outside_taitou check", function()
    local ctx = make_penalty_ctx({ cur_col = 2, taitou_col = 2, taitou_page = 1 })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    -- Taitou scope is preserved so resolve_node_indent can detect "outside scope"
    test_utils.assert_eq(ctx.taitou_col, 2)
    test_utils.assert_eq(ctx.taitou_page, 1)
end)

test_utils.run_test("wrap_to_next_column: negative indent reset to 0", function()
    local ctx = make_penalty_ctx({ cur_col = 2, cur_column_indent = -1 })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    -- Negative indent (taitou) should be reset to 0 on column wrap
    test_utils.assert_eq(ctx.cur_column_indent, 0)
end)

-- ============================================================================
-- PENALTY_DIGITAL_NEWLINE: always wraps even on empty column (cur_row == 0)
-- ============================================================================

test_utils.run_test("handle_penalty_breaks: PENALTY_DIGITAL_NEWLINE wraps on non-empty column", function()
    local ctx = make_penalty_ctx({ cur_row = 3 })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_DIGITAL_NEWLINE)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_DIGITAL_NEWLINE, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
end)

test_utils.run_test("handle_penalty_breaks: PENALTY_DIGITAL_NEWLINE wraps on EMPTY column (cur_row=0)", function()
    -- This is the key difference from PENALTY_FORCE_COLUMN:
    -- DIGITAL_NEWLINE always wraps, even when cur_row == 0 (empty column)
    local ctx = make_penalty_ctx({ cur_row = 0 })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_DIGITAL_NEWLINE)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_DIGITAL_NEWLINE, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
    -- Column should have advanced
    test_utils.assert_eq(ctx.cur_col > 0 or ctx.cur_page > 1, true)
end)

-- ============================================================================
-- PENALTY_DIGITAL_NEWLINE: skip after page break (page_has_content=false)
-- ============================================================================

test_utils.run_test("handle_penalty_breaks: PENALTY_DIGITAL_NEWLINE skips after page break", function()
    -- After \换页 (PENALTY_FORCE_PAGE), the page resets to col=0, row=0, page_has_content=false.
    -- The ^^M after \换页 produces PENALTY_DIGITAL_NEWLINE which should be silently consumed
    -- (not produce an empty column on the new page).
    local ctx = make_penalty_ctx({ cur_row = 0, cur_col = 0, page_has_content = false })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_DIGITAL_NEWLINE)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_DIGITAL_NEWLINE, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    -- Should NOT have flushed or advanced column
    test_utils.assert_eq(flushed, false)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_row, 0)
    -- auto_column_wrap should still be set to false
    test_utils.assert_eq(ctx.auto_column_wrap, false)
end)

-- ============================================================================
-- PENALTY_FORCE_PAGE: normal page break and skip-on-empty-page
-- ============================================================================

test_utils.run_test("handle_penalty_breaks: PENALTY_FORCE_PAGE advances page when content exists", function()
    local ctx = make_penalty_ctx({ cur_row = 3, cur_col = 5, cur_page = 0, page_has_content = true })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_FORCE_PAGE)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_FORCE_PAGE, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
    -- Page should have advanced
    test_utils.assert_eq(ctx.cur_page, 1)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_row, 0)
    test_utils.assert_eq(ctx.page_has_content, false)
end)

test_utils.run_test("handle_penalty_breaks: PENALTY_FORCE_PAGE skips on empty page (no duplicate break)", function()
    -- After a natural page wrap (col overflow), the page resets to col=0, row=0,
    -- page_has_content=false. A subsequent \换页 penalty should be skipped to
    -- avoid creating an empty page in 对开 (split-page) mode.
    local ctx = make_penalty_ctx({ cur_row = 0, cur_col = 0, cur_page = 1, page_has_content = false })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_FORCE_PAGE)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_FORCE_PAGE, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    -- Should NOT have flushed or advanced page
    test_utils.assert_eq(flushed, false)
    test_utils.assert_eq(ctx.cur_page, 1)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_row, 0)
end)

-- ============================================================================
-- Natural Mode Kinsoku helpers
-- ============================================================================

test_utils.run_test("is_line_start_forbidden_code: close/fullstop/comma/middle are forbidden", function()
    test_utils.assert_true(layout_grid._internal.is_line_start_forbidden_code(2))  -- close
    test_utils.assert_true(layout_grid._internal.is_line_start_forbidden_code(3))  -- fullstop
    test_utils.assert_true(layout_grid._internal.is_line_start_forbidden_code(4))  -- comma
    test_utils.assert_true(layout_grid._internal.is_line_start_forbidden_code(5))  -- middle
end)

test_utils.run_test("is_line_start_forbidden_code: open/nobreak are NOT forbidden", function()
    test_utils.assert_false(layout_grid._internal.is_line_start_forbidden_code(1))  -- open
    test_utils.assert_false(layout_grid._internal.is_line_start_forbidden_code(6))  -- nobreak
end)

test_utils.run_test("is_line_end_forbidden_code: only open is forbidden", function()
    test_utils.assert_true(layout_grid._internal.is_line_end_forbidden_code(1))   -- open
    test_utils.assert_false(layout_grid._internal.is_line_end_forbidden_code(2))  -- close
    test_utils.assert_false(layout_grid._internal.is_line_end_forbidden_code(3))  -- fullstop
    test_utils.assert_false(layout_grid._internal.is_line_end_forbidden_code(4))  -- comma
    test_utils.assert_false(layout_grid._internal.is_line_end_forbidden_code(5))  -- middle
end)

test_utils.run_test("calculate_kinsoku_action: squeeze preferred when cost is lower", function()
    local grid_height = 65536 * 14  -- 14pt
    local N = 15  -- 15 chars in buffer
    local col_buffer = {}
    for i = 1, N do
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x4E00)
        table.insert(col_buffer, {
            node = n,
            y_sp = (i - 1) * math.floor(grid_height * 1.1),
            cell_height = grid_height,
        })
    end
    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0xFF0C)  -- comma

    local ctx = {
        col_height_sp = math.floor(N * grid_height * 1.1),  -- fits N chars with 0.1 gap
        cur_page = 0, cur_col = 0,
        punct_config = nil,
    }

    local action = layout_grid._internal.calculate_kinsoku_action(col_buffer, t_node, ctx, grid_height)
    -- With N=15 chars and adding 1 more, squeeze should be feasible
    test_utils.assert_true(action == "squeeze" or action == "stretch")
end)

test_utils.run_test("calculate_kinsoku_action: stretch when squeeze not feasible", function()
    local grid_height = 65536 * 14  -- 14pt
    local N = 20  -- 20 chars tightly packed
    local col_buffer = {}
    for i = 1, N do
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x4E00)
        table.insert(col_buffer, {
            node = n,
            y_sp = (i - 1) * grid_height,
            cell_height = grid_height,
        })
    end
    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0xFF0C)

    local ctx = {
        col_height_sp = N * grid_height,  -- exactly fits N chars with zero gap
        cur_page = 0, cur_col = 0,
        punct_config = nil,
    }

    local action = layout_grid._internal.calculate_kinsoku_action(col_buffer, t_node, ctx, grid_height)
    test_utils.assert_eq(action, "stretch")  -- can't squeeze (no room for gaps)
end)

test_utils.run_test("check_natural_kinsoku: returns nil when no violation", function()
    local grid_height = 65536 * 14
    local col_buffer = {}
    for i = 1, 5 do
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x4E00)
        table.insert(col_buffer, {
            node = n,
            y_sp = (i - 1) * grid_height,
            cell_height = grid_height,
        })
    end
    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0x4E8C)  -- regular char

    local ctx = {
        col_height_sp = 20 * grid_height,
        cur_page = 0, cur_col = 0,
        punct_config = { kinsoku = true },
    }

    local action = layout_grid._internal.check_natural_kinsoku(t_node, ctx, col_buffer, grid_height)
    test_utils.assert_nil(action)
end)

test_utils.run_test("check_natural_kinsoku: returns action when t is line-start-forbidden", function()
    local grid_height = 65536 * 14
    local col_buffer = {}
    for i = 1, 5 do
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x4E00)
        table.insert(col_buffer, {
            node = n,
            y_sp = (i - 1) * grid_height,
            cell_height = grid_height,
        })
    end
    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0xFF0C)  -- comma (line-start-forbidden)
    D.set_attribute(t_node, constants.ATTR_PUNCT_TYPE, 4)  -- comma type

    local ctx = {
        col_height_sp = 20 * grid_height,
        cur_page = 0, cur_col = 0,
        punct_config = { kinsoku = true },
    }

    local action = layout_grid._internal.check_natural_kinsoku(t_node, ctx, col_buffer, grid_height)
    test_utils.assert_true(action == "squeeze" or action == "stretch")
end)

test_utils.run_test("check_natural_kinsoku: returns action when last is line-end-forbidden", function()
    local grid_height = 65536 * 14
    local col_buffer = {}
    for i = 1, 4 do
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x4E00)
        table.insert(col_buffer, {
            node = n,
            y_sp = (i - 1) * grid_height,
            cell_height = grid_height,
        })
    end
    -- Last char is open bracket (line-end-forbidden)
    local open_node = D.new(constants.GLYPH)
    D.setfield(open_node, "char", 0x300C)  -- 「
    D.set_attribute(open_node, constants.ATTR_PUNCT_TYPE, 1)  -- open type
    table.insert(col_buffer, {
        node = open_node,
        y_sp = 4 * grid_height,
        cell_height = grid_height,
    })

    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0x4E00)  -- regular char

    local ctx = {
        col_height_sp = 20 * grid_height,
        cur_page = 0, cur_col = 0,
        punct_config = { kinsoku = true },
    }

    local action = layout_grid._internal.check_natural_kinsoku(t_node, ctx, col_buffer, grid_height)
    test_utils.assert_true(action == "squeeze" or action == "stretch")
end)

test_utils.run_test("check_natural_kinsoku: returns nil when kinsoku disabled", function()
    local grid_height = 65536 * 14
    local col_buffer = {}
    local n = D.new(constants.GLYPH)
    D.setfield(n, "char", 0x4E00)
    table.insert(col_buffer, { node = n, y_sp = 0, cell_height = grid_height })

    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0xFF0C)
    D.set_attribute(t_node, constants.ATTR_PUNCT_TYPE, 4)

    -- kinsoku disabled
    local ctx = {
        col_height_sp = 20 * grid_height,
        cur_page = 0, cur_col = 0,
        punct_config = { kinsoku = false },
    }
    test_utils.assert_nil(layout_grid._internal.check_natural_kinsoku(t_node, ctx, col_buffer, grid_height))

    -- no punct_config
    ctx.punct_config = nil
    test_utils.assert_nil(layout_grid._internal.check_natural_kinsoku(t_node, ctx, col_buffer, grid_height))
end)

test_utils.run_test("check_natural_kinsoku: returns nil when buffer empty", function()
    local grid_height = 65536 * 14
    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0xFF0C)
    D.set_attribute(t_node, constants.ATTR_PUNCT_TYPE, 4)

    local ctx = {
        col_height_sp = 20 * grid_height,
        cur_page = 0, cur_col = 0,
        punct_config = { kinsoku = true },
    }
    test_utils.assert_nil(layout_grid._internal.check_natural_kinsoku(t_node, ctx, {}, grid_height))
end)

test_utils.run_test("check_natural_kinsoku: 两字幅单元不许断在中间（issue #119）", function()
    -- 破折号对的后一半即将落到下一列列首：—— 会被劈成两个孤立的短横。
    -- 断不断由同一套比价决定，但必须给出决策而不是放任断开。
    local grid_height = 65536 * 14
    local col_buffer = {}
    for i = 1, 5 do
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", i == 5 and 0xFE31 or 0x4E00)
        table.insert(col_buffer, {
            node = n,
            y_sp = (i - 1) * grid_height,
            cell_height = grid_height,
        })
    end
    local t_node = D.new(constants.GLYPH)
    D.setfield(t_node, "char", 0xFE31)                      -- ︱ 破折号后一半
    D.set_attribute(t_node, constants.ATTR_PUNCT_TYPE, 6)   -- nobreak
    D.set_attribute(t_node, constants.ATTR_RIGID_PREV, 2)   -- 两字幅单元内部

    local ctx = {
        col_height_sp = 20 * grid_height,
        cur_page = 0, cur_col = 0,
        punct_config = { kinsoku = true },
    }

    local action = layout_grid._internal.check_natural_kinsoku(
        t_node, ctx, col_buffer, grid_height)
    test_utils.assert_true(action == "squeeze" or action == "stretch")
end)

test_utils.run_test("calculate_buffer_height: 两字幅单元内部不计字距", function()
    -- 与 build_column_gaps 同口径；估算多算 0.1em 会让列尾提前换列
    local gh = 65536 * 14
    local function entry(char, rigid)
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", char)
        if rigid then D.set_attribute(n, constants.ATTR_RIGID_PREV, rigid) end
        return { node = n, cell_height = gh }
    end
    local plain = { entry(0x4E00), entry(0x4E8C) }
    local pair = { entry(0xFE31), entry(0xFE31, 2) }

    test_utils.assert_eq(layout_grid._internal.calculate_buffer_height(plain),
        2 * gh + math.floor(gh * 0.1))
    test_utils.assert_eq(layout_grid._internal.calculate_buffer_height(pair),
        2 * gh)
end)

test_utils.run_test("build_column_gaps: 两字幅单元内部字距归零", function()
    local gh = 65536 * 14
    local function entry(char, rigid)
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", char)
        if rigid then D.set_attribute(n, constants.ATTR_RIGID_PREV, rigid) end
        return { node = n, cell_height = gh }
    end
    local function inter_width(entries)
        local col = layout_grid._internal.build_column_gaps(entries, gh)
        return col.gaps[col.inter_idx[1]].width
    end

    -- —— 占整两个字幅，中间不能再夹 0.1em，否则连排破折号露出断口
    test_utils.assert_eq(inter_width({ entry(0xFE31), entry(0xFE31, 2) }), 0)
    -- 数字串只是锁死字距，不归零
    test_utils.assert_eq(inter_width({ entry(0x31), entry(0x32, 1) }),
        math.floor(gh * 0.1))
    -- 普通正文照旧
    test_utils.assert_eq(inter_width({ entry(0x4E00), entry(0x4E8C) }),
        math.floor(gh * 0.1))
end)

-- ============================================================================
-- marker_gap_sp: 脚注标号「前紧后松」
-- ============================================================================

test_utils.run_test("marker_gap_sp: 后侧间距大于前侧（标号依附前文）", function()
    local em = 65536 * 11
    local before = layout_grid._internal.marker_gap_sp(em, "before")
    local after = layout_grid._internal.marker_gap_sp(em, "after")
    test_utils.assert_true(after > before,
        "标号后应比标号前留出更多空隙，才不会读成依附后文")
end)

test_utils.run_test("marker_gap_sp: 前侧紧于普通字距、后侧宽于普通字距", function()
    local em = 65536 * 11
    local normal = math.floor(em * layout_grid._internal.GAP_RATIO)
    test_utils.assert_true(layout_grid._internal.marker_gap_sp(em, "before") < normal,
        "标号前应比普通字距更紧")
    test_utils.assert_true(layout_grid._internal.marker_gap_sp(em, "after") > normal,
        "标号后应比普通字距更松，与被标注内容分开")
end)

test_utils.run_test("marker_gap_sp: 按传入字幅等比缩放", function()
    local a = layout_grid._internal.marker_gap_sp(65536 * 10, "after")
    local b = layout_grid._internal.marker_gap_sp(65536 * 20, "after")
    test_utils.assert_near(b / a, 2.0, 0.01)
end)

test_utils.run_test("marker_gap_sp: 未知 side 按前侧处理", function()
    local em = 65536 * 11
    test_utils.assert_eq(layout_grid._internal.marker_gap_sp(em, nil),
        layout_grid._internal.marker_gap_sp(em, "before"))
end)

-- ============================================================================
-- build_column_gaps（clreq 行内调整：列 → gap 序列，设计 §2）
-- ============================================================================

local EM = 65536 * 14

-- 造一个条目；permille 参数按 1+千分比 的属性约定写入
local function entry(cell_height, attrs)
    local n = D.new(constants.GLYPH)
    D.setfield(n, "char", 0x4E00)
    for attr, permille in pairs(attrs or {}) do
        D.set_attribute(n, attr, 1 + permille)
    end
    return { node = n, cell_height = cell_height }
end

test_utils.run_test("build_column_gaps: 纯汉字列的 gap 结构与字距类别", function()
    local entries = { entry(EM), entry(EM), entry(EM) }
    local col = layout_grid._internal.build_column_gaps(entries, EM)
    -- head_1 + (tail,inter,head)×2 + tail_3 = 3N−1
    test_utils.assert_eq(#col.gaps, 3 * 3 - 1)
    -- 没有标点空白 → 刚性总量就是字幅总和
    test_utils.assert_eq(col.rigid_total, 3 * EM)
    -- 字距是 0.1em、可压到 0、参与兜底均分，类别是「最后手段」
    local g = col.gaps[col.inter_idx[1]]
    test_utils.assert_eq(g.width, math.floor(EM * 0.1))
    test_utils.assert_eq(g.min, 0)
    test_utils.assert_eq(g.shrink_class, "inter_char")
    test_utils.assert_true(g.fallback)
end)

test_utils.run_test("build_column_gaps: 标点的弹性空白升格为 gap，刚性只剩墨迹", function()
    -- 逗号：潜在空白 0.5em 全在末端，相邻规则只强制收回 0.2em
    -- → 字幅 0.8em，其中 0.3em 是可继续收回的弹性空白，0.5em 刚性
    local e = entry(math.floor(EM * 0.8), {
        [constants.ATTR_PUNCT_BLANK] = 500,
        [constants.ATTR_PUNCT_BLANK_HEAD] = 0,
        [constants.ATTR_PUNCT_SQUEEZE] = 200,
        [constants.ATTR_PUNCT_SQUEEZE_HEAD] = 0,
        [constants.ATTR_PUNCT_SHRINK_CLASS] = 5,  -- comma_group（SHRINK_ORDER 第 5）
    })
    local col = layout_grid._internal.build_column_gaps({ e, entry(EM) }, EM)
    local tail = col.gaps[col.tail_idx[1]]
    test_utils.assert_near(tail.width, EM * 0.3, EM * 0.002)
    test_utils.assert_eq(tail.min, 0)
    test_utils.assert_eq(tail.shrink_class, "comma_group")
    -- 刚性 + 弹性 = 原字幅（升格不改变自然长度）
    test_utils.assert_near(col.rigid[1] + tail.width + col.gaps[col.head_idx[1]].width,
        math.floor(EM * 0.8), 2)
end)

test_utils.run_test("build_column_gaps: 中西边界升格为 1/4em cjk_western gap", function()
    -- clreq：汉字与西文间加 1/4em，可挤至 1/8、拉至 1/2；
    -- 不参与兜底均分（1/2 是硬上限）
    local second = entry(EM)
    D.set_attribute(second.node, constants.ATTR_CJK_WESTERN_PREV, 1)
    local col = layout_grid._internal.build_column_gaps({ entry(EM), second }, EM)
    local inter = col.gaps[col.inter_idx[1]]
    test_utils.assert_eq(inter.width, math.floor(EM * 0.25))
    test_utils.assert_eq(inter.min, math.floor(EM * 0.125))
    test_utils.assert_eq(inter.max, math.floor(EM * 0.5))
    test_utils.assert_eq(inter.shrink_class, "cjk_western")
    test_utils.assert_eq(inter.stretch_class, "cjk_western")
    test_utils.assert_nil(inter.fallback)
end)

test_utils.run_test("calculate_buffer_height: 中西边界按 1/4em 估算", function()
    -- 估算与求解器不同口径会让列尾早换（或晚换）一列
    local gh = 65536 * 14
    local function mk(attr)
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x4E00)
        if attr then D.set_attribute(n, constants.ATTR_CJK_WESTERN_PREV, 1) end
        return { node = n, cell_height = gh }
    end
    test_utils.assert_eq(
        layout_grid._internal.calculate_buffer_height({ mk(), mk(true) }),
        2 * gh + math.floor(gh * 0.25))
end)

test_utils.run_test("build_column_gaps/估算: 横置串内部零字距且刚性", function()
    -- \横置 的字母连排成词：字幅 = advance，串内既无字距也不可拉开
    local gh = 65536 * 14
    local function mk(side)
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x41)
        if side then D.set_attribute(n, constants.ATTR_SIDEWAYS, 1) end
        return { node = n, cell_height = math.floor(gh * 0.5) }
    end
    local a, b = mk(true), mk(true)
    local col = layout_grid._internal.build_column_gaps({ a, b }, gh)
    local inter = col.gaps[col.inter_idx[1]]
    test_utils.assert_eq(inter.width, 0)
    test_utils.assert_eq(inter.max, 0, "串内不可拉开——兜底均分会把词撑散")
    test_utils.assert_eq(
        layout_grid._internal.calculate_buffer_height({ mk(true), mk(true) }),
        2 * math.floor(gh * 0.5), "估算同口径：串内无字距")
end)

test_utils.run_test("build_column_gaps/估算: 中横排组内零字距且刚性", function()
    -- \中横排 整组共占一格：组首字幅 1 字、组员 0，组内既无字距也不可拉开
    local gh = 65536 * 14
    local function mk(group, ch)
        local n = D.new(constants.GLYPH)
        D.setfield(n, "char", 0x31)
        if group then D.set_attribute(n, constants.ATTR_TCY, group) end
        return { node = n, cell_height = ch }
    end
    local a, b = mk(7, gh), mk(7, 0)
    local col = layout_grid._internal.build_column_gaps({ a, b }, gh)
    local inter = col.gaps[col.inter_idx[1]]
    test_utils.assert_eq(inter.width, 0)
    test_utils.assert_eq(inter.max, 0, "组内不可拉开——兜底均分会把组撑散")
    test_utils.assert_eq(
        layout_grid._internal.calculate_buffer_height({ mk(7, gh), mk(7, 0) }),
        gh, "估算同口径：整组只占组首一个字幅")
    -- 相邻两组组号不同，组间字距照常（不误并为一格）
    test_utils.assert_eq(
        layout_grid._internal.calculate_buffer_height({ mk(7, gh), mk(8, gh) }),
        2 * gh + math.floor(gh * 0.1), "相邻两组组间保留基准字距")
end)

test_utils.run_test("build_column_gaps: 刚性单元边界上的三个 gap 全部锁死", function()
    -- clreq 符号分离禁则：两字幅标点等单元内部不得有任何伸缩，
    -- 横排的教训是只清 stretch 不清 shrink 会把单元压扁
    local second = entry(EM, { [constants.ATTR_RIGID_PREV] = 0 })
    D.set_attribute(second.node, constants.ATTR_RIGID_PREV, 1)
    local col = layout_grid._internal.build_column_gaps({ entry(EM), second }, EM)
    local inter = col.gaps[col.inter_idx[1]]
    test_utils.assert_eq(inter.min, inter.width)
    test_utils.assert_eq(inter.max, inter.width)
    test_utils.assert_nil(inter.shrink_class)
    test_utils.assert_nil(inter.fallback)
end)

test_utils.run_test("build_column_gaps: 列末标点归入挤压第 1 级", function()
    local e = entry(EM, {
        [constants.ATTR_PUNCT_BLANK] = 500,
        [constants.ATTR_PUNCT_BLANK_HEAD] = 0,
        [constants.ATTR_PUNCT_SHRINK_CLASS] = 7,  -- fullstop_group（第 7）
    })
    local col = layout_grid._internal.build_column_gaps({ entry(EM), e }, EM)
    -- clreq 挤压顺序第 1 步就是「位于行末的标点」，优先于它平时的类别
    test_utils.assert_eq(col.gaps[col.tail_idx[2]].shrink_class, "line_end_punct")
end)

print("\nAll core/layout-grid-test tests passed!")
