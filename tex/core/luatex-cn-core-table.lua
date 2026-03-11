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
--
-- Tables are inline sections within BodyText that use band (分栏) mode.
-- \begin{表格} emits PENALTY_TABLE_START, \end{表格} emits PENALTY_TABLE_END.
-- The layout engine dynamically switches to band mode upon TABLE_START and
-- restores single-band mode upon TABLE_END.
--
-- Table parameters (n_bands, band_gap_sp, band_heights) are stored in
-- _G.content.table_params before the TABLE_START penalty is emitted.
-- ============================================================================

local constants = require('core.luatex-cn-constants')

local table_mod = {}

--- Initialize table mode and emit TABLE_START penalty
-- Called at \begin{Table} start
-- @param params table with n_bands, band_gap_sp, band_heights (optional)
function table_mod.init(params)
    _G.content = _G.content or {}
    _G.content.table_mode = true
    _G.content.table_col_groups = {}
    _G.content.table_cell_idx = 0
    _G.content.table_render_cell_idx = 0
    _G.content.table_params = params or {}
    _G.content.table_cur_band = 0
    _G.content.table_band_formats = {}
    _G.content.table_cell_valigns = {}

    local n = node.new("penalty")
    n.penalty = constants.PENALTY_TABLE_START
    node.write(n)
end

--- Clean up table mode and emit TABLE_END penalty
-- Called at \end{Table} end
function table_mod.cleanup()
    local n = node.new("penalty")
    n.penalty = constants.PENALTY_TABLE_END
    node.write(n)

    if _G.content then
        _G.content.table_mode = false
        -- NOTE: Do NOT clear table_col_groups or table_params here.
        -- Layout runs in post_linebreak_filter AFTER cleanup(),
        -- so TABLE_START/CELL_BREAK handling still needs this data.
        -- They will be cleared by TABLE_END handling in layout-grid.
        _G.content.table_cell_idx = nil
        _G.content.table_render_cell_idx = nil
    end
end

--- Register a cell and emit cell break penalty if needed
-- @param col_width (number) Number of columns this cell spans (0 = unlimited)
-- @param vertical_align (string|nil) Vertical alignment: "center", "top", "bottom"
function table_mod.begin_cell(col_width, vertical_align)
    _G.content = _G.content or {}
    local cell_idx = _G.content.table_cell_idx or 0
    local cur_band = _G.content.table_cur_band or 0

    -- Store per-band col_groups to avoid cross-band overwrites
    _G.content.table_col_groups = _G.content.table_col_groups or {}
    _G.content.table_col_groups[cur_band] = _G.content.table_col_groups[cur_band] or {}
    _G.content.table_col_groups[cur_band][cell_idx + 1] = col_width
    _G.content.table_cell_idx = cell_idx + 1

    if vertical_align then
        _G.content.table_cell_valigns = _G.content.table_cell_valigns or {}
        _G.content.table_cell_valigns[cur_band] = _G.content.table_cell_valigns[cur_band] or {}
        _G.content.table_cell_valigns[cur_band][cell_idx + 1] = vertical_align
    end

    if cell_idx > 0 then
        local n = node.new("penalty")
        n.penalty = constants.PENALTY_CELL_BREAK
        node.write(n)
    end
end

--- Reset cell counter for a new band (row)
-- Called by \换栏 command and by band break handler in layout-grid
function table_mod.reset_band_cells()
    if _G.content then
        _G.content.table_cell_idx = 0
        _G.content.table_cur_band = (_G.content.table_cur_band or 0) + 1
    end
end

--- Set format options for the current band
-- Called by \栏格式 / \BandFormat command
-- @param params table with optional column_border (bool)
function table_mod.set_band_format(params)
    _G.content = _G.content or {}
    local cur_band = _G.content.table_cur_band or 0
    _G.content.table_band_formats = _G.content.table_band_formats or {}
    _G.content.table_band_formats[cur_band] = params
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
