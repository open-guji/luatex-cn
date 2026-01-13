总结:为什么之前 cn_vertical_new.sty 无法 require 或加载 Lua 文件
主要问题:
大的 \directlua 块执行失败但错误被隐藏

一个包含复杂逻辑的大 \directlua 块更容易在某处静默失败
pcall() 捕获了错误,但 tex.error() 没有真正停止执行
只设置 package.loaded 但没有设置全局变量


-- 旧代码只做了这个:
package.loaded[modname] = result

-- 但没有做:
cn_vertical_constants = result  -- 这是关键!
路径查找可能失败

kpse.find_file() 可能找不到文件
fallback 到原文件名时路径可能不对
core.lua 依赖其他模块

core.lua 使用 require('constants') 等
如果 package.loaded 中没有正确的模块,会失败
但因为在同一个 \directlua 块中,错误被吞掉了