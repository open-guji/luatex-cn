-- Unit tests for core.luatex-cn-core-render-page (smoke tests)
-- This module has heavy dependencies, so we test what's feasible.
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

-- Mock content module
package.loaded['core.luatex-cn-core-content'] = package.loaded['core.luatex-cn-core-content'] or {
    calculate_content_dimensions = function(params)
        local w = (params.actual_cols or 1) * (params.grid_width or 65536 * 20)
        local h = params.content_height_sp or 65536 * 200
        return w, h, w, h
    end,
    set_font_color = function() end,
}

-- Mock page module
package.loaded['core.luatex-cn-core-page'] = package.loaded['core.luatex-cn-core-page'] or {
    draw_background = function(p_head) return p_head end,
}

-- Mock textbox module
package.loaded['core.luatex-cn-core-textbox'] = package.loaded['core.luatex-cn-core-textbox'] or {
    render_floating_box = function() end,
}

-- Mock linemark module
package.loaded['decorate.luatex-cn-linemark'] = package.loaded['decorate.luatex-cn-linemark'] or {
    render = function() end,
}

-- Mock render-page-process module
package.loaded['core.luatex-cn-core-render-page-process'] = package.loaded['core.luatex-cn-core-render-page-process'] or {
    handle_glyph_node = function(curr, p_head) return p_head end,
    handle_block_node = function(curr, p_head) return p_head end,
    handle_debug_drawing = function(curr, p_head) return p_head end,
    handle_decorate_node = function(curr, p_head) return p_head end,
    process_page_nodes = function(p_head) return p_head end,
}

local render_page = require("core.luatex-cn-core-render-page")

-- ============================================================================
-- Module loads
-- ============================================================================

test_utils.run_test("render_page: module loads", function()
    test_utils.assert_type(render_page, "table")
    test_utils.assert_type(render_page.apply_positions, "function")
end)

test_utils.run_test("render_page: _internal exported", function()
    test_utils.assert_type(render_page._internal, "table")
    test_utils.assert_type(render_page._internal.calculate_render_context, "function")
    test_utils.assert_type(render_page._internal.group_nodes_by_page, "function")
end)

-- ============================================================================
-- _internal.calculate_render_context
-- ============================================================================

test_utils.run_test("calculate_render_context: returns table with expected fields", function()
    _G.content = _G.content or {}
    _G.page = _G.page or {}
    local gw = 65536 * 20
    local gh = 65536 * 20
    local bt = tex.sp("0.4pt")
    local ctx = {
        engine = {
            border_thickness = bt,
            half_thickness = math.floor(bt / 2),
            b_padding_top = 0,
            b_padding_bottom = 0,
            outer_shift = 0,
            shift_x = 0,
            shift_y = 0,
            border_rgb_str = "0 0 0",
        },
        grid = {
            width = gw,
            height = gh,
            banxin_width = 0,
            body_font_size = gw,
            n_column = 0,
            cols = 10,
            line_limit = 20,
        },
        page = {
            ob_thickness = bt,
            ob_sep = bt,
        },
        visual = {
            vertical_align = "center",
        },
    }
    local result = render_page._internal.calculate_render_context(ctx)
    test_utils.assert_type(result, "table")
    test_utils.assert_eq(result.grid_height, gh)
    test_utils.assert_eq(result.p_cols, 10)
    test_utils.assert_eq(result.line_limit, 20)
    test_utils.assert_eq(result.vertical_align, "center")
end)

-- ============================================================================
-- _internal.group_nodes_by_page
-- ============================================================================

test_utils.run_test("group_nodes_by_page: empty input", function()
    local result = render_page._internal.group_nodes_by_page(nil, {}, 0)
    test_utils.assert_type(result, "table")
end)

test_utils.run_test("group_nodes_by_page: single node on page 0", function()
    local constants = require("core.luatex-cn-constants")
    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 0x4E00)
    D.setfield(g, "font", 1)

    local layout_map = {}
    layout_map[g] = { page = 0, col = 0, y_sp = 0 }

    local result = render_page._internal.group_nodes_by_page(g, layout_map, 1)
    test_utils.assert_type(result, "table")
    test_utils.assert_true(result[0] ~= nil, "page 0 should exist")
    test_utils.assert_true(result[0].head ~= nil, "page 0 should have head")
    test_utils.assert_eq(result[0].max_col, 0)
end)

print("\nAll core/render-page-test tests passed!")
