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
-- core_metadata.lua - 书籍元数据管理模块
-- ============================================================================
-- 文件名: luatex-cn-core-metadata.lua
-- 层级: 核心层 (Core Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责管理书籍的元数据信息：
--   1. book_name: 书名
--   2. chapter_title: 章节标题
--   3. publisher: 出版社/刊号
--   4. chapter_registry: 章节标记注册表（用于跨页章节标题切换）
--
-- ============================================================================

-- Load dependencies
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')

local D = node.direct

-- ============================================================================
-- Global State (全局状态)
-- ============================================================================
-- Initialize global metadata table
_G.metadata = _G.metadata or {}
_G.metadata.book_name = _G.metadata.book_name or ""
_G.metadata.chapter_title = _G.metadata.chapter_title or ""
_G.metadata.publisher = _G.metadata.publisher or ""

-- Chapter registry for tracking chapter changes across pages
_G.metadata.chapter_registry = _G.metadata.chapter_registry or {}
_G.metadata.chapter_counter = _G.metadata.chapter_counter or 0

-- ============================================================================
-- Setup Function
-- ============================================================================

--- Setup global metadata parameters from TeX
-- @param params (table) Parameters from TeX keyvals
local function setup(params)
    params = params or {}
    if params.book_name ~= nil then _G.metadata.book_name = params.book_name end
    if params.chapter_title ~= nil then _G.metadata.chapter_title = params.chapter_title end
    if params.publisher ~= nil then _G.metadata.publisher = params.publisher end
end

-- ============================================================================
-- Chapter Marker Functions
-- ============================================================================

--- Insert a chapter marker into the registry
-- Returns a unique registry ID that can be used to look up the chapter title
-- @param title (string) The chapter title
-- @return (number) Registry ID
local function insert_chapter_marker(title)
    local reg_id = utils.insert_chapter_marker(title)
    return reg_id
end

--- Create a chapter marker node for insertion into the document
-- @param title (string) The chapter title
-- @return (node) A zero-width hlist containing a kern with the chapter registry ID attribute
local function create_chapter_marker_node(title)
    local reg_id = insert_chapter_marker(title)

    -- Insert a zero-width kern with the chapter registry ID attribute
    local n = D.new(node.id("kern"))
    D.setfield(n, "kern", 0)
    D.set_attribute(n, constants.ATTR_CHAPTER_REG_ID, reg_id)

    -- Wrap in HLIST to be compatible with TeX box assignment
    local h = D.new(node.id("hlist"))
    D.setfield(h, "head", n)
    D.setfield(h, "width", 0)
    D.setfield(h, "height", 0)
    D.setfield(h, "depth", 0)

    return D.tonode(h)
end

--- Insert chapter marker into TeX box 0 (for TeX interface)
-- @param title (string) The chapter title
local function insert_chapter_marker_to_box(title)
    tex.box[0] = create_chapter_marker_node(title)
end

--- Get chapter title by registry ID
-- @param reg_id (number) Registry ID
-- @return (string|nil) Chapter title or nil if not found
local function get_chapter_title(reg_id)
    return utils.get_chapter_title(reg_id)
end

--- Clear chapter registry (call at end of document)
local function clear_registry()
    _G.metadata.chapter_registry = {}
    _G.metadata.chapter_counter = 0
end

-- ============================================================================
-- Module Export
-- ============================================================================

local metadata = {
    setup = setup,
    insert_chapter_marker = insert_chapter_marker,
    create_chapter_marker_node = create_chapter_marker_node,
    insert_chapter_marker_to_box = insert_chapter_marker_to_box,
    get_chapter_title = get_chapter_title,
    clear_registry = clear_registry,
}

-- Register module in package.loaded
package.loaded['core.luatex-cn-core-metadata'] = metadata

return metadata
