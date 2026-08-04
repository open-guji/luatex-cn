# clreq 共享内核接口契约（H0）

> 对应规划：`docs/CLREQ-HORIZONTAL-PLAN.md` H0 阶段。
> 三个模块位于 `tex/shared/`，**纯 Lua 纯函数、零 TeX 依赖**，横排/竖排两条后端共用。
> 硬性约束（横排规划 HR5）：任何 clreq 规则只允许写在这里，后端只做编码与绘制。

```
tex/shared/
├── luatex-cn-punct-table.lua   # clreq 附录标点全表（单一数据源）
├── luatex-cn-punct-squeeze.lua # 标点宽度调整的上下文判定
├── luatex-cn-punct-anchors.lua # 字面分布的度量锚点（style × mode → 墨心目标位置）
├── luatex-cn-adjust.lua        # 一维优先级空间分配器
└── luatex-cn-kinsoku.lua       # 四级禁则 + 符号分离禁则
```

依赖方向：`kinsoku`/`punct-squeeze` → `punct-table` ← 后端；`adjust` 无依赖。
单位约定：所有宽度/空间量均为**以字号为 1 的 em 比值**（纯数字），
由后端乘以字号换算为 sp。`adjust` 对单位无假设，只要求全体输入一致。

---

## 1. punct-table.lua — 标点全表

数据源：clreq 附录《中文标点符号表》（点号表 + 标号表 + 行间标号表 +
「不可分离 / 直排右旋 90°」表），加上正文《标点符号的宽度调整》
《挤压处理的优先顺序》的宽度与可调空间规定。

### 1.1 条目结构

```lua
[0x3002] = {           -- 键：Unicode 码位
  name  = "句号",
  class = "fullstop",  -- 见 1.2 类别表
  width  = { mainland = 1,     taiwan = 1 },      -- 名义字幅（em）
  space  = { mainland = "end", taiwan = "both" }, -- 可调空间位置：
                                                  --   "start"|"end"|"both"|"none"
                                                  --   （横排始端=左；直排始端=上）
  shrink = { mainland = 0.5,   taiwan = 0.5 },    -- 最大可挤压量（em）
  shrink_class = "fullstop_group",  -- 挤压 7 级中的组名（nil = 不参与挤压）
  unbreakable  = false,   -- 附录「不可分离」列（两字宽标点整体）
  vert_rotate  = false,   -- 附录「直排右旋 90°」列
  forbid_start = "basic", -- 行首禁则生效的最低级别（nil = 任何级别都不禁）
  forbid_end   = nil,     -- 行尾禁则生效的最低级别
}
```

### 1.2 类别（class）

| class | 字符 | clreq 归属 |
|-------|------|-----------|
| `fullstop` | 。． | 点号 |
| `comma` | ，、 | 点号 |
| `semicolon` | ； | 点号 |
| `colon` | ： | 点号 |
| `exclamation` | ！‼ | 点号 |
| `question` | ？⁇ | 点号 |
| `open` / `close` | 「」『』“”‘’（）《》〈〉【】〖〗〔〕［］｛｝ | 标号（引号/夹注号/书名号） |
| `dash` | — ⸺ | 标号（破折号） |
| `ellipsis` | … ⋯ | 标号（省略号） |
| `connector` | ～ - – | 标号（连接号；— 兼属，按 dash 收录） |
| `interpunct` | · ・ ‧ | 标号（间隔号） |
| `solidus` | / ／ | 标号（分隔号） |
| `linemark` | ＿ ﹏ | 行间标号（专名号/书名号甲式），无行内字幅 |
| `emphasis` | ● • | 行间标号（着重号），无行内字幅 |

### 1.3 查询 API

| 函数 | 返回 | 说明 |
|------|------|------|
| `get(char)` | entry \| nil | 原始条目 |
| `class_of(char)` | string \| nil | 类别 |
| `is_point(char)` | bool | 是否点号（句逗顿冒分叹问） |
| `space_info(char, style, mode)` | {side, shrink} \| nil | 见 1.4；style=`"mainland"|"taiwan"`，mode=`"horizontal"|"vertical"` |
| `shrink_class_of(char, style, mode)` | string \| nil | 挤压组名（与 adjust.lua 的 SHRINK_ORDER 一致） |
| `forbid_line_start(char, level)` | bool | level=`"none"|"basic"|"gb"|"strict"` |
| `forbid_line_end(char, level)` | bool | 同上 |
| `is_unbreakable(char)` | bool | 附录「不可分离」列 |
| `is_unbreakable_pair(a, b)` | bool | ——、……、⋯⋯ 成对判定（a==b 且为 dash/ellipsis）；叠用 ？？ ！！ ？！ ！？ 亦放行 |
| `is_stacked_pair(a, b)` | bool | 叹问号叠加（两侧都是 ！/？）——唯一允许 a≠b 的两字宽单元 |
| `vert_rotate(char)` | bool | 附录「直排右旋」列 |

> **叹问号叠加（已实现）**：`？？` `！！` `？！` `！？` 是两字宽刚性整体。
> 三处配合缺一不可：① `is_stacked_pair` 放行异字组合；②
> `kinsoku.no_break_between` 把两字宽单元判定放在行首禁则**之前**——
> 两符号本身都是行首禁则字符，否则原因被报成 `forbid_start`，后端的
> RIGID 集合就不认；③ hori 刚性单元内部除 stretch/class 外连 **shrink**
> 一并清零——？！是点号、字面自带可挤空白，与本无 shrink 的 —— 不同，
> 不清零则挤压行仍会把这一对压到 2 字宽以下（压力用例负对照可复现）。
| `legacy_type(char)` | string \| nil | 兼容旧六类：open/close/fullstop/comma/middle/nobreak（P1 迁移用） |

### 1.4 mode/style 修正规则（clreq 原文规定，编码在表内）

- **直排**：冒号、分号、问号、叹号固定一字宽（GB 偏靠式与港台居中式皆然）
  → `space_info` 在 `mode="vertical"` 时对这四类返回 `{side="none", shrink=0}`。
- **横排港台式**：问号、叹号固定一字宽 → 同上。
- **中国大陆 GB 式**：半字连接号（- –）、间隔号（·）、分隔号（/）固定半字宽
  → `width.mainland = 0.5`、`shrink = 0`。
- 台式间隔号占一字宽居中，可挤压（挤压组 `interpunct`，空间挤到 0 即半字宽）。

### 1.5 禁则级别与字符集（clreq 原文）

| 级别 | 行首禁 | 行尾禁 |
|------|--------|--------|
| `none` | 无 | 无 |
| `basic` | 点号（顿逗句冒分叹问）+ 结束引号/括号/书名号 + 连接号 + 间隔号 + 分隔号 | 开始引号/括号/书名号 |
| `gb` | 同 basic | basic + 分隔号 |
| `strict` | gb + 破折号 + 省略号 | 同 gb |

`forbid_start`/`forbid_end` 存最低生效级别，级别序 none < basic < gb < strict，
查询时 `当前级别 >= 条目级别` 即禁。

---

## 1bis. punct-squeeze.lua — 宽度调整的上下文判定

依赖 punct-table。回答的问题是「这个标点**此刻**该收回多少字面空白」，
clreq 只允许两种情形收回：① 相邻标点连排（夹注符号参与时无条件把 2 字宽
减到 1.5，风格可到 1）；② 位于行首/行尾。夹在汉字之间的单个标点占满一字幅。

| 函数 | 返回 | 说明 |
|------|------|------|
| `blanks(char, opts)` | head_em, tail_em | 该标点两端各携带的可收回空白（`side="both"` 各半；`style="none"` 全零） |
| `plan(prev, cur, next, ctx, opts)` | {head, tail, total, reasons} | 上下文判定结果；`ctx = {at_line_start, at_line_end}`，缺省 nil = 只判相邻 |
| `adjacent_reduction_cap(mode)` | number | `"1.5"→0.5`、`"1"→1.0`、`"natural"→0` |
| `is_bracket(char)` | bool | 是否夹注符号（连续标点缩减的触发条件） |

`opts = { style, mode, adjacent_punct, line_start_bracket, line_end_punct }`，
键名与横排 `luatexcn/hori`、竖排 `luatexcn/punct` 的用户键一一对应
（同一套风格预设 mainland / taiwan / none 贯穿两条后端）。

后端接线现状：横排 `hori-spacing` 用 `is_bracket` / `adjacent_reduction_cap`；
竖排 `punct.flatten` 用 `plan`（相邻上下文），结果写在 `ATTR_PUNCT_SQUEEZE`。
`ctx.at_line_start/at_line_end` 在竖排尚无人传——断列结果只有
`flush_buffer` 知道，见 `docs/CLREQ-VERTICAL-ADJUST-DESIGN.md`。

---

## 1ter. punct-anchors.lua — 字面分布的度量锚点

依赖为零（纯数据 + 纯函数）。回答的问题是「这个标点的**墨迹中心**
在本 style × mode 下应落在字幅的哪里」。字体把墨迹画在哪是字体的设计
惯例（中国大陆字体横排形在左下、vert 形在右上；台湾字体两向居中），排版
风格不应随字体漂移——后端读字形 boundingbox 算墨心，把差值写进
xoffset/yoffset。

| 函数 | 返回 | 说明 |
|------|------|------|
| `anchor(orig, style, mode)` | {x, y} \| nil | 锚点（em，x 自左、y 自基线向上）；style="none" 或未收录码位 → nil；y=nil 表示纵向随字形 |
| `offsets(orig, style, mode, bb, upem, em_sp)` | dx, dy（sp）\| nil | 把墨心挪到锚点的位移；含 0.002em 死区（样板字体严格零位移） |
| `vert_bracket_dy(class, bb, upem, h_em, d_em)` | dy（em）\| nil | 直排夹注号的字面位移（**相对当前落点**，不是绝对锚点）；class 取 punct-table 的 `"open"`/`"close"` |

锚点值取自各风格的**样板字体实测**：台湾式 = TW-Kai（横竖同值），
中国大陆式横排 = 思源宋体，中国大陆式直排 = TW-Kai 在旧经验偏移实现下的落点。
键为**原始码位**——vert GSUB 落到 PUA 的字形由后端先解析回来。

**夹注号**（引号/括号/书名号）另走一条路，因为 clreq 6.3.2.1 图 30 把它们
归在单侧一组：直排开始夹注符号「字面上侧」有空白（字面贴后文）、结束夹注
符号「字面下侧」有空白（字面贴前文）；图 30 的「字面上下两侧（居中）」一组
只有点号与间隔号，**两种风格都不给夹注号居中档**，港台式的差别只在
6.3.2 正文所说的「通常不做宽度调整（压缩）」。两点实现约束：

- **只锚直排**。横排字形的 advance 起点即字幅始端，字体画在哪就是字面
  分布，实测四款字体的 `（` 墨心都在 0.65～0.79（空白确实在外侧）；统一
  拉到 0.75 反而会松开思源宋体那种更贴紧的设计。
- **直排给的是相对位移**。直排下引擎按字形 height/depth 盒把字面居中在
  字幅里（`render-position.calc_grid_position` 的 `em_center=false` 分支），
  基线落点随字体浮动，写不了「基线以上 x em」的绝对锚点；`vert_bracket_dy`
  因此返回 `±0.25 + (h − d)/2 − 墨心`。h/d 由 luaotfload 从墨迹盒写来，
  墨迹整个在基线之上时 d 被截为 0，这个截断正是各字体结束夹注符号忽高
  忽低的来源（issue #105 ②）。

教训：锚点不能从 Tm 相对坐标量——xoffset 会写进 Tm，量出来的只是字形
自身的 bbox 中心，偏靠会整个丢失、退化为居中。

后端接线：竖排 `punct.render`（中国大陆式恒开；台湾式仅 squeeze-mode=context
挡位，保护 ltc-guji 的既有版面），横排 `hori-pipeline.apply_ink_anchor`
（pre_linebreak 对每个点号/中点类字形绝对写入，幂等）。夹注号那条在竖排
`punct.render` 里跟在锚点表未命中之后，另跳过脚注标号组
（`ATTR_FOOTNOTE_MARKER`，组内字幅按组高分配、括号已按真实墨迹缩放居中）
与引擎自转的字形（`ATTR_VERT_ROTATE`，位置写在变换矩阵里，
xoffset/yoffset 挪不动它）。

---

## 2. adjust.lua — 一维优先级空间分配器

**与横排/竖排无关、与 TeX 无关的纯函数**：给定目标长度和一串带类别的可调间隙，
按 clreq 的挤压/拉伸优先顺序依次用尽，输出每个间隙的最终值。

### 2.1 输入

```lua
adjust.solve(target, gaps)
-- target: number 目标长度（行长/列高，单位与 gaps 一致）
-- gaps:   array，每项：
--   {
--     width  = 1.0,      -- 理想值（必填）
--     min    = 0.5,      -- 挤压下限（缺省 = width，即不可挤）
--     max    = 1.5,      -- 拉伸上限（缺省 = width，即不可拉）
--     shrink_class  = "comma_group",  -- 挤压组（nil = 不参与挤压）
--     stretch_class = "western_word", -- 拉伸组（nil = 不参与拉伸）
--     fallback = true,   -- 是否参与兜底均分拉伸（汉字间隙 = true）
--   }
```

**注意**：gaps 是「间隙」不是「字符」。一个标点的可调空间由后端根据
`punct-table.space_info` 拆成 0/1/2 个 gap 传入（side="both" 拆两个，
各持 shrink/2）；汉字本体、字面墨迹不进 gaps。

### 2.2 优先顺序（模块常量，勿在后端复制）

```lua
adjust.SHRINK_ORDER = {
  "line_end_punct",  -- 1 行末标点（调成固定半字：min 由后端置为 0）
  "western_word",    -- 2 西文词距（min 1/4 em）
  "interpunct",      -- 3 间隔号（空间挤到 0）
  "bracket",         -- 4 夹注符号（min 半字）
  "comma_group",     -- 5 逗号/顿号/分号（min 半字）
  "cjk_western",     -- 6 中西间距（min 1/8 em）
  "fullstop_group",  -- 7 句号/问号/叹号（min 半字）
  "inter_char",      -- 8 字距本身——**不在 clreq 列举的七步之内**
}
adjust.STRETCH_ORDER = { "western_word", "cjk_western" }
-- 拉伸上限：西文词距/中西间距均至半字宽；之后兜底均分到 fallback 间隙
```

括号内的 min/max 是 clreq 的规定值，**由后端换算进 gap 的 min/max**；
adjust 只认字段，不查表——这保证它对任何长度单位与特殊风格都成立。

第 8 项 `inter_char` 是本项目的扩展：clreq 假定行内密排、字距无可压缩，
而本项目直排以 0.1 em 为基准字距（版式选择），所以它必须排在七步**之后**
作为最后手段——绝不能先于标点空白被压缩。横排不使用本类。

### 2.3 语义

1. `Σwidth > target`：按 SHRINK_ORDER 逐组处理；**组内所有间隙同时、同等量挤压**
   （clreq 原文），个别间隙先触底则退出该轮、其余继续，直至需求满足或全组触底，
   再进下一组。
2. `Σwidth < target`：按 STRETCH_ORDER 逐组同等量拉伸至 max；仍不足时把剩余
   **平均分配**到所有 `fallback=true` 的间隙（无上限）。
3. 两方向都可能失败（全部触底/无 fallback 间隙）——不抛错，如实报告。

### 2.4 输出

```lua
{
  widths   = { ... },  -- 与 gaps 等长，每个间隙的最终值
  total    = number,   -- Σwidths
  achieved = bool,     -- 是否精确达到 target
  deficit  = number,   -- 未消化量：>0 仍超长，<0 仍不足，0 达成
}
```

纯函数保证：不修改入参，同输入同输出，无全局状态。

### 2.5 后端接线方式

- **横排**：`post_linebreak_filter` 里对每行收集带 `ATTR_ADJUST_*` 的 glue，
  调 `solve(行长, gaps)`，把结果写回（覆盖 TeX 的比例分配）。
- **竖排**：`flush_buffer` 前对当前列收集 cell 间隙，调 `solve(列高, gaps)`。

---

## 3. kinsoku.lua — 禁则

依赖 punct-table。级别常量：`kinsoku.LEVELS = {none=0, basic=1, gb=2, strict=3}`。

### 3.1 API

| 函数 | 返回 | 说明 |
|------|------|------|
| `forbid_line_start(char, level)` | bool | 委托 punct-table |
| `forbid_line_end(char, level)` | bool | 同上 |
| `no_break_between(prev, next, opts)` | bool, reason | 核心判定，见 3.2 |
| `penalty_between(prev, next, opts)` | number | 横排用：`no_break` → 10000，否则 0 |
| `check_wrap(last_char, next_char, opts)` | nil \| "start_violation" \| "end_violation" | 竖排用：列满时判定禁则是否被违反 |
| `resolve_overflow(cands)` | "squeeze" \| "stretch", detail | 违反后怎么办：对「挤进」「推出」两个候选各解一次 `adjust.solve`，按 clreq 优先顺序加权比较形变代价。见 3.4 |

`opts = { level = "basic" }`（缺省 basic，clreq 最推荐级别）。
`reason` 为字符串（"forbid_start" / "forbid_end" / "unbreakable_pair" /
"digit_run" / "digit_suffix" / "sign_prefix" / "currency" / "western_word"），
仅供调试与测试断言。

### 3.2 no_break_between 规则（clreq §符号分离禁则 + 行首行尾禁则）

按序判定，命中即返回 true：

1. `next` 在当前级别行首禁 → 禁。
2. `prev` 在当前级别行尾禁 → 禁。
3. **两字宽标点成对**：prev==next 且为 dash/ellipsis → 禁
   （clreq：连续多个时允许在对与对之间拆——本函数只看相邻两字符，
   长串的对边界放行由**调用方**依据运行长度处理，契约见 3.3）。
4. **数字串**：digit+digit → 禁（含全角数字）。
5. **数字后缀**：digit + `% ‰ ° ℃ ′ ″ ％`→ 禁。
6. **符号前缀**：`+ - ± ＋ － ±` + digit → 禁。
7. **货币符号**：前置货币（¥ ＄ $ € £ ￥ ￠ ￡）+ digit，或 digit + 后置货币（₫ 等）→ 禁。
8. **西文单词**：letter+letter → 禁（连字符 `-` 之后允许断，即 prev 为 hyphen 时放行）。

上下标/注释记号与被标记文字的分离禁则不在本函数（需节点属性，属后端职责）。

### 3.4 挤进 / 推出的代价比较

```
cands = {
  squeeze = { target = <gap 可用总量>, gaps = {...} },  -- 多收一个字的排布
  stretch = { target = <gap 可用总量>, gaps = {...} },  -- 少一个字的排布
}
```

`target` 由后端算：列（行）可用长度 − 该候选的刚性总量。返回
`"squeeze"` 或 `"stretch"`，外加 `{squeeze_cost, stretch_cost, squeeze, stretch}`
（后两者是 `adjust.solve` 的结果，可直接落盘）。

代价模型是**词典序**，不是加权和。解完之后按类聚合形变剖面（每类记该类里
被动用得最狠的那个 gap 动了多少；只有可动的 gap 参与，刚性 gap 不是调整
手段），比较时**从最后手段（`inter_char` 字距）往前逐级比**，先分出胜负的
那一级说了算；全等时选挤进（clreq：先挤进，后推出）。`deficit > 0`
（全部触底仍装不下）判为不可行，直接出局。

**与 clreq 字面的偏离（须在符合度矩阵中声明）**：clreq 说「最后没有挤压
机会，再从前一行取最后一个字」，即只要挤得进就挤进；词典序求的是尽量少动
最后手段。挤进可行但要把字距压得比推出拉得更狠时，两者分歧——本实现选
推出（−52% 的字距比 +32% 的拉伸难看得多）。这是排版质量优先于规范字面的
有意取舍。

**容差**：`opts.tolerance`，与 gaps 同一单位，由后端按自己的量纲传入
（竖排传 `grid_height × 0.001`）；缺省按输入规模自适应。**不可硬编码绝对
容差**——本模块与 `adjust.lua` 同样「不假设单位」，1 em = 655360 sp，写死
的常数在 sp 量纲下会让「全等 → 先挤进」这条兜底失效，决策由浮点舍入决定。

**为什么不能加权求和**：clreq 的优先顺序是「第 1 级用尽才轮到第 2 级」的
词典序。把逗号空白收满 0.5 em 在规范语义里是零代价的正常操作，而线性权重
会把它算成「形变 0.5 的昂贵操作」——量级差远大于权重差（5 vs 8），于是
**多给一个规范允许的挤压手段，反而让该候选更贵**。实测（4000 组随机列）
会翻转约 13% 的决策，方向一律是把「字距零形变」的挤进方案判成不如
「字距全动」的推出方案。类内取最大值而非总和：类内是同时、同等量处理
（clreq 原文），最大值即「这一类被动用的程度」，且与 gap 个数无关——
两个候选 gap 数不同也可比。

**为什么必须在共享层**：后端若自己按「新字距 − 基准字距」比价，就看不见
标点字面空白——收一个逗号的空白（clreq 挤压第 5 级）远比拉开字距便宜，
土成本函数会把求解器本来吃得下的行/列推出去。横排没有这个问题只是因为
它把决策交给了 TeX 断行器。

### 3.3 长串两字宽标点的对边界

`—————…`（≥3 个相同 dash/ellipsis）时，clreq 允许拆成两行。调用方若持有
run 信息，可在**偶数对边界**（第 2k 与 2k+1 个之间）忽略规则 3；
`kinsoku.pair_boundary_breakable(run_len, index)` 提供该判定
（index 为 prev 在 run 中的序号，1 起）。

---

## 4. 测试与验收

- 单测：`test/unit_test/shared/{punct-table,adjust,kinsoku}-test.lua`，
  `texlua` 直跑，无 mock 需求（纯函数）。
- 验收（横排规划 H0）：单测覆盖全部挤压/拉伸优先级分支与四级禁则；
  clreq 条款与测试用例一一对应（用例注释标注条款名）。
- 后端（横排 H1+/竖排 P1+）**不得**在自己层内新增任何 clreq 规则常量；
  发现缺口时改共享层并补单测。
