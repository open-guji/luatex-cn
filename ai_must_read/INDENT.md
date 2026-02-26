# 缩进系统全面梳理

> **最后更新**: 2026-02-25
> **状态**: 现状分析 + 问题诊断（待重构）

## 目录

- [一、命令清单](#一命令清单)
- [二、编码体系](#二编码体系)
- [三、生命周期与作用域](#三生命周期与作用域)
- [四、Layout 阶段处理](#四layout-阶段处理)
- [五、Textflow（夹注）中的缩进](#五textflow夹注中的缩进)
- [六、guji vs guji-digital 差异](#六guji-vs-guji-digital-差异)
- [七、核心代码路径图](#七核心代码路径图)
- [八、已知问题与混乱根源](#八已知问题与混乱根源)

---

## 一、命令清单

### 1.1 环境级缩进

| 命令 | 定义位置 | 作用 |
|------|---------|------|
| `\begin{段落}[indent=N]` | `paragraph.sty:49` | 推入 style stack，后续字符继承 indent=N |
| `\begin{段落}[first-indent=M]` | 同上 | 首列用 M，后续列用 indent |
| `\begin{段落}[bottom-indent=K]` | 同上 | 列底部收缩 K 格（ATTR_RIGHT_INDENT） |

### 1.2 行内命令

| 命令 | 编码方式 | 插入 penalty | 推临时样式 | 作用域控制 |
|------|---------|-------------|-----------|-----------|
| `\缩进[N]` (N≥0) | forced indent | 无 | **是** | 临时样式 (`\\`/`\end{段落}` 恢复) |
| `\缩进[N]` (N<0) | forced indent | PENALTY_TAITOU | **是** | 临时样式 + taitou scope |
| `\平抬` = `\抬头[0]` | forced(-0) | PENALTY_TAITOU | **否** | 仅 taitou scope |
| `\单抬` = `\抬头[1]` | forced(-(-1)) | PENALTY_TAITOU | **否** | 仅 taitou scope |
| `\双抬` = `\抬头[2]` | forced(-(-2)) | PENALTY_TAITOU | **否** | 仅 taitou scope |
| `\三抬` = `\抬头[3]` | forced(-(-3)) | PENALTY_TAITOU | **否** | 仅 taitou scope |
| `\相对抬头[N]` | forced(current-N) | PENALTY_TAITOU | **否** | 仅 taitou scope |
| `\挪抬[N]` / `\空抬` | 插入 N 个全角空格 | 无 | 否 | 无状态（即时） |
| `\换行` | 无缩进改变 | PENALTY_FORCE_COLUMN | 否 | N/A |

### 1.3 中英文别名

| 简体 | 繁体 | 英文/拼音 |
|------|------|----------|
| `\缩进` | `\縮進` | `\Indent` |
| `\抬头` | — | `\TaiTou` |
| `\平抬` | — | `\PingTai` |
| `\单抬` | `\單抬` | `\DanTai` |
| `\双抬` | `\雙抬` | `\ShuangTai` |
| `\三抬` | — | `\SanTai` |
| `\挪抬` | — | `\NuoTai` |
| `\空抬` | — | `\KongTai` |
| `\相对抬头` | `\相對抬頭` | `\XiangDuiTaiTou` |
| `\换行` | `\換行` | `\HuanHang` |
| `段落` | — | `Paragraph` |

---

## 二、编码体系

定义在 `constants.lua:273-319`。

### 2.1 ATTR_INDENT 属性值含义

```
值          含义
──────────────────────────────────────────
0           INDENT_INHERIT — 继承 style stack
> 0         显式缩进值（如 indent=2 → 属性值 2）
-2          INDENT_FORCE_ZERO — 强制缩进=0（平抬）
< -1000     INDENT_FORCE_BASE - N — 强制缩进=N
            例: -1003 = 强制缩进 3
            例: -999  = 强制缩进 -1（单抬）
```

### 2.2 编码/解码函数

```lua
encode_forced_indent(0)   → -2          -- INDENT_FORCE_ZERO
encode_forced_indent(3)   → -1003       -- INDENT_FORCE_BASE - 3
encode_forced_indent(-1)  → -999        -- INDENT_FORCE_BASE - (-1)

is_forced_indent(-2)      → true, 0
is_forced_indent(-1003)   → true, 3
is_forced_indent(-999)    → true, -1
is_forced_indent(2)       → false, nil  -- 非强制
is_forced_indent(0)       → false, nil  -- 继承栈
```

### 2.3 三层优先级

```
优先级 1（最高）：强制缩进 (Forced Indent)  — encode_forced_indent() 编码
    ↓ 如果没有强制缩进
优先级 2（中等）：显式缩进 (Explicit Indent) — ATTR_INDENT > 0
    ↓ 如果没有显式缩进
优先级 3（最低）：样式栈缩进 (Style Stack)   — style_registry.get_indent(style_id)
```

### 2.4 Penalty 常量

```lua
PENALTY_FORCE_COLUMN   = -10002  -- \换行，不设 taitou scope
PENALTY_TAITOU         = -10004  -- \抬头/\平抬/\相对抬头，设 taitou scope
PENALTY_DIGITAL_NEWLINE = -10005 -- ^^M（数字化模式每行换列）
PENALTY_SMART_BREAK    = -10001  -- \end{段落} 后的智能断列
PENALTY_FORCE_PAGE     = -10003  -- \换页
```

### 2.5 Attribute 常量

```lua
ATTR_INDENT       -- 主缩进属性
ATTR_FIRST_INDENT -- 首行缩进属性
ATTR_RIGHT_INDENT -- 列底部（右侧）缩进
ATTR_BLOCK_ID     -- 段落分组 ID（用于区分 first-indent）
ATTR_STYLE_REG_ID -- 样式栈 ID
```

---

## 三、生命周期与作用域

### 3.1 `\begin{段落}[indent=N]`

**设置** (`paragraph.sty:49-87`):
1. `push_indent(N, first_indent)` → 推入 style stack
2. `ATTR_INDENT = N` (plain, 非 forced)
3. `ATTR_STYLE_REG_ID = style_id`
4. 重定义 `\\` 为 `restore_temp_indent + original \\`

**失效** (`paragraph.sty:88-111`):
1. `restore_temp_indent()` — 弹出可能的临时样式
2. `style_registry.pop()` — 弹出段落样式
3. `ATTR_INDENT = 0`, `ATTR_FIRST_INDENT = -1`
4. 插入 `PENALTY_SMART_BREAK`

**继承**：子 `\begin{段落}` 会在栈上覆盖父级值，`\end{段落}` 后恢复。

### 3.2 `\缩进[N]`（N≥0）

**设置** (`paragraph.sty:139-177`):
1. `push_indent(N, -1, temporary=true)` — 推入**临时**样式
2. `ATTR_INDENT = encode_forced_indent(N)` ← **forced 编码**
3. `ATTR_FIRST_INDENT = encode_forced_indent(N)`
4. `setindent_active_bool = true`

**失效** (`paragraph.sty:180-209`):
- `\\` 换行时调用 `restore_temp_indent:`
  - `pop_temporary()` 弹出临时样式
  - `ATTR_INDENT = style_registry.get_indent(current_id)` ← **plain 编码**恢复
  - `setindent_active_bool = false`
- `\end{段落}` 结束时也调用

**关键特征**：
- **不插入 PENALTY_TAITOU**（N≥0 时），不设 taitou scope
- 用 forced 编码 + 临时样式**双重机制**控制作用域
- `\\` 之后的字符带恢复后的 plain 属性值

### 3.3 `\缩进[N]`（N<0）

与 N≥0 相同，额外插入 PENALTY_TAITOU，触发换列 + 设 taitou scope。

### 3.4 `\抬头[N]` / `\平抬` / `\单抬` / `\双抬` / `\三抬`

**设置** (`paragraph.sty:225-239`):
1. 插入 `PENALTY_TAITOU` — 触发换列
2. `ATTR_INDENT = encode_forced_indent(-N)` ← forced 编码
3. **不推临时样式**，**不设 setindent_active_bool**

**失效**：
- 完全依靠 **taitou scope** 机制
- Layout 阶段换到下一列时，`outside_taitou=true` → forced indent 被清除
- `wrap_to_next_column()` 中负 `cur_column_indent` 被重置为 0

### 3.5 `\相对抬头[N]`

**设置** (`paragraph.sty:263-275`):
1. 插入 `PENALTY_TAITOU`
2. 计算 `target = style_registry.get_indent(current_id) - N`
3. `ATTR_INDENT = encode_forced_indent(target)` ← forced 编码

**失效**：与 `\抬头` 相同——taitou scope 机制。

### 3.6 作用域机制对比

| 机制 | 使用者 | 管理层 | 清除时机 |
|------|--------|-------|---------|
| 临时样式 + setindent_active_bool | `\缩进[N]` | TeX 层 | `\\` 或 `\end{段落}` |
| taitou scope (taitou_col/taitou_page) | `\抬头`/`\平抬`/`\相对抬头` | Layout 层 | 列变化时自动检查 |

**两套机制并行但逻辑不同，是混乱的根源。**

---

## 四、Layout 阶段处理

### 4.1 resolve_node_indent() (`layout-grid.lua:511-589`)

三层优先级检查：
```lua
1. Penalty? → return indent=0（penalty 不占布局空间）

2. 解码 forced indent:
   is_forced, forced_value = constants.is_forced_indent(ATTR_INDENT)

3. Taitou scope 检查:
   outside_taitou = taitou_col ~= nil AND (cur_col ~= taitou_col OR cur_page ~= taitou_page)
   if forced AND outside_taitou → 清除 forced，fallback 到 style stack

4. 确定 base_indent:
   forced? → forced_value
   显式 (ATTR_INDENT > 0)? → ATTR_INDENT
   否则 → style_registry.get_indent(style_id)

5. first_indent 同理

6. get_indent_for_current_pos() → 首列用 first_indent，后续用 base_indent
```

### 4.2 apply_indentation() (`layout-grid.lua:155-177`)

```lua
负缩进（抬头）:
  仅首次应用（cur_column_indent == 0 时）
  cur_row = indent (负值，如 -1)
  cur_column_indent = indent

正缩进:
  cur_row = max(cur_row, indent)
  cur_column_indent = max(cur_column_indent, indent)

同步 cur_y_sp = cur_row * grid_height
```

### 4.3 PENALTY_TAITOU 处理 (`layout-grid.lua:397-404`)

```lua
PENALTY_TAITOU:
  flush_buffer()
  wrap_to_next_column()  -- 换到新列
  ctx.taitou_col = ctx.cur_col     -- 记录 taitou 作用列
  ctx.taitou_page = ctx.cur_page   -- 记录 taitou 作用页
```

### 4.4 wrap_to_next_column() (`layout-grid.lua:250-307`)

```lua
1. pop_temporary() — 弹出所有临时样式
2. cur_col++, cur_row=0, cur_y_sp=0
3. 清空 textflow_pending 状态
4. 自动换页检查（guji 模式 only）
5. 重置：
   - reset_indent 或 cur_column_indent < 0 → cur_column_indent = 0
6. 负 indent 传递：
   - outside taitou scope → skip_indent = 0（不传递负值）
   - inside taitou scope → 保持（理论上不会发生，因为刚换列）
7. move_to_next_valid_position(skip_indent)
```

### 4.5 ctx 状态变量

| 变量 | 作用域 | 重置时机 | 用途 |
|------|-------|---------|------|
| `cur_row` | 列内 | 每次换列 → 0 | 当前行位置 |
| `cur_column_indent` | 列内 | 换列时（负值总是重置，正值看 reset_indent） | 防止重复应用 |
| `taitou_col` | 全文档 | **仅被下一个 PENALTY_TAITOU 覆盖** | taitou scope 列号 |
| `taitou_page` | 全文档 | 同上 | taitou scope 页号 |
| `cur_y_sp` | 列内 | 每次换列 → 0 | Y 坐标（sp） |

---

## 五、Textflow（夹注）中的缩进

### 5.1 入口 place_nodes() (`textflow.lua:666-743`)

1. 接收 `params.base_indent` 和 `params.first_indent`
2. 检测第一个 glyph 是否有 forced indent
3. 如果有 → 从 style stack 恢复 `orig_base_indent`（防止 forced 值污染后续计算）
4. 循环收集 segment（由 PENALTY_TAITOU / PENALTY_FORCE_COLUMN 分隔）

### 5.2 collect_nodes() (`textflow.lua:110-200`)

- 遇到 PENALTY_FORCE_COLUMN / PENALTY_DIGITAL_NEWLINE → `hit_column_break=true`
- 遇到 PENALTY_TAITOU:
  - **guji 模式**: 总是触发 segment break
  - **digital 模式** + 开头 (`skip_leading_taitou=true` 且 `#nodes==0`): 跳过
  - digital 模式 + 中间: 触发 segment break

### 5.3 place_textflow_segment() (`textflow.lua:444-657`)

1. 检测第一个节点是否 forced indent → 恢复 orig_base_indent
2. 计算 `capacity_per_subsequent = line_limit - orig_base_indent - r_indent`
3. 如果 forced indent 值 < cur_row → 额外空间 `forced_indent_extra_sp`
4. process_sequence() 分配节点到 chunk
5. 放置节点到 layout_map:
   - **forced indent**: `base_y_sp = ni_indent_val * gh`（绝对位置）
   - **非 forced**: `base_y_sp = ctx.cur_row * gh`（继承偏移）
   - **chunk > 1**（溢出到下一大列）: forced indent 被清除

### 5.4 段落/夹注缩进继承链

```
\begin{段落}[indent=2]
  → style_registry.push_indent(2)
  → ATTR_STYLE_REG_ID = id_A
  → ATTR_INDENT = 2 (plain)

  \夹注{内容}
    → textflow.place_nodes() 接收 params.base_indent=2
    → 夹注内每个字符继承 ATTR_STYLE_REG_ID = id_A
    → style_registry.get_indent(id_A) = 2

    \平抬 顶格内容
      → PENALTY_TAITOU → segment break
      → 新 segment 第一个字符: ATTR_INDENT = INDENT_FORCE_ZERO
      → place_textflow_segment: forced → base_y_sp = 0 * gh = 0（顶格）
      → orig_base_indent 从 style stack 恢复 = 2
      → 后续 chunk 正常用 indent=2
```

---

## 六、guji vs guji-digital 差异

| 维度 | guji (语义模式) | guji-digital (布局模式) |
|------|---------------|----------------------|
| 列分隔 | 自动换列 (auto_column_wrap=true) | 手动换列 (^^M = PENALTY_DIGITAL_NEWLINE) |
| `\缩进[N]` 语义 | 临时覆盖当前列缩进，`\\` 恢复 | 设置当前列缩进（同一行内容跟随） |
| `\缩进[-1]` 在 textflow 开头 | PENALTY_TAITOU → segment break | PENALTY_TAITOU **被跳过** |
| 换页 | 自动（列溢出时） | 仅 `\换页` 命令 |
| `\抬头` 在 textflow 中 | 触发 segment break | 开头时跳过，中间触发 break |
| 缩进恢复 | `\\` 或 `\end{段落}` | `\\` 或 `\end{正文}` |
| `\双列` | 不存在，用 `\夹注` 自动分栏 | 手动指定左右小列内容 |

---

## 七、核心代码路径图

```
TeX 输入
  │
  ├─ \begin{段落}[indent=N]
  │    → style_registry.push_indent(N, first_indent)
  │    → ATTR_INDENT = N (plain)
  │    → ATTR_STYLE_REG_ID = style_id
  │
  ├─ \缩进[M] (M≥0)
  │    → push_indent(M, -1, temporary=true)
  │    → ATTR_INDENT = encode_forced_indent(M)  ← forced
  │    → setindent_active_bool = true
  │
  ├─ \缩进[M] (M<0)
  │    → 同上 + 插入 PENALTY_TAITOU
  │
  ├─ \平抬/\抬头[N]
  │    → 插入 PENALTY_TAITOU
  │    → ATTR_INDENT = encode_forced_indent(-N)  ← forced
  │    （不推临时样式，不设 setindent_active_bool）
  │
  ├─ \相对抬头[N]
  │    → 插入 PENALTY_TAITOU
  │    → target = get_indent(current_id) - N
  │    → ATTR_INDENT = encode_forced_indent(target)  ← forced
  │
  ├─ \\
  │    → restore_temp_indent:
  │       pop_temporary()
  │       ATTR_INDENT = get_indent(current_id)  ← plain 恢复
  │       setindent_active_bool = false
  │
  └─ \end{段落}
       → restore_temp_indent
       → style_registry.pop()
       → ATTR_INDENT = 0, ATTR_FIRST_INDENT = -1
       → PENALTY_SMART_BREAK

Layout 阶段 (layout-grid.lua)
  │
  ├─ resolve_node_indent(node)
  │    1. Penalty → indent=0
  │    2. is_forced? + outside_taitou? → 清除 forced
  │    3. forced → forced_value
  │    4. 显式 → ATTR_INDENT
  │    5. 否则 → style_registry.get_indent()
  │    6. first_indent vs base_indent
  │
  ├─ apply_indentation(ctx, indent)
  │    ├─ < 0: cur_row = indent（仅首次）
  │    └─ > 0: cur_row = max(cur_row, indent)
  │
  ├─ PENALTY_TAITOU:
  │    → wrap_to_next_column()
  │    → taitou_col = cur_col, taitou_page = cur_page
  │
  └─ wrap_to_next_column():
       → pop_temporary()
       → cur_column_indent < 0 → 重置为 0
       → outside taitou → skip_indent = 0

Textflow 阶段 (textflow.lua)
  │
  ├─ place_nodes(): 恢复 orig_base_indent
  ├─ collect_nodes(): PENALTY_TAITOU → segment break
  └─ place_textflow_segment():
       ├─ forced → base_y_sp = forced_val * gh
       ├─ 非 forced → base_y_sp = cur_row * gh
       └─ chunk > 1 → 清除 forced
```

---

## 八、已知问题与混乱根源

### 8.1 两套作用域机制并行

**根本问题**：当前有两套独立的作用域机制同时运作：

| 机制 | 使用者 | 管理层 | 清除时机 |
|------|--------|-------|---------|
| 临时样式 + setindent_active_bool | `\缩进[N]` | TeX 层 | `\\` 或 `\end{段落}` |
| taitou scope (taitou_col/taitou_page) | `\抬头`系列 | Layout 层 | 列变化时检查 |

`\缩进[N]` 用了 forced 编码**却不设** taitou scope，而 `\抬头` 用了 forced 编码**却不推**临时样式。两者的 forced 值在 `resolve_node_indent` 中走同一个代码路径，但作用域语义完全不同。

### 8.2 taitou scope 永不主动清除

`ctx.taitou_col/taitou_page` 一旦设置后，**只有下一个 PENALTY_TAITOU 才会覆盖**。这意味着：

```latex
\begin{段落}[indent=2]
正文\单抬 皇帝\\     ← 设 taitou scope
\缩进[0]顶格内容\\   ← forced indent=0, 但 taitou scope 残留
                      ← outside_taitou=true → forced 被错误清除！
\end{段落}
```

`\缩进[0]` 本应强制顶格，但因为 `\单抬` 留下的 taitou scope 还在，且 `\缩进[0]` 在不同列，`outside_taitou=true` 导致 forced indent 被清除，回退到 style stack 的 indent=2。

### 8.3 `\缩进[N]` 不换行时的 forced 泄漏

```latex
\begin{段落}[indent=2]
\缩进[5]一二三四五六七八九十一二三四五六七八九十一（21字填满自动换列）
继续内容
\end{段落}
```

- `\缩进[5]` 设 forced indent=5，不设 taitou scope
- 字符填满一列，自动换列
- `wrap_to_next_column` 中 `pop_temporary()` 弹出临时样式
- 但**已经生成的节点**上的 forced 属性值不会被修改
- 如果最后几个字符的 ATTR_INDENT 还是 forced(-1005)，且 `taitou_col==nil`
- `resolve_node_indent` 中 `outside_taitou=false`（因为 taitou_col 是 nil）
- forced indent **不会被清除** → 泄漏到下一列

### 8.4 `\抬头` 不与临时样式集成

`\抬头` 不推临时样式、不设 `setindent_active_bool`，完全依赖 taitou scope。
而 `\缩进` 同时用临时样式 + forced 编码两套机制。

这导致混用时行为不可预测（见 8.2）。

### 8.5 INDENT.md 中的 `\平抬` 文档与实际不符

旧文档显示 `\平抬` 的实现是 `\\ + INDENT_FORCE_ZERO`，但实际代码是 `\抬头[0]`，即 `PENALTY_TAITOU + encode_forced_indent(0)`。文档已过期。

---

## 附录：相关文件清单

### 核心实现

| 文件 | 功能 |
|------|------|
| `core/luatex-cn-constants.lua` | 常量定义 + encode/decode 函数 |
| `core/luatex-cn-core-paragraph.sty` | 段落环境 + 所有缩进/抬头命令 |
| `core/luatex-cn-layout-grid.lua` | Layout 阶段：resolve_node_indent, apply_indentation, wrap_to_next_column |
| `core/luatex-cn-core-textflow.lua` | Textflow 阶段：place_nodes, place_textflow_segment, collect_nodes |
| `util/luatex-cn-style-registry.lua` | Style stack 管理：push_indent, pop, get_indent |
| `core/luatex-cn-core-flatten-nodes.lua` | Flatten 阶段：get_box_indentation, copy_node_with_attributes |

### 测试文件

| 文件 | 测试内容 |
|------|---------|
| `test/unit_test/core/layout-grid-test.lua` | PENALTY_TAITOU scope, PENALTY_DIGITAL_NEWLINE |
| `test/unit_test/core/flatten-nodes-test.lua` | get_box_indentation, forced indent 保留 |
| `test/unit_test/util/style-registry-test.lua` | push_indent, pop_temporary, get_indent |
| `test/unit_test/core/constants-test.lua` | PENALTY_TAITOU 常量值 |
| `test/regression_test/basic/tex/paragraph.tex` | 段落缩进 + 抬头全场景 |
| `test/regression_test/basic/tex/jiazhu.tex` | 夹注中的平抬/相对抬头 |
| `test/regression_test/past_issue/tex/issue_pingtai_in_jiazhu.tex` | 连续平抬在夹注中的 bug |
| `test/regression_test/basic/tex/guji-digital-basic.tex` | 数字化模式缩进 |
