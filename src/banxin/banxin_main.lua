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
-- banxin_main.lua - 版心模块独立入口（注册钩子）
-- ============================================================================
-- 文件名: banxin_main.lua
-- 层级: 扩展层 (Extension Layer) - 古籍版心功能
--
-- 【模块功能 / Module Purpose】
-- 本模块作为 banxin 包的独立入口，负责：
--   1. 向 vertical.hooks 系统注册版心相关回调
--   2. 管理版心配置映射
--   3. 协调 banxin.render_banxin 和 banxin.render_yuwei 模块
--
-- 【设计原理】
-- banxin 作为一个可选插件，通过覆盖 vertical.hooks 接口实现其功能。
--
-- ============================================================================

-- Ensure vertical namespace exists (should be loaded by now)
_G.vertical = _G.vertical or {}
_G.vertical.hooks = _G.vertical.hooks or {}

-- Create banxin namespace for our modules
_G.banxin = _G.banxin or {}

-- 1. Load sub-modules using full namespaced paths
local render_banxin = package.loaded['banxin.render_banxin'] or require('banxin.render_banxin')
-- Note: render_banxin will itself require banxin.render_yuwei if configured correctly

--- 在保留列（Reserved Column）上渲染版心内容
-- @param p_head (node) 当前页面节点列表头部
-- @param params (table) 来自 vertical 引擎的渲染参数
-- @return (node) 更新后的节点列表头部
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
