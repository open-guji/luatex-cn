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
-- luatex-cn-debug.lua - Centralized debugging console
-- ============================================================================

_G.luatex_cn_debug = _G.luatex_cn_debug or {
    global_enabled = false,
    modules = {}
}

local debug = _G.luatex_cn_debug

-- ANSI Color Codes for terminal output
local COLORS = {
    reset = "\27[0m",
    bold = "\27[1m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m"
}

-- Default module configuration
local DEFAULT_MODULE_CONFIG = {
    enabled = true,
    color = "cyan"
}

--- Register a module for debugging
-- @param name (string) Module name (e.g., "vertical", "banxin")
-- @param config (table) Optional configuration { enabled, color }
function debug.register_module(name, config)
    config = config or {}
    debug.modules[name] = {
        enabled = config.enabled ~= false,
        color = config.color or DEFAULT_MODULE_CONFIG.color
    }
end

--- Set global debugging status
-- @param status (boolean)
function debug.set_global_status(status)
    debug.global_enabled = (status == true or status == "true")
end

--- Set module-specific debugging status
-- @param name (string) Module name
-- @param status (boolean)
function debug.set_module_status(name, status)
    if debug.modules[name] then
        debug.modules[name].enabled = (status == true or status == "true")
    else
        -- Auto-register if not exists
        debug.register_module(name, { enabled = (status == true or status == "true") })
    end
end

--- Log a message to the terminal if debugging is enabled
-- @param module_name (string)
-- @param msg (string)
function debug.log(module_name, msg)
    if not debug.global_enabled then return end

    local mod = debug.modules[module_name]
    -- If module is not registered, we allow logging by default if global is on,
    -- but we won't have custom color.
    if mod and not mod.enabled then return end

    local color_code = mod and COLORS[mod.color] or COLORS.white
    local prefix = string.format("%s[%s]%s", color_code, module_name, COLORS.reset)

    -- Use texio.write_nl to ensure it goes to transcript and console
    if texio and texio.write_nl then
        texio.write_nl("term and log", string.format("%s %s", prefix, msg))
    else
        print(string.format("%s %s", prefix, msg))
    end
end

--- Check if debugging is enabled for a module
-- @param module_name (string)
-- @return (boolean)
function debug.is_enabled(module_name)
    if not debug.global_enabled then return false end
    local mod = debug.modules[module_name]
    return mod == nil or mod.enabled
end

return debug
