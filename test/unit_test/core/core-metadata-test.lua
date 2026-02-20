-- Unit tests for core.luatex-cn-core-metadata
local test_utils = require("test.test_utils")
local metadata = require("core.luatex-cn-core-metadata")

-- Helper: reset metadata state
local function reset()
    _G.metadata = {
        book_name = "",
        chapter_title = "",
        publisher = "",
        chapter_registry = {},
        chapter_counter = 0,
    }
end

-- ============================================================================
-- setup
-- ============================================================================

test_utils.run_test("setup: sets book_name", function()
    reset()
    metadata.setup({ book_name = "史记" })
    test_utils.assert_eq(_G.metadata.book_name, "史记")
end)

test_utils.run_test("setup: sets chapter_title", function()
    reset()
    metadata.setup({ chapter_title = "本纪第一" })
    test_utils.assert_eq(_G.metadata.chapter_title, "本纪第一")
end)

test_utils.run_test("setup: sets publisher", function()
    reset()
    metadata.setup({ publisher = "中华书局" })
    test_utils.assert_eq(_G.metadata.publisher, "中华书局")
end)

test_utils.run_test("setup: sets multiple fields", function()
    reset()
    metadata.setup({ book_name = "论语", chapter_title = "学而篇" })
    test_utils.assert_eq(_G.metadata.book_name, "论语")
    test_utils.assert_eq(_G.metadata.chapter_title, "学而篇")
    test_utils.assert_eq(_G.metadata.publisher, "")
end)

test_utils.run_test("setup: nil params safe", function()
    reset()
    metadata.setup(nil)
    test_utils.assert_eq(_G.metadata.book_name, "")
end)

test_utils.run_test("setup: empty params safe", function()
    reset()
    metadata.setup({})
    test_utils.assert_eq(_G.metadata.book_name, "")
end)

-- ============================================================================
-- insert_chapter_marker / get_chapter_title
-- ============================================================================

test_utils.run_test("insert_chapter_marker: returns incrementing IDs", function()
    reset()
    local id1 = metadata.insert_chapter_marker("第一回")
    local id2 = metadata.insert_chapter_marker("第二回")
    test_utils.assert_type(id1, "number")
    test_utils.assert_type(id2, "number")
    test_utils.assert_true(id2 > id1)
end)

test_utils.run_test("insert_chapter_marker: stores title in global registry", function()
    reset()
    _G.chapter_registry = {}
    local id = metadata.insert_chapter_marker("第三回")
    test_utils.assert_eq(_G.chapter_registry[id], "第三回")
end)

test_utils.run_test("insert_chapter_marker: multiple titles", function()
    reset()
    _G.chapter_registry = {}
    local id1 = metadata.insert_chapter_marker("第一回")
    local id2 = metadata.insert_chapter_marker("第二回")
    test_utils.assert_eq(_G.chapter_registry[id1], "第一回")
    test_utils.assert_eq(_G.chapter_registry[id2], "第二回")
end)

-- ============================================================================
-- clear_registry
-- ============================================================================

test_utils.run_test("clear_registry: clears counter", function()
    reset()
    metadata.insert_chapter_marker("第四回")
    metadata.clear_registry()
    test_utils.assert_eq(_G.metadata.chapter_counter, 0)
end)

test_utils.run_test("clear_registry: clears registry table", function()
    reset()
    metadata.insert_chapter_marker("第五回")
    metadata.clear_registry()
    test_utils.assert_eq(#_G.metadata.chapter_registry, 0)
end)

print("\nAll core/core-metadata-test tests passed!")
