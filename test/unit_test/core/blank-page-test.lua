-- Unit tests for issue #176: 对页补页 (facing pages) and 补空白页 (blank pages)
--   * layout-grid: PENALTY_BLANK_PAGE(_PLAIN) and the chapter-start padding
--   * core-page:   style normalisation, penalty selection, page-box marker
local test_utils = require("test.test_utils")

-- Same mocks as layout-grid-test: the layout module pulls these in at load time
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}
package.loaded['core.luatex-cn-hooks'] = {
    is_reserved_column = function(col, interval) return col % (interval + 1) == interval end,
    get_plugins = function() return {} end,
}
package.loaded['core.luatex-cn-textflow'] = package.loaded['core.luatex-cn-textflow'] or {
    calculate_sub_column_x_offset = function(base_x) return base_x end,
}

local layout_grid = require("core.luatex-cn-layout-grid")
local constants = require("core.luatex-cn-constants")
local page_mod = require("core.luatex-cn-core-page")
local D = node.direct
local I = layout_grid._internal

local GRID_H = 65536 * 20

local function make_ctx(overrides)
    local ctx = {
        cur_row = 0,
        cur_col = 0,
        cur_page = 0,
        cur_y_sp = 0,
        page_has_content = false,
        cur_column_indent = 0,
        occupancy = {},
        col_widths_sp = {},
        banxin_registry = {},
        p_cols = 10,
        n_bands = 1,
        layout_map = {},
        blank_pages = {},
        params = {},
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    _G.page = _G.page or {}
    _G.content = _G.content or {}
    return ctx
end

local function penalty(value)
    local n = D.new(constants.PENALTY)
    D.setfield(n, "penalty", value)
    return n
end

local function run_penalty(ctx, value)
    local n = penalty(value)
    local handled = I.handle_penalty_breaks(value, ctx, function() end, 10, 0, GRID_H, 0, n)
    return handled, n
end

-- ============================================================================
-- Constants
-- ============================================================================

test_utils.run_test("blank page penalties are distinct, unused values", function()
    test_utils.assert_eq(constants.PENALTY_BLANK_PAGE, -10011)
    test_utils.assert_eq(constants.PENALTY_BLANK_PAGE_PLAIN, -10012)
end)

-- ============================================================================
-- PENALTY_BLANK_PAGE: layout
-- ============================================================================

test_utils.run_test("blank page: after content, closes the page and adds one", function()
    local ctx = make_ctx({ cur_page = 0, cur_col = 3, cur_row = 5, page_has_content = true })
    local handled, n = run_penalty(ctx, constants.PENALTY_BLANK_PAGE)
    test_utils.assert_eq(handled, true)
    -- text on page 0, blank page is page 1, the cursor is on page 2
    test_utils.assert_eq(ctx.blank_pages[1], "normal")
    test_utils.assert_eq(ctx.layout_map[n].page, 1)
    test_utils.assert_eq(ctx.layout_map[n].mode, "placeholder")
    test_utils.assert_eq(ctx.cur_page, 2)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.cur_row, 0)
    test_utils.assert_eq(ctx.page_has_content, false)
end)

test_utils.run_test("blank page: on an untouched page that page is the blank one", function()
    local ctx = make_ctx({ cur_page = 4 })
    local _, n = run_penalty(ctx, constants.PENALTY_BLANK_PAGE)
    test_utils.assert_eq(ctx.blank_pages[4], "normal")
    test_utils.assert_eq(ctx.layout_map[n].page, 4)
    test_utils.assert_eq(ctx.cur_page, 5)
end)

test_utils.run_test("blank page: plain style is recorded", function()
    local ctx = make_ctx({ cur_page = 0, page_has_content = true, cur_row = 2 })
    local _, n = run_penalty(ctx, constants.PENALTY_BLANK_PAGE_PLAIN)
    test_utils.assert_eq(ctx.blank_pages[1], "plain")
    test_utils.assert_eq(ctx.layout_map[n].blank_page, "plain")
end)

test_utils.run_test("blank page: never elided, two in a row make two pages", function()
    local ctx = make_ctx({ cur_page = 0, page_has_content = true, cur_row = 2 })
    local _, a = run_penalty(ctx, constants.PENALTY_BLANK_PAGE)
    local _, b = run_penalty(ctx, constants.PENALTY_BLANK_PAGE_PLAIN)
    test_utils.assert_eq(ctx.layout_map[a].page, 1)
    test_utils.assert_eq(ctx.layout_map[b].page, 2)
    test_utils.assert_eq(ctx.blank_pages[1], "normal")
    test_utils.assert_eq(ctx.blank_pages[2], "plain")
    test_utils.assert_eq(ctx.cur_page, 3)
end)

test_utils.run_test("blank page: \\newpage right before it adds no extra page", function()
    local ctx = make_ctx({ cur_page = 0, page_has_content = true, cur_row = 2 })
    run_penalty(ctx, constants.PENALTY_FORCE_PAGE)   -- page 1, fresh
    local _, n = run_penalty(ctx, constants.PENALTY_BLANK_PAGE)
    test_utils.assert_eq(ctx.layout_map[n].page, 1)
    test_utils.assert_eq(ctx.cur_page, 2)
end)

-- ============================================================================
-- pad_for_facing_pages: chapter-start check
-- ============================================================================

--- A marker node already linked into a one-node list
local function marker_list()
    local marker = D.new(constants.KERN)
    return marker, marker
end

local function pad(ctx, marker, head)
    local flushed = false
    I.pad_for_facing_pages(ctx, head, marker, function() flushed = true end, 0, GRID_H)
    return flushed
end

test_utils.run_test("facing pages: off by default, nothing happens", function()
    local ctx = make_ctx({ cur_page = 1, params = { physical_page_base = 1 } })   -- physical page 2
    local marker, head = marker_list()
    pad(ctx, marker, head)
    test_utils.assert_eq(ctx.cur_page, 1)
    test_utils.assert_eq(next(ctx.blank_pages), nil)
end)

test_utils.run_test("facing pages: chapter on an odd physical page gets no blank page", function()
    local ctx = make_ctx({ cur_page = 0, params = { facing_pages = true, physical_page_base = 1 } })
    local marker, head = marker_list()
    pad(ctx, marker, head)
    test_utils.assert_eq(ctx.cur_page, 0)
    test_utils.assert_eq(next(ctx.blank_pages), nil)
end)

test_utils.run_test("facing pages: chapter that would open an even page gets a blank page", function()
    local ctx = make_ctx({ cur_page = 1, params = { facing_pages = true, physical_page_base = 1 } })
    local marker, head = marker_list()
    pad(ctx, marker, head)
    -- page 1 (physical 2) becomes the blank page, the chapter moves to page 2 (physical 3)
    test_utils.assert_eq(ctx.blank_pages[1], "normal")
    test_utils.assert_eq(ctx.cur_page, 2)
    -- the blank page hangs on a spare node spliced in right after the marker
    local anchor = marker.next
    test_utils.assert_eq(anchor ~= nil, true)
    test_utils.assert_eq(ctx.layout_map[anchor].page, 1)
    test_utils.assert_eq(ctx.layout_map[anchor].mode, "placeholder")
end)

test_utils.run_test("facing pages: parity follows the physical base, not the block-local page", function()
    -- the block starts on physical page 2: its page 0 is even, page 1 is odd
    local params = { facing_pages = true, physical_page_base = 2 }
    local ctx0 = make_ctx({ cur_page = 0, params = params })
    local m0, h0 = marker_list()
    pad(ctx0, m0, h0)
    test_utils.assert_eq(ctx0.blank_pages[0], "normal")
    test_utils.assert_eq(ctx0.cur_page, 1)

    local ctx1 = make_ctx({ cur_page = 1, params = params })
    local m1, h1 = marker_list()
    pad(ctx1, m1, h1)
    test_utils.assert_eq(next(ctx1.blank_pages), nil)
    test_utils.assert_eq(ctx1.cur_page, 1)
end)

test_utils.run_test("facing pages: a chapter starting mid-page is left alone", function()
    local ctx = make_ctx({ cur_page = 1, page_has_content = true, cur_row = 4,
        params = { facing_pages = true, physical_page_base = 1 } })
    local marker, head = marker_list()
    pad(ctx, marker, head)
    test_utils.assert_eq(ctx.cur_page, 1)
    test_utils.assert_eq(next(ctx.blank_pages), nil)
end)

test_utils.run_test("facing pages: not inside tables (n_bands > 1)", function()
    local ctx = make_ctx({ cur_page = 1, n_bands = 2,
        params = { facing_pages = true, physical_page_base = 1 } })
    local marker, head = marker_list()
    pad(ctx, marker, head)
    test_utils.assert_eq(next(ctx.blank_pages), nil)
end)

test_utils.run_test("facing pages: blank_page_style=plain is honoured", function()
    local ctx = make_ctx({ cur_page = 1,
        params = { facing_pages = true, physical_page_base = 1, blank_page_style = "plain" } })
    local marker, head = marker_list()
    pad(ctx, marker, head)
    test_utils.assert_eq(ctx.blank_pages[1], "plain")
end)

test_utils.run_test("facing pages: consecutive chapter markers pad only once", function()
    local params = { facing_pages = true, physical_page_base = 1 }
    local ctx = make_ctx({ cur_page = 1, params = params })
    local m1, h1 = marker_list()
    pad(ctx, m1, h1)             -- pads, now on page 2 (odd)
    local m2, h2 = marker_list()
    pad(ctx, m2, h2)             -- already odd
    test_utils.assert_eq(ctx.cur_page, 2)
    test_utils.assert_eq(ctx.blank_pages[1], "normal")
    test_utils.assert_eq(ctx.blank_pages[2], nil)
end)

-- ============================================================================
-- core-page helpers
-- ============================================================================

test_utils.run_test("normalize_blank_page_style: blank spellings", function()
    for _, v in ipairs({ "blank", "BLANK", "plain", "empty", "空白", "全空白", " 空白 ", "空白頁" }) do
        test_utils.assert_eq(page_mod.normalize_blank_page_style(v), "plain", v)
    end
end)

test_utils.run_test("normalize_blank_page_style: header spellings and empty", function()
    for _, v in ipairs({ "", "normal", "default", "header", "带页眉页码", "帶頁眉頁碼" }) do
        test_utils.assert_eq(page_mod.normalize_blank_page_style(v), "normal", v)
    end
    test_utils.assert_eq(page_mod.normalize_blank_page_style(nil), "normal")
end)

test_utils.run_test("set_facing_pages / set_blank_page_style write _G.page", function()
    page_mod.set_facing_pages("true")
    test_utils.assert_eq(_G.page.facing_pages, true)
    page_mod.set_facing_pages("false")
    test_utils.assert_eq(_G.page.facing_pages, false)
    page_mod.set_blank_page_style("空白")
    test_utils.assert_eq(_G.page.blank_page_style, "plain")
    page_mod.set_blank_page_style("")
    test_utils.assert_eq(_G.page.blank_page_style, "normal")
end)

test_utils.run_test("blank_penalty_for: explicit style wins, empty falls back to the document default", function()
    _G.page.blank_page_style = "normal"
    test_utils.assert_eq(page_mod.blank_penalty_for(""), constants.PENALTY_BLANK_PAGE)
    test_utils.assert_eq(page_mod.blank_penalty_for("空白"), constants.PENALTY_BLANK_PAGE_PLAIN)
    _G.page.blank_page_style = "plain"
    test_utils.assert_eq(page_mod.blank_penalty_for(""), constants.PENALTY_BLANK_PAGE_PLAIN)
    test_utils.assert_eq(page_mod.blank_penalty_for("header"), constants.PENALTY_BLANK_PAGE)
    _G.page.blank_page_style = nil
end)

test_utils.run_test("is_plain_blank_page: false when no plain blank page was ever made", function()
    _G.page.plain_blank_used = nil
    test_utils.assert_eq(page_mod.is_plain_blank_page({ list = nil }), false)
    test_utils.assert_eq(page_mod.is_plain_blank_page(nil), false)
end)

print("\nAll core/blank-page-test tests passed!")
