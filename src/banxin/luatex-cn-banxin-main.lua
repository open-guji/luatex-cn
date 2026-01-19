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
-- banxin_main.lua - ????????(????)
-- ============================================================================
-- ???: banxin_main.lua
-- ??: ??? (Extension Layer) - ??????
--
-- ????? / Module Purpose?
-- ????? banxin ??????,??:
--   1. ? vertical.hooks ??????????
--   2. ????????
--   3. ?? banxin.render_banxin ? banxin.render_yuwei ??
--
-- ??????
-- banxin ????????,???? vertical.hooks ????????
--
-- ============================================================================

-- Ensure vertical namespace exists (should be loaded by now)
_G.vertical = _G.vertical or {}
_G.vertical.hooks = _G.vertical.hooks or {}

-- Create banxin namespace for our modules
_G.banxin = _G.banxin or {}

-- 1. Load sub-modules using full namespaced paths
local render_banxin = package.loaded['banxin.render_banxin'] or require('banxin.luatex-cn-banxin-render-banxin')
-- Note: render_banxin will itself require banxin.render_yuwei if configured correctly

--- ????(Reserved Column)???????
-- @param p_head (node) ??????????
-- @param params (table) ?? vertical ???????
-- @return (node) ??????????
local function render_reserved_column(p_head, params)
    -- Simply forward to the drawing logic
    -- The vertical engine already passes the necessary context in 'params'
    -- including: x, y, width, height, font_size, border_color (as string), etc.
    return render_banxin.draw_banxin_column(p_head, params)
end

-- 2. Register Hooks
-- We overwrite the default no-op hooks in vertical.hooks
_G.vertical.hooks.render_reserved_column = render_reserved_column

-- 3. Export module table for TeX/other modules
local banxin_main = {
    render_reserved_column = render_reserved_column,
}

package.loaded['banxin_main'] = banxin_main
package.loaded['banxin.banxin_main'] = banxin_main

return banxin_main