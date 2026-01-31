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
-- luatex-cn-color-registry.lua - Color Registry for Cross-Page Preservation
-- ============================================================================
-- This module provides a global registry to map color IDs to color values.
-- Used in conjunction with ATTR_COLOR_REG_ID to preserve colors across
-- page boundaries.
--
-- Phase 1 of the Context System Design (doc/context-system-design.md)
-- ============================================================================

local color_registry = {}

-- Initialize global registry
if not _G.color_registry then
    _G.color_registry = {
        next_id = 1,
        colors = {},      -- id -> color_string
        color_to_id = {}, -- reverse lookup for deduplication
    }
end

--- Register a color and return its ID
-- @param color_str (string) RGB color string (e.g., "1 0 0" or "red")
-- @return (number|nil) Color ID, or nil if color_str is empty/nil
function color_registry.register(color_str)
    if not color_str or color_str == "" then
        return nil
    end

    -- Check if color already registered (deduplication)
    if _G.color_registry.color_to_id[color_str] then
        return _G.color_registry.color_to_id[color_str]
    end

    -- Register new color
    local id = _G.color_registry.next_id
    _G.color_registry.colors[id] = color_str
    _G.color_registry.color_to_id[color_str] = id
    _G.color_registry.next_id = id + 1

    return id
end

--- Get color string by ID
-- @param id (number) Color ID
-- @return (string|nil) Color string, or nil if ID not found
function color_registry.get(id)
    if not id then return nil end
    return _G.color_registry.colors[id]
end

--- Clear the registry (useful for testing or document end)
function color_registry.clear()
    _G.color_registry = {
        next_id = 1,
        colors = {},
        color_to_id = {},
    }
end

--- Get registry statistics (for debugging)
-- @return (table) { total_colors, next_id }
function color_registry.stats()
    local count = 0
    for _ in pairs(_G.color_registry.colors) do
        count = count + 1
    end
    return {
        total_colors = count,
        next_id = _G.color_registry.next_id,
    }
end

-- Register module
package.loaded['util.luatex-cn-color-registry'] = color_registry

return color_registry
