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

print("\nAll core/layout-grid-test tests passed!")
