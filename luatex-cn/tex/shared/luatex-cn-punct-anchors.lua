-- luatex-cn-punct-anchors.lua
-- clreq《标点符号的字面分布》的**度量锚点**（共享层）。
--
-- 中国大陆式：点号字面偏靠（横排左下、直排右上）；台湾式：字面居中。
-- 字体把墨迹画在字幅的哪个位置是字体自己的设计惯例（中国大陆字体横排形
-- 在左下、直排 vert 形在右上；台湾字体两个方向都居中）——排版风格
-- 不应随字体漂移。本模块给出每个标点在每种 style × mode 下墨迹中心
-- 应落的位置（em 比值，x 自左、y 自基线向上），后端读字形 boundingbox
-- 算出墨心，把差值写进 xoffset/yoffset：字体画在哪都无所谓，量出来
-- 再挪过去。
--
-- 锚点值取自该风格的样板字体实测（样板字体自身位移为零，其余字体
-- 收敛到同一落点）：
--   台湾式（横竖同值）：TW-Kai——横竖两个方向字形都居中；
--   中国大陆式横排：思源宋体（Source Han Serif SC）——GB 惯例左下；
--   中国大陆式直排：TW-Kai 在旧「经验偏移」实现下的实测落点（该观感已经
--   过基线评审）：墨心对中 + 0.2×格宽右移（cn-vbook 版式合 0.857em），
--   句号另 +0.25em 上移；中点类纵向取 TW-Kai 字形的自然位置。
--
-- 纯 Lua、零 TeX 依赖（HR5：clreq 规则只写在 tex/shared/）；只依赖同层的
-- punct-table（夹注号清单取自那份单一数据源）。
-- 契约见 ai_must_read/clreq-shared-core.md。

local M = {}

-- 键为**原始码位**（vert GSUB 落到 PUA 的字形由后端先解析回原始码位）。
-- 值 {x, y}：墨迹中心的目标位置（em）。y = nil 表示纵向随字形设计。

-- 台湾式（横排、直排同值）：字面居中。TW-Kai 实测。
local TAIWAN = {
    [0xFF0C] = { x = 0.495, y = 0.311 }, -- ，
    [0x3001] = { x = 0.478, y = 0.314 }, -- 、
    [0x3002] = { x = 0.499, y = 0.299 }, -- 。
    [0xFF0E] = { x = 0.499, y = 0.299 }, -- ．
    [0xFF1A] = { x = 0.500, y = 0.363 }, -- ：
    [0xFF1B] = { x = 0.496, y = 0.313 }, -- ；
    [0xFF01] = { x = 0.496, y = 0.316 }, -- ！
    [0xFF1F] = { x = 0.500, y = 0.320 }, -- ？
}

-- 中国大陆式横排：点号靠左下（GB 惯例）。思源宋体实测。
local HORI_MAINLAND = {
    [0xFF0C] = { x = 0.153, y = -0.039 },
    [0x3001] = { x = 0.165, y = 0.049 },
    [0x3002] = { x = 0.183, y = 0.059 },
    [0xFF0E] = { x = 0.183, y = 0.059 },
    [0xFF1A] = { x = 0.232, y = 0.296 },
    [0xFF1B] = { x = 0.214, y = 0.217 },
    [0xFF01] = { x = 0.249, y = 0.390 },
    [0xFF1F] = { x = 0.247, y = 0.377 },
}

-- 中国大陆式直排：点号偏靠右上（贴前字）。x=0.857 见文件头；中点类
-- （：；！？）保持直立，横向偏靠、纵向取 TW-Kai 的自然位置。
local VERT_MAINLAND = {
    [0xFF0C] = { x = 0.857, y = 0.31 },
    [0x3001] = { x = 0.857, y = 0.31 },
    [0x3002] = { x = 0.857, y = 0.55 },
    [0xFF0E] = { x = 0.857, y = 0.55 },
    [0xFF1A] = { x = 0.857, y = 0.363 },
    [0xFF1B] = { x = 0.857, y = 0.313 },
    [0xFF01] = { x = 0.857, y = 0.316 },
    [0xFF1F] = { x = 0.857, y = 0.320 },
}

-- ============================================================================
-- 夹注号（引号 / 括号 / 书名号）的字面分布
-- ============================================================================
--
-- clreq 6.3.2.1 图 30 把「可调整」的标点按空白所在侧分六类。夹注号在
-- 直排里分属**字面上侧**（︽︵﹁﹃ 等开始夹注符号，空白在上、字面贴后字）
-- 与**字面下侧**（︾︶﹂﹄ 等结束夹注符号，空白在下、字面贴前字）；横排
-- 则是字面左侧（开始）与字面右侧（结束）。图 30 的「字面上下两侧（居中）」
-- 一组只有点号与间隔号——**夹注号在两种风格下都是单侧**，港台式的差别只在
-- clreq 6.3.2 正文说的「台湾的很多印刷品都采用不调整（不压缩）的风格」。
-- 配套条款：「可以对开始夹注符号的前侧、结束夹注符号的后侧进行挤压」
-- 「挤压方向判定原则上应该让开始、结束夹注符号紧靠被夹注的内容」。
--
-- 与点号的差别：台湾《重訂標點符號手冊》夾注號甲式（）另有「居正中」的
-- 写法，但書名號乙式《》只说「各占行中一格」、引號说「居左上、右下角」，
-- 三者互不一致；本实现统一按 clreq 图 30 走单侧，不给台湾式开分支。
--
-- 半格：字面占半个字幅，字面中心落在该半格的中点，即离字幅中心 0.25em。
local BRACKET_HALF = 0.25

-- 只锚直排，横排不动。横排字形的 advance 起点就是字幅始端，字体画在哪
-- 直接就是字面分布——实测四款字体的 （ 墨心都在 0.65～0.79（都过了中线，
-- 空白确实在外侧），只是内侧贴合的松紧不同；把墨心统一拉到 0.75 反而会
-- 松开思源宋体那种贴得更紧的设计，还会让「开始夹注符号之后不加空白」的
-- 度量断言读到位移。直排则不同：引擎自己按字形 height/depth 盒把字面居中
-- 在字幅里（见下），字体的 vert 形怎么画都会被这层居中搅乱，必须锚。

--- 直排夹注号的字面位移——相对**引擎当前落点**，不是绝对锚点。
--
-- 直排下引擎把字形的 height/depth 盒居中在字幅里
-- （render-position.calc_grid_position 的 em_center=false 分支），基线落点
-- 因此随字体的 height/depth 浮动，没法像点号那样写「基线以上 x em」的
-- 绝对锚点。这里直接算「把字面中心从字幅中心挪到上/下半格中点」要多少位移：
--
--   落点：基线 = 字幅中心 − (h − d) / 2；字面中心 = 基线 + c
--   目标：字面中心 = 字幅中心 ± BRACKET_HALF
--   ⇒ dy = ±BRACKET_HALF + (h − d) / 2 − c
--
-- 注意 h/d 是 luaotfload 从字形墨迹盒写来的，墨迹整个在基线之上时 d 被
-- 截为 0（LEARNING 记过的 ︼ 例子），(h − d)/2 因此不等于 c——这个差正是
-- 各字体结束夹注符号忽高忽低的来源。
--
-- @param class (string) "open" | "close"
-- @param bb (table) 字形 boundingbox {xmin, ymin, xmax, ymax}（字体单位）
-- @param upem (number) 字体 units_per_em
-- @param h_em (number) 字形 height（em）
-- @param d_em (number) 字形 depth（em）
-- @return (number|nil) dy（em，向上为正）；数据不全时 nil
function M.vert_bracket_dy(class, bb, upem, h_em, d_em)
    if class ~= "open" and class ~= "close" then return nil end
    if not (bb and bb[2] and bb[4]) or not upem or upem <= 0 then return nil end
    if type(h_em) ~= "number" or type(d_em) ~= "number" then return nil end
    -- 直排：结束夹注符号的字面在上半格（贴前字），开始的在下半格（贴后字）
    local target = (class == "close") and BRACKET_HALF or -BRACKET_HALF
    local c = (bb[2] + bb[4]) / 2 / upem
    return target + (h_em - d_em) / 2 - c
end

--- 查锚点。
-- @param orig (number) 原始码位（PUA vert 形须先解析回来）
-- @param style (string) "mainland" | "taiwan" | "none"
-- @param mode (string) "horizontal" | "vertical"
-- @return (table|nil) { x, y } em；style="none" 或无此码位时 nil
function M.anchor(orig, style, mode)
    if style == "taiwan" then
        return TAIWAN[orig]
    elseif style == "mainland" then
        if mode == "horizontal" then
            return HORI_MAINLAND[orig]
        end
        return VERT_MAINLAND[orig]
    end
    return nil -- "none"：不调整预设，字面不挪动
end

--- 把墨迹中心挪到锚点所需的位移（纯函数，便于单测）。
-- @param orig (number) 原始码位
-- @param style (string) "mainland" | "taiwan" | "none"
-- @param mode (string) "horizontal" | "vertical"
-- @param bb (table) 字形 boundingbox {xmin, ymin, xmax, ymax}（字体单位）
-- @param upem (number) 字体 units_per_em
-- @param em_sp (number) 该字形自身字号（sp）
-- @return (number|nil, number) dx, dy（sp）；无锚点或数据不全时 nil
function M.offsets(orig, style, mode, bb, upem, em_sp)
    local a = M.anchor(orig, style, mode)
    if not a or not bb or not upem or upem <= 0 or not em_sp then
        return nil, 0
    end
    if not (bb[1] and bb[3]) then return nil, 0 end
    -- 死区：锚点值是样板字体的实测（3 位小数），与该字体自身墨心的
    -- 残差在 0.001em 量级。低于视觉阈值的位移一律取零——样板字体因此
    -- 严格零位移（版面 bit 不变），也避免亚可视的 yoffset 干扰按坐标
    -- 分行/分列的度量工具。
    local EPS = 0.002
    local function shift(target, center)
        local d = target - center
        if math.abs(d) < EPS then return 0 end
        return math.floor(d * em_sp + 0.5)
    end
    local dx = shift(a.x, (bb[1] + bb[3]) / 2 / upem)
    local dy = 0
    if a.y and bb[2] and bb[4] then
        dy = shift(a.y, (bb[2] + bb[4]) / 2 / upem)
    end
    return dx, dy
end

return M
