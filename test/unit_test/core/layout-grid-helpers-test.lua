-- Unit tests for core.luatex-cn-layout-grid-helpers
local test_utils = require("test.test_utils")
local helpers = require("core.luatex-cn-layout-grid-helpers")
local style_registry = require("util.luatex-cn-style-registry")

-- ============================================================================
-- Occupancy map: is_occupied / mark_occupied
-- ============================================================================

test_utils.run_test("is_occupied: empty map returns false", function()
    local occ = {}
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 2, 3), false)
end)

test_utils.run_test("mark_occupied: marks and is_occupied returns true", function()
    local occ = {}
    helpers.mark_occupied(occ, 1, 2, 3)
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 2, 3), true)
end)

test_utils.run_test("is_occupied: different position returns false", function()
    local occ = {}
    helpers.mark_occupied(occ, 1, 2, 3)
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 2, 4), false)
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 3, 3), false)
    test_utils.assert_eq(helpers.is_occupied(occ, 2, 2, 3), false)
end)

test_utils.run_test("mark_occupied: multiple positions", function()
    local occ = {}
    helpers.mark_occupied(occ, 1, 0, 0)
    helpers.mark_occupied(occ, 1, 0, 1)
    helpers.mark_occupied(occ, 2, 3, 5)
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 0, 0), true)
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 0, 1), true)
    test_utils.assert_eq(helpers.is_occupied(occ, 2, 3, 5), true)
    test_utils.assert_eq(helpers.is_occupied(occ, 1, 0, 2), false)
end)

-- ============================================================================
-- get_banxin_on
-- ============================================================================

test_utils.run_test("get_banxin_on: from params", function()
    test_utils.assert_eq(helpers.get_banxin_on({ banxin_on = true }), true)
    test_utils.assert_eq(helpers.get_banxin_on({ banxin_on = false }), false)
end)

test_utils.run_test("get_banxin_on: no _G fallback, returns false when not in params", function()
    _G.banxin = { enabled = true }
    test_utils.assert_eq(helpers.get_banxin_on({}), false, "should NOT read _G.banxin")
    _G.banxin = nil
end)

test_utils.run_test("get_banxin_on: false when banxin_on not in params", function()
    _G.banxin = nil
    test_utils.assert_eq(helpers.get_banxin_on({}), false)
end)

-- ============================================================================
-- get_grid_width
-- ============================================================================

test_utils.run_test("get_grid_width: from params", function()
    test_utils.assert_eq(helpers.get_grid_width({ grid_width = 100000 }), 100000)
end)

test_utils.run_test("get_grid_width: no _G fallback, returns nil when not in params", function()
    _G.content = { grid_width = 200000 }
    test_utils.assert_nil(helpers.get_grid_width({}), "should NOT read _G.content")
    _G.content = nil
end)

test_utils.run_test("get_grid_width: fallback parameter", function()
    test_utils.assert_eq(helpers.get_grid_width({}, 500000), 500000)
end)

test_utils.run_test("get_grid_width: nil when no grid_width and no fallback", function()
    test_utils.assert_nil(helpers.get_grid_width({}))
end)

test_utils.run_test("get_grid_width: ignores non-positive params, returns fallback", function()
    test_utils.assert_eq(helpers.get_grid_width({ grid_width = 0 }, 65536 * 20), 65536 * 20)
    test_utils.assert_eq(helpers.get_grid_width({ grid_width = -1 }, 65536 * 20), 65536 * 20)
    test_utils.assert_nil(helpers.get_grid_width({ grid_width = 0 }))
end)

-- ============================================================================
-- get_margin_right
-- ============================================================================

test_utils.run_test("get_margin_right: from params (number)", function()
    test_utils.assert_eq(helpers.get_margin_right({ margin_right = 100000 }), 100000)
end)

test_utils.run_test("get_margin_right: from params (string)", function()
    local result = helpers.get_margin_right({ margin_right = "10pt" })
    test_utils.assert_eq(result, tex.sp("10pt"))
end)

test_utils.run_test("get_margin_right: no _G fallback, returns 0 when not in params", function()
    _G.page = _G.page or {}
    _G.page.margin_right = 50000
    test_utils.assert_eq(helpers.get_margin_right({}), 0, "should NOT read _G.page")
    _G.page.margin_right = nil
end)

test_utils.run_test("get_margin_right: default 0", function()
    _G.page = {}
    test_utils.assert_eq(helpers.get_margin_right({}), 0)
end)

-- ============================================================================
-- get_chapter_title
-- ============================================================================

test_utils.run_test("get_chapter_title: from params", function()
    test_utils.assert_eq(helpers.get_chapter_title({ chapter_title = "第一回" }), "第一回")
end)

test_utils.run_test("get_chapter_title: no _G fallback, returns empty when not in params", function()
    _G.metadata = { chapter_title = "第二回" }
    test_utils.assert_eq(helpers.get_chapter_title({}), "", "should NOT read _G.metadata")
    _G.metadata = nil
end)

test_utils.run_test("get_chapter_title: default empty", function()
    _G.metadata = nil
    test_utils.assert_eq(helpers.get_chapter_title({}), "")
end)

-- ============================================================================
-- apply_style_attrs
-- ============================================================================

test_utils.run_test("apply_style_attrs: copies style fields to map_entry", function()
    style_registry.clear()
    local id = style_registry.register({
        font_color = "1 0 0",
        font_size = 655360,
        font = "SimSun",
    })
    local n = node.direct.new(node.id("glyph"))
    node.direct.set_attribute(n, require("core.luatex-cn-constants").ATTR_STYLE_REG_ID, id)

    local entry = {}
    helpers.apply_style_attrs(entry, n)
    test_utils.assert_eq(entry.font_color, "1 0 0")
    test_utils.assert_eq(entry.font_size, 655360)
    test_utils.assert_eq(entry.font, "SimSun")
end)

test_utils.run_test("apply_style_attrs: copies xshift/yshift to map_entry", function()
    style_registry.clear()
    local id = style_registry.register({
        xshift = { value = -0.3, unit = "em" },
        yshift = 32768,
    })
    local n = node.direct.new(node.id("glyph"))
    node.direct.set_attribute(n, require("core.luatex-cn-constants").ATTR_STYLE_REG_ID, id)

    local entry = {}
    helpers.apply_style_attrs(entry, n)
    test_utils.assert_eq(entry.xshift.value, -0.3)
    test_utils.assert_eq(entry.xshift.unit, "em")
    test_utils.assert_eq(entry.yshift, 32768)
end)

test_utils.run_test("apply_style_attrs: no style_id does nothing", function()
    local n = node.direct.new(node.id("glyph"))
    local entry = {}
    helpers.apply_style_attrs(entry, n)
    test_utils.assert_nil(entry.font_color)
end)

-- ============================================================================
-- get_cell_height: punct_config parameter
-- ============================================================================

test_utils.run_test("get_cell_height: punct mainland mode → half height for punctuation", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 4) -- comma type
    local grid_h = 65536 * 20
    local result = helpers.get_cell_height(n, grid_h, { style = "mainland", squeeze = true })
    -- Should be half of font size or grid_height
    test_utils.assert_true(result > 0)
    local full = helpers.get_cell_height(n, grid_h, { style = "taiwan", squeeze = true })
    test_utils.assert_true(result < full, "mainland punct should be less than taiwan punct")
end)

test_utils.run_test("get_cell_height: punct taiwan mode → full height for punctuation", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 3) -- fullstop type
    local grid_h = 65536 * 20
    local result = helpers.get_cell_height(n, grid_h, { style = "taiwan", squeeze = true })
    -- Should return full height, same as non-punct
    local n2 = node.direct.new(node.id("glyph"))
    node.direct.setfield(n2, "font", 1)
    local non_punct = helpers.get_cell_height(n2, grid_h, nil)
    test_utils.assert_eq(result, non_punct, "taiwan punct should equal non-punct height")
end)

test_utils.run_test("get_cell_height: squeeze=false → full height even for mainland", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 4) -- comma type
    local grid_h = 65536 * 20
    local result = helpers.get_cell_height(n, grid_h, { style = "mainland", squeeze = false })
    local n2 = node.direct.new(node.id("glyph"))
    node.direct.setfield(n2, "font", 1)
    local non_punct = helpers.get_cell_height(n2, grid_h, nil)
    test_utils.assert_eq(result, non_punct, "squeeze=false should return full height")
end)

test_utils.run_test("get_cell_height: fullstop mainland mode → full height (no squeeze)", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 3) -- fullstop type
    local grid_h = 65536 * 20
    local result = helpers.get_cell_height(n, grid_h, { style = "mainland", squeeze = true })
    local n2 = node.direct.new(node.id("glyph"))
    node.direct.setfield(n2, "font", 1)
    local non_punct = helpers.get_cell_height(n2, grid_h, nil)
    test_utils.assert_eq(result, non_punct, "fullstop should stay full height in mainland mode")
end)

test_utils.run_test("get_cell_height: middle mainland mode → full height (no squeeze)", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 5) -- middle type
    local grid_h = 65536 * 20
    local result = helpers.get_cell_height(n, grid_h, { style = "mainland", squeeze = true })
    local n2 = node.direct.new(node.id("glyph"))
    node.direct.setfield(n2, "font", 1)
    local non_punct = helpers.get_cell_height(n2, grid_h, nil)
    test_utils.assert_eq(result, non_punct, "middle punct should stay full height in mainland mode")
end)

test_utils.run_test("get_cell_height: open/close mainland mode → half height", function()
    local constants = require("core.luatex-cn-constants")
    local grid_h = 65536 * 20
    -- open (1) → half
    local n_open = node.direct.new(node.id("glyph"))
    node.direct.setfield(n_open, "font", 1)
    node.direct.set_attribute(n_open, constants.ATTR_PUNCT_TYPE, 1)
    local open_h = helpers.get_cell_height(n_open, grid_h, { style = "mainland", squeeze = true })
    -- close (2) → half
    local n_close = node.direct.new(node.id("glyph"))
    node.direct.setfield(n_close, "font", 1)
    node.direct.set_attribute(n_close, constants.ATTR_PUNCT_TYPE, 2)
    local close_h = helpers.get_cell_height(n_close, grid_h, { style = "mainland", squeeze = true })
    -- non-punct → full
    local n2 = node.direct.new(node.id("glyph"))
    node.direct.setfield(n2, "font", 1)
    local full_h = helpers.get_cell_height(n2, grid_h, nil)
    test_utils.assert_true(open_h < full_h, "open bracket should be half height")
    test_utils.assert_true(close_h < full_h, "close bracket should be half height")
end)

test_utils.run_test("get_cell_height: nil punct_config → no squeeze (no _G fallback)", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 4)
    local grid_h = 65536 * 20

    -- With nil punct_config, should NOT read _G.punct, just return full height
    local saved = _G.punct
    _G.punct = { style = "mainland", squeeze = true }
    local result = helpers.get_cell_height(n, grid_h, nil)
    local n2 = node.direct.new(node.id("glyph"))
    node.direct.setfield(n2, "font", 1)
    local non_punct = helpers.get_cell_height(n2, grid_h, nil)
    test_utils.assert_eq(result, non_punct, "nil config should NOT use _G.punct → full height")
    _G.punct = saved
end)

-- ============================================================================
-- resolve_cell_height
-- ============================================================================

test_utils.run_test("resolve_cell_height: from style registry", function()
    style_registry.clear()
    local id = style_registry.register({ cell_height = 100000 })
    local n = node.direct.new(node.id("glyph"))
    node.direct.set_attribute(n, require("core.luatex-cn-constants").ATTR_STYLE_REG_ID, id)

    local result = helpers.resolve_cell_height(n, 65536 * 20, nil)
    test_utils.assert_eq(result, 100000)
end)

test_utils.run_test("resolve_cell_height: from default_cell_height (grid mode)", function()
    local n = node.direct.new(node.id("glyph"))
    local result = helpers.resolve_cell_height(n, 65536 * 20, 80000)
    test_utils.assert_eq(result, 80000)
end)

test_utils.run_test("resolve_cell_height: falls back to font size", function()
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    local result = helpers.resolve_cell_height(n, 65536 * 20, nil)
    -- Should return a number (either font size or grid_height fallback)
    test_utils.assert_type(result, "number")
    test_utils.assert_true(result > 0)
end)

test_utils.run_test("resolve_cell_height: passes punct_config to natural mode", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 4) -- comma
    local grid_h = 65536 * 20
    -- Natural mode (default_cell_height = nil), taiwan punct_config → full height
    local taiwan_h = helpers.resolve_cell_height(n, grid_h, nil, { style = "taiwan", squeeze = true })
    -- Natural mode, mainland punct_config → half height
    local mainland_h = helpers.resolve_cell_height(n, grid_h, nil, { style = "mainland", squeeze = true })
    test_utils.assert_true(mainland_h < taiwan_h, "mainland punct should be smaller via resolve_cell_height")
end)

test_utils.run_test("resolve_cell_height: grid mode ignores punct_config", function()
    local constants = require("core.luatex-cn-constants")
    local n = node.direct.new(node.id("glyph"))
    node.direct.setfield(n, "font", 1)
    node.direct.set_attribute(n, constants.ATTR_PUNCT_TYPE, 4)
    local grid_h = 65536 * 20
    -- Grid mode (default_cell_height = grid_h) → always returns grid_h
    local result = helpers.resolve_cell_height(n, grid_h, grid_h, { style = "taiwan", squeeze = true })
    test_utils.assert_eq(result, grid_h, "grid mode returns default_cell_height regardless of punct_config")
end)

-- ============================================================================
-- resolve_cell_width
-- ============================================================================

test_utils.run_test("resolve_cell_width: from style registry", function()
    style_registry.clear()
    local id = style_registry.register({ cell_width = 50000 })
    local n = node.direct.new(node.id("glyph"))
    node.direct.set_attribute(n, require("core.luatex-cn-constants").ATTR_STYLE_REG_ID, id)

    local result = helpers.resolve_cell_width(n, nil)
    test_utils.assert_eq(result, 50000)
end)

test_utils.run_test("resolve_cell_width: from default", function()
    local n = node.direct.new(node.id("glyph"))
    local result = helpers.resolve_cell_width(n, 60000)
    test_utils.assert_eq(result, 60000)
end)

test_utils.run_test("resolve_cell_width: nil when no style and no default", function()
    local n = node.direct.new(node.id("glyph"))
    local result = helpers.resolve_cell_width(n, nil)
    test_utils.assert_nil(result)
end)

-- ============================================================================
-- resolve_cell_gap
-- ============================================================================

test_utils.run_test("resolve_cell_gap: from style registry", function()
    style_registry.clear()
    local id = style_registry.register({ cell_gap = 3000 })
    local n = node.direct.new(node.id("glyph"))
    node.direct.set_attribute(n, require("core.luatex-cn-constants").ATTR_STYLE_REG_ID, id)

    local result = helpers.resolve_cell_gap(n, 0)
    test_utils.assert_eq(result, 3000)
end)

test_utils.run_test("resolve_cell_gap: from default", function()
    local n = node.direct.new(node.id("glyph"))
    local result = helpers.resolve_cell_gap(n, 5000)
    test_utils.assert_eq(result, 5000)
end)

test_utils.run_test("resolve_cell_gap: 0 when no style and no default", function()
    local n = node.direct.new(node.id("glyph"))
    local result = helpers.resolve_cell_gap(n, nil)
    test_utils.assert_eq(result, 0)
end)

-- ============================================================================
-- create_linemark_entry
-- ============================================================================

test_utils.run_test("create_linemark_entry: creates entry with all fields", function()
    local entry = helpers.create_linemark_entry({
        group_id = 1,
        col = 3,
        y_sp = 100000,
        cell_height = 65536,
        font_size = 655360,
        sub_col = 0,
        x_center_sp = 50000,
    })
    test_utils.assert_eq(entry.group_id, 1)
    test_utils.assert_eq(entry.col, 3)
    test_utils.assert_eq(entry.y_sp, 100000)
    test_utils.assert_eq(entry.cell_height, 65536)
    test_utils.assert_eq(entry.font_size, 655360)
    test_utils.assert_eq(entry.sub_col, 0)
    test_utils.assert_eq(entry.x_center_sp, 50000)
end)

test_utils.run_test("create_linemark_entry: partial fields", function()
    local entry = helpers.create_linemark_entry({
        group_id = 2,
        col = 0,
        y_sp = 0,
    })
    test_utils.assert_eq(entry.group_id, 2)
    test_utils.assert_eq(entry.col, 0)
    test_utils.assert_nil(entry.cell_height)
end)

print("\nAll core/layout-grid-helpers-test tests passed!")
