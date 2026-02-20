local test_utils = require('test.test_utils')
local render = require('luatex-cn-core-render-page')
local constants = require('luatex-cn-constants')
local D = node.direct

local internal = render._internal

-- ============================================================================
-- calculate_render_context Tests
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
    test_utils.assert_eq(ctx.p_cols, 5, "Calculated p_cols (2*2+1)")
    test_utils.assert_eq(ctx.grid_width, 100, "Grid width")
    test_utils.assert_eq(ctx.outer_shift > 0, true, "Outer shift enabled")
end)

test_utils.run_test("calculate_render_context - zero shifts with outer border", function()
    if not internal.calculate_render_context then return end
    local params = {
        shift_x = 0,
        shift_y = 0,
        draw_outer_border = true,
        outer_border_thickness = 65536 * 2,
        outer_border_sep = 65536 * 2
    }
    local ctx = internal.calculate_render_context(params)
    test_utils.assert_eq(ctx.shift_x, ctx.outer_shift, "shift_x should default to outer_shift")
end)

test_utils.run_test("calculate_render_context - border shift calculation", function()
    if not internal.calculate_render_context then return end
    local params = {
        draw_border = true,
        border_thickness = 65536,
        b_padding_top = 65536 * 5
    }
    local ctx = internal.calculate_render_context(params)
    local expected_shift = ctx.outer_shift + 65536 + 65536 * 5
    test_utils.assert_eq(ctx.shift_y, expected_shift, "shift_y should include border padding")
end)

test_utils.run_test("calculate_render_context - jiazhu align settings", function()
    if not internal.calculate_render_context then return end
    local params = { jiazhu_align = "inward" }
    local ctx = internal.calculate_render_context(params)
    test_utils.assert_eq(ctx.jiazhu_align, "inward", "jiazhu_align should pass through")
end)

test_utils.run_test("calculate_render_context - judou settings", function()
    if not internal.calculate_render_context then return end
    local params = {
        judou_pos = "left-top",
        judou_size = "0.5em",
        judou_color = "blue"
    }
    local ctx = internal.calculate_render_context(params)
    test_utils.assert_eq(ctx.judou_pos, "left-top", "judou_pos should pass through")
    test_utils.assert_eq(ctx.judou_size, "0.5em", "judou_size should pass through")
    test_utils.assert_eq(ctx.judou_color, "blue", "judou_color should pass through")
end)

-- ============================================================================
-- group_nodes_by_page Tests
-- ============================================================================

test_utils.run_test("group_nodes_by_page - basic grouping", function()
    if not internal.group_nodes_by_page then return end
    local n1 = D.new(constants.GLYPH)
    local n2 = D.new(constants.GLYPH)
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

test_utils.run_test("group_nodes_by_page - multi page distribution", function()
    if not internal.group_nodes_by_page then return end
    local nodes = {}
    for i = 1, 6 do
        nodes[i] = D.new(constants.GLYPH)
        if i > 1 then D.setlink(nodes[i - 1], nodes[i]) end
    end

    local layout_map = {
        [nodes[1]] = { page = 0, col = 0 },
        [nodes[2]] = { page = 0, col = 1 },
        [nodes[3]] = { page = 1, col = 0 },
        [nodes[4]] = { page = 1, col = 2 },
        [nodes[5]] = { page = 2, col = 0 },
        [nodes[6]] = { page = 2, col = 3 }
    }

    local page_nodes = internal.group_nodes_by_page(nodes[1], layout_map, 3)
    test_utils.assert_eq(page_nodes[0].max_col, 1, "Page 0 max col")
    test_utils.assert_eq(page_nodes[1].max_col, 2, "Page 1 max col")
    test_utils.assert_eq(page_nodes[2].max_col, 3, "Page 2 max col")
end)

test_utils.run_test("group_nodes_by_page - empty pages", function()
    if not internal.group_nodes_by_page then return end
    local n1 = D.new(constants.GLYPH)
    local layout_map = {
        [n1] = { page = 2, col = 0 }
    }

    local page_nodes = internal.group_nodes_by_page(n1, layout_map, 3)
    test_utils.assert_eq(page_nodes[0].head, nil, "Page 0 should be empty")
    test_utils.assert_eq(page_nodes[1].head, nil, "Page 1 should be empty")
    test_utils.assert_eq(page_nodes[2].head, n1, "Page 2 should have node")
end)

-- ============================================================================
-- handle_glyph_node Tests
-- ============================================================================

test_utils.run_test("handle_glyph_node - basic positioning", function()
    if not internal.handle_glyph_node then return end
    local glyph = D.new(constants.GLYPH)
    D.setfield(glyph, "width", 65536 * 10)
    D.setfield(glyph, "height", 65536 * 8)
    D.setfield(glyph, "depth", 65536 * 2)
    D.setfield(glyph, "char", 20320)
    D.setfield(glyph, "font", 0)

    local pos = { col = 0, row = 0 }
    local params = { vertical_align = "center" }
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        jiazhu_align = "outward"
    }

    local new_head = internal.handle_glyph_node(glyph, glyph, pos, params, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head")
end)

test_utils.run_test("handle_glyph_node - column alignment", function()
    if not internal.handle_glyph_node then return end
    local glyph = D.new(constants.GLYPH)
    D.setfield(glyph, "width", 65536 * 10)
    D.setfield(glyph, "height", 65536 * 8)
    D.setfield(glyph, "depth", 0)
    D.setfield(glyph, "char", 65)
    D.setfield(glyph, "font", 0)

    local pos = { col = 2, row = 0 }
    local params = {
        vertical_align = "center",
        column_aligns = { [2] = "left" }
    }
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        jiazhu_align = "outward"
    }

    local new_head = internal.handle_glyph_node(glyph, glyph, pos, params, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head with alignment")
end)

test_utils.run_test("handle_glyph_node - jiazhu sub_col positioning", function()
    if not internal.handle_glyph_node then return end
    local glyph = D.new(constants.GLYPH)
    D.setfield(glyph, "width", 65536 * 5)
    D.setfield(glyph, "height", 65536 * 5)
    D.setfield(glyph, "depth", 0)
    D.setfield(glyph, "char", 65)
    D.setfield(glyph, "font", 0)

    local pos = { col = 0, row = 0, sub_col = 1 }
    local params = { vertical_align = "center" }
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        jiazhu_align = "outward"
    }

    local new_head = internal.handle_glyph_node(glyph, glyph, pos, params, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head with sub_col")
end)

-- ============================================================================
-- handle_block_node Tests
-- ============================================================================

test_utils.run_test("handle_block_node - basic hlist positioning", function()
    if not internal.handle_block_node then return end
    local hlist = D.new(constants.HLIST)
    D.setfield(hlist, "width", 65536 * 20)
    D.setfield(hlist, "height", 65536 * 15)

    local pos = { col = 0, row = 0, width = 2, height = 2, is_block = true }
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.handle_block_node(hlist, hlist, pos, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head")
    local shift = D.getfield(hlist, "shift")
    test_utils.assert_eq(shift ~= nil, true, "Block shift should be set")
end)

test_utils.run_test("handle_block_node - vlist positioning", function()
    if not internal.handle_block_node then return end
    local vlist = D.new(constants.VLIST)
    D.setfield(vlist, "width", 65536 * 30)
    D.setfield(vlist, "height", 65536 * 25)

    local pos = { col = 1, row = 2, width = 3, height = 3, is_block = true }
    local ctx = {
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        p_total_cols = 10,
        shift_x = 1000,
        shift_y = 2000,
        half_thickness = 500
    }

    local new_head = internal.handle_block_node(vlist, vlist, pos, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head for vlist")
end)

-- ============================================================================
-- handle_decorate_node Tests
-- ============================================================================

test_utils.run_test("handle_decorate_node - invalid registry id", function()
    if not internal.handle_decorate_node then return end
    _G.decorate_registry = {}

    local marker = D.new(constants.GLYPH)
    local pos = { col = 0, row = 1 }
    local params = {}
    local ctx = {
        grid_width = 65536,
        grid_height = 65536,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.handle_decorate_node(marker, marker, pos, params, ctx, 999)
    test_utils.assert_eq(new_head, marker, "Should return original head for invalid id")
end)

test_utils.run_test("handle_decorate_node - valid registry entry", function()
    if not internal.handle_decorate_node then return end
    _G.decorate_registry = {
        [1] = {
            char = 9679,
            xoffset = 0,
            yoffset = 0,
            color = "red",
            font_id = 0
        }
    }

    local marker = D.new(constants.GLYPH)
    D.set_attribute(marker, constants.ATTR_DECORATE_ID or 100, 1)
    local pos = { col = 0, row = 1 }
    local params = {}
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        last_font_id = 0
    }

    local new_head = internal.handle_decorate_node(marker, marker, pos, params, ctx, 1)
    test_utils.assert_eq(type(new_head), "table", "Should return head with decorate nodes")
end)

-- ============================================================================
-- handle_debug_drawing Tests
-- ============================================================================

test_utils.run_test("handle_debug_drawing - returns head", function()
    if not internal.handle_debug_drawing then return end
    local glyph = D.new(constants.GLYPH)
    local pos = { col = 0, row = 0 }
    local ctx = {
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        outer_shift = 0
    }

    local new_head = internal.handle_debug_drawing(glyph, glyph, pos, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head")
end)

-- ============================================================================
-- process_page_nodes Tests
-- ============================================================================

test_utils.run_test("process_page_nodes - single glyph", function()
    if not internal.process_page_nodes then return end
    local g1 = D.new(constants.GLYPH)
    D.setfield(g1, "width", 65536 * 10)
    D.setfield(g1, "height", 65536 * 8)
    D.setfield(g1, "depth", 0)
    D.setfield(g1, "char", 65)
    D.setfield(g1, "font", 0)

    local layout_map = {
        [g1] = { col = 0, row = 0 }
    }

    local params = { vertical_align = "center" }
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        jiazhu_align = "outward"
    }

    local new_head = internal.process_page_nodes(g1, layout_map, params, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head")
end)

test_utils.run_test("process_page_nodes - glue zeroing", function()
    if not internal.process_page_nodes then return end
    local glue = D.new(constants.GLUE)
    D.setfield(glue, "width", 65536 * 5)
    D.setfield(glue, "stretch", 65536)
    D.setfield(glue, "shrink", 65536)

    local layout_map = {}
    local params = {}
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.process_page_nodes(glue, layout_map, params, ctx)
    test_utils.assert_eq(D.getfield(glue, "width"), 0, "Glue width should be zeroed")
    test_utils.assert_eq(D.getfield(glue, "stretch"), 0, "Glue stretch should be zeroed")
    test_utils.assert_eq(D.getfield(glue, "shrink"), 0, "Glue shrink should be zeroed")
end)

test_utils.run_test("process_page_nodes - kern zeroing", function()
    if not internal.process_page_nodes then return end
    local kern = D.new(constants.KERN)
    D.setfield(kern, "kern", 65536 * 5)
    D.setfield(kern, "subtype", 0)

    local layout_map = {}
    local params = {}
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.process_page_nodes(kern, layout_map, params, ctx)
    test_utils.assert_eq(D.getfield(kern, "kern"), 0, "Non-explicit kern should be zeroed")
end)

test_utils.run_test("process_page_nodes - explicit kern preserved", function()
    if not internal.process_page_nodes then return end
    local kern = D.new(constants.KERN)
    D.setfield(kern, "kern", 65536 * 5)
    D.setfield(kern, "subtype", 1)

    local layout_map = {}
    local params = {}
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.process_page_nodes(kern, layout_map, params, ctx)
    test_utils.assert_eq(D.getfield(kern, "kern"), 65536 * 5, "Explicit kern should be preserved")
end)

test_utils.run_test("process_page_nodes - invalid column skipped", function()
    if not internal.process_page_nodes then return end
    local g1 = D.new(constants.GLYPH)
    D.setfield(g1, "width", 65536 * 10)
    D.setfield(g1, "char", 65)
    D.setfield(g1, "font", 0)

    local layout_map = {
        [g1] = { col = -1, row = 0 }
    }

    local params = {}
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.process_page_nodes(g1, layout_map, params, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head even with invalid col")
end)

-- ============================================================================
-- render_sidenotes Tests
-- ============================================================================

test_utils.run_test("render_sidenotes - empty list", function()
    if not internal.render_sidenotes then return end
    local head = D.new(constants.GLYPH)
    local new_head = internal.render_sidenotes(head, nil, {}, {})
    test_utils.assert_eq(new_head, head, "Empty sidenotes should return original head")
end)

test_utils.run_test("render_sidenotes - basic positioning", function()
    if not internal.render_sidenotes then return end
    local main_glyph = D.new(constants.GLYPH)

    local sidenote_glyph = D.new(constants.GLYPH)
    D.setfield(sidenote_glyph, "width", 65536 * 5)
    D.setfield(sidenote_glyph, "height", 65536 * 5)
    D.setfield(sidenote_glyph, "depth", 0)
    D.setfield(sidenote_glyph, "char", 65)
    D.setfield(sidenote_glyph, "font", 0)

    local sidenote_nodes = {
        { node = sidenote_glyph, col = 1, row = 0, metadata = {} }
    }

    local params = { vertical_align = "center" }
    local ctx = {
        grid_width = 65536 * 12,
        grid_height = 65536 * 12,
        p_total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0
    }

    local new_head = internal.render_sidenotes(main_glyph, sidenote_nodes, params, ctx)
    test_utils.assert_eq(type(new_head), "table", "Should return head with sidenotes")
end)

-- ============================================================================
-- position_floating_box Tests
-- ============================================================================

test_utils.run_test("position_floating_box - basics", function()
    if not internal.position_floating_box then return end
    local box = D.new(constants.HLIST)
    D.setfield(box, "width", 100)
    D.setfield(box, "height", 100)

    local item = { box = box, x = 0, y = 0 }
    local params = { paper_width = 1000, margin_left = 0, margin_top = 0, draw_debug = false }

    local res = internal.position_floating_box(nil, item, params)
    test_utils.assert_eq(type(res), "table", "Should return head")
end)

test_utils.run_test("position_floating_box - with margins", function()
    if not internal.position_floating_box then return end
    local box = D.new(constants.HLIST)
    D.setfield(box, "width", 65536 * 100)
    D.setfield(box, "height", 65536 * 50)

    local item = { box = box, x = 65536 * 50, y = 65536 * 30 }
    local params = {
        paper_width = 65536 * 500,
        margin_left = 65536 * 50,
        margin_top = 65536 * 50
    }

    local res = internal.position_floating_box(nil, item, params)
    test_utils.assert_eq(type(res), "table", "Should return head with margins")
end)

-- ============================================================================
-- render_single_page Tests
-- ============================================================================

test_utils.run_test("render_single_page - basic", function()
    if not internal.render_single_page then return end
    local head = D.new(constants.GLYPH)
    D.setfield(head, "width", 65536 * 10)
    D.setfield(head, "height", 65536 * 8)
    D.setfield(head, "char", 65)
    D.setfield(head, "font", 0)

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

test_utils.run_test("render_single_page - nil head", function()
    if not internal.render_single_page then return end
    local params = { grid_width = 100, grid_height = 100 }
    local ctx = internal.calculate_render_context(params)

    local res_head, cols = internal.render_single_page(nil, 0, 0, {}, params, ctx)
    test_utils.assert_eq(res_head, nil, "Should return nil for nil head")
    test_utils.assert_eq(cols, 0, "Should have 0 cols for nil head")
end)

test_utils.run_test("render_single_page - with borders", function()
    if not internal.render_single_page then return end
    local head = D.new(constants.GLYPH)
    D.setfield(head, "width", 65536 * 10)
    D.setfield(head, "char", 65)
    D.setfield(head, "font", 0)

    local layout_map = { [head] = { page = 0, col = 0, row = 0 } }
    local params = {
        draw_border = true,
        draw_outer_border = true,
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        total_pages = 1,
        b_padding_top = 0,
        b_padding_bottom = 0
    }
    local ctx = internal.calculate_render_context(params)

    local res_head, cols = internal.render_single_page(head, 0, 0, layout_map, params, ctx)
    test_utils.assert_eq(type(res_head), "table", "Should return head with borders")
end)

test_utils.run_test("render_single_page - enforces page_columns minimum", function()
    if not internal.render_single_page then return end
    local head = D.new(constants.GLYPH)
    D.setfield(head, "width", 65536 * 10)
    D.setfield(head, "char", 65)
    D.setfield(head, "font", 0)

    local layout_map = { [head] = { page = 0, col = 2, row = 0 } }
    local params = {
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        page_columns = 10,
        total_pages = 1
    }
    local ctx = internal.calculate_render_context(params)

    local res_head, cols = internal.render_single_page(head, 2, 0, layout_map, params, ctx)
    test_utils.assert_eq(cols, 10, "Should enforce page_columns minimum")
end)

-- ============================================================================
-- Integration Tests
-- ============================================================================

test_utils.run_test("render-page - apply positions", function()
    local n1 = D.new(constants.GLYPH)
    D.setfield(n1, "width", 65536 * 10)
    D.setfield(n1, "height", 65536 * 8)
    D.setfield(n1, "char", 65)
    D.setfield(n1, "font", 0)

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
        total_pages = 2
    }

    local pages = render.apply_positions(n1, map, params)
    test_utils.assert_eq(#pages, 1, "Should generate 1 page list")
    test_utils.assert_eq(type(pages[1].head), "table", "Page head should be a node table")
end)

test_utils.run_test("render-page - multi page rendering", function()
    local nodes = {}
    for i = 1, 4 do
        nodes[i] = D.new(constants.GLYPH)
        D.setfield(nodes[i], "width", 65536 * 10)
        D.setfield(nodes[i], "char", 65)
        D.setfield(nodes[i], "font", 0)
        if i > 1 then D.setlink(nodes[i - 1], nodes[i]) end
    end

    local map = {
        [nodes[1]] = { page = 0, col = 0, row = 0 },
        [nodes[2]] = { page = 0, col = 1, row = 0 },
        [nodes[3]] = { page = 1, col = 0, row = 0 },
        [nodes[4]] = { page = 1, col = 2, row = 0 }
    }

    local params = {
        grid_width = 655360,
        grid_height = 655360,
        page_columns = 5,
        line_limit = 10,
        total_pages = 2
    }

    local pages = render.apply_positions(nodes[1], map, params)
    test_utils.assert_eq(#pages, 2, "Should generate 2 pages")
end)

print("\nAll render-page tests passed!")
