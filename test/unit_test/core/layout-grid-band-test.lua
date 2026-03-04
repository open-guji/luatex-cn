-- Unit tests for band (分栏) feature in layout-grid
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
local helpers = require("core.luatex-cn-layout-grid-helpers")
local D = node.direct

-- Helper: create a ctx with band support
local function make_band_ctx(overrides)
    local grid_height = 65536 * 20  -- 20pt
    local col_height = grid_height * 21 -- 21 rows per column
    local n_bands = (overrides and overrides.n_bands) or 3
    local band_gap_sp = (overrides and overrides.band_gap_sp) or 0
    local p_cols = (overrides and overrides.p_cols) or 10
    local band_mode = (overrides and overrides.band_mode) or "auto"
    local line_limit = 21

    -- Calculate band layout
    local total_gap = band_gap_sp * (n_bands - 1)
    local available_height = col_height - total_gap
    local band_height = math.floor(available_height / n_bands)

    local ctx = {
        cur_row = 0,
        cur_col = 0,
        cur_page = 0,
        cur_y_sp = 0,
        cur_band = 0,
        page_has_content = true,
        cur_column_indent = 0,
        occupancy = {},
        just_wrapped_column = false,
        col_widths_sp = {},
        banxin_registry = {},
        p_cols = p_cols,
        params = { banxin_on = false },
        line_limit = line_limit,
        col_height_sp = band_height,
        auto_column_wrap = true,
        -- Band fields
        n_bands = n_bands,
        band_heights_sp = {},
        band_y_offsets_sp = {},
        band_line_limits = {},
        band_cols_per_band = p_cols,
        band_mode = band_mode,
        band_gap_sp = band_gap_sp,
    }

    -- Initialize band data
    local offset = 0
    for i = 0, n_bands - 1 do
        ctx.band_heights_sp[i] = band_height
        ctx.band_y_offsets_sp[i] = offset
        ctx.band_line_limits[i] = line_limit
        offset = offset + band_height + band_gap_sp
    end
    ctx.line_limit = ctx.band_line_limits[0]
    ctx.col_height_sp = ctx.band_heights_sp[0]

    if overrides then
        for k, v in pairs(overrides) do
            if k ~= "n_bands" and k ~= "band_gap_sp" and k ~= "p_cols" and k ~= "band_mode" then
                ctx[k] = v
            end
        end
    end

    _G.page = _G.page or {}
    _G.content = _G.content or {}
    return ctx
end

-- ============================================================================
-- wrap_to_next_column: band wrapping
-- ============================================================================

test_utils.run_test("band: wrap_to_next_column stays in band 0 when col < p_cols", function()
    local ctx = make_band_ctx({ cur_col = 3 })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    -- Should advance col by 1, stay in band 0
    test_utils.assert_eq(ctx.cur_col, 4)
    test_utils.assert_eq(ctx.cur_band, 0)
    test_utils.assert_eq(ctx.cur_page, 0)
end)

test_utils.run_test("band: wrap_to_next_column wraps to band 1 at col boundary", function()
    local ctx = make_band_ctx({ cur_col = 9 })  -- col 9 → col 10 >= p_cols=10
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_band, 1)
    test_utils.assert_eq(ctx.cur_page, 0)
end)

test_utils.run_test("band: wrap_to_next_column wraps from band 1 to band 2", function()
    local ctx = make_band_ctx({ cur_col = 9, cur_band = 1 })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_band, 2)
    test_utils.assert_eq(ctx.cur_page, 0)
end)

test_utils.run_test("band: auto mode wraps to next page when all bands full", function()
    local ctx = make_band_ctx({ cur_col = 9, cur_band = 2, band_mode = "auto" })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_band, 0, "should reset to band 0")
    test_utils.assert_eq(ctx.cur_page, 1, "should advance to next page")
    test_utils.assert_eq(ctx.page_has_content, false, "new page has no content")
end)

test_utils.run_test("band: per-page mode stays on last band when full", function()
    local ctx = make_band_ctx({ cur_col = 9, cur_band = 2, band_mode = "per-page" })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_band, 2, "should stay on last band")
    test_utils.assert_eq(ctx.cur_page, 0, "should NOT advance page")
end)

test_utils.run_test("band: line_limit updates on band wrap", function()
    local ctx = make_band_ctx()
    -- Manually set different line_limits per band for testing
    ctx.band_line_limits[0] = 10
    ctx.band_line_limits[1] = 15
    ctx.band_line_limits[2] = 20
    ctx.line_limit = ctx.band_line_limits[0]

    -- Wrap to band 1
    ctx.cur_col = 9
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.line_limit, 15, "should use band 1's line_limit")
    test_utils.assert_eq(ctx.cur_band, 1)
end)

test_utils.run_test("band: col_height_sp updates on band wrap", function()
    local ctx = make_band_ctx()
    ctx.band_heights_sp[0] = 100000
    ctx.band_heights_sp[1] = 200000
    ctx.col_height_sp = ctx.band_heights_sp[0]

    ctx.cur_col = 9
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.col_height_sp, 200000, "should use band 1's height")
end)

-- ============================================================================
-- n_bands=1: backward compatible (no band wrapping)
-- ============================================================================

test_utils.run_test("band: n_bands=1 wraps page at col boundary (no band logic)", function()
    local ctx = make_band_ctx({ n_bands = 1, cur_col = 9 })
    -- With n_bands=1, should NOT enter band wrapping code, just page wrap
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_band, 0, "band should stay 0")
    test_utils.assert_eq(ctx.cur_page, 1, "should wrap to next page")
end)

test_utils.run_test("band: n_bands=1 stays on same page within columns", function()
    local ctx = make_band_ctx({ n_bands = 1, cur_col = 3 })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_col, 4)
    test_utils.assert_eq(ctx.cur_band, 0)
    test_utils.assert_eq(ctx.cur_page, 0)
end)

-- ============================================================================
-- handle_penalty_breaks: PENALTY_BAND_BREAK
-- ============================================================================

test_utils.run_test("band: PENALTY_BAND_BREAK wraps to next band", function()
    local ctx = make_band_ctx({ cur_col = 3, cur_row = 5 })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_BAND_BREAK)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_BAND_BREAK, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
    test_utils.assert_eq(ctx.cur_band, 1, "should advance to band 1")
    test_utils.assert_eq(ctx.cur_col, 0, "should reset col")
    test_utils.assert_eq(ctx.cur_row, 0, "should reset row")
end)

test_utils.run_test("band: PENALTY_BAND_BREAK on last band wraps page (auto mode)", function()
    local ctx = make_band_ctx({ cur_col = 5, cur_band = 2 })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_BAND_BREAK)
    layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_BAND_BREAK, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(ctx.cur_band, 0, "should reset to band 0")
    test_utils.assert_eq(ctx.cur_page, 1, "should advance page")
    test_utils.assert_eq(ctx.page_has_content, false)
end)

test_utils.run_test("band: PENALTY_BAND_BREAK on last band stays (per-page mode)", function()
    local ctx = make_band_ctx({ cur_col = 5, cur_band = 2, band_mode = "per-page" })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_BAND_BREAK)
    layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_BAND_BREAK, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(ctx.cur_band, 2, "should stay on last band")
    test_utils.assert_eq(ctx.cur_page, 0, "should NOT advance page")
end)

test_utils.run_test("band: PENALTY_BAND_BREAK with n_bands=1 is no-op for band", function()
    local ctx = make_band_ctx({ n_bands = 1, cur_col = 5, cur_row = 3 })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_BAND_BREAK)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_BAND_BREAK, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true, "should still be handled")
    test_utils.assert_eq(ctx.cur_band, 0, "band stays 0")
    test_utils.assert_eq(ctx.cur_col, 5, "col unchanged")
end)

-- ============================================================================
-- handle_penalty_breaks: PENALTY_FORCE_PAGE resets band
-- ============================================================================

test_utils.run_test("band: PENALTY_FORCE_PAGE resets cur_band to 0", function()
    local ctx = make_band_ctx({ cur_col = 3, cur_band = 2, page_has_content = true })
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_FORCE_PAGE)
    layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_FORCE_PAGE, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(ctx.cur_band, 0, "should reset band on page break")
    test_utils.assert_eq(ctx.cur_page, 1, "should advance page")
    test_utils.assert_eq(ctx.line_limit, ctx.band_line_limits[0], "should restore band 0 line_limit")
end)

-- ============================================================================
-- Occupancy map: 4-level nesting with band
-- ============================================================================

test_utils.run_test("band: occupancy map uses band index", function()
    local occ = {}
    helpers.mark_occupied(occ, 0, 0, 5, 3)  -- page 0, band 0, col 5, row 3
    helpers.mark_occupied(occ, 0, 1, 5, 3)  -- page 0, band 1, col 5, row 3

    test_utils.assert_eq(helpers.is_occupied(occ, 0, 0, 5, 3), true)
    test_utils.assert_eq(helpers.is_occupied(occ, 0, 1, 5, 3), true)
    test_utils.assert_eq(helpers.is_occupied(occ, 0, 2, 5, 3), false, "band 2 not occupied")
    test_utils.assert_eq(helpers.is_occupied(occ, 0, 0, 5, 4), false, "different row not occupied")
end)

-- ============================================================================
-- Band Y offset values
-- ============================================================================

test_utils.run_test("band: band_y_offsets_sp computed correctly (no gap)", function()
    local ctx = make_band_ctx({ n_bands = 3, band_gap_sp = 0 })
    test_utils.assert_eq(ctx.band_y_offsets_sp[0], 0, "band 0 starts at 0")
    test_utils.assert_true(ctx.band_y_offsets_sp[1] > 0, "band 1 offset > 0")
    test_utils.assert_eq(ctx.band_y_offsets_sp[1], ctx.band_heights_sp[0],
        "band 1 offset = band 0 height")
    test_utils.assert_eq(ctx.band_y_offsets_sp[2], ctx.band_heights_sp[0] + ctx.band_heights_sp[1],
        "band 2 offset = sum of band 0+1 heights")
end)

test_utils.run_test("band: band_y_offsets_sp computed correctly (with gap)", function()
    local gap = 65536 * 5  -- 5pt gap
    local ctx = make_band_ctx({ n_bands = 3, band_gap_sp = gap })
    test_utils.assert_eq(ctx.band_y_offsets_sp[0], 0)
    test_utils.assert_eq(ctx.band_y_offsets_sp[1], ctx.band_heights_sp[0] + gap,
        "band 1 offset includes gap")
    test_utils.assert_eq(ctx.band_y_offsets_sp[2],
        ctx.band_heights_sp[0] + gap + ctx.band_heights_sp[1] + gap,
        "band 2 offset includes both gaps")
end)

test_utils.run_test("band: all bands have equal height (equal split)", function()
    local ctx = make_band_ctx({ n_bands = 5, band_gap_sp = 0 })
    local h0 = ctx.band_heights_sp[0]
    for i = 1, 4 do
        test_utils.assert_eq(ctx.band_heights_sp[i], h0,
            string.format("band %d height should equal band 0", i))
    end
end)

-- ============================================================================
-- cur_y_sp resets on band wrap
-- ============================================================================

test_utils.run_test("band: cur_y_sp resets to 0 on band wrap", function()
    local ctx = make_band_ctx({ cur_col = 9, cur_y_sp = 65536 * 100 })
    layout_grid._internal.wrap_to_next_column(ctx, 10, 0, 65536 * 20, 0, false, true)
    test_utils.assert_eq(ctx.cur_y_sp, 0, "Y should reset on band wrap")
    test_utils.assert_eq(ctx.cur_band, 1)
end)

print("\nAll core/layout-grid-band-test tests passed!")
