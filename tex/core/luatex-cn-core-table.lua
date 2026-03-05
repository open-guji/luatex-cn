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
-- luatex-cn-core-table.lua - Table mode support
-- ============================================================================

local table_mod = {}

--- Initialize table mode
-- Called at \begin{Table} start
function table_mod.init()
    _G.content = _G.content or {}
    _G.content.table_mode = true
    _G.content.table_col_groups = {}
    _G.content.table_cell_idx = 0
    _G.content.table_render_cell_idx = 0
end

--- Clean up table mode
-- Called at \end{Table} end
function table_mod.cleanup()
    if _G.content then
        _G.content.table_mode = false
        _G.content.table_col_groups = nil
        _G.content.table_cell_idx = nil
        _G.content.table_render_cell_idx = nil
    end
end

--- Register a cell and emit cell break penalty if needed
-- @param col_width (number) Number of columns this cell spans (0 = unlimited)
function table_mod.begin_cell(col_width)
    _G.content = _G.content or {}
    local cell_idx = _G.content.table_cell_idx or 0

    -- Record column group width (0 = unlimited)
    _G.content.table_col_groups = _G.content.table_col_groups or {}
    _G.content.table_col_groups[cell_idx + 1] = col_width
    _G.content.table_cell_idx = cell_idx + 1

    -- If not the first cell in this band, emit cell break penalty
    if cell_idx > 0 then
        local n = node.new("penalty")
        n.penalty = -10007  -- PENALTY_CELL_BREAK
        node.write(n)
    end
end

--- Reset cell counter for a new band (row)
-- Called by \换栏 command and by band break handler in layout-grid
function table_mod.reset_band_cells()
    if _G.content then
        _G.content.table_cell_idx = 0
    end
end

--- Reset render cell index for a new band (row)
-- Called by band break handler in layout-grid
function table_mod.reset_render_band()
    if _G.content and _G.content.table_mode then
        _G.content.table_render_cell_idx = 0
    end
end

-- Register module
package.loaded['core.luatex-cn-core-table'] = table_mod

return table_mod
