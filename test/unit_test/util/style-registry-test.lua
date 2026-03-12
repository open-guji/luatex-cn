-- Unit tests for util.luatex-cn-style-registry
local test_utils = require("test.test_utils")
local style_registry = require("util.luatex-cn-style-registry")

-- Helper: reset registry before each group
local function reset()
    style_registry.clear()
end

-- ============================================================================
-- register / get
-- ============================================================================

test_utils.run_test("register: returns numeric ID", function()
    reset()
    local id = style_registry.register({ font_color = "1 0 0" })
    test_utils.assert_type(id, "number")
    test_utils.assert_true(id >= 1)
end)

test_utils.run_test("register: nil/empty returns nil", function()
    reset()
    test_utils.assert_nil(style_registry.register(nil))
    test_utils.assert_nil(style_registry.register({}))
end)

test_utils.run_test("register: deduplication", function()
    reset()
    local id1 = style_registry.register({ font_color = "1 0 0" })
    local id2 = style_registry.register({ font_color = "1 0 0" })
    test_utils.assert_eq(id1, id2, "same style should return same ID")
end)

test_utils.run_test("register: different styles get different IDs", function()
    reset()
    local id1 = style_registry.register({ font_color = "1 0 0" })
    local id2 = style_registry.register({ font_color = "0 0 1" })
    test_utils.assert_true(id1 ~= id2, "different styles should get different IDs")
end)

test_utils.run_test("get: retrieves registered style", function()
    reset()
    local id = style_registry.register({ font_color = "1 0 0", font_size = 655360 })
    local style = style_registry.get(id)
    test_utils.assert_eq(style.font_color, "1 0 0")
    test_utils.assert_eq(style.font_size, 655360)
end)

test_utils.run_test("get: nil for invalid ID", function()
    reset()
    test_utils.assert_nil(style_registry.get(nil))
    test_utils.assert_nil(style_registry.get(999))
end)

-- ============================================================================
-- Attribute getters
-- ============================================================================

test_utils.run_test("get_font_color: returns color", function()
    reset()
    local id = style_registry.register({ font_color = "0 1 0" })
    test_utils.assert_eq(style_registry.get_font_color(id), "0 1 0")
end)

test_utils.run_test("get_font_size: returns size", function()
    reset()
    local id = style_registry.register({ font_size = 655360 })
    test_utils.assert_eq(style_registry.get_font_size(id), 655360)
end)

test_utils.run_test("get_font: returns font name", function()
    reset()
    local id = style_registry.register({ font = "SimSun" })
    test_utils.assert_eq(style_registry.get_font(id), "SimSun")
end)

test_utils.run_test("get_indent / get_first_indent", function()
    reset()
    local id = style_registry.register({ indent = 2, first_indent = 3 })
    test_utils.assert_eq(style_registry.get_indent(id), 2)
    test_utils.assert_eq(style_registry.get_first_indent(id), 3)
end)

test_utils.run_test("get_cell_height / width / gap", function()
    reset()
    local id = style_registry.register({ cell_height = 100, cell_width = 200, cell_gap = 50 })
    test_utils.assert_eq(style_registry.get_cell_height(id), 100)
    test_utils.assert_eq(style_registry.get_cell_width(id), 200)
    test_utils.assert_eq(style_registry.get_cell_gap(id), 50)
end)

test_utils.run_test("get_border / border_width / border_color", function()
    reset()
    local id = style_registry.register({ border = true, border_width = "0.4pt", border_color = "0 0 0" })
    test_utils.assert_eq(style_registry.get_border(id), true)
    test_utils.assert_eq(style_registry.get_border_width(id), "0.4pt")
    test_utils.assert_eq(style_registry.get_border_color(id), "0 0 0")
end)

test_utils.run_test("get_background_color", function()
    reset()
    local id = style_registry.register({ background_color = "1 1 0.9" })
    test_utils.assert_eq(style_registry.get_background_color(id), "1 1 0.9")
end)

test_utils.run_test("get_column_width / auto_width / width_scale", function()
    reset()
    local id = style_registry.register({ column_width = 500, auto_width = true, width_scale = 1.5 })
    test_utils.assert_eq(style_registry.get_column_width(id), 500)
    test_utils.assert_eq(style_registry.get_auto_width(id), true)
    test_utils.assert_eq(style_registry.get_width_scale(id), 1.5)
end)

test_utils.run_test("get_spacing_top / spacing_bottom", function()
    reset()
    local id = style_registry.register({ spacing_top = 100, spacing_bottom = 200 })
    test_utils.assert_eq(style_registry.get_spacing_top(id), 100)
    test_utils.assert_eq(style_registry.get_spacing_bottom(id), 200)
end)

test_utils.run_test("getter: nil for missing attribute", function()
    reset()
    local id = style_registry.register({ font_color = "0 0 0" })
    test_utils.assert_nil(style_registry.get_font_size(id))
end)

test_utils.run_test("get_debug: returns debug flag", function()
    reset()
    local id1 = style_registry.register({ debug = true })
    test_utils.assert_eq(style_registry.get_debug(id1), true)
    local id2 = style_registry.register({ debug = false })
    test_utils.assert_eq(style_registry.get_debug(id2), false)
    local id3 = style_registry.register({ font_color = "0 0 0" })
    test_utils.assert_nil(style_registry.get_debug(id3))
end)

test_utils.run_test("push: debug inherits from parent", function()
    reset()
    style_registry.push({ debug = true, font_color = "1 0 0" })
    style_registry.push({ font_size = 200 })
    local cur = style_registry.current()
    test_utils.assert_eq(cur.debug, true, "debug should inherit from parent")
end)

test_utils.run_test("make_extra: debug_flag param", function()
    reset()
    local extra = style_registry.make_extra(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "true")
    test_utils.assert_eq(extra.debug, true, "debug should be true")
    local extra2 = style_registry.make_extra(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "false")
    test_utils.assert_eq(extra2.debug, false, "debug should be false")
    local extra3 = style_registry.make_extra(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    test_utils.assert_nil(extra3, "nil debug_flag should not create extra table")
end)

test_utils.run_test("set_current_debug: modifies stack top in-place", function()
    reset()
    style_registry.push({ font_color = "1 0 0" })
    style_registry.push({ font_size = 200 })
    -- Enable debug on current stack top
    style_registry.set_current_debug(true)
    local cur = style_registry.current()
    test_utils.assert_eq(cur.debug, true, "debug should be enabled on top")
    test_utils.assert_eq(cur.font_size, 200, "font_size should be preserved")
    test_utils.assert_eq(cur.font_color, "1 0 0", "inherited font_color should be preserved")
    -- Pop should work correctly (no extra push was added)
    style_registry.pop()
    local parent = style_registry.current()
    test_utils.assert_nil(parent.debug, "parent should NOT have debug")
    test_utils.assert_eq(parent.font_color, "1 0 0")
end)

test_utils.run_test("set_current_debug: push on empty stack", function()
    reset()
    -- On empty stack, set_current_debug pushes a new style with the debug flag
    style_registry.set_current_debug(true)
    local cur = style_registry.current()
    test_utils.assert_true(cur ~= nil, "should have pushed a style")
    test_utils.assert_eq(cur.debug, true, "pushed style should have debug=true")
end)

test_utils.run_test("set_current_debug: child inherits debug", function()
    reset()
    style_registry.push({ font_color = "1 0 0" })
    style_registry.set_current_debug(true)
    -- Child push should inherit debug=true
    style_registry.push({ font_size = 300 })
    local child = style_registry.current()
    test_utils.assert_eq(child.debug, true, "child should inherit debug")
    test_utils.assert_eq(child.font_size, 300)
    -- Pop child, then disable debug
    style_registry.pop()
    style_registry.set_current_debug(false)
    -- New child should NOT inherit debug
    style_registry.push({ font_size = 400 })
    local child2 = style_registry.current()
    test_utils.assert_eq(child2.debug, false, "child should inherit debug=false")
end)

-- ============================================================================
-- Stack: push / pop / current
-- ============================================================================

test_utils.run_test("push/current: pushes style to stack", function()
    reset()
    style_registry.push({ font_color = "1 0 0" })
    local cur = style_registry.current()
    test_utils.assert_eq(cur.font_color, "1 0 0")
end)

test_utils.run_test("push: inherits from parent", function()
    reset()
    style_registry.push({ font_color = "1 0 0", font_size = 100 })
    style_registry.push({ font_size = 200 })
    local cur = style_registry.current()
    test_utils.assert_eq(cur.font_color, "1 0 0", "should inherit color from parent")
    test_utils.assert_eq(cur.font_size, 200, "should override font_size")
end)

test_utils.run_test("pop: removes top style", function()
    reset()
    style_registry.push({ font_color = "1 0 0" })
    style_registry.push({ font_color = "0 0 1" })
    test_utils.assert_eq(style_registry.current().font_color, "0 0 1")
    style_registry.pop()
    test_utils.assert_eq(style_registry.current().font_color, "1 0 0")
end)

test_utils.run_test("pop: empty stack returns nil", function()
    reset()
    test_utils.assert_nil(style_registry.pop())
end)

test_utils.run_test("current: empty stack returns nil", function()
    reset()
    test_utils.assert_nil(style_registry.current())
    test_utils.assert_nil(style_registry.current_id())
end)

-- ============================================================================
-- push_indent
-- ============================================================================

test_utils.run_test("push_indent: sets indent and first_indent", function()
    reset()
    style_registry.push_indent(2, 3)
    local cur = style_registry.current()
    test_utils.assert_eq(cur.indent, 2)
    test_utils.assert_eq(cur.first_indent, 3)
end)

test_utils.run_test("push_indent: first_indent=-1 inherits indent", function()
    reset()
    style_registry.push_indent(2, -1)
    local cur = style_registry.current()
    test_utils.assert_eq(cur.first_indent, 2)
end)

test_utils.run_test("push_indent: temporary flag", function()
    reset()
    style_registry.push_indent(1, 1, true)
    local cur = style_registry.current()
    test_utils.assert_eq(cur.temporary, true)
end)

-- ============================================================================
-- pop_temporary
-- ============================================================================

test_utils.run_test("pop_temporary: pops all temporary styles", function()
    reset()
    style_registry.push({ font_color = "1 0 0" })
    style_registry.push_indent(1, 1, true)
    style_registry.push_indent(2, 2, true)
    local count = style_registry.pop_temporary()
    test_utils.assert_eq(count, 2)
    test_utils.assert_eq(style_registry.current().font_color, "1 0 0")
end)

test_utils.run_test("pop_temporary: stops at non-temporary", function()
    reset()
    style_registry.push({ font_color = "1 0 0" })
    style_registry.push({ font_size = 200 })
    style_registry.push_indent(1, 1, true)
    local count = style_registry.pop_temporary()
    test_utils.assert_eq(count, 1)
    test_utils.assert_eq(style_registry.current().font_size, 200)
end)

-- ============================================================================
-- clear / stats
-- ============================================================================

test_utils.run_test("clear: resets registry", function()
    reset()
    style_registry.register({ font_color = "1 0 0" })
    style_registry.clear()
    local s = style_registry.stats()
    test_utils.assert_eq(s.total_styles, 0)
    test_utils.assert_eq(s.next_id, 1)
end)

test_utils.run_test("stats: reports correct counts", function()
    reset()
    style_registry.register({ font_color = "1 0 0" })
    style_registry.register({ font_color = "0 0 1" })
    local s = style_registry.stats()
    test_utils.assert_eq(s.total_styles, 2)
end)

print("\nAll util/style-registry-test tests passed!")
