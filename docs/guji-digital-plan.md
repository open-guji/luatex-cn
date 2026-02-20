# guji-digital 文档类实现计划

## 背景

`luatex-cn` 项目已有 `guji` 文档类，面向古籍排版的**语义化**场景（`\平抬`、`\夹注`、`\段落[indent=2]`）。现需新建 `guji-digital` 文档类，面向古籍**数字化**场景——直接记录页面的排版布局信息，不关心语义。

核心理念：**每个 TeX 换行 = 一列，每个 `\newpage` = 一页，版心内容显式指定，引擎不做任何自动计算。**

## 架构设计

### 类继承关系

```
guji-digital.cls
├─ article.cls (基础)
├─ luatex-cn-core (完整复用：Content、TextFlow、Style、Paragraph、Banxin、Decorate 等)
├─ debug/luatex-cn-debug
└─ digital/luatex-cn-digital.sty (NEW - 数字化专属命令)
```

与 `guji.cls` 的区别：**不加载** `guji/luatex-cn-guji.sty`（不需要句读、批注、眉批、印章、封面、标题页、目录、脚注）。

### 新增文件清单

| 文件 | 说明 | 约行数 |
|------|------|--------|
| `tex/guji-digital.cls` | 文档类入口 | ~80 |
| `tex/digital/luatex-cn-digital.sty` | 数字化专属 TeX 命令 | ~200 |
| `tex/configs/luatex-cn-digital-default.cfg` | 默认配置 | ~50 |
| `test/regression_test/tex/guji-digital-basic.tex` | 回归测试 | ~50 |

**不需要新增任何 Lua 模块**，所有 Lua 层能力完全复用现有代码。

## 关键技术方案

### 1. "换行=换列" — `DigitalContent` 环境

**方案：** `\vbox_set:Nw` + `\obeylines` + 活跃 `^^M` → `\par\penalty -10002`

```latex
\NewDocumentEnvironment{DigitalContent}{ O{} }
{
  % ... 标准 Content 初始化（font、geometry、sync）...
  \vbox_set:Nw \l_tmpa_box
    % 在 vbox 内部启用 obeylines
    \obeylines
    \begingroup\lccode`\~=`\^^M
    \lowercase{\endgroup\def~{\par\penalty-10002\relax}}%
}
{
  \vbox_set_end:
  % ... 标准 Content 处理（sync → init_style → core.process）...
}
```

- 使用 `\vbox_set:Nw`（异步捕获），而非 `\NewEnviron`（`\BODY` 宏 catcode 已固定）
- `PENALTY_FORCE_COLUMN (-10002)` 已被 layout 引擎完整支持，无需改 Lua
- 空行 → 连续两个 `\par\penalty-10002` → layout 产生空列

### 2. `\缩进[N]` — 当前行缩进

直接复用 `\SetIndent`：

```latex
\NewDocumentCommand{\缩进}{ O{0} }{ \SetIndent{#1} }
```

- 正值 = 缩进，负值 = 抬头（伸入天头）

### 3. `\双列{\右小列{...}\左小列{...}}` — 显式双列

**方案：** 收集左右内容 → 两个连续 `\TextFlow[only-column=right/left]`

```latex
\NewDocumentCommand{\双列}{ +m }
{
  \tl_clear:N \l__luatexcn_digital_right_col_tl
  \tl_clear:N \l__luatexcn_digital_left_col_tl
  #1  % 触发 \右小列 和 \左小列 收集内容
  \TextFlow[only-column=right, auto-balance=false]{\l__luatexcn_digital_right_col_tl}%
  \TextFlow[only-column=left, auto-balance=false]{\l__luatexcn_digital_left_col_tl}
}
```

利用 TextFlow continuation 机制。

### 4. 版心环境 — 显式版心内容

复用现有 banxin 系统，通过命令设置参数：

```latex
\begin{版心}
  \版心上部{书名}         → \banxinSetup{book-name={书名}}
  \begin{版心中部}
    \上鱼尾               → 设置 upper-yuwei=true
    \版心章节{章节名}     → \banxinSetup{chapter-title={章节名}}
    \版心页码{一}         → 设置显式页码
    \下鱼尾               → 设置 lower-yuwei=true
  \end{版心中部}
  \版心下部{出版商}       → \banxinSetup{publisher={出版商}}
\end{版心}
```

**需要小幅修改的现有文件：**
- `tex/banxin/luatex-cn-banxin-render-banxin.lua` — 添加显式页码支持（约5行）

## 分阶段实施（每阶段测试+提交）

### Phase 1: 基础框架（MVP）
**目标：** DigitalContent 环境 + `\缩进` 命令，验证换行=换列

**步骤：**
1. 创建 `tex/digital/` 目录
2. 创建 `tex/guji-digital.cls` — 仿照 `tex/guji.cls` 结构
3. 创建 `tex/digital/luatex-cn-digital.sty` — `DigitalContent` 环境 + `\缩进` 命令
4. 创建 `tex/configs/luatex-cn-digital-default.cfg` — 默认配置
5. 创建 `test/regression_test/tex/guji-digital-basic.tex` — 基本测试
6. 验证：`texlua test/run_all.lua` + 手动编译测试 tex 查看 PDF

**提交：** `feat: add guji-digital class with DigitalContent environment`

---

### Phase 2: 双列支持
**目标：** `\双列`、`\右小列`、`\左小列` 命令

**步骤：**
7. 在 `luatex-cn-digital.sty` 中添加双列命令
8. 更新回归测试 tex 文件添加双列测试用例
9. 验证 TextFlow continuation 机制，如不工作则回退到备选方案

**提交：** `feat: add dual-column support for guji-digital`

---

### Phase 3: 版心环境
**目标：** 显式版心内容指定

**步骤：**
10. 在 `luatex-cn-digital.sty` 中添加版心环境及子命令
11. 修改 `luatex-cn-banxin-render-banxin.lua` 添加显式页码
12. 更新回归测试添加版心测试用例

**提交：** `feat: add explicit banxin environment for guji-digital`

---

### Phase 4: 空行处理和边缘情况
**目标：** 空行=空列，各种边缘情况

**步骤：**
13. 验证空行→空列行为
14. 如空列被吞掉，在 `^^M` 定义中添加 `\kern0pt` 占位
15. 测试边缘情况

**提交：** `fix: handle empty lines and edge cases in guji-digital`

---

### Phase 5: 完善
**目标：** 别名、文档

**步骤：**
16. 添加中文别名（简体/繁体）和英文别名
17. 更新 CHANGELOG

**提交：** `docs: add aliases and update changelog for guji-digital`

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| `\obeylines` 在 `\vbox_set:Nw` 内不生效 | 备选：`\everypar` + 自定义 penalty 方案 |
| TextFlow continuation 不适用 right→left | 备选：单 TextFlow + 手动 sub 属性 |
| 空行被 flatten 优化掉 | 在 `^^M` 中插入 `\kern0pt` 占位 |
| 与 `guji.cls` 命名冲突 | 使用独立命名空间 `luatexcn/digital` |

## 关键参考文件

- `tex/guji.cls` — 类文件模板
- `tex/core/luatex-cn-core-content.sty` — Content/BodyText 环境实现
- `tex/core/luatex-cn-core-textflow.sty` — TextFlow 实现（双列基础）
- `tex/core/luatex-cn-core-paragraph.sty` — SetIndent/Paragraph 实现
- `tex/core/luatex-cn-core-style.sty` — Style 命令
- `tex/banxin/luatex-cn-banxin.sty` — 版心配置接口
- `tex/banxin/luatex-cn-banxin-render-banxin.lua` — 版心渲染（需小改）
- `tex/configs/luatex-cn-guji-default.cfg` — 默认配置模板
