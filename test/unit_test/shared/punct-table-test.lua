-- Unit tests for shared.luatex-cn-punct-table
-- Each test cites the clreq clause it verifies.
local test_utils = require("test.test_utils")
local pt = require("shared.luatex-cn-punct-table")

-- ============================================================================
-- Classification (clreq appendix: 点号表 / 标号表 / 行间标号表)
-- ============================================================================

test_utils.run_test("class: pause/stop marks (点号)", function()
    test_utils.assert_eq(pt.class_of(0x3002), "fullstop")    -- 。
    test_utils.assert_eq(pt.class_of(0xFF0E), "fullstop")    -- ．
    test_utils.assert_eq(pt.class_of(0xFF0C), "comma")       -- ，
    test_utils.assert_eq(pt.class_of(0x3001), "comma")       -- 、
    test_utils.assert_eq(pt.class_of(0xFF1A), "colon")       -- ：
    test_utils.assert_eq(pt.class_of(0xFF1B), "semicolon")   -- ；
    test_utils.assert_eq(pt.class_of(0xFF01), "exclamation") -- ！
    test_utils.assert_eq(pt.class_of(0xFF1F), "question")    -- ？
    test_utils.assert_eq(pt.class_of(0x203C), "exclamation") -- ‼
    test_utils.assert_eq(pt.class_of(0x2047), "question")    -- ⁇
end)

test_utils.run_test("class: indication marks (标号)", function()
    test_utils.assert_eq(pt.class_of(0x2014), "dash")        -- —
    test_utils.assert_eq(pt.class_of(0x2E3A), "dash")        -- ⸺
    test_utils.assert_eq(pt.class_of(0x2026), "ellipsis")    -- …
    test_utils.assert_eq(pt.class_of(0x22EF), "ellipsis")    -- ⋯
    test_utils.assert_eq(pt.class_of(0xFF5E), "connector")   -- ～
    test_utils.assert_eq(pt.class_of(0x002D), "connector")   -- -
    test_utils.assert_eq(pt.class_of(0x2013), "connector")   -- –
    test_utils.assert_eq(pt.class_of(0x00B7), "interpunct")  -- ·
    test_utils.assert_eq(pt.class_of(0x30FB), "interpunct")  -- ・
    test_utils.assert_eq(pt.class_of(0x2027), "interpunct")  -- ‧
    test_utils.assert_eq(pt.class_of(0x002F), "solidus")     -- /
    test_utils.assert_eq(pt.class_of(0xFF0F), "solidus")     -- ／
end)

test_utils.run_test("class: brackets and quotes", function()
    for _, c in ipairs({ 0x300C, 0x300E, 0x201C, 0x2018, 0xFF08,
                         0x300A, 0x3008, 0x3010, 0x3016, 0x3014,
                         0xFF3B, 0xFF5B }) do
        test_utils.assert_eq(pt.class_of(c), "open",
            string.format("U+%04X should be open", c))
    end
    for _, c in ipairs({ 0x300D, 0x300F, 0x201D, 0x2019, 0xFF09,
                         0x300B, 0x3009, 0x3011, 0x3017, 0x3015,
                         0xFF3D, 0xFF5D }) do
        test_utils.assert_eq(pt.class_of(c), "close",
            string.format("U+%04X should be close", c))
    end
end)

test_utils.run_test("class: inter-line marks (行间标号)", function()
    test_utils.assert_eq(pt.class_of(0xFF3F), "linemark")  -- ＿ 专名号
    test_utils.assert_eq(pt.class_of(0xFE4F), "linemark")  -- ﹏ 书名号甲式
    test_utils.assert_eq(pt.class_of(0x25CF), "emphasis")  -- ● 着重号
    test_utils.assert_eq(pt.class_of(0x2022), "emphasis")  -- • 着重号
end)

test_utils.run_test("class: non-punctuation returns nil", function()
    test_utils.assert_nil(pt.class_of(0x4E00))  -- 一
    test_utils.assert_nil(pt.class_of(0x41))    -- A
end)

test_utils.run_test("is_point: 点号 yes, 标号 no", function()
    test_utils.assert_true(pt.is_point(0x3002))
    test_utils.assert_true(pt.is_point(0xFF1B))
    test_utils.assert_false(pt.is_point(0x00B7))  -- 间隔号是标号
    test_utils.assert_false(pt.is_point(0x300C))
end)

-- ============================================================================
-- Appendix columns: Unbreakable / Rotated 90° in vertical
-- ============================================================================

test_utils.run_test("unbreakable column: only two-em dash/ellipsis members", function()
    -- clreq appendix: ⸺ —— …… ⋯⋯ marked unbreakable
    for _, c in ipairs({ 0x2E3A, 0x2014, 0x2026, 0x22EF }) do
        test_utils.assert_true(pt.is_unbreakable(c),
            string.format("U+%04X should be unbreakable", c))
    end
    for _, c in ipairs({ 0x3002, 0xFF0C, 0x300C, 0xFF5E, 0x00B7 }) do
        test_utils.assert_false(pt.is_unbreakable(c),
            string.format("U+%04X should not be unbreakable", c))
    end
end)

test_utils.run_test("unbreakable pair: identical dash/ellipsis only", function()
    test_utils.assert_true(pt.is_unbreakable_pair(0x2014, 0x2014))  -- ——
    test_utils.assert_true(pt.is_unbreakable_pair(0x2026, 0x2026))  -- ……
    test_utils.assert_true(pt.is_unbreakable_pair(0x22EF, 0x22EF))  -- ⋯⋯
    test_utils.assert_false(pt.is_unbreakable_pair(0x2014, 0x2026))
    test_utils.assert_false(pt.is_unbreakable_pair(0x3002, 0x3002))
end)

test_utils.run_test("vert_rotate column matches appendix", function()
    -- Rotated: dashes, ellipses, connectors, half-width solidus, brackets,
    -- quotes, LOW LINE, WAVY LOW LINE
    for _, c in ipairs({ 0x2E3A, 0x2014, 0x2026, 0x22EF, 0xFF5E, 0x002D,
                         0x2013, 0x002F, 0x300C, 0x300D, 0x201C, 0xFF08,
                         0x300A, 0x3008, 0x3010, 0xFF3F, 0xFE4F }) do
        test_utils.assert_true(pt.vert_rotate(c),
            string.format("U+%04X should rotate in vertical", c))
    end
    -- Not rotated: all pause/stop marks, interpuncts, fullwidth solidus,
    -- emphasis marks
    for _, c in ipairs({ 0x3002, 0xFF0C, 0x3001, 0xFF1A, 0xFF01, 0xFF1F,
                         0x00B7, 0x30FB, 0x2027, 0xFF0F, 0x25CF, 0x2022 }) do
        test_utils.assert_false(pt.vert_rotate(c),
            string.format("U+%04X should not rotate in vertical", c))
    end
end)

-- ============================================================================
-- Width and adjustable space (clreq 标点符号的宽度调整 / 挤压处理的优先顺序)
-- ============================================================================

test_utils.run_test("width: GB half-width connector/interpunct/solidus", function()
    -- clreq: 不可调整的标点包括：中国大陆GB式的半字连接号、间隔号、分隔号
    test_utils.assert_eq(pt.width_of(0x002D, "mainland"), 0.5)
    test_utils.assert_eq(pt.width_of(0x2013, "mainland"), 0.5)
    test_utils.assert_eq(pt.width_of(0x00B7, "mainland"), 0.5)
    test_utils.assert_eq(pt.width_of(0x002F, "mainland"), 0.5)
    -- Taiwan interpunct takes one em
    test_utils.assert_eq(pt.width_of(0x00B7, "taiwan"), 1)
end)

test_utils.run_test("width: two-em dash forms", function()
    test_utils.assert_eq(pt.width_of(0x2E3A, "mainland"), 2)  -- ⸺ alone
    test_utils.assert_eq(pt.width_of(0x2014, "mainland"), 1)  -- — (pair member)
end)

test_utils.run_test("space_info: mainland comma has end space, shrink 0.5", function()
    -- clreq: 位于行内的逗号、顿号、分号…最小可以挤压到半个汉字字宽
    local info = pt.space_info(0xFF0C, "mainland", "horizontal")
    test_utils.assert_eq(info.side, "end")
    test_utils.assert_eq(info.shrink, 0.5)
end)

test_utils.run_test("space_info: taiwan centered marks have both-side space", function()
    local info = pt.space_info(0x3002, "taiwan", "horizontal")
    test_utils.assert_eq(info.side, "both")
    test_utils.assert_eq(info.shrink, 0.5)
end)

test_utils.run_test("space_info: brackets adjustable on outer side", function()
    -- clreq: 可以对开始夹注符号的前侧、结束夹注符号的后侧进行挤压
    local o = pt.space_info(0xFF08, "mainland", "horizontal")
    test_utils.assert_eq(o.side, "start")
    test_utils.assert_eq(o.shrink, 0.5)
    local c = pt.space_info(0xFF09, "mainland", "horizontal")
    test_utils.assert_eq(c.side, "end")
    test_utils.assert_eq(c.shrink, 0.5)
end)

test_utils.run_test("space_info: vertical colon/semicolon/q/excl fixed one em", function()
    -- clreq: 直排的冒号、分号、问号、感叹号（包括GB偏靠式和港台居中式）固定一个字宽
    for _, style in ipairs({ "mainland", "taiwan" }) do
        for _, c in ipairs({ 0xFF1A, 0xFF1B, 0xFF1F, 0xFF01 }) do
            local info = pt.space_info(c, style, "vertical")
            test_utils.assert_eq(info.side, "none",
                string.format("U+%04X %s vertical should be fixed", c, style))
            test_utils.assert_eq(info.shrink, 0)
        end
    end
end)

test_utils.run_test("space_info: horizontal taiwan ？！ fixed one em", function()
    -- clreq: 不可调整…横排的港台式问号、感叹号
    for _, c in ipairs({ 0xFF1F, 0xFF01 }) do
        local info = pt.space_info(c, "taiwan", "horizontal")
        test_utils.assert_eq(info.side, "none")
        test_utils.assert_eq(info.shrink, 0)
    end
    -- But mainland horizontal ？！ are adjustable (step 7)
    local info = pt.space_info(0xFF1F, "mainland", "horizontal")
    test_utils.assert_eq(info.shrink, 0.5)
end)

test_utils.run_test("space_info: colon not in compression list", function()
    -- clreq 挤压 7 级不含冒号 → 不可挤压
    local info = pt.space_info(0xFF1A, "mainland", "horizontal")
    test_utils.assert_eq(info.shrink, 0)
end)

test_utils.run_test("shrink_class_of maps to adjust groups", function()
    test_utils.assert_eq(pt.shrink_class_of(0xFF0C, "mainland", "horizontal"), "comma_group")
    test_utils.assert_eq(pt.shrink_class_of(0xFF1B, "mainland", "horizontal"), "comma_group")
    test_utils.assert_eq(pt.shrink_class_of(0x3002, "mainland", "horizontal"), "fullstop_group")
    test_utils.assert_eq(pt.shrink_class_of(0xFF08, "mainland", "horizontal"), "bracket")
    test_utils.assert_eq(pt.shrink_class_of(0x00B7, "taiwan", "horizontal"), "interpunct")
    -- Fixed under GB style → no shrink group
    test_utils.assert_nil(pt.shrink_class_of(0x00B7, "mainland", "horizontal"))
    -- Vertical semicolon fixed → no shrink group
    test_utils.assert_nil(pt.shrink_class_of(0xFF1B, "mainland", "vertical"))
end)

-- ============================================================================
-- Kinsoku level flags (clreq 行首行尾禁则: 四种级别)
-- ============================================================================

test_utils.run_test("forbid_line_start: basic set", function()
    -- clreq basic: 点号、结束引号/括号/书名号、连接号、间隔号、分隔号
    for _, c in ipairs({ 0x3002, 0xFF0C, 0x3001, 0xFF1A, 0xFF1B, 0xFF01,
                         0xFF1F, 0x300D, 0xFF09, 0x300B, 0xFF5E, 0x002D,
                         0x00B7, 0x002F }) do
        test_utils.assert_true(pt.forbid_line_start(c, "basic"),
            string.format("U+%04X should be start-forbidden at basic", c))
    end
    -- Opening brackets are not start-forbidden
    test_utils.assert_false(pt.forbid_line_start(0x300C, "basic"))
    -- none level forbids nothing
    test_utils.assert_false(pt.forbid_line_start(0x3002, "none"))
end)

test_utils.run_test("forbid_line_start: dash/ellipsis only at strict", function()
    -- clreq strict: 在GB法基础上增加破折号、省略号不能出现在行首
    test_utils.assert_false(pt.forbid_line_start(0x2014, "basic"))
    test_utils.assert_false(pt.forbid_line_start(0x2014, "gb"))
    test_utils.assert_true(pt.forbid_line_start(0x2014, "strict"))
    test_utils.assert_true(pt.forbid_line_start(0x2026, "strict"))
end)

test_utils.run_test("forbid_line_end: open brackets at basic, solidus at gb", function()
    -- clreq basic: 开始引号/括号/书名号不能出现在行尾
    test_utils.assert_true(pt.forbid_line_end(0x300C, "basic"))
    test_utils.assert_true(pt.forbid_line_end(0xFF08, "basic"))
    -- clreq GB法: 增加分隔号也不能出现在行尾
    test_utils.assert_false(pt.forbid_line_end(0x002F, "basic"))
    test_utils.assert_true(pt.forbid_line_end(0x002F, "gb"))
    test_utils.assert_true(pt.forbid_line_end(0x002F, "strict"))
    -- Closing brackets are never end-forbidden
    test_utils.assert_false(pt.forbid_line_end(0x300D, "strict"))
end)

-- ============================================================================
-- Legacy six-type mapping (P1 migration)
-- ============================================================================

test_utils.run_test("legacy_type matches current engine classification", function()
    test_utils.assert_eq(pt.legacy_type(0x300C), "open")
    test_utils.assert_eq(pt.legacy_type(0x300D), "close")
    test_utils.assert_eq(pt.legacy_type(0x3002), "fullstop")
    test_utils.assert_eq(pt.legacy_type(0xFF0C), "comma")
    test_utils.assert_eq(pt.legacy_type(0x3001), "comma")
    test_utils.assert_eq(pt.legacy_type(0xFF1A), "middle")
    test_utils.assert_eq(pt.legacy_type(0xFF1B), "middle")
    test_utils.assert_eq(pt.legacy_type(0xFF01), "middle")
    test_utils.assert_eq(pt.legacy_type(0xFF1F), "middle")
    test_utils.assert_eq(pt.legacy_type(0x2014), "nobreak")
    test_utils.assert_eq(pt.legacy_type(0x2026), "nobreak")
    -- The legacy engine does not classify stacked/new chars
    test_utils.assert_nil(pt.legacy_type(0x203C))
    test_utils.assert_nil(pt.legacy_type(0x2047))
end)

test_utils.run_test("quote_convert: nesting depth and role preserved (clreq 引号体例)", function()
    -- 台式（先单后双）→ 简体弯引号（先双后单）：外层对外层、内层对内层
    test_utils.assert_eq(pt.quote_convert(0x300C, "curly"), 0x201C)  -- 「→“
    test_utils.assert_eq(pt.quote_convert(0x300D, "curly"), 0x201D)  -- 」→”
    test_utils.assert_eq(pt.quote_convert(0x300E, "curly"), 0x2018)  -- 『→‘
    test_utils.assert_eq(pt.quote_convert(0x300F, "curly"), 0x2019)  -- 』→’
    -- 反向
    test_utils.assert_eq(pt.quote_convert(0x201C, "corner"), 0x300C)
    test_utils.assert_eq(pt.quote_convert(0x2019, "corner"), 0x300F)
    -- 已是目标体例 / 非引号字符：不转换
    test_utils.assert_nil(pt.quote_convert(0x201C, "curly"))
    test_utils.assert_nil(pt.quote_convert(0x300C, "corner"))
    test_utils.assert_nil(pt.quote_convert(0x4E00, "curly"))
    test_utils.assert_nil(pt.quote_convert(0x300C, "keep"))
end)

test_utils.run_test("is_stacked_pair / is_unbreakable_pair: 叹问号叠加（clreq 非典型标点）", function()
    -- ？？ ！！ ？！ ！？ 四种组合都是两字宽刚性整体
    test_utils.assert_true(pt.is_stacked_pair(0xFF1F, 0xFF1F))  -- ？？
    test_utils.assert_true(pt.is_stacked_pair(0xFF01, 0xFF01))  -- ！！
    test_utils.assert_true(pt.is_stacked_pair(0xFF1F, 0xFF01))  -- ？！（异字组合）
    test_utils.assert_true(pt.is_stacked_pair(0xFF01, 0xFF1F))  -- ！？
    -- is_unbreakable_pair 随之放行（此前被 a==b 与 dash/ellipsis 两条挡住）
    test_utils.assert_true(pt.is_unbreakable_pair(0xFF1F, 0xFF01))
    test_utils.assert_true(pt.is_unbreakable_pair(0xFF1F, 0xFF1F))
    -- 非叠加组合不受影响
    test_utils.assert_false(pt.is_stacked_pair(0xFF1F, 0x3002))  -- ？。
    test_utils.assert_false(pt.is_stacked_pair(0x3002, 0xFF01))  -- 。！
    test_utils.assert_false(pt.is_unbreakable_pair(0xFF0C, 0xFF0C))  -- ，，
    -- 原有 dash/ellipsis 语义不变
    test_utils.assert_true(pt.is_unbreakable_pair(0x2014, 0x2014))
    test_utils.assert_false(pt.is_unbreakable_pair(0x2014, 0x2026))
end)

print("All punct-table tests passed.")
