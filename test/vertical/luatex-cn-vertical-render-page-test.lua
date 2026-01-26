local test_utils = require('test.test_utils')
local render = require('vertical.luatex-cn-vertical-render-page')
local constants = require('vertical.luatex-cn-vertical-base-constants')
local D = node.direct

local internal = render._internal

-- ============================================================================
-- Internal Helper Tests
-- ============================================================================

test_utils.run_test("calculate_render_context - defaults", function()
    if not internal.calculate_render_context then return end
    local params = {}
    local ctx = internal.calculate_render_context(params)
    test_utils.assert_eq(ctx.border_thickness, 26214, "Default border thickness")
    test_utils.assert_eq(ctx.p_cols, 1, "Default p_cols")
    test_utils.assert_eq(ctx.b_rgb_str, "0.0000 0.0000 0.0000", "Default border color")
end)

test_utils.run_test("calculate_render_context - overrides", function()
    if not internal.calculate_render_context then return end
    local params = {
        border_thickness = 65536,
        n_column = 2,
        grid_width = 100,
        draw_outer_border = true
    }
    local ctx = internal.calculate_render_context(params)
    test_utils.assert_eq(ctx.border_thickness, 65536, "Override border thickness")
    test_utils.assert_eq(ctx.interval, 2, "Interval set")
    -- p_cols = 2*2+1 = 5
    test_utils.assert_eq(ctx.p_cols, 5, "Calculated p_cols")
    test_utils.assert_eq(ctx.grid_width, 100, "Grid width")
    test_utils.assert_eq(ctx.outer_shift > 0, true, "Outer shift enabled")
end)

test_utils.run_test("group_nodes_by_page - basic grouping", function()
    if not internal.group_nodes_by_page then return end
    local n1 = D.new(constants.GLYPH)
    local n2 = D.new(constants.GLYPH)
    -- Layout map keys must be direct nodes (integers)
    local layout_map = {
        [n1] = { page = 0, col = 1 },
        [n2] = { page = 1, col = 0 }
    }
    D.setlink(n1, n2)

    local page_nodes = internal.group_nodes_by_page(n1, layout_map, 2)
    test_utils.assert_eq(page_nodes[0].head, n1, "Page 0 head")
    test_utils.assert_eq(page_nodes[0].max_col, 1, "Page 0 max_col")
    test_utils.assert_eq(page_nodes[1].head, n2, "Page 1 head")
end)

test_utils.run_test("render_single_page - basic", function()
    if not internal.render_single_page then return end
    local head = D.new(constants.GLYPH)
    -- Mock params and ctx
    local params = {
        grid_width = 100,
        grid_height = 100,
        draw_debug = false,
        total_pages = 1,
        layout_map = { [head] = { page = 0, col = 0, row = 0 } }
    }
    local ctx = internal.calculate_render_context(params)

    local res_head, cols = internal.render_single_page(head, 0, 0, params.layout_map, params, ctx)
    test_utils.assert_eq(type(res_head), "table", "Should return head node")
    test_utils.assert_eq(cols, 1, "Should have 1 col")
end)

test_utils.run_test("position_floating_box - basics", function()
    if not internal.position_floating_box then return end
    local box = D.new(constants.HLIST)
    D.setfield(box, "width", 100)
    D.setfield(box, "height", 100)

    local item = { box = box, x = 0, y = 0 } -- x=0 means at right edge
    local params = { paper_width = 1000, margin_left = 0, margin_top = 0, draw_debug = false }

    local res = internal.position_floating_box(nil, item, params)
    -- Should return a list with kerns and the box
    -- Should have: Kern(900) -> Kern -> Box ...
    -- rel_x = 1000 - 0 - 0 - 100 = 900.
    test_utils.assert_eq(type(res), "table", "Should return head")
end)

-- ============================================================================
-- Integration Tests
-- ============================================================================

test_utils.run_test("render-page - apply positions", function()
    local n1 = D.new(constants.GLYPH)
    local map = {
        [n1] = { page = 0, col = 0, row = 0 }
    }
    local params = {
        grid_width = 655360,
        grid_height = 655360,
        page_columns = 10,
        line_limit = 20,
        margin_top = 0,
        margin_left = 0,
        border_thickness = 65536,
        b_padding_top = 0,
        b_padding_bottom = 0,
        total_pages = 2 -- at least 2 to test grouping
    }

    -- apply_positions expects HEAD as a node (userdata or direct? usually expects userdata from TeX but converted internally)
    -- BUT if we pass a direct node ID here, apply_positions calls D.todirect() which works on IDs too.
    local pages = render.apply_positions(n1, map, params)
    test_utils.assert_eq(#pages, 1, "Should generate 1 page list")
    -- pages[1].head is likely a userdata node if converted back, OR direct node if D.tonode was skipped?
    -- render.apply_positions ends with: result_pages[p+1] = { head = D.tonode(p_head) ... }
    -- So it returns userdata.
    test_utils.assert_eq(type(pages[1].head), "table", "Page head should be a node table")
end)

print("\nAll render-page tests passed!")
