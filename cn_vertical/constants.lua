-- ============================================================================
-- constants.lua - 全局常量与工具函数库
-- ============================================================================
--
-- 【模块功能】
-- 本模块是所有子模块的共享基础设施，提供：
--   1. 节点类型 ID 常量（GLYPH、KERN、HLIST、VLIST 等）
--   2. 自定义属性索引（缩进、右缩进、textbox 尺寸等）
--   3. TeX 尺寸字符串到 scaled points 的转换函数 (to_dimen)
--   4. Node.direct 接口的快捷引用 (D)
--
-- 【注意事项】
--   • 本模块必须在所有其他模块之前加载（cn_vertical.sty 确保了这一点）
--   • 属性 ID 由 TeX 层注册（\newluatexattribute），Lua 层通过 luatexbase 访问
--   • to_dimen 函数会过滤空字符串和 "0pt"，返回 nil 而非 0（用于区分未设置）
--
-- 【整体架构】
--   constants.lua (本模块)
--      ├─ 导出常量 → 被所有子模块引用
--      ├─ to_dimen() → 被 core.lua 用于解析 TeX 参数
--      └─ ATTR_* 索引 → 被 flatten/layout/render 用于读写节点属性
--
-- Version: 0.3.0
-- Date: 2026-01-12
-- ============================================================================

-- Create module table
local constants = {}

-- Node.direct interface for performance
constants.D = node.direct

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
-- Note: Attributes are registered in cn_vertical.sty via \newluatexattribute
constants.ATTR_INDENT = luatexbase.attributes.cnverticalindent or luatexbase.new_attribute("cnverticalindent")
constants.ATTR_RIGHT_INDENT = luatexbase.attributes.cnverticalrightindent or luatexbase.new_attribute("cnverticalrightindent")
constants.ATTR_TEXTBOX_WIDTH = luatexbase.attributes.cnverticaltextboxwidth or luatexbase.new_attribute("cnverticaltextboxwidth")
constants.ATTR_TEXTBOX_HEIGHT = luatexbase.attributes.cnverticaltextboxheight or luatexbase.new_attribute("cnverticaltextboxheight")
constants.ATTR_TEXTBOX_DISTRIBUTE = luatexbase.attributes.cnverticaltextboxdistribute or luatexbase.new_attribute("cnverticaltextboxdistribute")

--- Convert TeX dimension string to scaled points
-- @param dim_str (string) TeX dimension string (e.g., "20pt", "1.5em")
-- @return (number|nil) Dimension in scaled points, or nil if invalid/zero
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
package.loaded['constants'] = constants

-- Return module
return constants
