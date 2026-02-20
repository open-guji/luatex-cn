-- Unit tests for core.luatex-cn-core-page-split
local test_utils = require("test.test_utils")
local split = require("core.luatex-cn-core-page-split")

-- Helper: reset page split state
local function reset()
    _G.page = {
        paper_width = 65536 * 200,  -- 200pt
        paper_height = 65536 * 300, -- 300pt
        split = {
            enabled = false,
            right_first = true,
        },
    }
end

-- ============================================================================
-- is_enabled
-- ============================================================================

test_utils.run_test("is_enabled: false by default", function()
    reset()
    test_utils.assert_eq(split.is_enabled(), false)
end)

test_utils.run_test("is_enabled: true after setting", function()
    reset()
    _G.page.split.enabled = true
    test_utils.assert_eq(split.is_enabled(), true)
end)

-- ============================================================================
-- is_right_first
-- ============================================================================

test_utils.run_test("is_right_first: true by default", function()
    reset()
    test_utils.assert_eq(split.is_right_first(), true)
end)

test_utils.run_test("is_right_first: false when set", function()
    reset()
    _G.page.split.right_first = false
    test_utils.assert_eq(split.is_right_first(), false)
end)

-- ============================================================================
-- is_right_page
-- ============================================================================

test_utils.run_test("is_right_page: right_first=true, odd page is right", function()
    reset()
    _G.page.split.right_first = true
    test_utils.assert_eq(split.is_right_page(1), true)
    test_utils.assert_eq(split.is_right_page(3), true)
    test_utils.assert_eq(split.is_right_page(5), true)
end)

test_utils.run_test("is_right_page: right_first=true, even page is left", function()
    reset()
    _G.page.split.right_first = true
    test_utils.assert_eq(split.is_right_page(2), false)
    test_utils.assert_eq(split.is_right_page(4), false)
end)

test_utils.run_test("is_right_page: right_first=false, even page is right", function()
    reset()
    _G.page.split.right_first = false
    test_utils.assert_eq(split.is_right_page(2), true)
    test_utils.assert_eq(split.is_right_page(4), true)
end)

test_utils.run_test("is_right_page: right_first=false, odd page is left", function()
    reset()
    _G.page.split.right_first = false
    test_utils.assert_eq(split.is_right_page(1), false)
    test_utils.assert_eq(split.is_right_page(3), false)
end)

-- ============================================================================
-- get_target_width / get_target_height
-- ============================================================================

test_utils.run_test("get_target_width: half of paper width", function()
    reset()
    local w = split.get_target_width()
    test_utils.assert_eq(w, math.floor(65536 * 200 / 2))
end)

test_utils.run_test("get_target_height: same as paper height", function()
    reset()
    local h = split.get_target_height()
    test_utils.assert_eq(h, 65536 * 300)
end)

test_utils.run_test("get_target_width: zero when no page dimensions", function()
    _G.page = { split = { enabled = false, right_first = true } }
    local w = split.get_target_width()
    test_utils.assert_eq(w, 0)
end)

-- ============================================================================
-- configure (smoke test)
-- ============================================================================

test_utils.run_test("configure: does not error", function()
    reset()
    split.configure()
end)

print("\nAll core/core-page-split-test tests passed!")
