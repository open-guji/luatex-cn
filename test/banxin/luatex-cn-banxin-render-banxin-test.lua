-- luatex-cn-banxin-render-banxin.lua - Unit tests for banxin rendering
local test_utils = require('test.test_utils')
local banxin = require('banxin.luatex-cn-banxin-render-banxin')
local render_pos = require('vertical.luatex-cn-vertical-render-position')

-- Mock create_vertical_text to return exactly 1 node for testing node counts
render_pos.create_vertical_text = function(text, params)
    return node.new(1, 1) -- Single node
end

-- Access internal functions for unit testing
local internal = banxin._internal

-- ============================================================================
-- Internal Helper Functions Tests
-- ============================================================================

test_utils.run_test("count_utf8_chars - ASCII", function()
    test_utils.assert_eq(internal.count_utf8_chars("hello"), 5, "ASCII chars count")
end)

test_utils.run_test("count_utf8_chars - Chinese", function()
    test_utils.assert_eq(internal.count_utf8_chars("你好"), 2, "Chinese chars count")
end)

test_utils.run_test("count_utf8_chars - Mixed", function()
    test_utils.assert_eq(internal.count_utf8_chars("Hello你好"), 7, "Mixed chars count")
end)

test_utils.run_test("count_utf8_chars - Empty", function()
    test_utils.assert_eq(internal.count_utf8_chars(""), 0, "Empty string count")
end)

test_utils.run_test("calculate_yuwei_dimensions", function()
    local width = 100 * 65536 -- 100pt
    local dims = internal.calculate_yuwei_dimensions(width)

    test_utils.assert_eq(dims.edge_height, width * 0.39, "edge_height calculation")
    test_utils.assert_eq(dims.notch_height, width * 0.17, "notch_height calculation")
    test_utils.assert_eq(dims.gap, 65536 * 3.7, "gap value")
end)

test_utils.run_test("calculate_yuwei_total_height", function()
    local dims = {
        edge_height = 39 * 65536,
        notch_height = 17 * 65536,
        gap = 65536 * 3.7,
    }
    local total = internal.calculate_yuwei_total_height(dims)
    local expected = dims.gap + dims.edge_height + dims.notch_height

    test_utils.assert_eq(total, expected, "yuwei total height")
end)

test_utils.run_test("parse_chapter_title - Single line", function()
    local parts = internal.parse_chapter_title("第一章")
    test_utils.assert_eq(#parts, 1, "Single line should have 1 part")
    test_utils.assert_eq(parts[1], "第一章", "Content match")
end)

test_utils.run_test("parse_chapter_title - Multi-line with \\\\", function()
    local parts = internal.parse_chapter_title("第一章\\\\正文")
    test_utils.assert_eq(#parts, 2, "Two lines should have 2 parts")
    test_utils.assert_eq(parts[1], "第一章", "First part")
    test_utils.assert_eq(parts[2], "正文", "Second part")
end)

test_utils.run_test("parse_chapter_title - Three lines", function()
    local parts = internal.parse_chapter_title("A\\\\B\\\\C")
    test_utils.assert_eq(#parts, 3, "Three lines should have 3 parts")
end)

test_utils.run_test("parse_chapter_title - Empty", function()
    local parts = internal.parse_chapter_title("")
    test_utils.assert_eq(#parts, 0, "Empty string should have 0 parts")
end)

test_utils.run_test("create_border_literal - Format check", function()
    local literal = internal.create_border_literal(0, 0, 65536, 65536, 65536, "0 0 0")
    -- Should contain PDF commands: q, w, RG, re, S, Q
    test_utils.assert_eq(string.find(literal, "q") ~= nil, true, "Should contain 'q'")
    test_utils.assert_eq(string.find(literal, "RG") ~= nil, true, "Should contain 'RG'")
    test_utils.assert_eq(string.find(literal, "re") ~= nil, true, "Should contain 're'")
    test_utils.assert_eq(string.find(literal, "S") ~= nil, true, "Should contain 'S'")
    test_utils.assert_eq(string.find(literal, "Q") ~= nil, true, "Should contain 'Q'")
end)

test_utils.run_test("create_divider_literal - Format check", function()
    local literal = internal.create_divider_literal(0, 0, 65536, 65536, "1 0 0")
    -- Should contain PDF commands for line: m, l, S
    test_utils.assert_eq(string.find(literal, "m") ~= nil, true, "Should contain 'm' (moveto)")
    test_utils.assert_eq(string.find(literal, "l") ~= nil, true, "Should contain 'l' (lineto)")
    test_utils.assert_eq(string.find(literal, "1 0 0 RG") ~= nil, true, "Should contain color")
end)

test_utils.run_test("calculate_book_name_params - Empty name", function()
    local result = internal.calculate_book_name_params({ book_name = "" }, 100 * 65536)
    test_utils.assert_eq(result, nil, "Empty name should return nil")
end)

test_utils.run_test("calculate_book_name_params - Valid name", function()
    local params = {
        book_name = "测试",
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
    }
    local result = internal.calculate_book_name_params(params, 28 * 65536)

    test_utils.assert_eq(result ~= nil, true, "Should return params")
    test_utils.assert_eq(result.text, "测试", "Text should match")
    test_utils.assert_eq(result.num_cells, 2, "Should have 2 cells")
end)

test_utils.run_test("calculate_chapter_title_layout - Empty title", function()
    local result = internal.calculate_chapter_title_layout(
        { chapter_title = "", y = 0 },
        28 * 65536,
        56 * 65536,
        { gap = 65536 * 3.7, edge_height = 7.8 * 65536, notch_height = 3.4 * 65536 }
    )
    test_utils.assert_eq(result, nil, "Empty title should return nil")
end)

test_utils.run_test("calculate_chapter_title_layout - Valid title", function()
    local yuwei_dims = {
        gap = 65536 * 3.7,
        edge_height = 7.8 * 65536,
        notch_height = 3.4 * 65536,
    }
    local params = {
        chapter_title = "第一章",
        y = 0,
        width = 20 * 65536,
        upper_yuwei = true,
        lower_yuwei = true,
        chapter_title_top_margin = 65536 * 5, -- Small margin for test
    }
    -- Use larger heights to ensure available_height > 0
    local result = internal.calculate_chapter_title_layout(
        params,
        28 * 65536,  -- upper_height
        200 * 65536, -- middle_height (large enough)
        yuwei_dims
    )

    test_utils.assert_eq(result ~= nil, true, "Should return layout")
    test_utils.assert_eq(#result.parts, 1, "Should have 1 part")
    test_utils.assert_eq(result.parts[1], "第一章", "Part content")
end)

test_utils.run_test("calculate_page_number_layout - No page number", function()
    local result = internal.calculate_page_number_layout(
        { page_number = nil },
        28 * 65536,
        56 * 65536,
        { gap = 0, edge_height = 0, notch_height = 0 }
    )
    test_utils.assert_eq(result, nil, "No page number should return nil")
end)

-- ============================================================================
-- draw_banxin Tests
-- ============================================================================

test_utils.run_test("draw_banxin - Default Parameters", function()
    local result = banxin.draw_banxin({})

    -- With empty params, should use defaults
    test_utils.assert_eq(result.upper_height, 0, "Empty params should have 0 upper_height")
    -- 2 dividers + 2 yuwei (defaults enabled) = 4
    test_utils.assert_eq(#result.literals, 4, "Should have 4 literals with defaults")
end)

test_utils.run_test("draw_banxin - Ratio Calculations", function()
    local params = {
        total_height = 100 * 65536,
        upper_ratio = 0.3,
        middle_ratio = 0.5,
        color_str = "0 1 0"
    }
    local result = banxin.draw_banxin(params)

    -- upper_height should be 30pt (30 * 65536)
    test_utils.assert_eq(result.upper_height, 30 * 65536, "Upper height mismatch")

    -- literals count
    -- 2 dividers + 1 upper_yuwei (default) + 1 lower_yuwei (default) = 4
    test_utils.assert_eq(#result.literals, 4, "Literals count mismatch")

    -- Check divider Y coordinates
    -- total_height = 100
    -- div1_y = y - 30 = -30
    -- div2_y = -30 - 50 = -80
    local div1_found = false
    local div2_found = false
    for _, lit in ipairs(result.literals) do
        if string.find(lit, "%-29%.%d+ m") then div1_found = true end
        if string.find(lit, "%-79%.%d+ m") then div2_found = true end
    end
    test_utils.assert_eq(div1_found, true, "Divider 1 not found or wrong Y")
    test_utils.assert_eq(div2_found, true, "Divider 2 not found or wrong Y")
end)

test_utils.run_test("draw_banxin - Yuwei Disabled", function()
    local params = {
        total_height = 100 * 65536,
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)

    -- Only 2 dividers, no yuwei
    test_utils.assert_eq(#result.literals, 2, "Should have 2 literals when yuwei disabled")
end)

test_utils.run_test("draw_banxin - Only Upper Yuwei", function()
    local params = {
        total_height = 100 * 65536,
        upper_yuwei = true,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)

    -- 2 dividers + 1 upper yuwei = 3
    test_utils.assert_eq(#result.literals, 3, "Should have 3 literals with only upper yuwei")
end)

test_utils.run_test("draw_banxin - Only Lower Yuwei", function()
    local params = {
        total_height = 100 * 65536,
        upper_yuwei = false,
        lower_yuwei = true,
    }
    local result = banxin.draw_banxin(params)

    -- 2 dividers + 1 lower yuwei = 3
    test_utils.assert_eq(#result.literals, 3, "Should have 3 literals with only lower yuwei")
end)

test_utils.run_test("draw_banxin - Dividers Disabled", function()
    local params = {
        total_height = 100 * 65536,
        banxin_divider = false,
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)

    -- No dividers, no yuwei
    test_utils.assert_eq(#result.literals, 0, "Should have 0 literals when all disabled")
end)

test_utils.run_test("draw_banxin - Custom Ratios", function()
    local params = {
        total_height = 200 * 65536,
        upper_ratio = 0.2,
        middle_ratio = 0.6,
        -- lower_ratio = 0.2 (implied)
    }
    local result = banxin.draw_banxin(params)

    -- upper_height = 200 * 0.2 = 40pt
    test_utils.assert_eq(result.upper_height, 40 * 65536, "Upper height should be 40pt")
end)

test_utils.run_test("draw_banxin - Color String", function()
    local params = {
        total_height = 100 * 65536,
        color_str = "1 0 0",
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)

    -- Check that color is in the literals
    local color_found = false
    for _, lit in ipairs(result.literals) do
        if string.find(lit, "1 0 0 RG") then
            color_found = true
            break
        end
    end
    test_utils.assert_eq(color_found, true, "Color string should be in literals")
end)

-- ============================================================================
-- draw_banxin_column Tests
-- ============================================================================

test_utils.run_test("draw_banxin_column - Node Insertion", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        draw_border = true,
        border_thickness = 1 / 2 * 65536,
        book_name = "TestBook"
    }

    local new_head = banxin.draw_banxin_column(p_head, params)

    -- Count nodes inserted before p_head
    -- 1 border + 2 dividers + 2 yuwei + 1 book_name (mocked as 1 node) = 6
    local count = 0
    local curr = new_head
    while curr and curr ~= p_head do
        count = count + 1
        curr = curr.next
    end

    test_utils.assert_eq(count, 6, "Inserted nodes count mismatch")
end)

test_utils.run_test("draw_banxin_column - Alignment Options", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.4 * 65536,
        book_name = "AlignTest",
        book_name_align = "top"
    }

    -- Just verify it runs without error with alignment params
    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle book_name_align='top': " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - No Border", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        draw_border = false,
        border_thickness = 0.5 * 65536,
    }

    local new_head = banxin.draw_banxin_column(p_head, params)

    -- Count nodes: no border + 2 dividers + 2 yuwei = 4
    local count = 0
    local curr = new_head
    while curr and curr ~= p_head do
        count = count + 1
        curr = curr.next
    end

    test_utils.assert_eq(count, 4, "Should have 4 nodes when border disabled")
end)

test_utils.run_test("draw_banxin_column - Chapter Title", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        chapter_title = "第一章",
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle chapter_title: " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - Multi-line Chapter Title", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        chapter_title = "第一章\\\\正文",
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle multi-line chapter_title: " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - Page Number", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        page_number = 5,
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle page_number: " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - Page Number Alignment Center", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        page_number = 10,
        page_number_align = "center",
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle page_number_align='center': " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - Page Number Alignment Bottom-Center", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        page_number = 10,
        page_number_align = "bottom-center",
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle page_number_align='bottom-center': " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - All Features Combined", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 100 * 65536,
        y = -50 * 65536,
        width = 20 * 65536,
        height = 200 * 65536,
        draw_border = true,
        border_thickness = 0.5 * 65536,
        color_str = "0.5 0.5 0.5",
        upper_ratio = 0.25,
        middle_ratio = 0.55,
        book_name = "测试书名",
        book_name_align = "center",
        chapter_title = "第一章\\\\小节",
        page_number = 42,
        page_number_align = "center",
        upper_yuwei = true,
        lower_yuwei = true,
        banxin_divider = true,
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle all features combined: " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - Empty Book Name", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        book_name = "",
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle empty book_name: " .. tostring(err))
end)

test_utils.run_test("draw_banxin_column - Grid Height Parameters", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.5 * 65536,
        book_name = "书",
        book_name_grid_height = "15pt",
        chapter_title = "章",
        chapter_title_grid_height = "20pt",
        page_number = 1,
        page_number_grid_height = "12pt",
    }

    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle grid height parameters: " .. tostring(err))
end)

print("\nAll render-banxin tests passed!")
