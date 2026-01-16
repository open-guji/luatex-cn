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
-- base_hooks.lua - 竖排引擎钩子系统（扩展接口）
-- ============================================================================
-- 文件名: base_hooks.lua
-- 层级: 基础层 (Base Layer) - 钩子/回调机制
--
-- 【模块功能 / Module Purpose】
-- 定义竖排引擎的扩展接口，允许外部包（如 cn_banxin）注册回调函数：
--   1. 列预留 - 指定哪些列需要跳过正文排版
--   2. 特殊列渲染 - 在预留列上绘制自定义内容（如版心）
--
-- 【使用方式 / Usage】
-- 外部包通过覆盖 hooks 表中的函数来注册自己的逻辑：
--   vertical.hooks.is_reserved_column = function(col) ... end
--   vertical.hooks.render_reserved_column = function(params) ... end
--
-- 【术语对照 / Terminology】
--   reserved_column   - 预留列（不放置正文内容的列）
--   hook              - 钩子（可被外部覆盖的函数）
--   callback          - 回调（外部注册的处理函数）
--
-- ============================================================================

local hooks = {}

--- 检查某列是否为预留列（不放置正文内容）
-- 默认实现：无预留列
-- @param col (number) 列索引（0-based）
-- @param interval (number) n_column 参数值
-- @return (boolean) 是否为预留列
function hooks.is_reserved_column(col, interval)
    if not interval or interval <= 0 then return false end
    -- Default logic: traditional banxin at (col % (n + 1)) == n
    return (col % (interval + 1)) == interval
end

--- 渲染预留列的内容
-- 默认实现：不渲染任何内容
-- @param p_head (node) 当前页面节点链表头
-- @param params (table) 渲染参数：
--   - col (number) 列索引
--   - x (number) X 坐标 (scaled points)
--   - y (number) Y 坐标 (scaled points)
--   - width (number) 列宽度 (scaled points)
--   - height (number) 列高度 (scaled points)
--   - border_thickness (number) 边框粗细
--   - page_number (number) 页码
--   - ... 其他渲染参数
-- @return (node) 更新后的节点链表头
function hooks.render_reserved_column(p_head, params)
    return p_head
end

--- 获取预留列的配置
-- 默认实现：无特殊配置
-- @return (table) 配置表 { interval = 0 }
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
