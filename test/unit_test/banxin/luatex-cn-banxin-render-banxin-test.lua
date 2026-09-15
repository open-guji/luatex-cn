-- Unit tests for banxin.luatex-cn-banxin-render-banxin
local test_utils = require('test.test_utils')

-- Mock textflow module (needed by render-position)
package.loaded['core.luatex-cn-textflow'] = package.loaded['core.luatex-cn-textflow'] or {
    calculate_sub_column_x_offset = function(base_x) return base_x end,
}

local banxin = require('banxin.luatex-cn-banxin-render-banxin')

-- Access internal functions for unit testing
local internal = banxin._internal

-- ============================================================================
-- Module loads
-- ============================================================================

test_utils.run_test("render-banxin: module loads", function()
    test_utils.assert_type(banxin, "table")
end)

test_utils.run_test("render-banxin: _internal exported", function()
    test_utils.assert_type(internal, "table")
end)

-- ============================================================================
-- Internal Helper Functions Tests
-- ============================================================================

test_utils.run_test("count_utf8_chars: ASCII", function()
    test_utils.assert_eq(internal.count_utf8_chars("hello"), 5)
end)

test_utils.run_test("count_utf8_chars: Chinese", function()
    test_utils.assert_eq(internal.count_utf8_chars("你好"), 2)
end)

test_utils.run_test("count_utf8_chars: Mixed", function()
    test_utils.assert_eq(internal.count_utf8_chars("Hello你好"), 7)
end)

test_utils.run_test("count_utf8_chars: Empty", function()
    test_utils.assert_eq(internal.count_utf8_chars(""), 0)
end)

test_utils.run_test("calculate_yuwei_dimensions: ratios", function()
    local width = 100 * 65536 -- 100pt
    local dims = internal.calculate_yuwei_dimensions(width)
    test_utils.assert_eq(dims.edge_height, width * 0.39)
    test_utils.assert_eq(dims.notch_height, width * 0.17)
    test_utils.assert_eq(dims.gap, 65536 * 3.7)
end)

test_utils.run_test("calculate_yuwei_total_height", function()
    local dims = {
        edge_height = 39 * 65536,
        notch_height = 17 * 65536,
        gap = 65536 * 3.7,
    }
    local total = internal.calculate_yuwei_total_height(dims)
    local expected = dims.gap + dims.edge_height + dims.notch_height
    test_utils.assert_eq(total, expected)
end)

test_utils.run_test("parse_section_text: single line", function()
    local parts = internal.parse_section_text("第一章")
    test_utils.assert_eq(#parts, 1)
    test_utils.assert_eq(parts[1], "第一章")
end)

test_utils.run_test("parse_section_text: multi-line with \\\\", function()
    local parts = internal.parse_section_text("第一章\\\\正文")
    test_utils.assert_eq(#parts, 2)
    test_utils.assert_eq(parts[1], "第一章")
    test_utils.assert_eq(parts[2], "正文")
end)

test_utils.run_test("parse_section_text: three lines", function()
    local parts = internal.parse_section_text("A\\\\B\\\\C")
    test_utils.assert_eq(#parts, 3)
end)

test_utils.run_test("parse_section_text: empty", function()
    local parts = internal.parse_section_text("")
    test_utils.assert_eq(#parts, 0)
end)

test_utils.run_test("create_border_literal: contains PDF commands", function()
    local literal = internal.create_border_literal(0, 0, 65536, 65536, 65536, "0 0 0")
    test_utils.assert_true(string.find(literal, "q") ~= nil, "Should contain 'q'")
    test_utils.assert_true(string.find(literal, "RG") ~= nil, "Should contain 'RG'")
    test_utils.assert_true(string.find(literal, "re") ~= nil, "Should contain 're'")
    test_utils.assert_true(string.find(literal, "S") ~= nil, "Should contain 'S'")
    test_utils.assert_true(string.find(literal, "Q") ~= nil, "Should contain 'Q'")
end)

test_utils.run_test("create_divider_literal: contains PDF commands", function()
    local literal = internal.create_divider_literal(0, 0, 65536, 65536, "1 0 0")
    test_utils.assert_true(string.find(literal, "m") ~= nil, "Should contain 'm' (moveto)")
    test_utils.assert_true(string.find(literal, "l") ~= nil, "Should contain 'l' (lineto)")
    test_utils.assert_true(string.find(literal, "1 0 0 RG") ~= nil, "Should contain color")
end)

-- ============================================================================
-- draw_banxin Tests
-- ============================================================================

test_utils.run_test("draw_banxin: default parameters", function()
    local result = banxin.draw_banxin({})
    test_utils.assert_type(result, "table")
    test_utils.assert_type(result.literals, "table")
    test_utils.assert_type(result.upper_height, "number")
end)

test_utils.run_test("draw_banxin: yuwei disabled", function()
    local params = {
        total_height = 100 * 65536,
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)
    -- Only 2 dividers, no yuwei
    test_utils.assert_eq(#result.literals, 2)
end)

test_utils.run_test("draw_banxin: dividers disabled", function()
    local params = {
        total_height = 100 * 65536,
        banxin_divider = false,
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)
    test_utils.assert_eq(#result.literals, 0)
end)

test_utils.run_test("draw_banxin: custom ratios", function()
    local params = {
        total_height = 200 * 65536,
        upper_ratio = 0.2,
        middle_ratio = 0.6,
    }
    local result = banxin.draw_banxin(params)
    test_utils.assert_eq(result.upper_height, 40 * 65536)
end)

test_utils.run_test("draw_banxin: color string in literals", function()
    local params = {
        total_height = 100 * 65536,
        color_str = "1 0 0",
        upper_yuwei = false,
        lower_yuwei = false,
    }
    local result = banxin.draw_banxin(params)
    local color_found = false
    for _, lit in ipairs(result.literals) do
        if string.find(lit, "1 0 0 RG") then
            color_found = true
            break
        end
    end
    test_utils.assert_true(color_found, "Color string should be in literals")
end)

-- ============================================================================
-- resolve_page_number_string
-- issue #161: \pageSetup{页码样式=digits} 对版心页码也要生效
-- ============================================================================

local resolve = banxin._internal.resolve_page_number_string

test_utils.run_test("版心页码: 未设置样式沿用位值中文", function()
    _G.page = nil
    test_utils.assert_eq(resolve(144, nil), "一百四十四")
    _G.page = {}
    test_utils.assert_eq(resolve(144, nil), "一百四十四")
    _G.page = { number_style = "" }
    test_utils.assert_eq(resolve(144, nil), "一百四十四")
end)

test_utils.run_test("版心页码: 页码样式=digits 逐位输出", function()
    _G.page = { number_style = "digits" }
    test_utils.assert_eq(resolve(144, nil), "一四四")
end)

test_utils.run_test("版心页码: 页码样式=arabic", function()
    _G.page = { number_style = "arabic" }
    test_utils.assert_eq(resolve(144, nil), "144")
end)

test_utils.run_test("版心页码: 页码样式=none 不显示", function()
    _G.page = { number_style = "none" }
    test_utils.assert_eq(resolve(144, nil), "")
end)

test_utils.run_test("版心页码: 显式页码（数字化模式）优先于样式", function()
    _G.page = { number_style = "digits" }
    test_utils.assert_eq(resolve(144, "卷三"), "卷三")
    _G.page = nil
end)

-- ============================================================================
-- get_scaled_font: 缩放字体记忆化（issue #167）
-- ============================================================================

local function with_font_mock(fn)
    local orig_getfont, orig_define = font.getfont, font.define
    local define_calls, next_id = 0, 100
    font.getfont = function(id)
        if id == 7 then return { size = 655360 } end   -- 10pt 原字体
        return nil                                      -- 缩放后的 id 拿不到（LEARNING 3.4）
    end
    font.define = function(data)
        define_calls = define_calls + 1
        next_id = next_id + 1
        return next_id
    end
    for k in pairs(internal.scaled_font_cache) do internal.scaled_font_cache[k] = nil end
    local ok, err = pcall(fn, function() return define_calls end)
    font.getfont, font.define = orig_getfont, orig_define
    for k in pairs(internal.scaled_font_cache) do internal.scaled_font_cache[k] = nil end
    if not ok then error(err, 0) end
end

test_utils.run_test("get_scaled_font: 无缩放参数时原样返回", function()
    with_font_mock(function(calls)
        local fid, scale = internal.get_scaled_font(7, {})
        test_utils.assert_eq(fid, 7)
        test_utils.assert_eq(scale, 1.0)
        test_utils.assert_eq(calls(), 0)
    end)
end)

test_utils.run_test("get_scaled_font: font_size 分支只 define 一次，命中缓存返回同 id 与同 scale", function()
    with_font_mock(function(calls)
        local fid1, s1 = internal.get_scaled_font(7, { font_size = "5pt" })
        test_utils.assert_eq(calls(), 1)
        test_utils.assert_eq(s1, 0.5)
        local fid2, s2 = internal.get_scaled_font(7, { font_size = "5pt" })
        test_utils.assert_eq(calls(), 1)
        test_utils.assert_eq(fid2, fid1)
        test_utils.assert_eq(s2, 0.5)
    end)
end)

test_utils.run_test("get_scaled_font: font_scale 分支只 define 一次，scale 原样缓存", function()
    with_font_mock(function(calls)
        local fid1, s1 = internal.get_scaled_font(7, { font_scale = 0.8 })
        test_utils.assert_eq(calls(), 1)
        test_utils.assert_eq(s1, 0.8)
        local fid2, s2 = internal.get_scaled_font(7, { font_scale = 0.8 })
        test_utils.assert_eq(calls(), 1)
        test_utils.assert_eq(fid2, fid1)
        test_utils.assert_eq(s2, 0.8)
    end)
end)

test_utils.run_test("get_scaled_font: 不同字号 / 不同分支各自缓存，互不串", function()
    with_font_mock(function(calls)
        local a = internal.get_scaled_font(7, { font_size = "5pt" })
        local b = internal.get_scaled_font(7, { font_size = "8pt" })
        local c = internal.get_scaled_font(7, { font_scale = 0.5 })
        test_utils.assert_eq(calls(), 3)
        test_utils.assert_true(a ~= b and b ~= c and a ~= c)
        -- 再来一轮全部命中
        internal.get_scaled_font(7, { font_size = "5pt" })
        internal.get_scaled_font(7, { font_size = "8pt" })
        internal.get_scaled_font(7, { font_scale = 0.5 })
        test_utils.assert_eq(calls(), 3)
    end)
end)

test_utils.run_test("get_scaled_font: 原字体拿不到时不 define、不缓存", function()
    with_font_mock(function(calls)
        local fid, scale = internal.get_scaled_font(99, { font_size = "5pt" })
        test_utils.assert_eq(fid, 99)
        test_utils.assert_eq(scale, 1.0)
        local fid2, scale2 = internal.get_scaled_font(99, { font_scale = 0.8 })
        test_utils.assert_eq(fid2, 99)
        test_utils.assert_eq(scale2, 0.8)
        test_utils.assert_eq(calls(), 0)
    end)
end)

print("\nAll render-banxin tests passed!")
