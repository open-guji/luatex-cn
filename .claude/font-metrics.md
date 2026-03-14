# 字体 Metrics 特性总结

> 不同字体在 LuaTeX 中的 metrics 表现差异，以及 luatex-cn 的应对策略。

## 1. 字体数据访问路径

LuaTeX 中获取字形数据有三层路径：

```
优先级 1: f.characters[charcode].boundingbox     — 最快，直接在内存中
优先级 2: f.shared.rawdata.descriptions[key].boundingbox — 需要间接查询
优先级 3: fontloader.open(filename) → glyphs      — 最慢，需要打开字体文件
```

### descriptions key 差异 (Critical)

不同字体对 `rawdata.descriptions` 使用不同的 key 类型：

| 字体 | descriptions key | 查找方式 |
|------|-----------------|----------|
| TW-Kai | glyph index (`c.index`) | `descriptions[c.index]` |
| KingHwaOldSong | glyph index | `descriptions[c.index]` |
| Noto Serif CJK SC | **unicode 码点** | `descriptions[charcode]` |
| FZShuSong-Z01 | glyph index | `descriptions[c.index]` |

**教训**: 必须同时尝试 index 和 unicode 两种 key（Issue #73 修复）：
```lua
local desc = (c.index and descs[c.index]) or descs[char_code]
```

## 2. 顿号（、）U+3001 的 Metrics 对比

以 28pt (1835008 sp) 为例：

| 字段 | TW-Kai | Noto Serif CJK SC | KingHwaOldSong |
|------|--------|-------------------|----------------|
| units_per_em | 1024 | 1000 | 1000 |
| width | 1835008 | 1835008 | 1835008 |
| height | 749056 | 317456 | ~317000 |
| depth | 0 | 139461 | ~139000 |
| boundingbox (characters) | 无 | 无 | 无 |
| boundingbox (rawdata) | `[402,-178,619,134]` | `[39,-76,290,173]` | 有 |
| rawdata key 类型 | index | **unicode** | index |
| visual_center | 914816 | **需 unicode fallback** | ~917000 |

**关键差异**：
- TW-Kai 的 `、` 高度=749056, 深度=0（字形完全在基线上方）
- Noto 的 `、` 高度=317456, 深度=139461（字形跨越基线）
- boundingbox 水平范围：TW-Kai `[402,619]` vs Noto `[39,290]`（Noto 的墨迹偏左很多）

## 3. vert/vrt2 GSUB 替换

### 特性说明

CJK 字体通过 OpenType `vert` (Vertical Writing) 和 `vrt2` (Vertical Alternates and Rotation) 特性提供竖排替换字形：

```
横排字形 → vert/vrt2 GSUB → 竖排字形（可能映射到 PUA 码点）
```

### 字体配置

所有字体统一启用：
```lua
features = "RawFeature={+vert,+vrt2}"
```

### PUA 字符问题

某些字体（如 KingHwaOldSong）的 vert GSUB 替换会将标点映射到 Private Use Area (PUA, U+F0000+)：

```
U+FF0C (，) → vert GSUB → U+F0001 (PUA 竖排逗号)
```

**影响**：
1. PUA 字符的 `tounicode` 字段保存原始 unicode（如 `"FF0C"`）
2. 标点分类需要通过 `tounicode` 反向查询原始码点
3. PUA 字形可能需要额外的 Y 轴补偿（墨迹中心偏移）

### Y 轴补偿策略

```lua
-- 仅对 PUA 字符应用，原生字体标点通常不需要
if is_pua_char and y_deviation > 0.03 then
    comp_y = floor((0.5 - ratio_y) * glyph_width * 1.5 + 0.5)
end
```

- **1.5x 倍数**：经验值，平衡不同字体的偏差
- **3% 阈值**：忽略微小偏差，避免不必要的调整

## 4. 居中计算策略

### 水平居中（装饰符号）

使用 `get_visual_center()` 基于 boundingbox 的墨迹中心：

```lua
-- boundingbox = [xMin, yMin, xMax, yMax]  (设计单位)
raw_v_center = (bbox[1] + bbox[3]) / 2     -- 水平墨迹中心
visual_center = raw_v_center * (font_size / units_per_em)  -- 转为 sp

-- 对齐: 将墨迹中心放在列中心
center_offset = (col_width / 2) - (visual_center * scale)
```

**Fallback**: 无 boundingbox 时用 `width / 2`

### 垂直居中（装饰符号）

使用 height/depth 计算墨迹中心：

```lua
-- 墨迹中心 = 基线上方 (h-d)/2 处
scaled_ink_center = ((glyph_h - glyph_d) / 2) * scale
target_baseline_y = cell_center_y - scaled_ink_center
```

### 标点居中（主文本）

使用 fontloader 扫描的墨迹中心比率：

```lua
-- 比率 = ink_center / advance_width (范围 0~1)
ratio_x = (bbox[1] + bbox[3]) / 2 / advance_width
comp_x = floor((0.5 - ratio_x) * glyph_width + 0.5)
```

## 5. 常见字体的特性总结

| 特性 | TW-Kai | Noto CJK | KingHwaOldSong | FZShuSong |
|------|--------|----------|----------------|-----------|
| 格式 | TTF | OTF (CFF) | TTF | TTF |
| units_per_em | 1024 | 1000 | 1000 | 1000 |
| characters.bbox | 无 | 无 | 无 | 无 |
| rawdata.desc key | index | unicode | index | index |
| vert GSUB→PUA | 否 | 否 | **是** | 否 |
| 标点 Y 偏移 | 小 | 小 | **大** (需补偿) | 中 |
| 竖排标点质量 | 好 | 好 | 需补偿 | 需补偿 |

## 6. 相关 Issue 与修复

| Issue | 问题 | 根因 | 修复 |
|-------|------|------|------|
| #71 | 特定字体标点位置不对 | PUA 字符墨迹偏移 | Y 轴 1.5x 补偿 |
| #73 | Noto 字体装饰符号偏左 | rawdata.descriptions 用 unicode 作 key | 增加 unicode fallback 查找 |

## 7. 代码位置索引

| 功能 | 文件 | 关键行 |
|------|------|--------|
| 视觉中心计算 | `tex/core/luatex-cn-render-position.lua` | L231-258 |
| 装饰符号定位 | `tex/decorate/luatex-cn-decorate.lua` | L118-168 |
| 标点墨迹中心 | `tex/core/luatex-cn-core-punct.lua` | L75-121 |
| PUA 码点还原 | `tex/core/luatex-cn-core-punct.lua` | L247-280 |
| Y 轴补偿 | `tex/core/luatex-cn-core-punct.lua` | L844-856 |
| 字体自动检测 | `tex/fonts/luatex-cn-font-autodetect.lua` | 全文 |
