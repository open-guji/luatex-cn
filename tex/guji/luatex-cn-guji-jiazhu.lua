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
-- luatex-cn-guji-jiazhu.lua - Jiazhu (夹注) configuration module
-- ============================================================================
-- Provides global state management for Jiazhu parameters.
-- The actual rendering logic is in the textflow engine.
-- ============================================================================

-- Initialize global jiazhu table
_G.jiazhu = _G.jiazhu or {}
_G.jiazhu.align = _G.jiazhu.align or "outward"
_G.jiazhu.font_size = _G.jiazhu.font_size or nil
_G.jiazhu.font = _G.jiazhu.font or nil
_G.jiazhu.font_color = _G.jiazhu.font_color or nil

--- Setup global jiazhu parameters from TeX
-- @param params (table) Parameters from TeX keyvals
local function setup(params)
    params = params or {}
    if params.align and params.align ~= "" then
        _G.jiazhu.align = params.align
    end
    if params.font_size and params.font_size ~= "" then
        _G.jiazhu.font_size = params.font_size
    end
    if params.font and params.font ~= "" then
        _G.jiazhu.font = params.font
    end
    if params.font_color and params.font_color ~= "" then
        _G.jiazhu.font_color = params.font_color
    end
end

-- Create module table
local jiazhu = {
    setup = setup,
}

-- Register module in package.loaded
package.loaded['guji.luatex-cn-guji-jiazhu'] = jiazhu

return jiazhu
