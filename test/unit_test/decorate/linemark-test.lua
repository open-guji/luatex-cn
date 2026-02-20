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

print("\nAll decorate/linemark-test tests passed!")
