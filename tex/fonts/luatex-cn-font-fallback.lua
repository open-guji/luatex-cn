-- luatex-cn-font-fallback.lua
-- 按需加载的字体回退链（\设置字体族 的多字体回退）。
--
-- 为什么不直接用 luaotfload 的 fallback 特性（issue #197）：
--   luaotfload 的 fallback 在载入主字体的每一个新字号时，都把链上每一支回退字体
--   按该字号**全部**载入，再建一张「码位 → 字体 id」的总查表（覆盖全部 CJK 表意
--   文字时十几万条），每个字体实例还会把这张表 table.merged 复制一份。
--   六支回退链约 90 MB/字号，按比例缩排产生几十种零碎字号的长书因此 OOM。
--
-- 这里的做法：
--   * 主字体只记一个特性值 luatexcnfallback=<链 id>，载入时不碰回退字体；
--   * 在 luaotfload 的 pre_shaping_filter（与其原 fallback 处理同一时机、shaping 之前）
--     中逐字检查：主字体缺字时，才沿链查找哪一支有这个字；
--   * 某支回退字体只在「某字号下真的出现了要它补的字」时才按该字号载入，
--     并按 (支, 字号) 缓存；判断一支字体是否有某字只需它任一字号实例的字表
--     （码位集合与字号无关），因此每支只需首次载入时取一次。
--   这样不含生僻字的字号不再为回退链付任何内存；行为与 luaotfload fallback 等价
--   （同样是 shaping 前把字形节点的 font 改成回退字体的 id）。

local fallback = {}

local FEATURE = "luatexcnfallback"
fallback.FEATURE = FEATURE

-- 链 id → { specs = {spec...}, coverage = {[i] = characters|false},
--           fids = {[i] = {[size] = fid|false}} }
local chains = {}
-- 字体 id → 该字体的「码位 → 回退字体 id|false」缓存表；不挂回退链的字体为 false
local font_maps = {}

local warned = {}

fallback._internal = {}

--- 取字体数据表：luaotfload 载入的字体在 fonts.hashes.identifiers 里有完整 tfmdata。
function fallback._internal.get_fontdata(fid)
    local hashes = fonts and fonts.hashes and fonts.hashes.identifiers
    local f = hashes and hashes[fid]
    if f then return f end
    return font and font.getfont and font.getfont(fid) or nil
end

--- 按给定字号载入一支回退字体，返回 (font id, characters 表)。失败返回 nil。
-- 与 luaotfload-fallback.lua 的做法一致：define_font 可能返回已定义字体的 id，
-- 也可能返回新的 tfmdata 表（需 font.define 并向 luaotfload 登记）。
function fallback._internal.load_font(spec, size)
    local define_font = luaotfload and luaotfload.define_font
    if not define_font then return nil end
    local ok, f = pcall(define_font, spec, size)
    if not ok or not f then return nil end
    local fid
    if type(f) == "table" then
        fid = font.define(f)
        if fonts and fonts.definers and fonts.definers.register then
            fonts.definers.register(f, fid)
        end
    elseif type(f) == "number" and f > 0 then
        fid = f
        f = fallback._internal.get_fontdata(fid)
    else
        return nil
    end
    return fid, f and f.characters
end

local function warn_once(spec)
    if warned[spec] then return end
    warned[spec] = true
    if texio and texio.write_nl then
        texio.write_nl("term and log",
            "[luatex-cn] 回退字体载入失败，已跳过: " .. tostring(spec))
    end
end

--- 某支回退字体在指定字号下的字体 id（按需载入并缓存）。
local function chain_fid(chain, i, size)
    local per_size = chain.fids[i]
    local fid = per_size[size]
    if fid == nil then
        local chars
        fid, chars = fallback._internal.load_font(chain.specs[i], size)
        if fid then
            if chain.coverage[i] == nil then chain.coverage[i] = chars or false end
        else
            fid = false
            warn_once(chain.specs[i])
            if chain.coverage[i] == nil then chain.coverage[i] = false end
        end
        per_size[size] = fid
    end
    return fid
end

--- 沿回退链为 (chain, size) 下的码位 cp 找一支有该字的字体，返回其 id 或 false。
local function resolve(chain, size, cp)
    for i = 1, #chain.specs do
        local cov = chain.coverage[i]
        if cov == nil then
            -- 尚不知道这支字体覆盖哪些字：在当前字号载入一次，顺带得到字表
            chain_fid(chain, i, size)
            cov = chain.coverage[i]
        end
        if cov and cov[cp] then
            local fid = chain_fid(chain, i, size)
            if fid then return fid end
        end
    end
    return false
end
fallback._internal.resolve = resolve

local function chain_id_of(fdata)
    if not fdata then return nil end
    local id = fdata.luatexcn_fallback
    if not id then
        local shared = fdata.shared
        local feats = shared and shared.features
        id = feats and feats[FEATURE]
    end
    if type(id) ~= "string" then return nil end
    return id:lower()
end

--- 字体 id → 码位映射表（惰性）。不挂回退链的字体返回 false。
local function map_for(fid)
    local m = font_maps[fid]
    if m ~= nil then return m end
    local fdata = fallback._internal.get_fontdata(fid)
    local chain = chains[chain_id_of(fdata) or ""]
    if not chain then
        font_maps[fid] = false
        return false
    end
    local chars = fdata.characters or {}
    local size = fdata.size
    m = setmetatable({}, {
        __index = function(t, cp)
            local r = false
            if not chars[cp] then r = resolve(chain, size, cp) end
            rawset(t, cp, r)
            return r
        end,
    })
    font_maps[fid] = m
    return m
end
fallback._internal.map_for = map_for

--- pre_shaping_filter 回调：把主字体缺的字改到回退字体上。
function fallback.process(head)
    if not head then return true end
    local D = node.direct
    local h = D.todirect(head)
    local setfont = D.setfont
    local last_fid, last_map
    for cur, cid, fid in D.traverse_char(h) do
        if fid ~= last_fid then
            last_fid, last_map = fid, map_for(fid)
        end
        if last_map then
            local nf = last_map[cid]
            if nf then setfont(cur, nf) end
        end
    end
    return true
end

local feature_registered = false
local callback_registered = false

local function register_feature()
    if feature_registered then return true end
    local constructors = fonts and fonts.constructors
    if not (constructors and constructors.newfeatures) then return false end
    local function manipulate(tfmdata, _, value)
        if type(value) == "string" then
            tfmdata.luatexcn_fallback = value:lower()
        end
    end
    constructors.newfeatures("otf").register {
        name = FEATURE,
        description = "luatex-cn on-demand font fallback chain",
        manipulators = { node = manipulate, plug = manipulate },
    }
    feature_registered = true
    return true
end

local function register_callback()
    if callback_registered then return true end
    if not (luatexbase and luatexbase.add_to_callback
            and luatexbase.callbacktypes
            and luatexbase.callbacktypes.pre_shaping_filter) then
        return false
    end
    luatexbase.add_to_callback("pre_shaping_filter", fallback.process,
        "luatexcn.font_fallback")
    callback_registered = true
    return true
end

--- 当前环境能否使用按需回退（需 luaotfload ≥ 3.15 的 pre_shaping_filter）。
function fallback.available()
    return register_feature() and register_callback()
end

--- 注册一条回退链。
-- @param id (string) 链 id（主字体以 RawFeature={luatexcnfallback=<id>} 引用）
-- @param specs (table) luaotfload 字体规格列表，按回退顺序
function fallback.register(id, specs)
    id = id:lower()
    local chain = { specs = {}, coverage = {}, fids = {} }
    for i, s in ipairs(specs) do
        chain.specs[i] = s
        chain.fids[i] = {}
    end
    chains[id] = chain
    -- 链内容变了：清掉字体 → 映射缓存（重用同名 id 时不能沿用旧结果）
    font_maps = {}
    return id
end

--- 测试用：清空全部状态。
function fallback._internal.reset()
    chains, font_maps, warned = {}, {}, {}
    feature_registered, callback_registered = false, false
end

package.loaded['fonts.luatex-cn-font-fallback'] = fallback

return fallback
