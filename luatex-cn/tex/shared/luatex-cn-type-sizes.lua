-- luatex-cn-type-sizes.lua
-- 号数制字号表（中文活字/照排传统，clreq「字号」节采用的号数系统）。
-- 横排（H5）与竖排共享的单一数据源；纯 Lua，零 TeX 依赖。
--
-- 数值单位为 bp（美式点，1 bp = 1/72 in）——号数制源于美式点制，
-- 印刷业标准即按此标定（五号 = 10.5 点）。TeX 侧用 "Nbp" 尺寸即可。

local M = {}

-- 号数 → 字号 (bp)。含通行的「小X号」半档。
M.SIZES = {
    ["初号"] = 42,
    ["小初"] = 36,
    ["一号"] = 26,
    ["小一"] = 24,
    ["二号"] = 22,
    ["小二"] = 18,
    ["三号"] = 16,
    ["小三"] = 15,
    ["四号"] = 14,
    ["小四"] = 12,
    ["五号"] = 10.5,
    ["小五"] = 9,
    ["六号"] = 7.5,
    ["小六"] = 6.5,
    ["七号"] = 5.5,
    ["八号"] = 5,
}

-- 默认行距倍数（字号 × 倍数 = \baselineskip）。中文书刊正文常用 1.5–1.7；
-- 取 1.5 为兜底，文档可自行覆盖。
M.DEFAULT_LEADING = 1.5

--- 查询号数对应的字号。
-- @param name (string) 号数名（如 "五号"、"小四"）
-- @return (number|nil) 字号 (bp)，未知号数返回 nil
function M.size_of(name)
    return M.SIZES[name]
end

-- ============================================================================
-- TeX shim（仅编码转换，无规则）
-- ============================================================================

--- 把号数解析结果写入 TeX 宏：
-- \l__luatexcn_hori_zihao_size_tl（"10.5bp" 形式）与
-- \l__luatexcn_hori_zihao_base_tl（行距 = 字号 × 倍数）。
-- 未知号数时两宏均置空，由 TeX 侧报错。
-- @param name (string) 号数名
-- @param leading (number|nil) 行距倍数，缺省用 DEFAULT_LEADING
function M.tex_lookup(name, leading)
    local size = M.SIZES[name]
    if not size then
        token.set_macro("l__luatexcn_hori_zihao_size_tl", "")
        token.set_macro("l__luatexcn_hori_zihao_base_tl", "")
        return
    end
    local mult = leading or M.DEFAULT_LEADING
    token.set_macro("l__luatexcn_hori_zihao_size_tl",
        string.format("%.5fbp", size))
    token.set_macro("l__luatexcn_hori_zihao_base_tl",
        string.format("%.5fbp", size * mult))
end

return M
