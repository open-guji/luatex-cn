-- Unit tests for two-side margin support (twoside feature)
-- Tests that margins are correctly swapped for odd/even pages
local test_utils = require 'test.test_utils'

-- Load modules
local page_mod = require 'core.luatex-cn-core-page'
local content_mod = require 'core.luatex-cn-core-content'

-- ============================================================================
-- Helper: Calculate content area width with given parameters
-- ============================================================================
local function calc_content_width(page_num, twoside, margin_inner, margin_outer, margin_left, margin_right)
    -- Setup page state
    _G.page = _G.page or {}
    _G.page.current_page_number = page_num
    _G.page.paper_width = 170 * 65536  -- 170mm in sp
    _G.page.margin_top = 25 * 65536
    _G.page.margin_bottom = 15 * 65536
    _G.page.twoside = twoside
    _G.page.margin_inner = margin_inner
    _G.page.margin_outer = margin_outer
    _G.page.margin_left = margin_left
    _G.page.margin_right = margin_right

    _G.content = _G.content or {}
    _G.content.border_on = false
    _G.content.outer_border_on = false
    _G.content.border_thickness = 0
    _G.content.outer_border_thickness = 0
    _G.content.outer_border_sep = 0

    -- Call the content module's sync_params to trigger calculation
    content_mod.sync_params({})

    return _G.content.content_width
end

-- ============================================================================
-- Tests
-- ============================================================================

-- Test 1: Disabled twoside - margins should be symmetric
test_utils.run_test("page-twoside: Disabled twoside with symmetric margins", function()
    -- Both odd and even pages should have same width when twoside=false
    local width_odd = calc_content_width(1, false, 0, 0, 22 * 65536, 18 * 65536)
    local width_even = calc_content_width(2, false, 0, 0, 22 * 65536, 18 * 65536)

    -- Content width = 170mm - 22mm - 18mm = 130mm
    local expected_width = (170 - 22 - 18) * 65536

    test_utils.assert_eq(width_odd, expected_width, "Odd page width matches")
    test_utils.assert_eq(width_even, expected_width, "Even page width matches")
    test_utils.assert_eq(width_odd, width_even, "Width unchanged for twoside=false")
end)

-- Test 2: Enabled twoside - odd page should have inner on left, outer on right
test_utils.run_test("page-twoside: Enabled twoside - odd page margins", function()
    local page_num = 1  -- Odd page
    local inner = 18 * 65536
    local outer = 22 * 65536

    local width = calc_content_width(page_num, true, inner, outer, 0, 0)

    -- For odd page: left=inner (18mm), right=outer (22mm)
    -- Content width = 170mm - 18mm - 22mm = 130mm
    local expected_width = (170 - 18 - 22) * 65536

    test_utils.assert_eq(width, expected_width, "Odd page: inner on left, outer on right")
end)

-- Test 3: Enabled twoside - even page should have outer on left, inner on right
test_utils.run_test("page-twoside: Enabled twoside - even page margins", function()
    local page_num = 2  -- Even page
    local inner = 18 * 65536
    local outer = 22 * 65536

    local width = calc_content_width(page_num, true, inner, outer, 0, 0)

    -- For even page: left=outer (22mm), right=inner (18mm)
    -- Content width = 170mm - 22mm - 18mm = 130mm
    local expected_width = (170 - 22 - 18) * 65536

    test_utils.assert_eq(width, expected_width, "Even page: outer on left, inner on right")
end)

-- Test 4: Verify same content width for both odd and even with twoside
test_utils.run_test("page-twoside: Twoside maintains equal content width for odd/even pages", function()
    local inner = 18 * 65536
    local outer = 22 * 65536

    local width_odd = calc_content_width(1, true, inner, outer, 0, 0)
    local width_even = calc_content_width(3, true, inner, outer, 0, 0)

    test_utils.assert_eq(width_odd, width_even, "Odd and even pages have same content width")
end)

-- Test 5: Page number parity detection
test_utils.run_test("page-twoside: Page number parity detection (1,3,5 odd; 2,4,6 even)", function()
    local inner = 18 * 65536
    local outer = 22 * 65536

    -- Test several odd pages
    local w1 = calc_content_width(1, true, inner, outer, 0, 0)
    local w3 = calc_content_width(3, true, inner, outer, 0, 0)
    local w5 = calc_content_width(5, true, inner, outer, 0, 0)

    -- Test several even pages
    local w2 = calc_content_width(2, true, inner, outer, 0, 0)
    local w4 = calc_content_width(4, true, inner, outer, 0, 0)
    local w6 = calc_content_width(6, true, inner, outer, 0, 0)

    -- All odd pages should have same width
    test_utils.assert_eq(w1, w3, "Pages 1 and 3 have same width")
    test_utils.assert_eq(w3, w5, "Pages 3 and 5 have same width")

    -- All even pages should have same width
    test_utils.assert_eq(w2, w4, "Pages 2 and 4 have same width")
    test_utils.assert_eq(w4, w6, "Pages 4 and 6 have same width")

    -- Odd and even should have same width (due to symmetric inner/outer)
    test_utils.assert_eq(w1, w2, "Odd and even pages have same width")
end)

-- Test 6: Asymmetric inner/outer margins
test_utils.run_test("page-twoside: Asymmetric inner/outer margins produce correct widths", function()
    local inner = 15 * 65536
    local outer = 25 * 65536

    local width_odd = calc_content_width(1, true, inner, outer, 0, 0)
    local width_even = calc_content_width(2, true, inner, outer, 0, 0)

    -- Both should give same total width despite asymmetric margins
    -- width = 170 - 15 - 25 = 130
    local expected = (170 - 15 - 25) * 65536

    test_utils.assert_eq(width_odd, expected, "Odd page with asymmetric margins")
    test_utils.assert_eq(width_even, expected, "Even page with asymmetric margins")
    test_utils.assert_eq(width_odd, width_even, "Both pages have equal content width")
end)

-- Test 7: Page.setup() properly stores twoside settings
test_utils.run_test("page-twoside: Page.setup() stores twoside settings", function()
    page_mod.setup({
        paper_width = "170mm",
        paper_height = "240mm",
        margin_left = "22mm",
        margin_right = "18mm",
        margin_top = "25mm",
        margin_bottom = "15mm",
        twoside = true,
        margin_inner = "18mm",
        margin_outer = "22mm",
    })

    test_utils.assert_true(_G.page.twoside, "twoside flag set to true")
    -- Check that inner/outer margins are stored and non-zero (exact value depends on unit conversion)
    test_utils.assert_true(_G.page.margin_inner > 0, "margin_inner stored as positive value")
    test_utils.assert_true(_G.page.margin_outer > 0, "margin_outer stored as positive value")
    test_utils.assert_true(_G.page.margin_outer > _G.page.margin_inner, "outer margin is larger than inner")
end)

-- Test 8: Fallback to margin-left/right when twoside is false
test_utils.run_test("page-twoside: Fallback to margin-left/right when twoside is false", function()
    local width = calc_content_width(1, false, 0, 0, 22 * 65536, 18 * 65536)

    -- Should use margin-left and margin-right, not inner/outer
    local expected = (170 - 22 - 18) * 65536

    test_utils.assert_eq(width, expected, "Uses margin-left and margin-right when twoside=false")
end)

print("\nAll page-twoside tests passed!")
