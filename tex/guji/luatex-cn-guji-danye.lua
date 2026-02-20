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
-- luatex-cn-guji-danye.lua - Single page (单页) support for traditional Chinese books
-- Used for content that should appear on a single page without split
-- ============================================================================

local danye = {}

--- Calculate dimensions for single page mode
-- Takes the current spread dimensions and returns single page dimensions
-- @return table with paper_width, margin_left, margin_right (all in sp)
function danye.get_single_page_dims()
    local pw = (_G.page and _G.page.paper_width) or 0
    local ml = (_G.page and _G.page.margin_left) or 0
    local mr = (_G.page and _G.page.margin_right) or 0

    return {
        paper_width = math.floor(pw / 2),
        margin_left = math.floor(ml / 2),
        margin_right = math.floor(mr / 2),
    }
end

--- Get single page paper width as string for TeX
function danye.get_paper_width_str()
    local dims = danye.get_single_page_dims()
    return string.format("%.5fpt", dims.paper_width / 65536)
end

--- Get single page margin left as string for TeX
function danye.get_margin_left_str()
    local dims = danye.get_single_page_dims()
    return string.format("%.5fpt", dims.margin_left / 65536)
end

--- Get single page margin right as string for TeX
function danye.get_margin_right_str()
    local dims = danye.get_single_page_dims()
    return string.format("%.5fpt", dims.margin_right / 65536)
end

-- Register module
package.loaded['guji.luatex-cn-guji-danye'] = danye

return danye
