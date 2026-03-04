-- Unit tests for core.luatex-cn-core-punct
local test_utils = require("test.test_utils")
local punct = require("core.luatex-cn-core-punct")

-- ============================================================================
-- classify
-- ============================================================================

test_utils.run_test("classify: opening brackets", function()
    test_utils.assert_eq(punct.classify(0x300C), "open")   -- 「
    test_utils.assert_eq(punct.classify(0x300E), "open")   -- 『
    test_utils.assert_eq(punct.classify(0xFF08), "open")   -- （
    test_utils.assert_eq(punct.classify(0x3008), "open")   -- 〈
    test_utils.assert_eq(punct.classify(0x300A), "open")   -- 《
    test_utils.assert_eq(punct.classify(0x3010), "open")   -- 【
    test_utils.assert_eq(punct.classify(0x201C), "open")   -- "
    test_utils.assert_eq(punct.classify(0x2018), "open")   -- '
end)

test_utils.run_test("classify: vertical presentation forms (open)", function()
    test_utils.assert_eq(punct.classify(0xFE41), "open")   -- ﹁
    test_utils.assert_eq(punct.classify(0xFE43), "open")   -- ﹃
    test_utils.assert_eq(punct.classify(0xFE35), "open")   -- ︵
    test_utils.assert_eq(punct.classify(0xFE3D), "open")   -- ︽
end)

test_utils.run_test("classify: closing brackets", function()
    test_utils.assert_eq(punct.classify(0x300D), "close")  -- 」
    test_utils.assert_eq(punct.classify(0x300F), "close")  -- 』
    test_utils.assert_eq(punct.classify(0xFF09), "close")  -- ）
    test_utils.assert_eq(punct.classify(0x3009), "close")  -- 〉
    test_utils.assert_eq(punct.classify(0x300B), "close")  -- 》
    test_utils.assert_eq(punct.classify(0x201D), "close")  -- "
    test_utils.assert_eq(punct.classify(0x2019), "close")  -- '
end)

test_utils.run_test("classify: vertical presentation forms (close)", function()
    test_utils.assert_eq(punct.classify(0xFE42), "close")  -- ﹂
    test_utils.assert_eq(punct.classify(0xFE44), "close")  -- ﹄
    test_utils.assert_eq(punct.classify(0xFE36), "close")  -- ︶
    test_utils.assert_eq(punct.classify(0xFE3C), "close")  -- ︼
end)

test_utils.run_test("classify: fullstop", function()
    test_utils.assert_eq(punct.classify(0x3002), "fullstop") -- 。
    test_utils.assert_eq(punct.classify(0xFF0E), "fullstop") -- ．
end)

test_utils.run_test("classify: comma", function()
    test_utils.assert_eq(punct.classify(0xFF0C), "comma")  -- ，
    test_utils.assert_eq(punct.classify(0x3001), "comma")  -- 、
end)

test_utils.run_test("classify: middle punctuation", function()
    test_utils.assert_eq(punct.classify(0xFF1A), "middle") -- ：
    test_utils.assert_eq(punct.classify(0xFF1B), "middle") -- ；
    test_utils.assert_eq(punct.classify(0xFF01), "middle") -- ！
    test_utils.assert_eq(punct.classify(0xFF1F), "middle") -- ？
end)

test_utils.run_test("classify: nobreak characters", function()
    test_utils.assert_eq(punct.classify(0x2014), "nobreak") -- — em dash
    test_utils.assert_eq(punct.classify(0x2026), "nobreak") -- … ellipsis
end)

test_utils.run_test("classify: non-punctuation returns nil", function()
    test_utils.assert_nil(punct.classify(0x4E00))  -- 一 (CJK character)
    test_utils.assert_nil(punct.classify(0x0041))  -- A (Latin)
    test_utils.assert_nil(punct.classify(0x0020))  -- space
end)

-- ============================================================================
-- is_line_start_forbidden
-- ============================================================================

test_utils.run_test("is_line_start_forbidden: close/fullstop/comma/middle forbidden", function()
    test_utils.assert_true(punct.is_line_start_forbidden("close"))
    test_utils.assert_true(punct.is_line_start_forbidden("fullstop"))
    test_utils.assert_true(punct.is_line_start_forbidden("comma"))
    test_utils.assert_true(punct.is_line_start_forbidden("middle"))
end)

test_utils.run_test("is_line_start_forbidden: open/nobreak allowed", function()
    test_utils.assert_eq(punct.is_line_start_forbidden("open"), false)
    test_utils.assert_eq(punct.is_line_start_forbidden("nobreak"), false)
end)

test_utils.run_test("is_line_start_forbidden: nil type allowed", function()
    test_utils.assert_eq(punct.is_line_start_forbidden(nil), false)
end)

-- ============================================================================
-- is_line_end_forbidden
-- ============================================================================

test_utils.run_test("is_line_end_forbidden: open forbidden", function()
    test_utils.assert_true(punct.is_line_end_forbidden("open"))
end)

test_utils.run_test("is_line_end_forbidden: close/fullstop/comma/middle allowed", function()
    test_utils.assert_eq(punct.is_line_end_forbidden("close"), false)
    test_utils.assert_eq(punct.is_line_end_forbidden("fullstop"), false)
    test_utils.assert_eq(punct.is_line_end_forbidden("comma"), false)
    test_utils.assert_eq(punct.is_line_end_forbidden("middle"), false)
end)

test_utils.run_test("is_line_end_forbidden: nil type allowed", function()
    test_utils.assert_eq(punct.is_line_end_forbidden(nil), false)
end)

-- ============================================================================
-- type_from_code / code_from_type
-- ============================================================================

test_utils.run_test("type_from_code: valid codes", function()
    test_utils.assert_eq(punct.type_from_code(1), "open")
    test_utils.assert_eq(punct.type_from_code(2), "close")
    test_utils.assert_eq(punct.type_from_code(3), "fullstop")
    test_utils.assert_eq(punct.type_from_code(4), "comma")
    test_utils.assert_eq(punct.type_from_code(5), "middle")
    test_utils.assert_eq(punct.type_from_code(6), "nobreak")
end)

test_utils.run_test("type_from_code: invalid code returns nil", function()
    test_utils.assert_nil(punct.type_from_code(0))
    test_utils.assert_nil(punct.type_from_code(7))
    test_utils.assert_nil(punct.type_from_code(99))
end)

test_utils.run_test("code_from_type: valid types", function()
    test_utils.assert_eq(punct.code_from_type("open"), 1)
    test_utils.assert_eq(punct.code_from_type("close"), 2)
    test_utils.assert_eq(punct.code_from_type("fullstop"), 3)
    test_utils.assert_eq(punct.code_from_type("comma"), 4)
    test_utils.assert_eq(punct.code_from_type("middle"), 5)
    test_utils.assert_eq(punct.code_from_type("nobreak"), 6)
end)

test_utils.run_test("code_from_type: invalid type returns nil", function()
    test_utils.assert_nil(punct.code_from_type("unknown"))
    test_utils.assert_nil(punct.code_from_type(""))
end)

test_utils.run_test("type_from_code/code_from_type: roundtrip", function()
    local types = {"open", "close", "fullstop", "comma", "middle", "nobreak"}
    for _, t in ipairs(types) do
        local code = punct.code_from_type(t)
        test_utils.assert_eq(punct.type_from_code(code), t, "roundtrip failed for " .. t)
    end
end)

-- ============================================================================
-- setup
-- ============================================================================

test_utils.run_test("setup: sets global punct config", function()
    _G.punct = nil
    punct.setup({ style = "taiwan", squeeze = false, hanging = true, kinsoku = false })
    test_utils.assert_eq(_G.punct.style, "taiwan")
    test_utils.assert_eq(_G.punct.squeeze, false)
    test_utils.assert_eq(_G.punct.hanging, true)
    test_utils.assert_eq(_G.punct.kinsoku, false)
end)

test_utils.run_test("setup: partial config", function()
    _G.punct = { style = "mainland" }
    punct.setup({ kinsoku = true })
    test_utils.assert_eq(_G.punct.style, "mainland")
    test_utils.assert_eq(_G.punct.kinsoku, true)
end)

-- ============================================================================
-- initialize
-- ============================================================================

test_utils.run_test("initialize: returns context when no judou plugin context", function()
    _G.punct = nil
    local ctx = punct.initialize({}, {}, {})
    test_utils.assert_type(ctx, "table")
    test_utils.assert_eq(ctx.style, "mainland")
    test_utils.assert_eq(ctx.squeeze, true)
    test_utils.assert_eq(ctx.kinsoku, true)
    test_utils.assert_eq(ctx.hanging, false)
end)

test_utils.run_test("initialize: returns nil when judou plugin context has non-normal mode", function()
    local plugin_contexts = { judou = { punct_mode = "judou" } }
    local ctx = punct.initialize({}, {}, plugin_contexts)
    test_utils.assert_nil(ctx)
end)

test_utils.run_test("initialize: reads _G.punct config", function()
    _G.punct = { style = "taiwan", squeeze = false, hanging = true, kinsoku = false }
    local ctx = punct.initialize({}, {}, {})
    test_utils.assert_eq(ctx.style, "taiwan")
    test_utils.assert_eq(ctx.squeeze, false)
    test_utils.assert_eq(ctx.hanging, true)
    test_utils.assert_eq(ctx.kinsoku, false)
    _G.punct = nil
end)

-- ============================================================================
-- make_kinsoku_hook
-- ============================================================================

test_utils.run_test("make_kinsoku_hook: returns nil when no ctx", function()
    test_utils.assert_nil(punct.make_kinsoku_hook(nil))
end)

test_utils.run_test("make_kinsoku_hook: returns nil when kinsoku disabled", function()
    test_utils.assert_nil(punct.make_kinsoku_hook({ kinsoku = false }))
end)

test_utils.run_test("make_kinsoku_hook: returns function when kinsoku enabled", function()
    local hook = punct.make_kinsoku_hook({ kinsoku = true })
    test_utils.assert_type(hook, "function")
end)

-- ============================================================================
-- _internal: parse_tounicode (Issue #71)
-- ============================================================================

local parse_tounicode = punct._internal.parse_tounicode

test_utils.run_test("parse_tounicode: valid 4-digit hex string", function()
    test_utils.assert_eq(parse_tounicode("FF0C"), 0xFF0C)
    test_utils.assert_eq(parse_tounicode("3001"), 0x3001)
    test_utils.assert_eq(parse_tounicode("3002"), 0x3002)
    test_utils.assert_eq(parse_tounicode("0041"), 0x0041)
end)

test_utils.run_test("parse_tounicode: nil and empty input", function()
    test_utils.assert_nil(parse_tounicode(nil))
    test_utils.assert_nil(parse_tounicode(""))
end)

test_utils.run_test("parse_tounicode: wrong length strings return nil", function()
    test_utils.assert_nil(parse_tounicode("FF"))       -- too short
    test_utils.assert_nil(parse_tounicode("FF0C00"))   -- too long (surrogate pair)
    test_utils.assert_nil(parse_tounicode("D800DC00")) -- 8-digit surrogate pair
end)

-- ============================================================================
-- _internal: resolve_original_codepoint (Issue #71)
-- ============================================================================

local resolve_original_codepoint = punct._internal.resolve_original_codepoint

test_utils.run_test("resolve_original_codepoint: non-PUA char returns nil", function()
    test_utils.assert_nil(resolve_original_codepoint(99, 0xFF0C))  -- standard Unicode
    test_utils.assert_nil(resolve_original_codepoint(99, 0x4E00))  -- CJK char
    test_utils.assert_nil(resolve_original_codepoint(99, 0x0041))  -- ASCII
end)

test_utils.run_test("resolve_original_codepoint: PUA char with tounicode resolves to punct", function()
    -- Clear cache from previous tests
    for k in pairs(punct._internal.font_tounicode_cache) do
        punct._internal.font_tounicode_cache[k] = nil
    end

    -- Mock font.getfont to return a font with PUA characters
    local orig_getfont = font.getfont
    font.getfont = function(id)
        if id == 42 then
            return {
                size = 655360,
                characters = {
                    [0xF00A0] = { tounicode = "FF0C", index = 100 },  -- ， PUA
                    [0xF0071] = { tounicode = "3001", index = 101 },  -- 、 PUA
                    [0xF0072] = { tounicode = "3002", index = 102 },  -- 。 PUA
                    [0xFF1A]  = { tounicode = "FF1A", index = 200 },  -- ： (not PUA)
                    [0x4E00]  = { index = 300 },                      -- 一 (no tounicode)
                }
            }
        end
        return orig_getfont(id)
    end

    -- PUA chars with punct tounicode should resolve
    test_utils.assert_eq(resolve_original_codepoint(42, 0xF00A0), 0xFF0C)  -- ，
    test_utils.assert_eq(resolve_original_codepoint(42, 0xF0071), 0x3001)  -- 、
    test_utils.assert_eq(resolve_original_codepoint(42, 0xF0072), 0x3002)  -- 。

    -- Non-PUA char should still return nil (even if in same font)
    test_utils.assert_nil(resolve_original_codepoint(42, 0xFF1A))

    -- PUA char not in the font should return nil
    test_utils.assert_nil(resolve_original_codepoint(42, 0xF0099))

    -- Restore
    font.getfont = orig_getfont
end)

test_utils.run_test("resolve_original_codepoint: BMP PUA range also works", function()
    for k in pairs(punct._internal.font_tounicode_cache) do
        punct._internal.font_tounicode_cache[k] = nil
    end

    local orig_getfont = font.getfont
    font.getfont = function(id)
        if id == 43 then
            return {
                size = 655360,
                characters = {
                    [0xE000] = { tounicode = "FF0C", index = 50 },  -- BMP PUA
                }
            }
        end
        return orig_getfont(id)
    end

    test_utils.assert_eq(resolve_original_codepoint(43, 0xE000), 0xFF0C)

    font.getfont = orig_getfont
end)

test_utils.run_test("resolve_original_codepoint: PUA char with non-punct tounicode returns nil", function()
    for k in pairs(punct._internal.font_tounicode_cache) do
        punct._internal.font_tounicode_cache[k] = nil
    end

    local orig_getfont = font.getfont
    font.getfont = function(id)
        if id == 44 then
            return {
                size = 655360,
                characters = {
                    [0xF0001] = { tounicode = "4E00", index = 10 },  -- 一 (not punct)
                }
            }
        end
        return orig_getfont(id)
    end

    test_utils.assert_nil(resolve_original_codepoint(44, 0xF0001))

    font.getfont = orig_getfont
end)

test_utils.run_test("resolve_original_codepoint: caches per font", function()
    for k in pairs(punct._internal.font_tounicode_cache) do
        punct._internal.font_tounicode_cache[k] = nil
    end

    local call_count = 0
    local orig_getfont = font.getfont
    font.getfont = function(id)
        call_count = call_count + 1
        return {
            size = 655360,
            characters = {
                [0xF00A0] = { tounicode = "FF0C", index = 100 },
            }
        }
    end

    -- First call: builds cache
    resolve_original_codepoint(45, 0xF00A0)
    local first_count = call_count

    -- Second call: should use cache, no extra font.getfont call
    resolve_original_codepoint(45, 0xF00A0)
    test_utils.assert_eq(call_count, first_count, "should use cache on second call")

    font.getfont = orig_getfont
end)

-- ============================================================================
-- _internal: get_ink_center_ratio with PUA chars (Issue #71)
-- ============================================================================

local get_ink_center_ratio = punct._internal.get_ink_center_ratio

test_utils.run_test("get_ink_center_ratio: returns 0.5, 0.5 for unknown font", function()
    for k in pairs(punct._internal.font_ink_center_cache) do
        punct._internal.font_ink_center_cache[k] = nil
    end

    local orig_getfont = font.getfont
    font.getfont = function(id) return nil end

    local rx, ry = get_ink_center_ratio(999, 0xFF0C)
    test_utils.assert_eq(rx, 0.5)
    test_utils.assert_eq(ry, 0.5)

    font.getfont = orig_getfont
end)

test_utils.run_test("get_ink_center_ratio: returns 0.5, 0.5 for font without filename", function()
    for k in pairs(punct._internal.font_ink_center_cache) do
        punct._internal.font_ink_center_cache[k] = nil
    end

    local orig_getfont = font.getfont
    font.getfont = function(id) return { size = 655360 } end

    local rx, ry = get_ink_center_ratio(998, 0xFF0C)
    test_utils.assert_eq(rx, 0.5)
    test_utils.assert_eq(ry, 0.5)

    font.getfont = orig_getfont
end)

test_utils.run_test("get_ink_center_ratio: caches x and y ratios for PUA chars", function()
    for k in pairs(punct._internal.font_ink_center_cache) do
        punct._internal.font_ink_center_cache[k] = nil
    end

    -- Mock fontloader to return glyphs with bounding boxes
    local orig_getfont = font.getfont
    local orig_fontloader = fontloader
    font.getfont = function(id)
        if id == 50 then
            return {
                size = 655360,
                filename = "mock_font.otf",
                characters = {
                    -- Standard Unicode comma (glyph index 10)
                    [0xFF0C] = { tounicode = "FF0C", width = 655360, index = 10 },
                    -- PUA vert comma (glyph index 20) - mapped via vert GSUB
                    [0xF00A0] = { tounicode = "FF0C", width = 655360, index = 20 },
                    -- PUA vert ideographic comma (glyph index 21)
                    [0xF0071] = { tounicode = "3001", width = 655360, index = 21 },
                }
            }
        end
        return orig_getfont(id)
    end

    fontloader = {
        open = function(filename)
            return { _filename = filename }
        end,
        to_table = function(raw)
            return {
                glyphcnt = 30,
                glyphs = {
                    -- Index 10: standard comma, cx=(100+400)/2=250, cy=(0+800)/2=400
                    [10] = { unicode = 0xFF0C, width = 1000,
                             boundingbox = { 100, 0, 400, 800 } },
                    -- Index 20: vert comma (PUA), cx=(400+900)/2=650, cy=(200+600)/2=400
                    [20] = { width = 1000,
                             boundingbox = { 400, 200, 900, 600 } },
                    -- Index 21: vert ideo comma (PUA), cx=(100+600)/2=350, cy=(500+800)/2=650
                    [21] = { width = 1000,
                             boundingbox = { 100, 500, 600, 800 } },
                }
            }
        end,
        close = function(raw) end
    }

    -- Standard Unicode char: cx=250/1000=0.25, cy=400/1000=0.4
    local rx, ry = get_ink_center_ratio(50, 0xFF0C)
    test_utils.assert_eq(rx, 0.25, "standard comma ink center x")
    test_utils.assert_eq(ry, 0.4, "standard comma ink center y")

    -- PUA vert comma: cx=650/1000=0.65, cy=400/1000=0.4
    local prx, pry = get_ink_center_ratio(50, 0xF00A0)
    test_utils.assert_eq(prx, 0.65, "PUA vert comma ink center x")
    test_utils.assert_eq(pry, 0.4, "PUA vert comma ink center y")

    -- PUA vert ideographic comma: cx=350/1000=0.35, cy=650/1000=0.65
    local prx2, pry2 = get_ink_center_ratio(50, 0xF0071)
    test_utils.assert_eq(prx2, 0.35, "PUA vert ideo comma ink center x")
    test_utils.assert_eq(pry2, 0.65, "PUA vert ideo comma ink center y")

    -- Restore
    font.getfont = orig_getfont
    fontloader = orig_fontloader
end)

-- ============================================================================
-- _internal: INK_CENTER_CHARS coverage (Issue #71)
-- ============================================================================

test_utils.run_test("INK_CENTER_CHARS: contains expected punctuation", function()
    local chars = punct._internal.INK_CENTER_CHARS
    test_utils.assert_true(chars[0xFF0C] == true)  -- ，
    test_utils.assert_true(chars[0x3001] == true)  -- 、
    test_utils.assert_true(chars[0x3002] == true)  -- 。
    test_utils.assert_true(chars[0xFF0E] == true)  -- ．
    test_utils.assert_true(chars[0xFF1A] == true)  -- ：
    test_utils.assert_true(chars[0xFF1B] == true)  -- ；
    test_utils.assert_true(chars[0xFF01] == true)  -- ！
    test_utils.assert_true(chars[0xFF1F] == true)  -- ？
end)

test_utils.run_test("INK_CENTER_CHARS: does not contain CJK or Latin", function()
    local chars = punct._internal.INK_CENTER_CHARS
    test_utils.assert_nil(chars[0x4E00])   -- 一
    test_utils.assert_nil(chars[0x0041])   -- A
    test_utils.assert_nil(chars[0xF00A0])  -- PUA (not in INK_CENTER_CHARS directly)
end)

print("\nAll core/core-punct-test tests passed!")
