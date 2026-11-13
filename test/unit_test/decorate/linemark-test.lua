-- Unit tests for decorate.luatex-cn-linemark
local test_utils = require("test.test_utils")

-- Mock textflow module
package.loaded['core.luatex-cn-textflow'] = package.loaded['core.luatex-cn-textflow'] or {
    calculate_sub_column_x_offset = function(base_x) return base_x end,
}

local linemark = require("decorate.luatex-cn-linemark")

-- ============================================================================
-- Module loads
-- ============================================================================

test_utils.run_test("linemark: module loads", function()
    test_utils.assert_type(linemark, "table")
    test_utils.assert_type(linemark.render_line_marks, "function")
end)

-- ============================================================================
-- render_line_marks: empty entries (smoke test)
-- ============================================================================

test_utils.run_test("render_line_marks: empty entries does not error", function()
    local head = node.direct.new(node.id("whatsit"), 1)
    local result = linemark.render_line_marks(head, {}, {
        shift_x = 0,
        grid_height = 65536 * 20,
        col_geom = { grid_width = 65536 * 20, banxin_width = 0, interval = 0 },
        p_cols = 10,
    })
    test_utils.assert_true(result ~= nil)
end)

-- ============================================================================
-- Inline 反白 (issue #201)
-- ============================================================================

test_utils.run_test("inverted_ordinal: running ordinal and group total", function()
    local map = { [1] = { invert_id = 7 }, [2] = { invert_id = 7 },
                  [3] = { invert_id = 7 }, [4] = { invert_id = 8 }, [5] = {} }
    local n1, t1 = linemark.inverted_ordinal(map, 7)
    local n2, t2 = linemark.inverted_ordinal(map, 7)
    local m1, u1 = linemark.inverted_ordinal(map, 8)
    test_utils.assert_eq(n1, 1); test_utils.assert_eq(t1, 3)
    test_utils.assert_eq(n2, 2); test_utils.assert_eq(t2, 3)
    test_utils.assert_eq(m1, 1); test_utils.assert_eq(u1, 1)
end)

test_utils.run_test("octagon_path: corners cut only where requested", function()
    local op = linemark._internal.octagon_path
    -- 8 vertices; with no cuts the first vertex is the top-left corner itself
    local square = op(0, 100, 10, 50, 2, false, false)
    test_utils.assert_true(square:find("^0%.0000 100%.0000 m") ~= nil)
    local both = op(0, 100, 10, 50, 2, true, true)
    test_utils.assert_true(both:find("^2%.0000 100%.0000 m") ~= nil)
    -- bottom cut only: last bottom vertex is (0, 52)
    local bot = op(0, 100, 10, 50, 2, false, true)
    test_utils.assert_true(bot:find("0%.0000 52%.0000 l") ~= nil)
    test_utils.assert_true(bot:find("^0%.0000 100%.0000 m") ~= nil)
end)

test_utils.run_test("render_line_marks: inverted run split at column break", function()
    _G.line_mark_registry = _G.line_mark_registry or {}
    _G.line_mark_registry[901] = { type = "inverted", shape = "octagon",
        background = "0.2 0.2 0.2", border_color = "0 0 0",
        border_width = 26214, break_style = "square" }
    local gh = 65536 * 20
    local entries = {
        { group_id = 901, col = 0, y_sp = 18 * gh, cell_height = gh, x_center_sp = 0, ordinal = 1, total = 4 },
        { group_id = 901, col = 0, y_sp = 19 * gh, cell_height = gh, x_center_sp = 0, ordinal = 2, total = 4 },
        { group_id = 901, col = 1, y_sp = 0, cell_height = gh, x_center_sp = 0, ordinal = 3, total = 4 },
        { group_id = 901, col = 1, y_sp = gh, cell_height = gh, x_center_sp = 0, ordinal = 4, total = 4 },
    }
    local head = node.direct.new(node.id("whatsit"), 1)
    local result = linemark.render_line_marks(head, entries, { grid_height = gh, shift_y = 0 })
    local n = 0
    local cur = result
    while cur do n = n + 1; cur = node.direct.getnext(cur) end
    -- two segments -> two literals inserted before the original head
    test_utils.assert_eq(n, 3)
end)

print("\nAll decorate/linemark-test tests passed!")
