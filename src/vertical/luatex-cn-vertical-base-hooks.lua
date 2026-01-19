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
-- base_hooks.lua - ????????(????)
-- ============================================================================
-- ???: base_hooks.lua
-- ??: ??? (Base Layer) - ??/????
--
-- ????? / Module Purpose?
-- ???????????,?????(? cn_banxin)??????:
--   1. ??? - ?????????????
--   2. ????? - ????????????(???)
--
-- ????? / Usage?
-- ??????? hooks ?????????????:
--   vertical.hooks.is_reserved_column = function(col) ... end
--   vertical.hooks.render_reserved_column = function(params) ... end
--
-- ????? / Terminology?
--   reserved_column   - ???(?????????)
--   hook              - ??(?????????)
--   callback          - ??(?????????)
--
-- ============================================================================

local hooks = {}

--- ??????????(???????)
-- ????:????
-- @param col (number) ???(0-based)
-- @param interval (number) n_column ???
-- @return (boolean) ??????
function hooks.is_reserved_column(col, interval)
    if not interval or interval <= 0 then return false end
    -- Default logic: traditional banxin at (col % (n + 1)) == n
    return (col % (interval + 1)) == interval
end

--- ????????
-- ????:???????
-- @param p_head (node) ?????????
-- @param params (table) ????:
--   - col (number) ???
--   - x (number) X ?? (scaled points)
--   - y (number) Y ?? (scaled points)
--   - width (number) ??? (scaled points)
--   - height (number) ??? (scaled points)
--   - border_thickness (number) ????
--   - page_number (number) ??
--   - ... ??????
-- @return (node) ?????????
function hooks.render_reserved_column(p_head, params)
    return p_head
end

--- ????????
-- ????:?????
-- @return (table) ??? { interval = 0 }
function hooks.get_reserved_config()
    return { interval = 0 }
end

-- Register in global namespace for access from TeX and other modules
_G.vertical = _G.vertical or {}
if not _G.vertical.hooks then
    _G.vertical.hooks = hooks
else
    -- Update existing hooks table with our defaults if they are missing
    for k, v in pairs(hooks) do
        if _G.vertical.hooks[k] == nil then
            _G.vertical.hooks[k] = v
        end
    end
    hooks = _G.vertical.hooks
end

-- Register module
package.loaded['luatex-cn-vertical-base-hooks'] = hooks

return hooks