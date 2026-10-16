-- Unit tests for core.luatex-cn-core-textflow (white-box via _internal)
-- Covers the column-wrap guards around place_textflow_segment:
--   1. Wrap before placing when the column has no room for the first node
--      (glyph would protrude beyond the column bottom border).
--   2. Clear just_wrapped_column once textflow content is placed, and the
--      matching smart-break empty-column guard in layout-grid.
local test_utils = require("test.test_utils")

-- Mock hooks module (required by layout-grid)
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}
_G.core.hooks.is_reserved_column = function(col, interval)
    return col % (interval + 1) == interval
end
package.loaded['core.luatex-cn-hooks'] = {
    is_reserved_column = _G.core.hooks.is_reserved_column,
    get_plugins = function() return {} end,
}

local textflow = require("core.luatex-cn-core-textflow")
local layout_grid = require("core.luatex-cn-layout-grid")
local constants = require("core.luatex-cn-constants")
local D = node.direct

local GH = 655360  -- 10pt grid height

-- Helper: build a textflow glyph node
local function make_tf_glyph(char)
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", char or 0x4E00)
    D.set_attribute(g, constants.ATTR_JIAZHU, 1)
    return g
end

-- Helper: minimal ctx/params/callbacks for place_textflow_segment
local function make_env(overrides)
    local line_limit = 20
    local ctx = {
        cur_row = 0,
        cur_y_sp = 0,
        cur_col = 0,
        cur_page = 0,
        cur_band = 0,
        p_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        col_height_sp = line_limit * GH,
        auto_column_wrap = true,
        just_wrapped_column = false,
        params = { grid_width = GH },
    }
    local params = {
        grid_height = GH,
        grid_width = GH,
        effective_limit = line_limit,
        line_limit = line_limit,
        r_indent = 0,
        base_indent = 0,
        first_indent = -1,
        textflow_mode = 0,
        block_id = nil,
    }
    if overrides then
        for k, v in pairs(overrides) do ctx[k] = v end
    end
    local wrap_count = 0
    local callbacks = {
        wrap = function()
            wrap_count = wrap_count + 1
            ctx.cur_col = ctx.cur_col + 1
            ctx.cur_row = 0
            ctx.cur_y_sp = 0
        end,
        get_indent = function() return 0 end,
    }
    return ctx, params, callbacks, function() return wrap_count end
end

-- ============================================================================
-- _internal exports
-- ============================================================================

test_utils.run_test("textflow: _internal exported", function()
    test_utils.assert_type(textflow._internal, "table")
    test_utils.assert_type(textflow._internal.place_textflow_segment, "function")
end)

test_utils.run_test("get_node_h: falls back to default grid height", function()
    test_utils.assert_eq(textflow._internal.get_node_h(nil, 1, GH), GH)
    test_utils.assert_eq(textflow._internal.get_node_h({ [1] = 2 * GH }, 1, GH), 2 * GH)
    test_utils.assert_eq(textflow._internal.get_node_h({ [1] = 2 * GH }, 2, GH), GH)
end)

-- ============================================================================
-- Fix 1: wrap before placing when column has no room for the first node
-- ============================================================================

test_utils.run_test("place: full column wraps before placing first node", function()
    local ctx, params, callbacks, wraps = make_env({
        cur_row = 20,             -- column completely full
        cur_y_sp = 20 * GH,
    })
    local layout_map = {}
    local g = make_tf_glyph()
    textflow._internal.place_textflow_segment(ctx, { g }, layout_map, params, callbacks, nil)

    test_utils.assert_eq(wraps(), 1)  -- wrapped once before placing
    local entry = layout_map[g]
    test_utils.assert_type(entry, "table")
    test_utils.assert_eq(entry.col, 1)   -- placed in the NEXT column
    test_utils.assert_eq(entry.y_sp, 0)  -- at the top, not beyond the border
end)

test_utils.run_test("place: column with room does not wrap", function()
    local ctx, params, callbacks, wraps = make_env({
        cur_row = 5,
        cur_y_sp = 5 * GH,
    })
    local layout_map = {}
    local g = make_tf_glyph()
    textflow._internal.place_textflow_segment(ctx, { g }, layout_map, params, callbacks, nil)

    test_utils.assert_eq(wraps(), 0)
    local entry = layout_map[g]
    test_utils.assert_eq(entry.col, 0)
    test_utils.assert_eq(entry.y_sp, 5 * GH)
end)

test_utils.run_test("place: no wrap guard when auto_column_wrap disabled", function()
    local ctx, params, callbacks, wraps = make_env({
        cur_row = 20,
        cur_y_sp = 20 * GH,
        auto_column_wrap = false,  -- digital mode: never auto-wrap
    })
    local layout_map = {}
    local g = make_tf_glyph()
    textflow._internal.place_textflow_segment(ctx, { g }, layout_map, params, callbacks, nil)

    test_utils.assert_eq(wraps(), 0)
    test_utils.assert_eq(layout_map[g].col, 0)
end)

-- ============================================================================
-- Fix 2a: just_wrapped_column cleared when textflow places content
-- ============================================================================

test_utils.run_test("place: clears just_wrapped_column after placing", function()
    local ctx, params, callbacks = make_env({
        just_wrapped_column = true,
    })
    local layout_map = {}
    textflow._internal.place_textflow_segment(ctx, { make_tf_glyph() }, layout_map, params, callbacks, nil)
    test_utils.assert_eq(ctx.just_wrapped_column, false)
end)

test_utils.run_test("place: empty node list keeps just_wrapped_column", function()
    local ctx, params, callbacks = make_env({
        just_wrapped_column = true,
    })
    textflow._internal.place_textflow_segment(ctx, {}, {}, params, callbacks, nil)
    test_utils.assert_eq(ctx.just_wrapped_column, true)
end)

-- ============================================================================
-- Fix 2b: smart-break empty-column guard only discards pending state when
-- the column is truly empty (just_wrapped_column still true)
-- ============================================================================

-- Helper: ctx for handle_penalty_node (mirrors layout-grid-test's make_penalty_ctx)
local function make_penalty_ctx(overrides)
    local ctx = {
        cur_row = 0,
        cur_col = 0,
        cur_page = 1,
        cur_y_sp = 0,
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

-- Helper: smart-break penalty followed by a normal (non-textflow) glyph
local function make_smart_break()
    local p = D.new(constants.PENALTY)
    D.setfield(p, "penalty", constants.PENALTY_SMART_BREAK)
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 0x4E8C)
    D.setlink(p, g)
    return p
end

test_utils.run_test("smart-break: truly empty column discards pending state", function()
    local ctx = make_penalty_ctx({
        cur_row = 0,
        textflow_pending_sub_col = 1,
        textflow_pending_row_used = 2,
        just_wrapped_column = true,  -- nothing placed since the wrap
    })
    layout_grid._internal.handle_penalty_node(make_smart_break(), ctx, GH, 0, 0, 10, function() end)

    test_utils.assert_eq(ctx.textflow_pending_sub_col, nil)
    test_utils.assert_eq(ctx.textflow_pending_row_used, nil)
    test_utils.assert_eq(ctx.cur_row, 0)  -- no advance, no wrap
    test_utils.assert_eq(ctx.cur_col, 0)
end)

test_utils.run_test("smart-break: column with textflow content flushes pending and wraps", function()
    local ctx = make_penalty_ctx({
        cur_row = 0,
        textflow_pending_sub_col = 1,
        textflow_pending_row_used = 2,
        just_wrapped_column = false,  -- textflow HAS placed content here
    })
    layout_grid._internal.handle_penalty_node(make_smart_break(), ctx, GH, 0, 0, 10, function() end)

    -- Pending rows flushed (cur_row advanced) then wrapped to next column
    test_utils.assert_eq(ctx.textflow_pending_sub_col, nil)
    test_utils.assert_eq(ctx.textflow_pending_row_used, nil)
    test_utils.assert_eq(ctx.cur_col, 1)  -- wrap happened
    test_utils.assert_eq(ctx.cur_row, 0)  -- new column starts at top
end)

test_utils.run_test("push_style: n_char is stored for layout-time grid height (issue #82)", function()
    local style_registry = require("util.luatex-cn-style-registry")
    local id = textflow.push_style(nil, "20pt", nil, nil, true, nil, nil, 20)
    test_utils.assert_eq(style_registry.get(id).textflow_n_char, 20)
    test_utils.assert_eq(style_registry.get(id).textflow_grid_height, nil)
    textflow.pop_style()
end)

test_utils.run_test("push_style: explicit grid height wins over n_char", function()
    local style_registry = require("util.luatex-cn-style-registry")
    local id = textflow.push_style(nil, "20pt", nil, nil, true, 655360, nil, 20)
    test_utils.assert_eq(style_registry.get(id).textflow_n_char, nil)
    test_utils.assert_eq(style_registry.get(id).textflow_grid_height, 655360)
    textflow.pop_style()
end)

print("\nAll textflow tests passed!")
