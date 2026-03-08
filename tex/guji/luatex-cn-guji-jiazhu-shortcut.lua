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
-- jiazhu-shortcut.lua - 夹注捷径 (Jiazhu Shortcut) 模块
-- ============================================================================
-- 通过 process_input_buffer 回调，将自定义括号（如【...】）替换为 \夹注{...}

local shortcut = {}

-- 已注册的快捷方式列表
-- 每项: { open = "【", close = "】", command = "\\夹注", opts = "" }
shortcut.rules = {}

-- 回调是否已注册
shortcut._callback_registered = false

--- 将 UTF-8 字符串拆分为字符数组
--- @param s string UTF-8 字符串
--- @return table 字符数组
local function utf8_chars(s)
    local chars = {}
    for _, code in utf8.codes(s) do
        chars[#chars + 1] = utf8.char(code)
    end
    return chars
end

--- 检查字符数组从 pos 开始是否匹配 target 字符串
--- @param chars table 字符数组
--- @param pos number 起始位置（1-indexed）
--- @param target_chars table 目标字符数组
--- @return boolean 是否匹配
local function match_at(chars, pos, target_chars)
    for i = 1, #target_chars do
        if chars[pos + i - 1] ~= target_chars[i] then
            return false
        end
    end
    return true
end

--- 对一行文本应用所有替换规则
--- @param line string 输入行
--- @return string 替换后的行
local function apply_rules(line)
    for _, rule in ipairs(shortcut.rules) do
        local open_chars = utf8_chars(rule.open)
        local close_chars = utf8_chars(rule.close)
        local open_len = #open_chars
        local close_len = #close_chars

        local chars = utf8_chars(line)
        local result = {}
        local i = 1
        local changed = false

        while i <= #chars do
            if match_at(chars, i, open_chars) then
                -- 找到开始标记，寻找匹配的结束标记（支持嵌套）
                local depth = 1
                local j = i + open_len
                while j <= #chars and depth > 0 do
                    if match_at(chars, j, open_chars) then
                        depth = depth + 1
                        j = j + open_len
                    elseif match_at(chars, j, close_chars) then
                        depth = depth - 1
                        if depth == 0 then
                            break
                        end
                        j = j + close_len
                    else
                        j = j + 1
                    end
                end

                if depth == 0 then
                    -- 成功匹配：提取内容并替换
                    local content = {}
                    for k = i + open_len, j - 1 do
                        content[#content + 1] = chars[k]
                    end
                    if rule.opts ~= "" then
                        result[#result + 1] = rule.command
                            .. "[" .. rule.opts .. "]"
                            .. "{" .. table.concat(content) .. "}"
                    else
                        result[#result + 1] = rule.command
                            .. "{" .. table.concat(content) .. "}"
                    end
                    i = j + close_len
                    changed = true
                else
                    -- 未找到匹配的结束标记，保留原始字符
                    result[#result + 1] = chars[i]
                    i = i + 1
                end
            else
                result[#result + 1] = chars[i]
                i = i + 1
            end
        end

        if changed then
            line = table.concat(result)
        end
    end
    return line
end

--- process_input_buffer 回调函数
--- @param line string 输入行
--- @return string 处理后的行
function shortcut.process_input_buffer(line)
    if #shortcut.rules == 0 then
        return line
    end
    return apply_rules(line)
end

--- 注册一对快捷方式
--- @param open string 开始字符（如 "【"）
--- @param close string 结束字符（如 "】"）
--- @param command string TeX 命令（如 "\\夹注"）
--- @param opts string 可选参数（如 "font-color=red"）
function shortcut.register(open, close, command, opts)
    shortcut.rules[#shortcut.rules + 1] = {
        open = open,
        close = close,
        command = command or "\\夹注",
        opts = opts or "",
    }

    if not shortcut._callback_registered then
        luatexbase.add_to_callback(
            "process_input_buffer",
            shortcut.process_input_buffer,
            "luatex-cn-jiazhu-shortcut"
        )
        shortcut._callback_registered = true
    end
end

--- 清除所有快捷方式并移除回调
function shortcut.clear()
    shortcut.rules = {}
    if shortcut._callback_registered then
        luatexbase.remove_from_callback(
            "process_input_buffer",
            "luatex-cn-jiazhu-shortcut"
        )
        shortcut._callback_registered = false
    end
end

-- 导出内部函数供测试使用
shortcut._internal = {
    utf8_chars = utf8_chars,
    match_at = match_at,
    apply_rules = apply_rules,
}

return shortcut
