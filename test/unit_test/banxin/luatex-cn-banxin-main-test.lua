-- Unit tests for banxin.luatex-cn-banxin-main
local test_utils = require('test.test_utils')

-- Setup environment before requiring banxin-main
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}
_G.banxin = _G.banxin or {}

local banxin_main = require('banxin.luatex-cn-banxin-main')

-- ============================================================================
-- Module loads and exports
-- ============================================================================

test_utils.run_test("banxin_main: module loads as table", function()
    test_utils.assert_type(banxin_main, "table")
end)

test_utils.run_test("banxin_main: exports plugin interface functions", function()
    test_utils.assert_type(banxin_main.initialize, "function")
    test_utils.assert_type(banxin_main.setup, "function")
    test_utils.assert_type(banxin_main.render, "function")
end)

-- ============================================================================
-- setup
-- ============================================================================

test_utils.run_test("banxin_main: setup enables banxin", function()
    _G.banxin.enabled = false
    banxin_main.setup({ enabled = true })
    test_utils.assert_eq(_G.banxin.enabled, true)
end)

test_utils.run_test("banxin_main: setup disables banxin", function()
    _G.banxin.enabled = true
    banxin_main.setup({ enabled = false })
    test_utils.assert_eq(_G.banxin.enabled, false)
end)

test_utils.run_test("banxin_main: setup with nil params does not error", function()
    banxin_main.setup(nil)
end)

-- ============================================================================
-- initialize
-- ============================================================================

test_utils.run_test("banxin_main: initialize returns inactive context when disabled", function()
    _G.banxin.enabled = false
    local ctx = banxin_main.initialize({}, {})
    test_utils.assert_type(ctx, "table")
    test_utils.assert_eq(ctx.active, false)
end)

test_utils.run_test("banxin_main: initialize returns active context with n_column", function()
    -- banxin_on is read via token.create; alternatively, n_column > 0 activates banxin
    local ctx = banxin_main.initialize({ n_column = 10 }, {})
    test_utils.assert_type(ctx, "table")
    test_utils.assert_eq(ctx.active, true)
end)

-- \版心设置{font-size=12pt} 之类的样式 key：以前 banxin-main 没 require constants，
-- 直接 constants.to_dimen 就报「attempt to index a nil value (global 'constants')」。
test_utils.run_test("banxin_main: initialize converts style font-size / grid-height", function()
    local saved = token.get_macro
    local tls = {
        l__luatexcn_banxin_style_font_size_tl = "12pt",
        l__luatexcn_banxin_style_grid_height_tl = "20pt",
        l__luatexcn_banxin_style_font_color_tl = "red",
    }
    token.get_macro = function(name) return tls[name] end
    local ok, ctx = pcall(banxin_main.initialize, { n_column = 10 }, {})
    token.get_macro = saved
    test_utils.assert_true(ok, "initialize must not error: " .. tostring(ctx))
    test_utils.assert_eq(ctx.banxin_style.font_size, 12 * 65536)
    test_utils.assert_eq(ctx.banxin_style.grid_height, 20 * 65536)
    test_utils.assert_eq(ctx.banxin_style.font_color, "red")
end)

-- ============================================================================
-- require idempotency
-- ============================================================================

test_utils.run_test("banxin_main: require returns same module", function()
    local m1 = require('banxin.luatex-cn-banxin-main')
    local m2 = require('banxin.luatex-cn-banxin-main')
    test_utils.assert_eq(m1, m2)
end)

print("\nAll banxin-main tests passed!")
