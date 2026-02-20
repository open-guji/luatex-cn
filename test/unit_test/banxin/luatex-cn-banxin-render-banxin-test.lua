-- Unit tests for banxin.luatex-cn-banxin-render-banxin
local test_utils = require('test.test_utils')

-- Mock textflow module (needed by render-position)
package.loaded['core.luatex-cn-textflow'] = package.loaded['core.luatex-cn-textflow'] or {
    calculate_sub_column_x_offset = function(base_x) return base_x end,
}

local banxin = require('banxin.luatex-cn-banxin-render-banxin')

-- Access internal functions for unit testing
local internal = banxin._internal

-- ============================================================================
-- Module loads
-- ============================================================================

test_utils.run_test("render-banxin: module loads", function()
    test_utils.assert_type(banxin, "table")
end)

test_utils.run_test("render-banxin: _internal exported", function()
    test_utils.assert_type(internal, "table")
end)

-- ============================================================================
-- Internal Helper Functions Tests
-- ============================================================================

test_utils.run_test("count_utf8_chars: ASCII", function()
    test_utils.assert_eq(internal.count_utf8_chars("hello"), 5)
end)

test_utils.run_test("count_utf8_chars: Chinese", function()
    test_utils.assert_eq(internal.count_utf8_chars("你好"), 2)
end)

test_utils.run_test("count_utf8_chars: Mixed", function()
    test_utils.assert_eq(internal.count_utf8_chars("Hello你好"), 7)
end)

test_utils.run_test("count_utf8_chars: Empty", function()
    test_utils.assert_eq(internal.count_utf8_chars(""), 0)
end)

test_utils.run_test("calculate_yuwei_dimensions: ratios", function()
    local width = 100 * 65536 -- 100pt
    local dims = internal.calculate_yuwei_dimensions(width)
    test_utils.assert_eq(dims.edge_height, width * 0.39)
    test_utils.assert_eq(dims.notch_height, width * 0.17)
    test_utils.assert_eq(dims.gap, 65536 * 3.7)
end)

test_utils.run_test("calculate_yuwei_total_height", function()
    local dims = {
        edge_height = 39 * 65536,
        notch_height = 17 * 65536,
        gap = 65536 * 3.7,
    }
    local total = internal.calculate_yuwei_total_height(dims)
    local expected = dims.gap + dims.edge_height + dims.notch_height
    test_utils.assert_eq(total, expected)
end)

test_utils.run_test("parse_chapter_title: single line", function()
    local parts = internal.parse_chapter_title("第一章")
    test_utils.assert_eq(#parts, 1)
    test_utils.assert_eq(parts[1], "第一章")
end)

test_utils.run_test("parse_chapter_title: multi-line with \\\\", function()
    local parts = internal.parse_chapter_title("第一章\\\\正文")
    test_utils.assert_eq(#parts, 2)
    test_utils.assert_eq(parts[1], "第一章")
    test_utils.assert_eq(parts[2], "正文")
end)

test_utils.run_test("parse_chapter_title: three lines", function()
    local parts = internal.parse_chapter_title("A\\\\B\\\\C")
    test_utils.assert_eq(#parts, 3)
end)

test_utils.run_test("parse_chapter_title: empty", function()
    local parts = internal.parse_chapter_title("")
    test_utils.assert_eq(#parts, 0)
end)

test_utils.run_test("create_border_literal: contains PDF commands", function()
    local literal = internal.create_border_literal(0, 0, 65536, 65536, 65536, "0 0 0")
    test_utils.assert_true(string.find(literal, "q") ~= nil, "Should contain 'q'")
    test_utils.assert_true(string.find(literal, "RG") ~= nil, "Should contain 'RG'")
    test_utils.assert_true(string.find(literal, "re") ~= nil, "Should contain 're'")
    test_utils.assert_true(string.find(literal, "S") ~= nil, "Should contain 'S'")
    test_utils.assert_true(string.find(literal, "Q") ~= nil, "Should contain 'Q'")
end)

test_utils.run_test("create_divider_literal: contains PDF commands", function()
    local literal = internal.create_divider_literal(0, 0, 65536, 65536, "1 0 0")
    test_utils.assert_true(string.find(literal, "m") ~= nil, "Should contain 'm' (moveto)")
    test_utils.assert_true(string.find(literal, "l") ~= nil, "Should contain 'l' (lineto)")
    test_utils.assert_true(string.find(literal, "1 0 0 RG") ~= nil, "Should contain color")
end)

-- ============================================================================
-- draw_banxin Tests
-- ============================================================================

test_utils.run_test("draw_banxin: default parameters", function()
    local result = banxin.draw_banxin({})
    test_utils.assert_type(result, "table")
    test_utils.assert_type(result.literals, "table")
    test_utils.assert_type(result.upper_height, "number")
end)

test_utils.run_test("draw_banxin: yuwei disabled", function()
    local params = {
        total_height = 100 * 65536,
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)
    -- Only 2 dividers, no yuwei
    test_utils.assert_eq(#result.literals, 2)
end)

test_utils.run_test("draw_banxin: dividers disabled", function()
    local params = {
        total_height = 100 * 65536,
        banxin_divider = false,
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)
    test_utils.assert_eq(#result.literals, 0)
end)

test_utils.run_test("draw_banxin: custom ratios", function()
    local params = {
        total_height = 200 * 65536,
        upper_ratio = 0.2,
        middle_ratio = 0.6,
    }
    local result = banxin.draw_banxin(params)
    test_utils.assert_eq(result.upper_height, 40 * 65536)
end)

test_utils.run_test("draw_banxin: color string in literals", function()
    local params = {
        total_height = 100 * 65536,
        color_str = "1 0 0",
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)
    local color_found = false
    for _, lit in ipairs(result.literals) do
        if string.find(lit, "1 0 0 RG") then
            color_found = true
            break
        end
    end
    test_utils.assert_true(color_found, "Color string should be in literals")
end)

print("\nAll render-banxin tests passed!")
