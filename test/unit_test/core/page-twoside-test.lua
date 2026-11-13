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
    _G.page.mirror_margins = true
    _G.page.binding_offset = 0

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

-- Test 2: Enabled twoside - odd (left) page: outer on left, inner (spine) on right
test_utils.run_test("page-twoside: Enabled twoside - odd page margins", function()
    local page_num = 1  -- Odd page
    local inner = 18 * 65536
    local outer = 22 * 65536

    local width = calc_content_width(page_num, true, inner, outer, 0, 0)

    -- For odd page (left page of a right-bound vertical book): left=outer, right=inner
    -- Content width = 170mm - 18mm - 22mm = 130mm
    local expected_width = (170 - 18 - 22) * 65536

    test_utils.assert_eq(width, expected_width, "Odd page: outer on left, inner on right")
end)

-- Test 3: Enabled twoside - even (right) page: inner (spine) on left, outer on right
test_utils.run_test("page-twoside: Enabled twoside - even page margins", function()
    local page_num = 2  -- Even page
    local inner = 18 * 65536
    local outer = 22 * 65536

    local width = calc_content_width(page_num, true, inner, outer, 0, 0)

    -- For even page: left=inner (18mm), right=outer (22mm)
    -- Content width = 170mm - 22mm - 18mm = 130mm
    local expected_width = (170 - 22 - 18) * 65536

    test_utils.assert_eq(width, expected_width, "Even page: inner on left, outer on right")
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

-- Test 9: twoside=false ignores inner/outer entirely
test_utils.run_test("page-twoside: twoside=false ignores inner/outer", function()
    local width = calc_content_width(1, false, 16 * 65536, 24 * 65536, 20 * 65536, 20 * 65536)
    test_utils.assert_eq(width, (170 - 20 - 20) * 65536, "Only margin-left/right used")
    local l, r = page_mod.get_effective_margins(2)
    test_utils.assert_eq(l, 20 * 65536, "even page left = margin-left")
    test_utils.assert_eq(r, 20 * 65536, "even page right = margin-right")
end)

-- Test 10: twoside=true ignores left/right entirely; inner is the spine side
-- (vertical books bind on the right: odd = left page, spine on its right)
test_utils.run_test("page-twoside: twoside=true ignores left/right", function()
    local width = calc_content_width(1, true, 16 * 65536, 24 * 65536, 5 * 65536, 5 * 65536)
    test_utils.assert_eq(width, (170 - 16 - 24) * 65536, "Only inner/outer used")
    local l1, r1 = page_mod.get_effective_margins(1)
    local l2, r2 = page_mod.get_effective_margins(2)
    test_utils.assert_eq(l1, 24 * 65536, "odd left = outer (fore-edge)")
    test_utils.assert_eq(r1, 16 * 65536, "odd right = inner (spine)")
    test_utils.assert_eq(l2, 16 * 65536, "even left = inner (spine)")
    test_utils.assert_eq(r2, 24 * 65536, "even right = outer (fore-edge)")
end)

-- Test 11: twoside=false with only margin-left/right (no inner/outer) is symmetric per page
test_utils.run_test("page-twoside: twoside=false pages are identical", function()
    local l1, r1 = page_mod.get_effective_margins(1)
    _G.page.twoside = false
    _G.page.margin_left = 16 * 65536
    _G.page.margin_right = 16 * 65536
    for pn = 1, 4 do
        local l, r = page_mod.get_effective_margins(pn)
        test_utils.assert_eq(l, 16 * 65536, "page " .. pn .. " left")
        test_utils.assert_eq(r, 16 * 65536, "page " .. pn .. " right")
    end
end)

-- Test 12: warning only when the ignored group is changed by the call
test_utils.run_test("page-twoside: ignored-margin warning", function()
    local msgs = {}
    local orig = texio.write_nl
    texio.write_nl = function(_, m) msgs[#msgs + 1] = m end
    _G.page.quiet = false
    _G.page.twoside = false
    _G.page.margin_inner = 0
    _G.page.margin_outer = 0
    page_mod.setup({ twoside = false, margin_left = "16mm", margin_right = "16mm" })
    test_utils.assert_eq(#msgs, 0, "no warning for the active group")
    page_mod.setup({ twoside = false, margin_left = "16mm", margin_right = "16mm", margin_inner = "10mm" })
    test_utils.assert_eq(#msgs, 1, "warning when inner is set with twoside=false")
    page_mod.setup({ twoside = false, margin_left = "16mm", margin_right = "16mm", margin_inner = "10mm" })
    test_utils.assert_eq(#msgs, 1, "no repeat warning for unchanged value")
    _G.page.quiet = true
    page_mod.setup({ twoside = true, margin_left = "30mm" })
    test_utils.assert_eq(#msgs, 1, "quiet suppresses warning")
    _G.page.quiet = false
    texio.write_nl = orig
end)

-- Test 13: switching twoside onto an all-zero margin group warns even when
-- no margin key changed in the same call (ltc-guji user writing only twoside=true)
test_utils.run_test("page-twoside: warning when twoside switches to a zero margin group", function()
    local msgs = {}
    local orig = texio.write_nl
    texio.write_nl = function(_, m) msgs[#msgs + 1] = m end
    _G.page.quiet = false
    -- class config: only left/right set, like ltc-guji before this fix
    _G.page.twoside = false
    _G.page.margin_left = 133 * 65536
    _G.page.margin_right = 133 * 65536
    _G.page.margin_inner = 0
    _G.page.margin_outer = 0
    page_mod.setup({ twoside = true, margin_left = "133pt", margin_right = "133pt" })
    test_utils.assert_eq(#msgs, 1, "warns: twoside=true with inner/outer both 0")
    test_utils.assert_true(msgs[1]:find("margin%-inner/margin%-outer are both 0") ~= nil, "message names the empty group")
    -- same call again: twoside did not switch, no repeat
    page_mod.setup({ twoside = true, margin_left = "133pt", margin_right = "133pt" })
    test_utils.assert_eq(#msgs, 1, "no repeat warning when twoside unchanged")
    -- with inner/outer provided (templates after this fix) there is nothing to warn
    _G.page.twoside = false
    _G.page.margin_inner = 133 * 65536
    _G.page.margin_outer = 133 * 65536
    page_mod.setup({ twoside = true, margin_left = "133pt", margin_right = "133pt" })
    test_utils.assert_eq(#msgs, 1, "no warning when inner/outer are set")
    -- the mirror case: twoside switched off with left/right both 0
    _G.page.twoside = true
    _G.page.margin_left = 0
    _G.page.margin_right = 0
    page_mod.setup({ twoside = false, margin_inner = "133pt", margin_outer = "133pt" })
    test_utils.assert_eq(#msgs, 2, "warns: twoside=false with left/right both 0")
    _G.page.quiet = false
    texio.write_nl = orig
end)

-- ============================================================================
-- Issue #198: fixed content area (mirror-margins=false) + binding offset
-- ============================================================================

local MM = 186467 -- sp per mm (rounded, as constants.to_dimen gives for "1mm")

local function set_fixed(twoside, mirror, left, right, inner, outer, gutter)
    _G.page.twoside = twoside
    _G.page.mirror_margins = mirror
    _G.page.margin_left = left
    _G.page.margin_right = right
    _G.page.margin_inner = inner
    _G.page.margin_outer = outer
    _G.page.binding_offset = gutter
end

test_utils.run_test("page-twoside #198: mirror-margins=false keeps left/right on every page", function()
    set_fixed(true, false, 20 * 65536, 25 * 65536, 10 * 65536, 30 * 65536, 0)
    for pn = 1, 4 do
        local l, r = page_mod.get_effective_margins(pn)
        test_utils.assert_eq(l, 20 * 65536, "page " .. pn .. " left = margin-left")
        test_utils.assert_eq(r, 25 * 65536, "page " .. pn .. " right = margin-right")
    end
    test_utils.assert_true(page_mod.uses_left_right(), "left/right group in force")
end)

test_utils.run_test("page-twoside #198: binding offset goes to the spine side", function()
    local g = 8 * 65536
    -- fixed area: odd (left) page gets the gutter on its right, even on its left
    set_fixed(true, false, 20 * 65536, 20 * 65536, 0, 0, g)
    local l1, r1 = page_mod.get_effective_margins(1)
    local l2, r2 = page_mod.get_effective_margins(2)
    test_utils.assert_eq(l1, 20 * 65536, "odd left unchanged")
    test_utils.assert_eq(r1, 28 * 65536, "odd right = right + gutter")
    test_utils.assert_eq(l2, 28 * 65536, "even left = left + gutter")
    test_utils.assert_eq(r2, 20 * 65536, "even right unchanged")
    test_utils.assert_eq(l1 + r1, l2 + r2, "content width equal on both pages")
    -- mirrored: gutter adds to inner
    set_fixed(true, true, 0, 0, 16 * 65536, 24 * 65536, g)
    l1, r1 = page_mod.get_effective_margins(1)
    l2, r2 = page_mod.get_effective_margins(2)
    test_utils.assert_eq(r1, 24 * 65536, "odd spine = inner + gutter")
    test_utils.assert_eq(l2, 24 * 65536, "even spine = inner + gutter")
    test_utils.assert_eq(l1, 24 * 65536, "odd fore-edge = outer")
    -- twoside=false: every page bound on the right
    set_fixed(false, true, 20 * 65536, 20 * 65536, 0, 0, g)
    for pn = 1, 2 do
        local l, r = page_mod.get_effective_margins(pn)
        test_utils.assert_eq(l, 20 * 65536, "single-sided page " .. pn .. " left")
        test_utils.assert_eq(r, 28 * 65536, "single-sided page " .. pn .. " right + gutter")
    end
    set_fixed(true, true, 0, 0, 16 * 65536, 24 * 65536, 0)
end)

test_utils.run_test("page-twoside #198: setup() parses mirror-margins and binding-offset", function()
    _G.page.quiet = true
    page_mod.setup({ twoside = true, mirror_margins = false, binding_offset = "8mm" })
    test_utils.assert_eq(_G.page.mirror_margins, false, "mirror_margins stored")
    test_utils.assert_true(math.abs(_G.page.binding_offset - 8 * MM) < 16, "binding_offset stored in sp")
    page_mod.setup({ mirror_margins = true, binding_offset = "" })
    test_utils.assert_eq(_G.page.binding_offset, 0, "empty binding_offset = 0")
    _G.page.quiet = false
end)

test_utils.run_test("page-twoside #198: warning names mirror-margins=false", function()
    local msgs = {}
    local orig = texio.write_nl
    texio.write_nl = function(_, m) msgs[#msgs + 1] = m end
    _G.page.quiet = false
    set_fixed(true, true, 20 * 65536, 20 * 65536, 16 * 65536, 16 * 65536, 0)
    page_mod.setup({ twoside = true, mirror_margins = false })
    test_utils.assert_eq(#msgs, 0, "switching to fixed with left/right set: no warning")
    page_mod.setup({ twoside = true, mirror_margins = false, margin_inner = "10mm" })
    test_utils.assert_eq(#msgs, 1, "inner changed while fixed: warning")
    test_utils.assert_true(msgs[1]:find("mirror%-margins=false") ~= nil, "message names the mode")
    texio.write_nl = orig
    set_fixed(true, true, 0, 0, 16 * 65536, 24 * 65536, 0)
end)

test_utils.run_test("page-twoside #198: spine side and current page", function()
    _G.page.twoside = true
    test_utils.assert_true(page_mod.spine_on_right(1), "odd page: spine on right")
    test_utils.assert_true(not page_mod.spine_on_right(2), "even page: spine on left")
    _G.page.twoside = false
    test_utils.assert_true(page_mod.spine_on_right(2), "single-sided: spine always on right")
    _G.page.twoside = true
    local old_count = tex.count
    tex.count = { [0] = 7 }
    test_utils.assert_eq(page_mod.current_page(), 7, "current page reads \\count0")
    set_fixed(true, false, 20 * 65536, 30 * 65536, 0, 0, 0)
    test_utils.assert_eq(page_mod.current_left_margin_str(), "20.00000pt", "left margin string")
    tex.count = old_count
    set_fixed(true, true, 0, 0, 16 * 65536, 24 * 65536, 0)
end)

print("\nAll page-twoside tests passed!")
