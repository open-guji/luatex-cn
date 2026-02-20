-- Unit tests for guji.luatex-cn-guji-meipi
local test_utils = require("test.test_utils")
local meipi = require("guji.luatex-cn-guji-meipi")

-- Helper: setup page dimensions for meipi
local function setup_page()
    _G.page = {
        paper_width = 65536 * 400,   -- 400pt
        paper_height = 65536 * 600,  -- 600pt
        margin_left = 65536 * 30,
        margin_right = 65536 * 30,
        margin_top = 65536 * 40,
    }
    _G.content = _G.content or {}
    meipi.reset()
end

-- ============================================================================
-- setup
-- ============================================================================

test_utils.run_test("setup: sets default values", function()
    meipi.setup({})
    -- Should not error
end)

test_utils.run_test("setup: with custom spacing", function()
    meipi.setup({ spacing = "5pt", gap = "3pt" })
    -- Should not error
end)

-- ============================================================================
-- reset
-- ============================================================================

test_utils.run_test("reset: clears state", function()
    setup_page()
    -- After reset, next registration should start fresh
    meipi.reset()
end)

-- ============================================================================
-- calculate_x / calculate_y
-- ============================================================================

test_utils.run_test("calculate_x: returns a number", function()
    setup_page()
    local x = meipi.calculate_x(65536 * 50)  -- 50pt wide annotation
    test_utils.assert_type(x, "number")
end)

test_utils.run_test("calculate_y: returns a number", function()
    setup_page()
    local y = meipi.calculate_y(65536 * 30)  -- 30pt tall annotation
    test_utils.assert_type(y, "number")
end)

-- ============================================================================
-- register
-- ============================================================================

test_utils.run_test("register: returns x,y coordinates", function()
    setup_page()
    local x, y = meipi.register(65536 * 50, 65536 * 30)
    test_utils.assert_type(x, "number")
    test_utils.assert_type(y, "number")
end)

test_utils.run_test("register: successive calls increase x offset", function()
    setup_page()
    local x1 = meipi.register(65536 * 50, 65536 * 30)
    local x2 = meipi.register(65536 * 50, 65536 * 30)
    -- x is distance from RIGHT edge; second annotation is further left = larger offset
    test_utils.assert_true(x2 > x1, "second annotation should have larger x offset (further from right)")
end)

print("\nAll guji/meipi-test tests passed!")
