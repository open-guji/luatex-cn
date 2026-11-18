-- luacheck 配置：texlua test/run_all.lua 之外的静态检查（CI 的 lint job 使用）
-- 运行：luacheck tex
std = "luajit"
allow_defined_top = true
max_line_length = false
-- LuaTeX / luaotfload 运行时提供的全局
read_globals = {
    "node", "font", "texio", "luatexbase", "token", "lua", "callback",
    "pdf", "status", "kpse", "lfs", "unicode", "fontloader", "luaotfload",
    "img", "mplib", "md5", "sha2", "fonts", "utf8", "os", "lang", "newtoken",
}
-- 本项目约定挂在 _G 上的共享状态（模块之间经 _G.xxx 交互）
globals = { "_G", "core", "texio", "token", "tex" }
-- 插件钩子、回调签名要求的参数即便不用也保留
unused_args = false
-- 带说明注释的空分支是有意为之（「透明节点」等）
ignore = { "542" }
