-- Unit tests for core/luatex-cn-core-param-check.lua (issue #195):
-- a parameter that another one silently overrides gets one warning,
-- but only when the user set it (not a template), and only once per document.
local test_utils = require 'test.test_utils'
local check = require 'core.luatex-cn-core-param-check'

local PT = 65536

-- Capture warnings written through texio
local messages
local function capture()
    messages = {}
    texio.write_nl = function(_, s) messages[#messages + 1] = s end
end
local function count_matching(pattern)
    local n = 0
    for _, m in ipairs(messages) do
        if m:find(pattern, 1, true) then n = n + 1 end
    end
    return n
end

local function fresh()
    check._reset()
    capture()
end

test_utils.run_test("param-check: grid-height ignored while n-char-per-col > 0", function()
    fresh()
    check.mark("grid_height")
    check.guji_layout({ n_column = 8, n_char_per_col = 21, grid_width_sp = 51 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(count_matching("grid-height is ignored"), 1, "one grid-height warning")
    test_utils.assert_eq(count_matching("28.00pt"), 1, "message names the computed grid height")
end)

test_utils.run_test("param-check: no warning when n-char-per-col = 0", function()
    fresh()
    check.mark("grid_height")
    check.guji_layout({ n_column = 8, n_char_per_col = 0, grid_width_sp = 51 * PT, grid_height_sp = 40 * PT })
    test_utils.assert_eq(count_matching("grid-height"), 0, "grid-height is honoured, no warning")
end)

test_utils.run_test("param-check: template values (quiet) are not user settings", function()
    fresh()
    check.quiet(true)
    check.mark("grid_height")
    check.mark("grid_width")
    check.quiet(true)   -- nested template load
    check.quiet(false)
    check.mark("page_columns")
    check.quiet(false)
    test_utils.assert_false(check.is_user_set("grid_height"), "grid_height set by template")
    test_utils.assert_false(check.is_user_set("page_columns"), "still quiet inside nesting")
    check.guji_layout({ n_column = 8, n_char_per_col = 21, grid_width_sp = 51 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(#messages, 0, "no warnings for template values")
    check.mark("grid_height")
    test_utils.assert_true(check.is_user_set("grid_height"), "after the template, marks count")
    check.quiet(false) -- unbalanced pop must not go negative
    check.mark("grid_width")
    test_utils.assert_true(check.is_user_set("grid_width"), "depth stays at 0")
end)

test_utils.run_test("param-check: grid-width ignored while n-column > 0", function()
    fresh()
    check.mark("grid_width")
    check.guji_layout({ n_column = 8, n_char_per_col = 0, grid_width_sp = 51 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(count_matching("grid-width is ignored"), 1, "grid-width warning")
    fresh()
    check.mark("grid_width")
    check.guji_layout({ n_column = 0, n_char_per_col = 0, grid_width_sp = 40 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(#messages, 0, "free mode (n-column = 0) keeps grid-width")
end)

test_utils.run_test("param-check: each warning once per document", function()
    fresh()
    check.mark("grid_height")
    for _ = 1, 3 do
        check.guji_layout({ n_column = 8, n_char_per_col = 21, grid_width_sp = 51 * PT, grid_height_sp = 28 * PT })
    end
    test_utils.assert_eq(count_matching("grid-height is ignored"), 1, "deduplicated")
end)

test_utils.run_test("param-check: page-columns with banxin / with n-column", function()
    fresh()
    check.page_columns(10, true)
    test_utils.assert_eq(#messages, 0, "page-columns not set by user: silent")
    check.mark("page_columns")
    check.page_columns(0, true)
    test_utils.assert_eq(#messages, 0, "page-columns empty: silent")
    check.page_columns(10, true)
    test_utils.assert_eq(count_matching("does not reserve the banxin"), 1, "banxin warning")
    fresh()
    check.mark("page_columns")
    check.page_columns(10, false)
    test_utils.assert_eq(#messages, 0, "no banxin, n-column untouched: silent")
    check.mark("n_column")
    check.page_columns(10, false)
    test_utils.assert_eq(count_matching("page-columns overrides n-column"), 1, "n-column warning")
end)

test_utils.run_test("param-check: font-size larger than the grid height", function()
    fresh()
    check.font_fit({ font_size_sp = 40 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(#messages, 0, "neither font-size nor n-char-per-col set by the user: silent")
    check.mark("font_size")
    check.font_fit({ font_size_sp = 24 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(#messages, 0, "fits")
    check.font_fit({ font_size_sp = 28.3 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(#messages, 0, "within 0.5pt rounding tolerance")
    check.font_fit({ font_size_sp = 40 * PT, grid_height_sp = 28 * PT, layout_mode = "natural" })
    test_utils.assert_eq(#messages, 0, "natural mode has no grid")
    check.font_fit({ font_size_sp = 40 * PT, grid_height_sp = 28 * PT })
    test_utils.assert_eq(count_matching("larger than the grid height"), 1, "height warning")
    fresh()
    check.mark("n_char_per_col")
    check.font_fit({ font_size_sp = 28 * PT, grid_height_sp = 20 * PT })
    test_utils.assert_eq(count_matching("larger than the grid height"), 1, "user raised n-char-per-col")
    fresh()
    check.mark("font_size")
    check.font_fit({ font_size_sp = "1em", grid_height_sp = nil })
    test_utils.assert_eq(#messages, 0, "non-numeric / unset values are skipped")
end)

test_utils.run_test("param-check: banxin ratios", function()
    fresh()
    check.banxin_ratios(0.282, 0.563)
    check.banxin_ratios(0.5, 0.5)
    test_utils.assert_eq(#messages, 0, "sum <= 1 is fine")
    check.banxin_ratios("0.6", "0.6")
    test_utils.assert_eq(count_matching("must not exceed 1"), 1, "sum > 1 warns")
    test_utils.assert_eq(count_matching("1.2 > 1"), 1, "message shows the sum")
    fresh()
    check.banxin_ratios(nil, 0.6)
    test_utils.assert_eq(#messages, 0, "missing value: skip")
end)

check._reset()
texio.write_nl = function() end
print("\nAll param-check tests passed!")
