-- Unit tests for guji.luatex-cn-guji-jiazhu-shortcut
local test_utils = require("test.test_utils")
local shortcut = require("guji.luatex-cn-guji-jiazhu-shortcut")

-- Reset state before each test group
local function reset()
    shortcut.rules = {}
    shortcut._callback_registered = false
end

-- ============================================================================
-- _internal.utf8_chars
-- ============================================================================

test_utils.run_test("utf8_chars: ASCII string", function()
    local chars = shortcut._internal.utf8_chars("abc")
    test_utils.assert_eq(#chars, 3)
    test_utils.assert_eq(chars[1], "a")
    test_utils.assert_eq(chars[2], "b")
    test_utils.assert_eq(chars[3], "c")
end)

test_utils.run_test("utf8_chars: CJK string", function()
    local chars = shortcut._internal.utf8_chars("你好世界")
    test_utils.assert_eq(#chars, 4)
    test_utils.assert_eq(chars[1], "你")
    test_utils.assert_eq(chars[4], "界")
end)

test_utils.run_test("utf8_chars: mixed ASCII and CJK", function()
    local chars = shortcut._internal.utf8_chars("a你b")
    test_utils.assert_eq(#chars, 3)
    test_utils.assert_eq(chars[1], "a")
    test_utils.assert_eq(chars[2], "你")
    test_utils.assert_eq(chars[3], "b")
end)

test_utils.run_test("utf8_chars: empty string", function()
    local chars = shortcut._internal.utf8_chars("")
    test_utils.assert_eq(#chars, 0)
end)

-- ============================================================================
-- _internal.apply_rules (basic replacement)
-- ============================================================================

test_utils.run_test("apply_rules: basic bracket replacement", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules(
        "正文【夹注内容】继续"
    )
    test_utils.assert_eq(result, "正文\\夹注{夹注内容}继续")
end)

test_utils.run_test("apply_rules: multiple occurrences in one line", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules(
        "甲【注一】乙【注二】丙"
    )
    test_utils.assert_eq(result, "甲\\夹注{注一}乙\\夹注{注二}丙")
end)

test_utils.run_test("apply_rules: with opts", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "font-color=red",
    }}
    local result = shortcut._internal.apply_rules("文【注】字")
    test_utils.assert_eq(result, "文\\夹注[font-color=red]{注}字")
end)

test_utils.run_test("apply_rules: nested brackets (only outermost replaced)", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules("文【外【内】外】字")
    test_utils.assert_eq(result, "文\\夹注{外【内】外}字")
end)

test_utils.run_test("apply_rules: unmatched open bracket kept as-is", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules("文【未闭合")
    test_utils.assert_eq(result, "文【未闭合")
end)

test_utils.run_test("apply_rules: no brackets, no change", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules("普通正文无括号")
    test_utils.assert_eq(result, "普通正文无括号")
end)

test_utils.run_test("apply_rules: empty content between brackets", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules("文【】字")
    test_utils.assert_eq(result, "文\\夹注{}字")
end)

test_utils.run_test("apply_rules: different bracket pair", function()
    reset()
    shortcut.rules = {{
        open = "〔", close = "〕", command = "\\夹注", opts = "",
    }}
    local result = shortcut._internal.apply_rules("文〔注释〕字")
    test_utils.assert_eq(result, "文\\夹注{注释}字")
end)

test_utils.run_test("apply_rules: multiple rules", function()
    reset()
    shortcut.rules = {
        { open = "【", close = "】", command = "\\夹注", opts = "" },
        { open = "〔", close = "〕", command = "\\夹注", opts = "font-color=blue" },
    }
    local result = shortcut._internal.apply_rules("甲【注一】乙〔注二〕丙")
    test_utils.assert_eq(result, "甲\\夹注{注一}乙\\夹注[font-color=blue]{注二}丙")
end)

-- ============================================================================
-- _internal.apply_rules (issue #76 example)
-- ============================================================================

test_utils.run_test("apply_rules: issue #76 example text", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local input = "先生施教，弟子是則。温恭自虚，所受是極。" ..
        "【必虚其心，然後能有所容也。極，謂盡其本原也。】" ..
        "見善從之，聞義則服。温柔孝弟，母驕恃力。"
    local expected = "先生施教，弟子是則。温恭自虚，所受是極。" ..
        "\\夹注{必虚其心，然後能有所容也。極，謂盡其本原也。}" ..
        "見善從之，聞義則服。温柔孝弟，母驕恃力。"
    test_utils.assert_eq(shortcut._internal.apply_rules(input), expected)
end)

-- ============================================================================
-- process_input_buffer
-- ============================================================================

test_utils.run_test("process_input_buffer: no rules, returns unchanged", function()
    reset()
    local result = shortcut.process_input_buffer("【测试】")
    test_utils.assert_eq(result, "【测试】")
end)

test_utils.run_test("process_input_buffer: with rules, applies replacement", function()
    reset()
    shortcut.rules = {{
        open = "【", close = "】", command = "\\夹注", opts = "",
    }}
    local result = shortcut.process_input_buffer("正文【注】继续")
    test_utils.assert_eq(result, "正文\\夹注{注}继续")
end)

-- ============================================================================
-- register (without actual callback registration, since luatexbase is mocked)
-- ============================================================================

test_utils.run_test("register: adds rule to rules table", function()
    reset()
    shortcut.register("【", "】", "\\夹注", "")
    test_utils.assert_eq(#shortcut.rules, 1)
    test_utils.assert_eq(shortcut.rules[1].open, "【")
    test_utils.assert_eq(shortcut.rules[1].close, "】")
    test_utils.assert_eq(shortcut.rules[1].command, "\\夹注")
end)

test_utils.run_test("register: multiple registrations accumulate", function()
    reset()
    shortcut.register("【", "】", "\\夹注", "")
    shortcut.register("〔", "〕", "\\夹注", "font-color=red")
    test_utils.assert_eq(#shortcut.rules, 2)
    test_utils.assert_eq(shortcut.rules[2].opts, "font-color=red")
end)

test_utils.run_test("register: callback registered once", function()
    reset()
    shortcut.register("【", "】", "\\夹注", "")
    test_utils.assert_eq(shortcut._callback_registered, true)
    shortcut.register("〔", "〕", "\\夹注", "")
    test_utils.assert_eq(shortcut._callback_registered, true)
end)

-- ============================================================================
-- clear
-- ============================================================================

test_utils.run_test("clear: removes all rules", function()
    reset()
    shortcut.register("【", "】", "\\夹注", "")
    shortcut.clear()
    test_utils.assert_eq(#shortcut.rules, 0)
    test_utils.assert_eq(shortcut._callback_registered, false)
end)

print("\nAll guji/jiazhu-shortcut-test tests passed!")
