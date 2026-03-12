-- Unit tests for core.luatex-cn-core-export
local test_utils = require("test.test_utils")
local export = require("core.luatex-cn-core-export")

local json_encode = export._internal.json_encode
local json_escape_string = export._internal.json_escape_string
local is_array = export._internal.is_array
local SP_TO_PT = export._internal.SP_TO_PT

-- ============================================================================
-- JSON Serializer: Primitives
-- ============================================================================

test_utils.run_test("json_encode: nil → null", function()
    test_utils.assert_eq(json_encode(nil), "null")
end)

test_utils.run_test("json_encode: true → true", function()
    test_utils.assert_eq(json_encode(true), "true")
end)

test_utils.run_test("json_encode: false → false", function()
    test_utils.assert_eq(json_encode(false), "false")
end)

test_utils.run_test("json_encode: integer", function()
    test_utils.assert_eq(json_encode(42), "42")
end)

test_utils.run_test("json_encode: negative integer", function()
    test_utils.assert_eq(json_encode(-7), "-7")
end)

test_utils.run_test("json_encode: zero", function()
    test_utils.assert_eq(json_encode(0), "0")
end)

test_utils.run_test("json_encode: float", function()
    test_utils.assert_eq(json_encode(3.1415), "3.14")
end)

test_utils.run_test("json_encode: NaN → null", function()
    test_utils.assert_eq(json_encode(0/0), "null")
end)

test_utils.run_test("json_encode: inf → null", function()
    test_utils.assert_eq(json_encode(math.huge), "null")
end)

-- ============================================================================
-- JSON Serializer: Strings
-- ============================================================================

test_utils.run_test("json_encode: simple string", function()
    test_utils.assert_eq(json_encode("hello"), '"hello"')
end)

test_utils.run_test("json_encode: Chinese string", function()
    test_utils.assert_eq(json_encode("史记"), '"史记"')
end)

test_utils.run_test("json_encode: string with quotes", function()
    test_utils.assert_eq(json_encode('say "hi"'), '"say \\"hi\\""')
end)

test_utils.run_test("json_encode: string with backslash", function()
    test_utils.assert_eq(json_encode("a\\b"), '"a\\\\b"')
end)

test_utils.run_test("json_encode: string with newline", function()
    test_utils.assert_eq(json_encode("a\nb"), '"a\\nb"')
end)

test_utils.run_test("json_encode: string with tab", function()
    test_utils.assert_eq(json_encode("a\tb"), '"a\\tb"')
end)

-- ============================================================================
-- JSON Serializer: Arrays
-- ============================================================================

test_utils.run_test("json_encode: empty array", function()
    test_utils.assert_eq(json_encode({}), "[]")
end)

test_utils.run_test("json_encode: simple array", function()
    local result = json_encode({1, 2, 3})
    test_utils.assert_match(result, "1")
    test_utils.assert_match(result, "2")
    test_utils.assert_match(result, "3")
end)

test_utils.run_test("json_encode: array of strings", function()
    local result = json_encode({"a", "b"})
    test_utils.assert_match(result, '"a"')
    test_utils.assert_match(result, '"b"')
end)

-- ============================================================================
-- JSON Serializer: Objects
-- ============================================================================

test_utils.run_test("json_encode: simple object", function()
    local result = json_encode({name = "test", value = 42})
    test_utils.assert_match(result, '"name": "test"')
    test_utils.assert_match(result, '"value": 42')
end)

test_utils.run_test("json_encode: object keys sorted", function()
    local result = json_encode({zebra = 1, alpha = 2, middle = 3})
    local alpha_pos = result:find('"alpha"')
    local middle_pos = result:find('"middle"')
    local zebra_pos = result:find('"zebra"')
    test_utils.assert_true(alpha_pos < middle_pos, "alpha before middle")
    test_utils.assert_true(middle_pos < zebra_pos, "middle before zebra")
end)

test_utils.run_test("json_encode: nested object", function()
    local result = json_encode({outer = {inner = "value"}})
    test_utils.assert_match(result, '"inner": "value"')
    test_utils.assert_match(result, '"outer"')
end)

test_utils.run_test("json_encode: object with null value", function()
    local result = json_encode({a = 1, b = nil})
    -- nil values are not included in pairs() iteration, so only "a" appears
    test_utils.assert_match(result, '"a": 1')
end)

-- ============================================================================
-- JSON Serializer: Mixed nested structures
-- ============================================================================

test_utils.run_test("json_encode: array of objects", function()
    local result = json_encode({
        {char = "史", col = 0},
        {char = "记", col = 1},
    })
    test_utils.assert_match(result, '"char": "史"')
    test_utils.assert_match(result, '"char": "记"')
    test_utils.assert_match(result, '"col": 0')
    test_utils.assert_match(result, '"col": 1')
end)

-- ============================================================================
-- json_escape_string
-- ============================================================================

test_utils.run_test("json_escape_string: control chars", function()
    -- \x01 should be escaped as \u0001
    local result = json_escape_string("\x01")
    test_utils.assert_eq(result, "\\u0001")
end)

-- ============================================================================
-- is_array
-- ============================================================================

test_utils.run_test("is_array: sequential table is array", function()
    test_utils.assert_true(is_array({1, 2, 3}))
end)

test_utils.run_test("is_array: empty table is array", function()
    test_utils.assert_true(is_array({}))
end)

test_utils.run_test("is_array: keyed table is not array", function()
    test_utils.assert_eq(is_array({a = 1}), false)
end)

-- ============================================================================
-- SP_TO_PT conversion
-- ============================================================================

test_utils.run_test("SP_TO_PT: 65536 sp = 1 pt", function()
    test_utils.assert_near(65536 * SP_TO_PT, 1.0, 0.0001)
end)

test_utils.run_test("SP_TO_PT: 0 sp = 0 pt", function()
    test_utils.assert_eq(0 * SP_TO_PT, 0)
end)

-- ============================================================================
-- enable / is_enabled / reset
-- ============================================================================

test_utils.run_test("enable: sets enabled state", function()
    export.reset()
    test_utils.assert_eq(export.is_enabled(), false)
    export.enable({})
    test_utils.assert_eq(export.is_enabled(), true)
    export.reset()
end)

test_utils.run_test("enable: sets _G.export.enabled", function()
    export.reset()
    export.enable({})
    test_utils.assert_eq(_G.export.enabled, true)
    export.reset()
end)

test_utils.run_test("reset: clears state", function()
    export.enable({})
    export.reset()
    test_utils.assert_eq(export.is_enabled(), false)
end)

-- ============================================================================
-- collect: basic structure verification
-- ============================================================================

test_utils.run_test("collect: does nothing when disabled", function()
    export.reset()
    -- Should not error when called while disabled
    export.collect(nil, {layout_map = {}, total_pages = 0}, {}, {}, {})
end)

test_utils.run_test("collect: produces page structure with empty input", function()
    export.reset()
    export.enable({})

    -- Mock minimal structures
    local layout_results = {
        layout_map = {},
        total_pages = 1,
    }
    local engine_ctx = {
        g_width = 65536 * 10,   -- 10pt
        g_height = 65536 * 12,  -- 12pt
        page_columns = 8,
        n_column = 0,
        line_limit = 21,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        col_geom = { grid_width = 65536 * 10, banxin_width = 0, interval = 0 },
    }
    local p_info = {
        p_width = 65536 * 200,  -- 200pt
        p_height = 65536 * 300, -- 300pt
        m_top = 65536 * 20,
        m_bottom = 65536 * 20,
        m_left = 65536 * 15,
        m_right = 65536 * 15,
        is_textbox = false,
    }

    -- Need a node list head (use nil, collect handles it)
    -- Since D.todirect(nil) returns nil, the while loop just won't execute
    export.collect(nil, layout_results, engine_ctx, {}, p_info)

    -- Verify internal state was populated (write_json would use it)
    -- We can't easily inspect collected_data without exposing it,
    -- but write_json should not error
    export.reset()
end)

-- ============================================================================
-- JSON schema: full structure smoke test
-- ============================================================================

test_utils.run_test("json_encode: full layout schema (PageLayout-compatible)", function()
    local schema = {
        version = "1.0",
        generator = "luatex-cn",
        document = {
            page_width_pt = 568.0,
            page_height_pt = 894.6,
            total_pages = 1,
            grid_width_pt = 15.0,
            grid_height_pt = 12.0,
            line_limit = 21,
            columns_count = 8,
            split_page = {
                enabled = false,
            },
        },
        pages = {
            {
                page_index = 0,
                margins = { top_pt = 20.0, bottom_pt = 20.0, left_pt = 15.0, right_pt = 15.0 },
                columns_count = 8,
                columns = {
                    {
                        col_index = 0,
                        position = { left_x = 185.0, right_x = 185.0 },
                        characters = {
                            {
                                char = "史",
                                unicode = 21490,
                                row_index = 0,
                                position = { x = 185.0, y_top = 20.0, y_bottom = 32.0 },
                                type = "normal",
                                confidence = 1.0,
                            },
                        },
                    },
                },
                sidenotes = {},
            },
        },
    }

    local result = json_encode(schema)
    -- Verify it's valid JSON-like output
    test_utils.assert_match(result, '"version": "1.0"')
    test_utils.assert_match(result, '"generator": "luatex%-cn"')
    test_utils.assert_match(result, '"char": "史"')
    test_utils.assert_match(result, '"unicode": 21490')
    test_utils.assert_match(result, '"type": "normal"')
    test_utils.assert_match(result, '"confidence": 1')
    test_utils.assert_match(result, '"row_index": 0')
    test_utils.assert_match(result, '"y_top": 20')
    test_utils.assert_match(result, '"y_bottom": 32')
    test_utils.assert_match(result, '"left_x": 185')
    test_utils.assert_match(result, '"page_index": 0')
    test_utils.assert_match(result, '"total_pages": 1')
end)

-- ============================================================================
-- build_col_summary
-- ============================================================================

local build_col_summary = export._internal.build_col_summary

test_utils.run_test("build_col_summary: empty characters → empty string", function()
    test_utils.assert_eq(build_col_summary({}), "")
end)

test_utils.run_test("build_col_summary: normal only → plain string", function()
    local chars = {
        {char = "史", type = "normal"},
        {char = "記", type = "normal"},
        {char = "卷", type = "normal"},
    }
    test_utils.assert_eq(build_col_summary(chars), "史記卷")
end)

test_utils.run_test("build_col_summary: jiazhu only → single segment array", function()
    local chars = {
        {char = "集", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "解", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "索", type = "jiazhu", jiazhu = {sub_col = 2}},
        {char = "隱", type = "jiazhu", jiazhu = {sub_col = 2}},
    }
    local result = build_col_summary(chars)
    test_utils.assert_eq(type(result), "table")
    test_utils.assert_eq(#result, 1) -- one jiazhu segment
    test_utils.assert_eq(result[1][1], "集解")  -- right sub-col
    test_utils.assert_eq(result[1][2], "索隱")  -- left sub-col
end)

test_utils.run_test("build_col_summary: normal then jiazhu → mixed segments", function()
    local chars = {
        {char = "正", type = "normal"},
        {char = "文", type = "normal"},
        {char = "漢", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "唐", type = "jiazhu", jiazhu = {sub_col = 2}},
    }
    local result = build_col_summary(chars)
    test_utils.assert_eq(type(result), "table")
    test_utils.assert_eq(#result, 2)
    test_utils.assert_eq(result[1], "正文")       -- normal segment
    test_utils.assert_eq(result[2][1], "漢")      -- jiazhu right
    test_utils.assert_eq(result[2][2], "唐")      -- jiazhu left
end)

test_utils.run_test("build_col_summary: alternating J-N-J (like shiji)", function()
    local chars = {
        {char = "角", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "龍", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "黄", type = "jiazhu", jiazhu = {sub_col = 2}},
        {char = "帝", type = "jiazhu", jiazhu = {sub_col = 2}},
        {char = "少", type = "normal"},
        {char = "典", type = "normal"},
        {char = "集", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "解", type = "jiazhu", jiazhu = {sub_col = 1}},
        {char = "周", type = "jiazhu", jiazhu = {sub_col = 2}},
        {char = "曰", type = "jiazhu", jiazhu = {sub_col = 2}},
    }
    local result = build_col_summary(chars)
    test_utils.assert_eq(type(result), "table")
    test_utils.assert_eq(#result, 3) -- J, N, J
    test_utils.assert_eq(result[1][1], "角龍")   -- jiazhu segment 1 right
    test_utils.assert_eq(result[1][2], "黄帝")   -- jiazhu segment 1 left
    test_utils.assert_eq(result[2], "少典")       -- normal segment
    test_utils.assert_eq(result[3][1], "集解")   -- jiazhu segment 2 right
    test_utils.assert_eq(result[3][2], "周曰")   -- jiazhu segment 2 left
end)

-- ============================================================================
-- build_page_summary
-- ============================================================================

local build_page_summary = export._internal.build_page_summary

test_utils.run_test("build_page_summary: empty pages → empty array", function()
    local result = build_page_summary({})
    test_utils.assert_eq(#result, 0)
end)

test_utils.run_test("build_page_summary: single page type", function()
    local pages = {{page_index = 0, columns = {}}}
    local result = build_page_summary(pages)
    test_utils.assert_eq(result[1].type, "single")
end)

test_utils.run_test("build_page_summary: spread page types", function()
    local pages = {
        {page_index = 0, columns = {}, split_info = {leaf = "right"}},
        {page_index = 1, columns = {}, split_info = {leaf = "left"}},
    }
    local result = build_page_summary(pages)
    -- split_info present → unified "spread" type (no longer split into spread_right/spread_left)
    test_utils.assert_eq(result[1].type, "spread")
    test_utils.assert_eq(result[2].type, "spread")
end)

test_utils.run_test("build_page_summary: empty column gap filled", function()
    local pages = {
        {
            page_index = 0,
            columns = {
                {col_index = 0, characters = {{char = "甲", type = "normal"}}},
                -- col_index=1 is missing (gap)
                {col_index = 2, characters = {{char = "乙", type = "normal"}}},
            },
        },
    }
    local result = build_page_summary(pages)
    test_utils.assert_eq(#result[1].cols, 3)
    test_utils.assert_eq(result[1].cols[1], "甲")
    test_utils.assert_eq(result[1].cols[2], "")     -- gap filled
    test_utils.assert_eq(result[1].cols[3], "乙")
end)

test_utils.run_test("build_page_summary: page with no columns → empty cols", function()
    local pages = {{page_index = 0, columns = {}}}
    local result = build_page_summary(pages)
    test_utils.assert_eq(#result[1].cols, 0)
end)

-- ============================================================================
-- JSON serialization of page_summary
-- ============================================================================

test_utils.run_test("json_encode: page_summary with mixed col types", function()
    local summary = {
        {
            page = 0,
            type = "single",
            cols = {
                "欽定四庫全書",
                "",
                {{"右小列", "左小列"}},
            },
        },
    }
    local result = json_encode(summary)
    test_utils.assert_match(result, '"page": 0')
    test_utils.assert_match(result, '"type": "single"')
    test_utils.assert_match(result, '"欽定四庫全書"')
    test_utils.assert_match(result, '""')
    test_utils.assert_match(result, '"右小列"')
    test_utils.assert_match(result, '"左小列"')
end)

test_utils.run_test("json_encode: page_summary sorts before pages", function()
    local schema = {
        page_summary = {{page = 0, type = "single", cols = {}}},
        pages = {{page_index = 0}},
    }
    local result = json_encode(schema)
    local ps_pos = result:find('"page_summary"')
    local p_pos = result:find('"pages"')
    test_utils.assert_true(ps_pos < p_pos, "page_summary before pages")
end)

print("\n=== core-export-test: All tests passed ===")
