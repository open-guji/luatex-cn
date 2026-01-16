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
-- base_constants.lua - 基础常量与工具函数库
-- ============================================================================
-- 文件名: base_constants.lua (原 constants.lua)
-- 层级: 基础层 (Base Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块是所有子模块的共享基础设施，提供：
--   1. 节点类型 ID 常量（GLYPH、KERN、HLIST、VLIST 等）
--   2. 自定义属性索引（缩进、右缩进、textbox 尺寸等）
--   3. TeX 尺寸字符串到 scaled points 的转换函数 (to_dimen)
--   4. Node.direct 接口的快捷引用 (D)
--
-- 【术语对照 / Terminology】
--   scaled points (sp)  - TeX 内部单位，1pt = 65536sp
--   GLYPH               - 字形节点（glyph node）
--   KERN                - 字距节点（kerning node）
--   HLIST               - 水平列表（horizontal list）
--   VLIST               - 垂直列表（vertical list）
--   GLUE                - 胶水/弹性空白（glue）
--   PENALTY             - 惩罚节点（penalty，用于换行/分页控制）
--   ATTR_INDENT         - 缩进属性（indent attribute）
--   ATTR_TEXTBOX_*      - 文本框属性（textbox attributes）
--
-- 【注意事项】
--   • 本模块必须在所有其他模块之前加载（vertical.sty 确保了这一点）
--   • 属性 ID 由 TeX 层注册（\newluatexattribute），Lua 层通过 luatexbase 访问
--   • to_dimen 函数会过滤空字符串和 "0pt"，返回 nil 而非 0（用于区分未设置）
--
-- 【整体架构 / Architecture】
--   base_constants.lua (本模块)
--      ├─ 导出常量 → 被所有子模块引用
--      ├─ to_dimen() → 被 core_main.lua 用于解析 TeX 参数
--      └─ ATTR_* 索引 → 被 flatten/layout/render 用于读写节点属性
--
-- ============================================================================

-- Create module table
local constants = {}

-- Node.direct interface for performance
constants.D = node.direct

-- Global debug configuration
_G.vertical = _G.vertical or {}
_G.vertical.debug = {
    enabled = false,        -- 是否开启调试模式
    show_grid = true,      -- 显示字符格
    show_boxes = true,     -- 显示文本框避让区
    show_banxin = true,    -- 显示版心参考线
    verbose_log = true     -- 是否在 .log 中输出详细坐标
}

-- Node type IDs
constants.GLYPH = node.id("glyph")
constants.KERN = node.id("kern")
constants.HLIST = node.id("hlist")
constants.VLIST = node.id("vlist")
constants.WHATSIT = node.id("whatsit")
constants.GLUE = node.id("glue")
constants.PENALTY = node.id("penalty")
constants.LOCAL_PAR = node.id("local_par")

-- Custom attributes for indentation
-- Note: Attributes are registered in vertical.sty via \newluatexattribute
constants.ATTR_INDENT = luatexbase.attributes.cnverticalindent or luatexbase.new_attribute("cnverticalindent")
constants.ATTR_RIGHT_INDENT = luatexbase.attributes.cnverticalrightindent or luatexbase.new_attribute("cnverticalrightindent")
constants.ATTR_TEXTBOX_WIDTH = luatexbase.attributes.cnverticaltextboxwidth or luatexbase.new_attribute("cnverticaltextboxwidth")
constants.ATTR_TEXTBOX_HEIGHT = luatexbase.attributes.cnverticaltextboxheight or luatexbase.new_attribute("cnverticaltextboxheight")
constants.ATTR_TEXTBOX_DISTRIBUTE = luatexbase.attributes.cnverticaltextboxdistribute or luatexbase.new_attribute("cnverticaltextboxdistribute")

-- Block Indentation Attributes
constants.ATTR_BLOCK_ID = luatexbase.attributes.cnverticalblockid or luatexbase.new_attribute("cnverticalblockid")
constants.ATTR_FIRST_INDENT = luatexbase.attributes.cnverticalfirstindent or luatexbase.new_attribute("cnverticalfirstindent")

-- Attributes for Jiazhu (Interlinear Note)
constants.ATTR_JIAZHU = luatexbase.attributes.cnverticaljiazhu or luatexbase.new_attribute("cnverticaljiazhu")
constants.ATTR_JIAZHU_SUB = luatexbase.attributes.cnverticaljiazhusub or luatexbase.new_attribute("cnverticaljiazhusub")

--- 将 TeX 尺寸字符串转换为 scaled points (sp)
-- @param dim_str (string) TeX 尺寸字符串（例如 "20pt", "1.5em"）
-- @return (number|nil) 以 scaled points 为单位的尺寸，如果无效或为零则返回 nil
-- @usage local sp = constants.to_dimen("20pt")
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" or dim_str == "0" or dim_str == "0pt" then
        return nil
    end
    -- Strip curly braces if present
    dim_str = tostring(dim_str):gsub("^%s*{", ""):gsub("}%s*$", "")

    local ok, res = pcall(tex.sp, dim_str)
    if ok then
        if res == 0 then return nil end
        return res
    else
        return nil
    end
end

constants.to_dimen = to_dimen

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['luatex-cn-vertical-base-constants'] = constants

-- Return module
return constants
