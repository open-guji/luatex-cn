-- luatex-cn-ruby-metrics.lua
-- Shared metric constants and word-alignment rules for inter-line annotations
-- (行间注: 汉语拼音标音、中外文对照、注音符号), digitized from clreq
-- "Phonetic notation" (拼音/注音). Horizontal (H4) and vertical (P4) backends
-- both read from here so the ratios stay single-sourced (HR5).
--
-- Pure Lua, zero TeX dependency; tex_layout()/tex_defaults() additionally
-- talk to the token library when run inside LuaTeX (thin encoding shims, no
-- rules of their own).
--
-- Units: constants are em ratios; layout() works in any consistent length
-- unit (the backends pass sp).

local M = {}

-- ============================================================================
-- clreq constants
-- ============================================================================

-- 拼音注文字号与基文字号之比（clreq: 拼音字母通常采用基本文字尺寸的一半）
M.RUBY_SIZE_RATIO = 0.5

-- 注文与基文之间的空隙（基文 em）
M.RUBY_GAP = 0.10

-- 相邻注文之间的最小间距（注文字 em；clreq: 至少四分之一注音字宽）。
-- 无悬伸布局下由「注文不越出注块」构造性满足；悬伸实现须显式校验。
M.RUBY_MIN_SEP = 0.25

-- 注音符号宽度与汉字宽度之比（clreq: 注音与汉字比例为 3:10）
M.ZHUYIN_WIDTH_RATIO = 3 / 10

-- 轻声调号占位与汉字之比（clreq: 1:15）
M.ZHUYIN_LIGHT_TONE_RATIO = 1 / 15

-- 注音排于汉字右侧时需预留的字距（汉字 em；clreq: ≥ 1/2 字宽）
M.ZHUYIN_SIDE_GAP = 0.5

-- ============================================================================
-- Word alignment (clreq 词对齐)
-- ============================================================================

--- Solve the ruby block layout for one base/annotation pair.
-- clreq: 注文短于基文时加大注文字距（基文单字时居中）；注文长于基文时
-- 加大基文字距。伸长的一行按「n 个等宽槽位」分布：行内 n−1 个内隙各占
-- 一槽，两端各半槽——即两端对齐、端部留半隙，单元素时退化为居中。
-- @param base_w (number) natural width of the base text row
-- @param ann_w (number) natural width of the annotation row
-- @param n_base (number) item count of the base row (characters)
-- @param n_ann (number) item count of the annotation row (syllables/words)
-- @return (table) {
--   width      = block width (max of the two rows),
--   base_edge, base_inner = edge/inner gaps for the base row,
--   ann_edge,  ann_inner  = edge/inner gaps for the annotation row,
-- } — the longer row gets zero gaps.
function M.layout(base_w, ann_w, n_base, n_ann)
    local width = math.max(base_w, ann_w)

    local function spread(row_w, n)
        local extra = width - row_w
        if extra <= 0 or n < 1 then return 0, 0 end
        local slot = extra / n
        return slot / 2, slot
    end

    local base_edge, base_inner = spread(base_w, n_base)
    local ann_edge, ann_inner = spread(ann_w, n_ann)
    return {
        width = width,
        base_edge = base_edge, base_inner = base_inner,
        ann_edge = ann_edge, ann_inner = ann_inner,
    }
end

-- ============================================================================
-- TeX shims (no layout rules here — encoding only)
-- ============================================================================

local function set_sp_macro(name, v)
    token.set_macro(name, string.format("%dsp", math.floor(v + 0.5)))
end

--- Solve and publish the result as TeX macros (sp dimension texts):
-- \l__luatexcn_hori_ruby_{width,base_edge,base_inner,ann_edge,ann_inner}_tl
function M.tex_layout(base_w, ann_w, n_base, n_ann)
    local L = M.layout(base_w, ann_w, n_base, n_ann)
    set_sp_macro("l__luatexcn_hori_ruby_width_tl", L.width)
    set_sp_macro("l__luatexcn_hori_ruby_base_edge_tl", L.base_edge)
    set_sp_macro("l__luatexcn_hori_ruby_base_inner_tl", L.base_inner)
    set_sp_macro("l__luatexcn_hori_ruby_ann_edge_tl", L.ann_edge)
    set_sp_macro("l__luatexcn_hori_ruby_ann_inner_tl", L.ann_inner)
end

--- Publish the shared default constants as TeX macros (plain decimals), so
-- package keys can initialize from the shared layer:
-- \c__luatexcn_ruby_size_default_tl / \c__luatexcn_ruby_gap_default_tl
function M.tex_defaults()
    token.set_macro("c__luatexcn_ruby_size_default_tl",
        tostring(M.RUBY_SIZE_RATIO))
    token.set_macro("c__luatexcn_ruby_gap_default_tl",
        tostring(M.RUBY_GAP))
end

return M
