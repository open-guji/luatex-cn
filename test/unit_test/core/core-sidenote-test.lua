-- Unit tests for core.luatex-cn-core-sidenote
local test_utils = require("test.test_utils")
local sidenote = require("core.luatex-cn-core-sidenote")
local constants = require("core.luatex-cn-constants")
local D = node.direct

local gh = 655360 -- default grid_height = 10pt in sp

-- ============================================================================
-- calculate_next_node_pos: wrapped column starts at row 0
-- ============================================================================

test_utils.run_test("calculate_next_node_pos: overflow wraps to next col at row 0", function()
    local tracker = sidenote._internal.create_gap_tracker()
    local config = {
        p_cols = 13,
        line_limit = 10,
        banxin_on = false,
        interval = 0,
        padding_top_grid = 0,
        padding_bottom_grid = 0,
        step = 1,
        tracker = tracker,
        base_indent = 3, -- anchor has indent, but wrapped col should reset to 0
    }
    -- Current: row 9, next glyph would go to row 10 >= line_limit(10)
    local np, nc, nr = sidenote._internal.calculate_next_node_pos(0, 1, 9, constants.GLYPH, config)
    test_utils.assert_eq(nc, 2, "wraps to next column")
    test_utils.assert_eq(nr, 0, "wrapped row starts at 0, not base_indent(3)")
end)

test_utils.run_test("calculate_next_node_pos: no wrap when within limit", function()
    local tracker = sidenote._internal.create_gap_tracker()
    local config = {
        p_cols = 13,
        line_limit = 10,
        banxin_on = false,
        interval = 0,
        padding_top_grid = 0,
        padding_bottom_grid = 0,
        step = 1,
        tracker = tracker,
        base_indent = 0,
    }
    local np, nc, nr = sidenote._internal.calculate_next_node_pos(0, 1, 4, constants.GLYPH, config)
    test_utils.assert_eq(nc, 1, "stays in same column")
    test_utils.assert_eq(nr, 5, "advances by 1 row")
end)

test_utils.run_test("calculate_next_node_pos: non-glyph nodes don't advance row", function()
    local tracker = sidenote._internal.create_gap_tracker()
    local config = {
        p_cols = 13,
        line_limit = 10,
        banxin_on = false,
        interval = 0,
        padding_top_grid = 0,
        padding_bottom_grid = 0,
        step = 1,
        tracker = tracker,
        base_indent = 0,
    }
    local np, nc, nr = sidenote._internal.calculate_next_node_pos(0, 1, 4, constants.GLUE, config)
    test_utils.assert_eq(nr, 4, "GLUE does not advance row")
end)

-- ============================================================================
-- Gap tracker: negative positions not clamped
-- ============================================================================

test_utils.run_test("calculate_start_position: negative yshift produces negative row", function()
    -- anchor at row 0, yshift = -3em → negative row
    local metadata = { yshift = { unit = "em", value = -3 } }
    local result = sidenote._internal.calculate_start_position(0, metadata, gh)
    test_utils.assert_true(result < 0, "negative yshift produces negative start row")
end)

test_utils.run_test("calculate_start_position: positive yshift still works", function()
    local metadata = { yshift = { unit = "em", value = 2 } }
    local result = sidenote._internal.calculate_start_position(0, metadata, gh)
    test_utils.assert_true(result > 0, "positive yshift produces positive start row")
end)

test_utils.run_test("calculate_start_position: anchor row at middle with yshift", function()
    -- anchor at row 5, yshift = -2 → result should be 3
    local metadata = { yshift = { unit = "em", value = -2 } }
    local result = sidenote._internal.calculate_start_position(5 * gh, metadata, gh)
    test_utils.assert_eq(result, 3, "anchor 5 + yshift -2 = 3")
end)

-- ============================================================================
-- create_gap_tracker: default value is -1
-- ============================================================================

test_utils.run_test("create_gap_tracker: default returns -1 for empty positions", function()
    local tracker = sidenote._internal.create_gap_tracker()
    test_utils.assert_eq(tracker.get(0, 0), -1, "empty position returns -1")
    test_utils.assert_eq(tracker.get(0, 1), -1, "empty position returns -1")
end)

test_utils.run_test("create_gap_tracker: set and get", function()
    local tracker = sidenote._internal.create_gap_tracker()
    tracker.set(0, 0, 5)
    test_utils.assert_eq(tracker.get(0, 0), 5, "returns set value")
end)

-- ============================================================================
-- place_individual_sidenote: reverse flow with negative start
-- ============================================================================

test_utils.run_test("place_individual_sidenote: reverse flow goes to previous column", function()
    -- Create a simple sidenote with 2 glyphs
    local glyph1 = D.new(constants.GLYPH)
    glyph1.char = 97
    D.setnext(glyph1, nil)
    -- Create a longer register entry for wrapping test
    local glyph2 = D.new(constants.GLYPH)
    glyph2.char = 98
    D.setnext(glyph1, glyph2)

    local registry_item = {
        head = node.direct.tonode(glyph1), -- use node.direct.tonode for the registry
        metadata = { yshift = { unit = "em", value = -3 } }
    }

    local last_node_pos = {
        page = 0,
        col = 1, -- non-zero column so we can go back to col 0
        y_sp = 0,  -- anchor at row 0
        indent = 0,
    }

    local params = {
        page_columns = 13,
        line_limit = 10,
        grid_height = gh,
        banxin_on = false,
    }

    local tracker = sidenote._internal.create_gap_tracker()
    local result = sidenote._internal.place_individual_sidenote(1, registry_item, last_node_pos, params, tracker, nil)

    test_utils.assert_not_nil(result, "returns placed nodes")

    -- With yshift=-3 at anchor row 0, start should be row -3 → column 0, row 7 (10 + (-3))
    test_utils.assert_eq(result[1].col, 0, "reverse-flowed to previous column")
    test_utils.assert_eq(result[1].y_sp / gh, 7, "starts at line_limit + (-3) = 7")

    -- Second glyph should be at row 8 of column 0
    test_utils.assert_eq(result[2].col, 0, "second glyph also in previous column")
    test_utils.assert_eq(result[2].y_sp / gh, 8, "second glyph at row 8")
end)

test_utils.run_test("place_individual_sidenote: wraps to next column at row 0", function()
    -- Create a sidenote with many glyphs to trigger wrap
    local head = nil
    local tail = nil
    for i = 1, 8 do
        local g = D.new(constants.GLYPH)
        g.char = 96 + i
        if not head then
            head = g
        else
            D.setnext(tail, g)
        end
        tail = g
    end

    local registry_item = {
        head = node.direct.tonode(head),
        metadata = {}
    }

    -- Anchor near bottom of column to trigger wrap quickly
    local last_node_pos = {
        page = 0,
        col = 1,
        y_sp = 7 * gh, -- row 7, after 3 chars we wrap
        indent = 0,
    }

    local params = {
        page_columns = 13,
        line_limit = 10,
        grid_height = gh,
        banxin_on = false,
    }

    local tracker = sidenote._internal.create_gap_tracker()
    local result = sidenote._internal.place_individual_sidenote(1, registry_item, last_node_pos, params, tracker, nil)

    test_utils.assert_not_nil(result, "returns placed nodes")
    test_utils.assert_eq(#result, 8, "all 8 glyphs placed")

    -- First glyph at col 1, row 7 (anchor position)
    test_utils.assert_eq(result[1].col, 1)
    test_utils.assert_true(result[1].y_sp / gh > 6.5, "first glyph near row 7")

    -- After wrapping: glyphs in column 2 should start at row 0
    local first_wrapped = nil
    for i = 1, #result do
        if result[i].col == 2 then
            first_wrapped = result[i]
            break
        end
    end
    test_utils.assert_not_nil(first_wrapped, "some glyphs wrapped to column 2")
    test_utils.assert_true(first_wrapped.y_sp / gh < 1, "wrapped starts at row 0 (flush with body)")
end)

test_utils.run_test("place_individual_sidenote: anchor at column bottom flows to next column", function()
    -- When the anchor is at the LAST character of a column (y_sp = line_limit),
    -- the first sidenote character should go to the next column, not ride the bottom edge.
    local glyph = D.new(constants.GLYPH)
    glyph.char = 97

    local registry_item = {
        head = node.direct.tonode(glyph),
        metadata = {}
    }

    local last_node_pos = {
        page = 0,
        col = 1,
        y_sp = 10 * gh, -- anchor at row 10 = line_limit (column bottom)
        indent = 0,
    }

    local params = {
        page_columns = 13,
        line_limit = 10,
        grid_height = gh,
        banxin_on = false,
        n_column = 0,
    }

    local tracker = sidenote._internal.create_gap_tracker()
    local result = sidenote._internal.place_individual_sidenote(1, registry_item, last_node_pos, params, tracker, nil)

    test_utils.assert_eq(#result, 1, "single glyph placed")
    test_utils.assert_eq(result[1].col, 2, "flows to next column instead of riding bottom")
    test_utils.assert_true(result[1].y_sp < gh, "starts at row 0 in next column")
end)

test_utils.run_test("place_individual_sidenote: normal placement without wrap", function()
    local glyph = D.new(constants.GLYPH)
    glyph.char = 97

    local registry_item = {
        head = node.direct.tonode(glyph),
        metadata = {}
    }

    local last_node_pos = {
        page = 0,
        col = 1,
        y_sp = 3 * gh,
        indent = 0,
    }

    local params = {
        page_columns = 13,
        line_limit = 10,
        grid_height = gh,
        banxin_on = false,
    }

    local tracker = sidenote._internal.create_gap_tracker()
    local result = sidenote._internal.place_individual_sidenote(1, registry_item, last_node_pos, params, tracker, nil)

    test_utils.assert_eq(#result, 1, "single glyph placed")
    test_utils.assert_eq(result[1].col, 1)
    test_utils.assert_true(result[1].y_sp / gh > 2.5, "placed near anchor row 3")
end)

-- ============================================================================
-- build_col_min_row: extracts minimum rows from layout_map
-- ============================================================================

test_utils.run_test("build_col_min_row: extracts minimum rows from layout_map", function()
    -- Mock layout_map entries with various y_sp values across columns
    local layout_map = {
        a = { page = 0, col = 0, y_sp = -2 * gh },
        b = { page = 0, col = 0, y_sp = 3 * gh },
        c = { page = 0, col = 1, y_sp = 0 },
        d = { page = 0, col = 1, y_sp = 5 * gh },
    }
    local result = sidenote._internal.build_col_min_row(layout_map, gh)
    test_utils.assert_eq(result[0][0], -2, "col 0 min row is -2 (taitou)")
    test_utils.assert_eq(result[0][1], 0, "col 1 min row is 0 (no taitou)")
end)

test_utils.run_test("build_col_min_row: skips placeholder entries", function()
    local layout_map = {
        a = { page = 0, col = 0, y_sp = 0 },
        b = { page = 0, col = 0, y_sp = -3 * gh, mode = "placeholder" },
    }
    local result = sidenote._internal.build_col_min_row(layout_map, gh)
    test_utils.assert_eq(result[0][0], 0, "placeholder entry is ignored")
end)

-- ============================================================================
-- calculate_next_node_pos: taitou-aware wrapping
-- ============================================================================

test_utils.run_test("calculate_next_node_pos: wraps to taitou column at aligned row", function()
    local tracker = sidenote._internal.create_gap_tracker()
    local config = {
        p_cols = 13,
        line_limit = 10,
        banxin_on = false,
        interval = 0,
        padding_top_grid = 0,
        padding_bottom_grid = 0,
        step = 1,
        tracker = tracker,
        base_indent = 0,
        col_min_row = { [0] = { [2] = -2 } }, -- next column (2) has taitou=2
    }
    -- Current: row 9, next glyph would go to row 10 >= line_limit
    local np, nc, nr = sidenote._internal.calculate_next_node_pos(0, 1, 9, constants.GLYPH, config)
    test_utils.assert_eq(nc, 2, "wraps to next column")
    test_utils.assert_eq(nr, -2, "wrapped row aligned with taitou (-2), not 0")
end)

test_utils.run_test("calculate_next_node_pos: wraps to col without taitou at row 0", function()
    local tracker = sidenote._internal.create_gap_tracker()
    local config = {
        p_cols = 13,
        line_limit = 10,
        banxin_on = false,
        interval = 0,
        padding_top_grid = 0,
        padding_bottom_grid = 0,
        step = 1,
        tracker = tracker,
        base_indent = 0,
        col_min_row = {}, -- no taitou info
    }
    local np, nc, nr = sidenote._internal.calculate_next_node_pos(0, 1, 9, constants.GLYPH, config)
    test_utils.assert_eq(nc, 2, "wraps to next column")
    test_utils.assert_eq(nr, 0, "wrapped row starts at 0 when no taitou")
end)

-- ============================================================================
-- place_individual_sidenote: taitou-aware wrapping
-- ============================================================================

test_utils.run_test("place_individual_sidenote: wraps to taitou column at aligned row", function()
    local head = nil
    local tail = nil
    for i = 1, 5 do
        local g = D.new(constants.GLYPH)
        g.char = 96 + i
        if not head then head = g else D.setnext(tail, g) end
        tail = g
    end

    local registry_item = {
        head = node.direct.tonode(head),
        metadata = {}
    }

    -- Anchor near bottom of column 1 to trigger wrap to column 2
    local last_node_pos = {
        page = 0, col = 1, y_sp = 8 * gh, indent = 0,
    }

    local params = {
        page_columns = 13, line_limit = 10,
        grid_height = gh, banxin_on = false,
    }

    -- Column 2 has taitou=2 (min row = -2)
    local col_min_row = { [0] = { [2] = -2 } }

    local tracker = sidenote._internal.create_gap_tracker()
    local result = sidenote._internal.place_individual_sidenote(1, registry_item, last_node_pos, params, tracker, col_min_row)

    test_utils.assert_not_nil(result, "returns placed nodes")
    test_utils.assert_eq(result[1].col, 1, "first glyph in anchor column")

    -- After wrapping: glyphs in column 2 should start at row -2 (taitou aligned)
    local first_wrapped = nil
    for i = 1, #result do
        if result[i].col == 2 then
            first_wrapped = result[i]
            break
        end
    end
    test_utils.assert_not_nil(first_wrapped, "some glyphs wrapped to column 2")
    test_utils.assert_eq(first_wrapped.y_sp / gh, -2, "wrapped starts at taitou row -2")
end)

-- ============================================================================
-- extract_registry_content
-- ============================================================================

test_utils.run_test("extract_registry_content: table with head", function()
    local content, metadata = sidenote._internal.extract_registry_content({
        head = "content_head",
        metadata = { xshift = 5 }
    })
    test_utils.assert_eq(content, "content_head")
    test_utils.assert_eq(metadata.xshift, 5)
end)

test_utils.run_test("extract_registry_content: non-table returns as content", function()
    local content, metadata = sidenote._internal.extract_registry_content("raw_content")
    test_utils.assert_eq(content, "raw_content")
    test_utils.assert_eq(type(metadata), "table")
end)

-- ============================================================================
-- skip_to_valid_column
-- ============================================================================

test_utils.run_test("skip_to_valid_column: no skip when no banxin", function()
    local p, c = sidenote._internal.skip_to_valid_column(0, 5, 13, false, 0)
    test_utils.assert_eq(p, 0)
    test_utils.assert_eq(c, 5, "column unchanged when no banxin")
end)

test_utils.run_test("skip_to_valid_column: wraps page when col >= p_cols", function()
    local p, c = sidenote._internal.skip_to_valid_column(0, 13, 13, false, 0)
    test_utils.assert_eq(p, 1, "wraps to next page")
    test_utils.assert_eq(c, 0, "resets to column 0")
end)
