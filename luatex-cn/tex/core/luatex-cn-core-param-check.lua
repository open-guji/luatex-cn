-- Copyright 2026 Open-Guji (https://github.com/open-guji)
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================
-- luatex-cn-core-param-check.lua - 参数相互覆盖 / 不合理组合的提醒（issue #195）
-- ============================================================================
-- 很多「一起用会变形」其实是一个参数静默覆盖了另一个。这里在排版时检查这些组合，
-- 用户设的值不生效、或几个值凑在一起放不下时发一次警告。
--
-- 「谁设的」：只有用户在导言区或正文里设的 key 才算（mark）；类文件与模板 .cfg
-- 加载期间（quiet 深度 > 0）设的值不算，否则每份文档都会因模板默认值刷警告。
-- 每条警告每份文档只发一次。

local check = {}

local state = {
    quiet = 0,        -- >0 while a class / template config file is loading
    user_set = {},    -- key -> true, set by the user (not by a template)
    warned = {},      -- message id -> true
}

local function pt(sp)
    return string.format("%.2fpt", (sp or 0) / 65536)
end

--- Enter (true) or leave (false) a template-loading region; nests.
function check.quiet(flag)
    if flag then
        state.quiet = state.quiet + 1
    elseif state.quiet > 0 then
        state.quiet = state.quiet - 1
    end
end

--- Record that the user set a key (ignored while a template is loading).
-- @param key (string) canonical key name, e.g. "grid_height"
function check.mark(key)
    if state.quiet == 0 then state.user_set[key] = true end
end

function check.is_user_set(key)
    return state.user_set[key] == true
end

--- Emit a warning once per document.
-- @return (boolean) true when the warning was written now
function check.warn_once(id, msg)
    if state.warned[id] then return false end
    state.warned[id] = true
    if texio and texio.write_nl then
        texio.write_nl("term and log", "luatex-cn Warning: " .. msg)
    end
    return true
end

--- ltc-guji 自动版式（行数 > 0）：格宽总由版面宽度、行数、版心比例算出；
-- 每行字数 > 0 时格高由版面高度算出。用户另设的格宽 / 格高因此不生效。
-- @param p (table) { n_column, n_char_per_col, grid_width_sp, grid_height_sp }
--   the computed values that replace the user's
function check.guji_layout(p)
    if (p.n_column or 0) > 0 and check.is_user_set("grid_width") then
        check.warn_once("grid-width",
            "格宽（grid-width）不生效：行数（n-column）> 0 时格宽由版面宽度、行数与版心比例算出"
            .. "（现为 " .. pt(p.grid_width_sp) .. "）；要改格宽请调 n-column、左右边距或 banxin-ratio"
            .. " (grid-width is ignored while n-column > 0; it is computed from the page width,"
            .. " n-column and banxin-ratio).")
    end
    if (p.n_char_per_col or 0) > 0 and check.is_user_set("grid_height") then
        check.warn_once("grid-height",
            "格高（grid-height）不生效：每行字数（n-char-per-col）= " .. p.n_char_per_col
            .. " 时格高由版面高度算出（现为 " .. pt(p.grid_height_sp) .. "）；要用格高请设 n-char-per-col=0"
            .. " (grid-height is ignored while n-char-per-col > 0; set n-char-per-col=0 to use it).")
    end
end

--- 版面行数（page-columns）直接定每页列数，按内容区等分格宽：
-- 不再给版心留位（版心开着时正文会压在版心上），行数也不再起作用。
-- @param explicit_page_cols (number) page-columns (0 = not set)
-- @param banxin_on (boolean)
function check.page_columns(explicit_page_cols, banxin_on)
    if (explicit_page_cols or 0) <= 0 or not check.is_user_set("page_columns") then return end
    if banxin_on then
        check.warn_once("page-columns-banxin",
            "版面行数（page-columns）= " .. explicit_page_cols
            .. " 时按内容区等分列宽，不给版心留位，正文会压在版心上；有版心时请用 n-column（行数）"
            .. " (page-columns does not reserve the banxin column; use n-column when banxin is on).")
    elseif check.is_user_set("n_column") then
        check.warn_once("page-columns-n-column",
            "版面行数（page-columns）与行数（n-column）同时设置时以版面行数为准，行数不生效"
            .. " (page-columns overrides n-column).")
    end
end

--- 字号大于格高：上下相邻的字压叠。只在用户自己设了字号或每行字数时检查
-- （只改纸张、不碰这两个的文档，如只排封面的，不提醒）。
-- 格宽不查：数字化等模式下 grid_width 不等于实际列宽，会误报。
-- @param p (table) { font_size_sp, grid_height_sp, layout_mode }
function check.font_fit(p)
    if p.layout_mode == "natural" then return end
    if not (check.is_user_set("font_size") or check.is_user_set("n_char_per_col")) then return end
    local fs, gh = p.font_size_sp, p.grid_height_sp
    if type(fs) ~= "number" or fs <= 0 or type(gh) ~= "number" or gh <= 0 then return end
    local tol = 65536 / 2 -- 0.5pt: rounding of computed grids
    if fs > gh + tol then
        check.warn_once("font-size-grid-height",
            "字号（font-size）" .. pt(fs) .. " 大于格高 " .. pt(gh) .. "，上下相邻的字会压叠；"
            .. "请减小字号或每行字数（n-char-per-col）"
            .. " (font-size is larger than the grid height; characters will overlap).")
    end
end

--- 版心上比 + 中比 > 1：下段（页码处）没有空间，下分隔线与页码被挤出版心。
function check.banxin_ratios(upper, middle)
    upper, middle = tonumber(upper), tonumber(middle)
    if not upper or not middle then return end
    if upper + middle > 1 + 1e-9 then
        check.warn_once("banxin-ratios",
            string.format("版心上比（banxin-upper-ratio）%.3g + 版心中比（banxin-middle-ratio）%.3g = %.3g > 1，"
                .. "版心下段没有空间，下分隔线与页码会被挤出版心"
                .. " (banxin-upper-ratio + banxin-middle-ratio must not exceed 1).",
                upper, middle, upper + middle))
    end
end

--- Reset all state (unit tests).
function check._reset()
    state.quiet = 0
    state.user_set = {}
    state.warned = {}
end

package.loaded['core.luatex-cn-core-param-check'] = check
return check
