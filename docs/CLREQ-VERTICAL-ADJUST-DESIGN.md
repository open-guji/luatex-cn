# 竖排接线设计：`shared/adjust.lua` → `flush_buffer`（P2 第一步）

> 对应规划：`docs/CLREQ-GAP-ANALYSIS.md` P2「弹性行内调整引擎接线」。
> 本文只解决一个问题——**列级调用求解器时，gap 从哪里来、target 怎么算**。
> 这是检验 H0 接口的地方：如果 `adjust.solve` 的入参在竖排凑不出来，
> 说明接口有缺口，应改共享层而不是在后端打补丁（HR5）。

> **状态（2026-08-02）：待评审，未动工。** 第 5 节的五步一步都没开始。

前置状态（本设计文档写作时）：P1 第一步已完成——标点宽度调整改为上下文
相关，规则在 `tex/shared/luatex-cn-punct-squeeze.lua`，收回量由
`punct.flatten` 写在 `ATTR_PUNCT_SQUEEZE` 上，layout 阶段据此缩短字幅。
**其中「行首/行尾」这一半没有实现**，因为断列结果在 flatten 阶段还不知道——
它正是本设计要接的那一步。

---

## 1. 现状：flush_buffer 里那套临时策略

`tex/core/luatex-cn-layout-grid.lua`：

| 位置 | 内容 |
|------|------|
| `flush_buffer(col_buffer, ctx, grid_height, distribute, layout_map)` :1838 | 列缓冲落盘：定位、footnote marker 组、导出 layout_map |
| natural 模式重排块 :1918–2059 | 本设计要替换的部分 |

现有模型是「**每字一个 cell + 字间一个 gap**」：

- `e.cell_height`：该字占的纵向尺寸（P1 之后已含标点收回量）；
- 字间 gap 分四类：marker 组内（0，刚性）、marker 边界（固定 0.1em）、
  block（固定 0.1em）、正文字间（基准 0.1em，可伸缩）；
- 分配策略是三分支的经验规则：
  1. `remaining < 0`（禁则挤进导致超长）→ 把可伸缩 gap **平均**压到装下为止；
  2. `0 ≤ remaining < 一个字幅` → 把余量**平均**拉伸到可伸缩 gap；
  3. 否则 → 一律 0.1em。

问题正是 clreq 差距分析第 4.2 节第 4 条：**没有优先级**。压缩时逗号空白、
中西间距、夹注符号空白、字间距被一视同仁地平均处理，而 clreq 规定的是
7 级挤压 / 2 级拉伸 + 兜底均分。`shared/adjust.lua` 就是那套顺序。

---

## 2. gap 从哪里来

### 2.1 模型转换：字幅里的空白升格为 gap

现在标点的可调空白被折进 `cell_height`（P1 把收回量算好后一次性扣掉）。
接线后改为**cell 只留刚性部分，空白全部升格为 gap**：

```
          ┌─ head gap ─┐┌── cell ──┐┌─ tail gap ─┐
直排一个字：  可调空白      字面墨迹        可调空白
```

对每个 `col_buffer[i]`（字号 `em_i`，由该 entry 的 font size 决定——natural
模式下夹注/批注字号不同，**不能用列的 grid_height 统一换算**）：

- `head_i, tail_i = punct_squeeze.blanks(char_i, opts)`（em）→ 乘 `em_i` 得 sp；
- 刚性 cell：`cell_i = advance_i − (head_i + tail_i) * em_i`；
- 字间另有一个 `fallback` gap（现行 0.1em 基准，`stretch_class = nil`、
  `fallback = true`），保持现在的密排观感。

于是一列的 gap 序列为（N 个字）：

```
[head_1] cell_1 [tail_1 | inter_1] cell_2 [tail_2 | inter_2] … cell_N [tail_N]
```

`tail_i` 与 `inter_i` 是**同一处边界上的两个 gap**，传给 solver 时合并成
一项更稳妥：`width = tail_i + head_{i+1} + 0.1em`，其 `min` 为 `0.1em`
（空白全收回）、`max` 为 `width + 拉伸上限`。合并后每列的 gap 数 = N+1
（含列首 `head_1`、列末 `tail_N`）。

### 2.2 每个 gap 的字段怎么填

`adjust.solve` 只认字段，不查表（契约 2.2）。后端按下表填：

| 字段 | 来源 |
|------|------|
| `width` | 理想值：两侧空白之和 + 0.1em 字间基准 |
| `min` | `width − 可收回空白`（可收回量由 `punct_squeeze` 判定，见 2.3） |
| `max` | 西文词距/中西间距至半字宽；其余 = `width`（不可拉） |
| `shrink_class` | `punct_table.shrink_class_of(char, style, "vertical")`；两侧都有取**较大贡献方**（与横排 `hori-spacing` 一致） |
| `stretch_class` | 仅 `western_word` / `cjk_western` |
| `fallback` | 汉字—汉字边界为 `true`，刚性单元内部为 `false` |

刚性单元（`kinsoku.no_break_between` 返回 `unbreakable_pair` / `digit_run` /
`digit_suffix` / `sign_prefix` / `currency` / `western_word`，以及 footnote
marker 组内部）：`shrink_class = nil`、`stretch_class = nil`、
`fallback = false`、`min = max = width`。横排已用同一套 `RIGID_REASONS`
（`hori-spacing.lua`），竖排照抄常量而不是重写规则。

### 2.3 行首/行尾在这里落地

`punct_squeeze.plan` 的 `ctx = { at_line_start, at_line_end }` 目前无人传——
flush_buffer 正是唯一知道答案的地方：`col_buffer[1]` 就在列首，
`col_buffer[N]` 就在列尾。于是：

- `head_1`：若首字是开始夹注符号且 `line_start_bracket = trim` →
  `min = 0`（整段空白可收回）；
- `tail_N`：若末字是点号且 `line_end_punct = compress` →
  `min = 0`，且该 gap 的 `shrink_class = "line_end_punct"`（挤压第 1 级）；
  开启悬挂时改为 `width = 0` 并给 render 阶段留出「整字悬于版口外」的标记。

相邻标点（P1 已实现的那一半）保持由 flatten 预判，flush 阶段只在
`min` 上叠加行首/行尾，两者取更小的 `min`（收回量取大者，与
`punct_squeeze.plan` 内「行首/行尾覆盖相邻分摊量」的语义一致）。

---

## 3. target 怎么算

```
target = ctx.col_height_sp − col_start_y
```

`col_start_y` 已含列首缩进与 padding（现行代码同名变量），因此 target 就是
这一列**实际可用的纵向长度**。但**不是每一列都该均排**：

| 列的成因 | target | 理由 |
|----------|--------|------|
| 正常写满后换列（`should_wrap`） | `col_height_sp − col_start_y` | 列满，挤压/拉伸都可能发生 |
| 禁则「挤进」导致超长 | 同上 | 超长量由 SHRINK_ORDER 逐级消化，替换现行「平均压缩」 |
| 段末列 / `\par` 或换页强制结束的列 | `Σwidth`（自然长度） | clreq：正文末行不均排（横排已按此口径，见 commit 73acb62） |
| `distribute` 模式（textbox 均分） | 保持现行分布逻辑 | 与 clreq 行内调整无关，不接入 |
| grid 模式（`default_cell_height` 非空） | 不调用 solver | 固定格 = shrink/stretch 均为 0 的退化情形（R1） |

段末列的判定：flush_buffer 需要知道「这次 flush 是因为写满换列，还是因为
段落/页面结束」。现在 `flush_fn()` 在两种情形下都被调用，**要加一个参数**
（如 `flush_buffer(..., reason)`，`reason = "wrap" | "end"`），这是本次接线
唯一需要改的调用协议。

余量为负且全组触底时 `solve` 返回 `deficit > 0`：按 clreq「先挤进，后推出」，
此时应把末字推到下一列并重解，而不是硬压——推出决策留在后端
（`kinsoku.check_wrap` 已提供判定，代价比较仍是后端职责，契约 3.1）。

---

## 4. 落盘：从 solve 结果回写 y_sp

`solve` 返回 `widths[]`（与 gaps 等长）。位置由前缀和得到：

```
y = col_start_y + widths[1]              -- 列首 head gap
for i = 1..N:
    col_buffer[i].y_sp = y
    col_buffer[i].cell_height = cell_i    -- 刚性部分
    y = y + cell_i + widths[i+1]
```

注意 `cell_height` 此后是**刚性墨迹尺寸**，不再等于「字幅」。render 阶段
用它做居中（`punct.render` 的偏靠偏移、`calc_grid_position` 的居中）时，
必须同时知道该字的 head/tail 收回量才能把字面放对——**这一步 P1 已经踩过**：
只传总收回量会让居中逻辑把句号向上飘半个收回量、紧贴前字，后侧反而留洞。
现行做法是 render 读 `ATTR_PUNCT_SQUEEZE`（总量）与
`ATTR_PUNCT_SQUEEZE_HEAD`（始端量），按**原始满幅**居中、再按始端量上移
（`render-page-process.lua`）。接线后收回量改由 solver 决定、不再是每字一个
常量，届时应把这两个量随 layout_map entry 下发（`head_sp` / `tail_sp`），
render 仍只读不算。

---

## 5. 迁移步骤（每步独立可测）

1. **只读接线**：在 flush_buffer 里按 §2 组装 gaps 并调用 `solve`，但结果
   只写进 debug 日志与 layout JSON，不改 y_sp。用现有 vbook 用例对比
   solver 结果与现行三分支策略的差异，确认差异只出现在有标点的列。
2. **换掉「超长」分支**：`remaining < 0` 时改用 solve 的挤压结果
   （SHRINK_ORDER）。此分支现在就是平均压缩，最容易看出优先级效果。
3. **换掉「近满」分支**：拉伸走 STRETCH_ORDER + 兜底均分。
4. **行首/行尾接入**（§2.3），同时把 P1 留的缺口补上。
5. **grid 模式合流**：cells 全为 `default_cell_height`、gaps 全 0，
   走同一条代码路径（消灭 R2 双轨）。

每步的验收都是同一组：`texlua test/run_all.lua` → `python3
test/clreq_test.py`（竖排断言用例 `test/clreq_test/vert-punct.tex`，
逐步补行首/行尾条款）→ `python3 test/regression_test.py check --all`，
且 `ltc-guji` 三套基线零变化（R5）。

---

## 6. 已知的接口缺口（做之前先在共享层补）

- `adjust.solve` 的 `deficit > 0` 只报告不决策，推出逻辑要在后端写一遍——
  横排目前也各写一份，可考虑在 `kinsoku` 侧补一个统一的「挤进/推出」代价
  比较函数。
- `punct_squeeze.plan` 目前一次只判一个字符，行首/行尾要后端自己传 ctx；
  若第 4 步发现调用点繁琐，可在共享层加一个 `plan_run(chars, opts)`
  对整列一次算完（纯函数，仍不碰 TeX）。
- **验收工具本身有个洞**：`test/clreq_test.py` 的 PDF 解析器只认单位矩阵
  `Tm`，遇到被 `cm` 缩放过的字形（脚注标号组就是）会把坐标读成变换前的
  原点。第 1 步的「只读接线」要靠它对比 solver 与现行策略的差异，
  **宜在动工前先修**，否则含标号的列读出来的位置是假的。
- 叹问号叠加（`？！` `！？`）仍未识别为刚性两字幅单元，见
  `ai_must_read/clreq-shared-core.md` 的待补条目——它会直接影响本设计里
  「刚性单元」的判定，宜在第 1 步之前补掉。
