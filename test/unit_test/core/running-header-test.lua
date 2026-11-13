-- Unit tests for the vbook running header / page number positions (issue #198)
local test_utils = require 'test.test_utils'
local rh = require 'core.luatex-cn-core-running-header'

local MM = 65536 -- use whole "mm" = 1pt units for readable arithmetic

local function setup_page(twoside, mirror, left, right, gutter)
    _G.page = _G.page or {}
    _G.page.paper_width = 170 * MM
    _G.page.paper_height = 240 * MM
    _G.page.margin_top = 30 * MM
    _G.page.margin_bottom = 20 * MM
    _G.page.twoside = twoside
    _G.page.mirror_margins = mirror
    _G.page.margin_left = left
    _G.page.margin_right = right
    _G.page.margin_inner = 24 * MM
    _G.page.margin_outer = 16 * MM
    _G.page.binding_offset = gutter or 0
end

local function settings(over)
    local s = {
        anchor = "content", header_position = "outer", number_position = "outer",
        header_sep = 6 * MM, header_y_set = false, number_y_set = false,
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

test_utils.run_test("running-header: outer side is physical (odd = left page)", function()
    setup_page(true, true, 0, 0)
    test_utils.assert_true(rh.on_left("outer", 1), "odd page outer = left")
    test_utils.assert_true(not rh.on_left("outer", 2), "even page outer = right")
    test_utils.assert_true(not rh.on_left("inner", 1), "odd page inner = right")
    test_utils.assert_true(rh.on_left("inner", 2), "even page inner = left")
    setup_page(false, true, 20 * MM, 20 * MM)
    test_utils.assert_true(rh.on_left("outer", 2), "single-sided: always left")
end)

test_utils.run_test("running-header: paper anchor keeps the old expressions", function()
    setup_page(true, true, 0, 0)
    local p1 = rh.positions(1, settings({ anchor = "paper" }))
    local p2 = rh.positions(2, settings({ anchor = "paper" }))
    test_utils.assert_eq(p1.header_x, "\\cnVbookPageNumX", "odd header on the left edge")
    test_utils.assert_eq(p2.header_x, "\\paperwidth-\\cnVbookPageNumX-2em", "even header on the right edge")
    test_utils.assert_eq(p1.number_x, p1.header_x, "number shares the header column")
    test_utils.assert_eq(p1.header_y, "-\\cnVbookHeaderY", "header y from paper top")
    test_utils.assert_eq(p1.number_y, "\\cnVbookPageNumY", "number y from paper bottom")
    local c = rh.positions(1, settings({ anchor = "paper", number_position = "center" }))
    test_utils.assert_eq(c.number_x, "0.5\\paperwidth-1em", "centered number")
end)

test_utils.run_test("running-header: content anchor follows the content area", function()
    setup_page(true, false, 20 * MM, 25 * MM)
    local p1 = rh.positions(1, settings())
    local p2 = rh.positions(2, settings())
    -- odd: outer = left edge of content (20) - sep (6) = 14
    test_utils.assert_eq(p1.header_x, "14.00000pt-1em", "odd header column")
    -- even: outer = right edge (170 - 25) + 6 = 151
    test_utils.assert_eq(p2.header_x, "151.00000pt-1em", "even header column")
    test_utils.assert_eq(p1.number_x, p1.header_x, "odd number in header column")
    test_utils.assert_eq(p1.header_y, "-30.00000pt", "header top on content top")
    test_utils.assert_eq(p1.number_y, "20.00000pt", "number foot on content bottom")
end)

test_utils.run_test("running-header: content anchor with binding offset and offsets", function()
    setup_page(true, false, 20 * MM, 20 * MM, 8 * MM)
    local p2 = rh.positions(2, settings())
    -- even page: content from 28 to 150; outer edge right 150 + 6
    test_utils.assert_eq(p2.header_x, "156.00000pt-1em", "even header beside shifted content")
    local p1 = rh.positions(1, settings({ header_y_set = true, number_y_set = true }))
    test_utils.assert_eq(p1.header_x, "14.00000pt-1em", "odd outer edge unaffected by gutter")
    test_utils.assert_eq(p1.header_y, "-30.00000pt-\\cnVbookHeaderY", "explicit header-y is an offset")
    test_utils.assert_eq(p1.number_y, "20.00000pt+\\cnVbookPageNumY", "explicit page-number-y is an offset")
    local c = rh.positions(1, settings({ number_position = "center" }))
    -- odd: content 20 .. 142 -> centre 81
    test_utils.assert_eq(c.number_x, "81.00000pt-1em", "centered on the content area")
    test_utils.assert_eq(c.number_y, "14.00000pt", "header-sep below the content bottom")
end)

print("\nAll running-header tests passed!")
