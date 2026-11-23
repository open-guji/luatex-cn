# 字体清单与 Metrics 特性总结

> 项目所用字体的完整清单（版本、来源、覆盖范围、授权），可复现性约定，
> 以及不同字体在 LuaTeX 中的 metrics 表现差异与应对策略。
> 覆盖率数据由 fontTools 对字体 cmap 实测（2026-07-30，脚本见文末）。

## 0. 字体清单（按用途）

### 0.1 测试基准字体：TW-Kai（全字庫正楷體）

回归测试的 .tex 硬编码此字体，是项目唯一"钉死"的字体。

| 项目 | 值 |
|------|-----|
| 文件 | `TW-Kai-98_1.ttf`（37 MB，TTF，upem 1024） |
| 版本 | Version **11503.01**（民國 115 年 3 月 = 2026-03） |
| 字形数 | 39,208 glyphs / 39,203 码点 |
| 覆盖 | CJK 基本区 20,923/20,992（99.7%）、Ext-A 6,591/6,592（100%）、CJK 标点 64/64；**不含 Ext-B**（在独立文件中） |
| 官方来源 | 数位发展部 CNS11643 全字庫，data.gov.tw 数据集 5961 |
| 获取途径 | `scripts/download_test_fonts.sh` → GitHub 镜像 `free-fonts-npm/TW-CNS11643-Fonts` **固定 commit `de5bd2e3`**（2026-05-05 批次） |
| SHA-256 | `c206333edcc3c8c86ee547da4c78ad1c8f7ec2670a2b550a768532258f75806a` |
| 授权 | **双授权二选一：政府資料開放授權條款 v1 或 SIL OFL 1.1**（官方声明，可按 OFL 1.1 使用/分发/嵌入） |

同家族扩展文件（当前测试未用，古籍生僻字场景可按需引入，同一镜像 commit 下载）：

| 文件 | 版本 | 码点数 | 覆盖 | SHA-256 |
|------|------|--------|------|---------|
| `TW-Kai-Ext-B-98_1.ttf`（46 MB） | 11505.01 | 49,568 | **Ext-B 42,711/42,720（100%）**、Ext-C 98.6%、Ext-D 87.1%、Ext-E 21.9% | `562d19fde56dfa52a3fed88a53154698e1d66e4b9c0a1faa9ba4ffa98e9d7a92` |
| `TW-Kai-Plus-98_1.ttf`（25 MB） | 11505.01 | 25,079 | 全部在 **Plane 15 PUA**（U+F0000+，24,978 字）：CNS 有码、Unicode 未收的字 | `acd099424c70c2baf3fe8d7b31abbbc6a97af76ef210e94c07eb1eb84d1c62fb` |

配套 TW-Sung（正宋體）三文件同批次同授权，镜像 `Fonts_Sung/` 目录。

### 0.2 Linux 自动检测字体（linux scheme）

`font-autodetect.lua` 在 Linux 上的默认族：宋/黑 = Noto Serif/Sans CJK SC
或思源系；楷 = 文鼎楷体（AR PL UKai / KaitiM，Arphic Public License）
或霞鹜文楷（OFL 1.1）；仿宋 = Zhuque Fangsong（朱雀仿宋，OFL 1.1）。
均按名字探测系统已装字体，缺失时落到 `common` 方案。

> **历史（2026-08 移除 Fandol）**：此前 Linux 默认族与部分回归用例使用
> Fandol 系列（CI 经 TeX Live 包 `fandol` 安装，版本无法钉定；覆盖仅
> 37.8% 基本区汉字，无 Ext-A/B；其授权自称 GPLv3 + font exception——
> **并非 OFL**，且来源存疑）。现回归用例统一改用 manifest 钉定的
> Source Han Serif SC，CI 装包列表已不含 `fandol`。
> **上游状态（2026-11）**：CTAN `fandol` v0.4（2026-11-21）已把宋/黑/楷/仿宋
> 六个汉字字体标为 obsolete（README 称思源系发布后其「已经完成了其历史
> 使命」，仅留副本备考）；字体文件与 v0.3 逐字节相同，授权声明未变；盲文
> 字体拆到新包 `fandol-braille`。不要再把 Fandol 加回默认族、测试或示例。
> 旧坑备考：曾因 CI 删 `ctex` 丢失其传递依赖 fandol 导致回归全挂（PR #107）。

### 0.3 macOS 本地开发字体（mac scheme）

自动检测在 mac 上解析到系统字体（Songti SC / PingFang SC / Kaiti SC /
STFangsong 等），随 macOS 版本漂移、**不可复现**，仅供本地预览。本机
Songti SC 实测：version 17.0d2e3，仅 7,103 个基本区汉字（33.8%）——这
就是 decorate/gongche/textbox 三个用例在 mac 上必然与基线有像素差异的
根源（见 memory: regression-env-diff-tests）。

### 0.4 文档/示例中出现过的第三方字体（不随项目分发）

| 字体 | 授权 | 说明 |
|------|------|------|
| KingHwaOldSong 京華老宋体 | 作者自定义免费商用声明（**非 OFL**，约 39k 字含部分 Ext-B） | Issue #71 的 PUA 竖排补偿即为它引入 |
| FZShuSong-Z01 方正书宋 | 商业授权（方正免费个人使用） | 仅示例提及 |
| Noto Serif/Sans CJK | OFL 1.1 | autodetect 的 ubuntu/common 方案备选 |
| 花園明朝 A/B | OFL 类（Hanazono 自由授权） | 文档提及，Ext-B 覆盖极好 |

## 0.5 可复现性约定

1. **Canonical 字体清单**：`scripts/font-manifest.json` 是机器可读的唯一
   事实来源——每个字体的固定下载 URL（pinned commit）、SHA-256、版本、
   授权、覆盖摘要都在这里。改字体 = 改 manifest，不改代码。
2. **测试只认 TW-Kai**：回归 .tex 硬编码 `TW-Kai`，不依赖系统字体；
   `regression_test.py` 自动把 `OSFONTDIR` 指向 `test/fonts/`。
   **字体从不安装进用户系统字体库。**
3. **下载即校验**：`python3 scripts/download_fonts.py`（或兼容入口
   `sh scripts/download_test_fonts.sh`）按 manifest 下载并校验 SHA-256，
   不符即报错；`--verify` 只校验、`--all` 连同 optional（Ext-B/Plus）。
4. **CI 与本地同源**：CI 用同一脚本 + actions/cache（key 含脚本哈希）。
5. **已知不可复现点**（按影响排序）：
   - mac 系统字体随 OS 漂移（仅影响本地预览）；
   - ~~Fandol 经 CTAN 安装无版本锁~~ → 已消除（2026-08：回归用例全部
     改用 manifest 钉定字体，不再依赖 TeX Live 装包字体）。

## 0.6 OFL / 开放来源替代方案评估（2026-07）

结论：**TW-Kai 本身即可按 SIL OFL 1.1 使用**（官方双授权二选一），
"换成 OFL 来源"不需要换字体，只需在文档与分发物中注明选用 OFL 1.1 并
附授权文本。备选对比（楷体、面向古籍）：

| 字体 | 授权 | 基本区 | Ext-A | Ext-B | 结论 |
|------|------|--------|-------|-------|------|
| **TW-Kai（现用）** | OFL 1.1（可选） | 99.7% | 100% | 100%（Ext-B 文件） | ✅ 保持现状最优 |
| 文鼎PL简中楷 AR PL KaitiM GB | Arphic PL（1999 文鼎官方开源） | 32.2%（GB2312） | 无 | 无 | 传统印刷体楷书（manifest 已钉定，示例在用）；覆盖仅 GB2312 |
| LXGW WenKai GB 霞鹜文楷 | OFL 1.1 | 100% | 100% | 无 | 手写钢笔风楷体；Ext-B 缺，古籍生僻字不够 |
| Noto Serif CJK | OFL 1.1 | 100% | 100% | 少量 | 宋体非楷体；Ext-B 弱 |
| KingHwa 京華老宋体 | 自定义声明 | 高（约 39k 字） | 有 | 部分 | 非标准授权，且为宋体 |
| 花園明朝 A+B | 自由授权 | 100% | 100% | 100% | 明朝体风格，日系笔形，不合楷书需求 |

若未来需要 Ext-B 生僻字测试用例：引入 `TW-Kai-Ext-B-98_1.ttf`（下载
脚本加一行即可，哈希见 0.1），fontspec 侧做 fallback 字体链。

### 提高生僻字覆盖率的候选（fallback 链末端）

以下项目均为开放授权，适合作为 fallback 字体链的最后一环，专门兜底
超大字符集（Ext-B 及以后、GlyphWiki 收录字）：

| 项目 | 基础/来源 | 风格 | 说明 |
|------|-----------|------|------|
| **Jigmo**（字雲） | 花園明朝的后继，GlyphWiki 资料生成 | 明朝体 | 花園明朝 A+B 已停更，Jigmo 持续跟进新版 Unicode；有 Jigmo/Jigmo2/Jigmo3 分档。也可基于 GlyphWiki 资料自行重新生成（含 SC/TC 字形风格定制） |
| **遍黑体 / Plangothic Project** | 思源黑体（Source Han Sans）扩展 | 黑体 | 专攻 Ext-B~I 全覆盖，OFL；分 P1/P2 两个文件 |
| **文津明朝 / WenJin Mincho** | 思源宋体（Source Han Serif）扩展 | 宋/明朝体 | 大字符集扩展，各有取舍 |
| **源起明體 / Genki Mincho** | 思源宋体扩展 | 明朝体 | 同上，繁体取向 |
| **源樣明體 / GenYo Mincho** | 思源宋体（台标字形调整） | 明朝体 | 台湾教育部字形习惯 |
| **WFG 全宋體** | 全字符集宋体项目 | 宋体 | 面向全 Unicode CJK 覆盖 |
| **BabelStone Han / 巴貝斯通漢** | Andrew West 维护 | 宋体 | 持续更新，收录大量罕用字、历史文字，Free license |

注意事项：

- **风格断裂**：fallback 链末端字体与主字体（楷体 TW-Kai）风格不同
  （明朝/黑体 vs 楷书），生僻字会"跳出来"——古籍排版中可接受度需逐例
  判断，必要时对 fallback 字形做灰度/标注提示。
- **地区字形变体**：Noto Serif / Source Serif（以及上表思源系衍生）均
  分 SC / TC / HK / TW 等地区风格，同一码点笔形不同。font-autodetect
  与 fallback 链设计时应按文档语境（简/繁/港/台）选对应变体，而不是
  混用；未来 manifest 中收录时也应把地区变体作为独立条目区分。

---

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

## 8. 覆盖率复测方法（可复现）

```bash
# 依赖: pip install fonttools（或系统包）
python3 - <<'EOF'
from fontTools.ttLib import TTFont
f = TTFont("test/fonts/TW-Kai-98_1.ttf", lazy=True)
cmap = set(f.getBestCmap())
for label, lo, hi in [("URO", 0x4E00, 0x9FFF), ("ExtA", 0x3400, 0x4DBF),
                      ("ExtB", 0x20000, 0x2A6DF)]:
    n = sum(1 for c in cmap if lo <= c <= hi)
    print(label, f"{n}/{hi-lo+1}")
EOF
```

数据来源链接：
- 全字庫官方：https://data.gov.tw/dataset/5961 （双授权声明见页内）
- 镜像仓库：https://github.com/free-fonts-npm/TW-CNS11643-Fonts （pinned commit 见下载脚本）
- Fandol（上游 v0.4 起标为 obsolete，本项目已不使用，仅备考）：https://ctan.org/pkg/fandol
- LXGW WenKai：https://github.com/lxgw/LxgwWenKai
