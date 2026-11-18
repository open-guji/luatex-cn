---
name: fix-github-issue
description: 修复 GitHub Issue 的完整工作流
---

# 修复 GitHub Issue 工作流

当需要修复 GitHub issue 时，请遵循以下完整流程以确保代码质量和正确性。

## 1. 获取 Issue 详情

// turbo
首先，使用 `gh` CLI 工具获取 issue 的完整信息：
```bash
gh issue view <issue-number> --repo open-guji/luatex-cn
```

**目的**：
- 理解问题的具体描述
- 查看附带的截图或示例
- 了解用户期望的行为

### 1.1 下载用户附带的原文件（必须）

用户通常附了 `.txt`（改了后缀的 .tex）和编译出的 `.pdf`。**源文件和 PDF 都要下载**，
放进仓库外一个单独的空目录。后面复现和验证修复都以这个原文件为准，最小用例只是补充。

```bash
mkdir -p /tmp/issue<N>-user && cd /tmp/issue<N>-user
# 本地：直接下载 issue 里的 github.com/user-attachments/files/... 链接
# 云端会话：curl 会被代理拦截。先用 WebFetch 打开该链接，拿到 302 指向的
#          objects.githubusercontent.com 签名地址（5 分钟内有效），再用 curl 下载
```

**为什么**：#201 当时只用自己写的最小用例验证。用户原文件里写的是
`\反白[border-shape=…]`，新实现整段退回了旧代码，修复对用户完全没生效，
直到发版后用户又报了 #210。#216 也一样：用户的文件同时开着句读和夹注
n-char-per-col，而我们的 n-char 用例开着 `\无标点模式`，碰不到句读。

## 2. 定位相关代码

使用搜索工具找到相关的代码文件：

// turbo
**按关键词搜索**（中英文关键词）：
```bash
# 使用 Grep 工具搜索 issue 中提到的关键词
# 支持中英文混合搜索
```

// turbo
**按文件类型搜索**：
```bash
# 使用 Glob 工具查找相关文件
# 例如：**/*.lua, **/*.sty, **/*.tex
```

**关键文件结构**：
- `tex/core/` - 核心渲染逻辑
- `tex/guji/` - 古籍特定功能
- `tex/banxin/` - 版心相关功能
- `tex/decorate/` - 装饰元素
- `test/regression_test/tex/` - 测试文件

## 3. 理解代码逻辑

// turbo
**阅读相关文件**：
- 使用 Read 工具仔细阅读定位到的文件
- 理解渲染流程和数据流
- 找出问题的根本原因

**系统架构**：
1. Stage 1: Flatten nodes（展平节点）
2. Stage 2: Layout grid（布局计算）
3. Stage 3: Render page（渲染应用）
   - 绘制背景
   - 绘制边框和装饰元素
   - 应用节点坐标
   - 插件渲染

**关键概念**：
- **Z-order（层叠顺序）**：后渲染的元素显示在上层
- **Node list order**：节点在列表中的顺序决定渲染顺序
- **Plugin system**：功能通过插件系统集成
- **坐标系统**：理解 xoffset/yoffset 和 kern/shift 的区别

## 4. 重现问题

**关键步骤**：在修复前，必须先成功重现问题。

### 4.1 先用用户原文件重现（必须）

编译 1.1 下载的原文件，**只把字体换成测试字体**（`\setFontFamily{…}` 换成
`\setmainfont{TW-Kai}`），其余一字不改：

```bash
cd /tmp/issue<N>-user
sed 's/\\setFontFamily{[^}]*}/\\setmainfont{TW-Kai}/' default.txt > user.tex
OSFONTDIR=<repo>/test/fonts TEXINPUTS=<repo>/tex//: LUAINPUTS=<repo>/tex//: \
  lualatex -interaction=nonstopmode user.tex
```

把结果和用户附的 PDF 对照，确认看到的是**同一个**现象，位置和幅度都要对得上。
对不上，说明还有别的触发条件没找到，先别急着写最小用例。

### 4.2 再写最小复现用例

在仓库外的临时目录创建最小复现用例：

```bash
mkdir -p /tmp/issue<N>-min && cd /tmp/issue<N>-min
# 创建测试文件 issue_<number>.tex
cat > issue_<number>.tex << 'EOF'
\documentclass{ltc-guji}  % 或 ltc-cn-vbook 等
% 根据 issue 描述添加相关配置
\begin{document}
% 最小化的测试内容
\end{document}
EOF

# 编译测试
lualatex -interaction=nonstopmode issue_<number>.tex
```

**目的**：
- 验证问题确实存在
- 理解问题的触发条件
- 创建简化的复现场景
- **保留用户文件里与问题相关的全局设置**：句读/标点模式、模板、字号、夹注设置等。
  不要顺手加 `\无标点模式` 之类让用例「更干净」的设置，#216 就是这样被藏起来的。

### 4.3 决定测试用例位置

成功重现后，根据用法频率选择测试位置：

#### **常见用法** → `test/regression_test/basic/tex/`

如果是**常用功能**或**核心特性**，在已有测试文件中添加测试用例：

```bash
# 例如：标点相关 → punctuation.tex
# 例如：夹注相关 → jiazhu.tex
# 例如：版心相关 → page.tex
```

**特点**：
- 会被频繁运行（每次 regression test）
- 应该保持文件小而快
- 覆盖该功能的多种使用场景

#### **不常见用法** → `test/regression_test/past_issue/tex/`

如果是**边缘场景**或**特定字体/配置**，创建独立测试文件：

```bash
# 命名格式：<feature>_issue<number>.tex
# 例如：vert_font_kinsoku_issue71.tex
```

**特点**：
- 记录历史问题（防止回归）
- 可以包含特殊配置或依赖
- 文件名直接关联 issue 编号

**判断标准**：
| 条件 | 位置 |
|------|------|
| 使用通用字体（Source Han Serif SC/TW-Kai） | basic |
| 使用特殊字体（KingHwa_OldSong + vert） | past_issue |
| 核心功能的常见用法（句读、夹注、版心） | basic |
| 特殊组合或边缘场景 | past_issue |
| 简单示例（< 30 行） | basic（合并到已有文件） |
| 复杂示例（> 30 行） | past_issue（独立文件） |

### 4.4 创建测试用例

**在 basic 中添加**（合并到已有文件）：
```latex
% 在 test/regression_test/basic/tex/punctuation.tex 中添加
\newpage
% Test for issue #71: PUA punctuation positioning
\setmainfont[RawFeature={vert}]{KingHwa_OldSong}
测试标点位置，。、
```

**在 past_issue 中创建**（独立文件）：
```bash
cd test/regression_test/past_issue/tex
cat > vert_font_kinsoku_issue71.tex << 'EOF'
\documentclass{ltc-cn-vbook}
\setmainfont[RawFeature={vert}]{KingHwa_OldSong}
\begin{document}
\begin{正文}
% 从 4.2 复制已验证的最小复现用例
\end{正文}
\end{document}
EOF
```

## 5. 实现修复

**修改代码时注意**：
- 保持代码风格一致
- 添加清晰的注释说明修改意图
- 考虑性能影响
- 避免破坏现有功能

**常见问题类型及修复思路**：
- **渲染层级问题**：调整节点插入位置或渲染顺序
- **位置计算问题**：检查坐标计算逻辑和参数传递
- **视觉效果问题**：确认渲染参数和颜色设置
- **布局问题**：检查网格计算和列宽行高设置

## 6. 验证修复（关键！）

### 6.0 用户原文件修复前后对比（必须）

用 4.1 的 `user.tex` 分别在 main 和修复分支上编译。main 可以用
`git worktree add /tmp/main-wt origin/main`，`TEXINPUTS` / `LUAINPUTS` 指向各自的 `tex//`。
渲染出问题所在的页面，左右拼成一张「修复前 / 修复后」对比图，放进 PR 描述。

- **修复后，用户文件里的现象必须消失。** 如果只修好了最小用例、用户文件没变，
  说明用户走的是另一条路径（#201 → #210 就是这样）。
- 截图放在 `issue-assets` 分支的 `issue-<N>/` 下，PR 里用
  `https://raw.githubusercontent.com/open-guji/luatex-cn/issue-assets/issue-<N>/<file>.png`
  引用，不要提交到 PR 分支。

**期望**：修复后，regression test 应该在相关测试文件上**显示变化**。

### 6.1 编译测试

// turbo
找到或创建相关的测试文件并编译：
```bash
lualatex --interaction=nonstopmode test/regression_test/basic/tex/<test-file>.tex
# 或
lualatex --interaction=nonstopmode test/regression_test/past_issue/tex/<test-file>.tex
```

### 6.2 单元测试（如果修改了 Lua 代码）

// turbo
```bash
texlua test/run_all.lua
```

**必须先通过 unit tests，再运行 regression tests**。

### 6.3 回归测试

// turbo
运行完整的回归测试以确保没有破坏现有功能：
```bash
python3 test/regression_test.py check
```

**关键验证点**：
1. ✅ **修复的测试文件应该显示差异**（FAIL 或像素差异）
   - 如果 regression test 显示所有测试都 PASSED（0 像素差异）
   - 说明修复**可能没有生效**或测试用例不正确

2. ✅ **其他测试文件应该保持通过**（PASSED，0 像素差异）
   - 如果其他文件也出现差异，说明修复影响了其他功能
   - 需要检查是否引入了副作用

**期望输出示例**：
```
FAIL: vert_font_kinsoku_issue71.tex differs on pages: [1]  ← 修复生效！
PASSED: punctuation.tex (0 pixels diff)                    ← 其他测试不受影响
PASSED: jiazhu.tex (0 pixels diff)
...
```

### 6.4 视觉验证

**检查修复效果**：
```bash
# 查看生成的 PDF
okular test/regression_test/basic/pdf/<test-file>.pdf
# 或
okular test/regression_test/past_issue/pdf/<test-file>.pdf

# 查看差异图像
ls -lh test/regression_test/basic/diff/
# 或
ls -lh test/regression_test/past_issue/diff/
```

**确认要点**：
- ✅ 生成的 PDF 中问题已修复
- ✅ 视觉效果符合 issue 描述的预期
- ✅ 没有引入新的视觉问题
- ✅ 如果修复涉及多个测试文件，确保都检查过

**使用 overlay_compare.py 对比修复前后**（可选）：
```bash
python3 scripts/overlay_compare.py \
  test/regression_test/past_issue/baseline/<test>-1.png \
  test/regression_test/past_issue/current/<test>-1.png \
  /tmp/overlay.png

# 查看叠加对比图
okular /tmp/overlay.png
```

## 7. 创建 past-issue 回归测试（有代表性时）

只有**有代表性、可能再出现**的问题才在 `test/regression_test/past_issue/tex/` 中加用例，
比如常见写法、新功能、以后重构时容易再坏的路径。不太可能再出现的边角情况，有 unit test 就够了。
先 `ls test/regression_test/past_issue/tex | grep <关键词>`，已有相关用例就优先往里加一页。
加不加都要在 PR 描述里写明理由。

问题出在**两个功能的交叉处**时（如句读 × 夹注格高），优先补进
`basic/tex/jiazhu-combo.tex` 这类组合用例，不要只加在单功能用例里。

**新功能自己的用例也不要关掉句读/标点**：#82（夹注 n-char-per-col）的用例开着
`\无标点模式`，于是 #216 里句读在 n-char 夹注中偏移，没有任何测试能发现。

### 7.1 创建测试文件

```bash
# 命名格式：<feature>_issue<number>.tex
cat > test/regression_test/past_issue/tex/<feature>_issue<number>.tex << 'EOF'
% Issue #<number>: <问题简要描述>
% https://github.com/open-guji/luatex-cn/issues/<number>
%
% 修复前: <修复前的错误行为>
% 修复后: <修复后的正确行为>
\documentclass{ltc-guji}
\setmainfont{TW-Kai}
\关闭分页
% 标点/句读模式与用户原文件保持一致；不要为了「干净」关掉它

\title{测试}
\chapter{Issue <number>}

\begin{document}
\begin{正文}
% 从 4.2 复制已验证的最小复现用例
% 包含多个测试场景（正常用法 + 边缘情况）
\end{正文}
\end{document}
EOF
```

**测试文件要求**：
- 文件头注释包含 issue 编号、GitHub URL、修复前后行为描述
- 包含正常对照（不受影响的基线场景）
- 包含核心复现场景（触发 bug 的用例）
- 可选：包含边缘情况（auto-balance 切换、不同 textbox 类型等）

### 7.2 生成 baseline

```bash
# 生成 past_issue suite 的 baseline
python3 test/regression_test.py save --past-issues
```

### 7.3 验证测试通过

```bash
# 确认新测试能通过
python3 test/regression_test.py check --past-issues
```

## 8. 更新基线

**仅当**修复导致了预期的视觉变化时更新基线：

// turbo
```bash
# 更新所有有差异的测试文件
python3 test/regression_test.py save

# 或只更新特定测试文件
python3 test/regression_test.py save test/regression_test/past_issue/tex/<test-file>.tex
```

**注意事项**：
- ✅ 只保存真正需要更新的基线图像
- ✅ 确认所有视觉变化都是预期且正确的
- ❌ 不要提交临时文件（diff/ 和 current/ 目录）
- ❌ 不要提交 PDF 文件（会自动生成）

**验证更新**：
```bash
# 再次运行 regression test，应该全部 PASSED
python3 test/regression_test.py check
```

## 9. 提交代码

### 9.1 检查变更

// turbo
```bash
git status
git diff
```

**预期应该看到**：
- ✅ 修改的源代码文件（.lua, .sty, .tex）
- ✅ 新增或更新的 baseline 图片（.png）
- ✅ 新增的测试文件（如果在 past_issue 中创建了新测试）
- ❌ **不应该有** PDF、辅助文件、diff/current 目录下的文件

### 9.2 暂存文件

只暂存需要提交的文件：
```bash
git add <modified-source-files>  # .lua, .sty 等
git add test/regression_test/basic/baseline/*.png         # 如果更新了 basic 基线
git add test/regression_test/past_issue/baseline/*.png    # 如果更新了 past_issue 基线
git add test/regression_test/past_issue/tex/<new-test>.tex  # 如果创建了新测试
```

**常见错误**（不要提交）：
- ❌ `test/regression_test/*/pdf/*.pdf` - PDF 文件（自动生成）
- ❌ `test/regression_test/*/diff/*.png` - 差异图（临时文件）
- ❌ `test/regression_test/*/current/*.png` - 当前输出（临时文件）
- ❌ `*.aux`, `*.log`, `*.out` - LaTeX 辅助文件
- ❌ 仓库外 /tmp/issue<N>-* 下的复现文件（仅用于本地测试）

### 9.3 编写提交信息

使用规范的提交信息格式。标题写 `fix(<模块>): <简短标题> (#<number>)`，正文写 `Refs #<number>`。

**不要在提交信息和 PR 描述里写 `Fixes / Closes / Resolves #N`（也不要写 `fix #N`）**：合并进 main 时 GitHub 会按这些关键词直接关闭 issue。本项目的约定是合并后 issue 保持打开、由 `.github/workflows/fix-ready-label.yml` 加 `fix-ready` 标签，等发版时发布说明里写 `fix #N` 再由同一 workflow 关闭。
```bash
git commit -m "fix(<模块>): <简短标题> (#<issue-number>)

<详细描述原问题是什么，为什么会出现>

Changes:
- <具体改动点1>
- <具体改动点2>

<如有必要，说明技术实现细节>

Refs #<issue-number>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
"
```

**提交信息要素**：
1. **标题**：`fix(<模块>): ... (#<number>)`；正文用 `Refs #<number>` 关联 issue（**不要**用 Fixes/Closes/fix #N，会在合并时关闭 issue）
2. **问题描述**：说明原来的问题及其原因
3. **Changes**：列出具体的代码改动
4. **技术细节**：如有必要，解释实现方案和考虑因素
5. **Co-Authored-By**：标注协作者

## 10. 最终验证

// turbo
提交后再次运行回归测试确保一切正常：
```bash
python3 test/regression_test.py check
```

**所有测试应该显示 PASSED**（基线已更新，不应再有差异）

## 11. 推送代码

```bash
# 推送到远程 dev 分支
git push origin dev
```

## 12. 在 Issue 中添加修复总结

推送成功后，在 issue 中添加修复总结 comment。

**流程**：
1. 先将 comment 内容展示给用户 review
2. 用户确认后，使用 `gh issue comment` 命令发布：

```bash
gh issue comment <issue-number> --repo open-guji/luatex-cn --body "$(cat <<'COMMENT'
✅ 修复已推送到 dev 分支。

## 问题总结
<简要说明问题是什么>

## 根本原因
<解释为什么会出现这个问题>

## 解决方案
<说明如何修复的>

## 测试验证
- ✓ unit tests 通过
- ✓ regression tests 通过
- ✓ 新增/更新测试: <test-file-name>

## 相关提交
- <commit-hash>: <commit-title>
COMMENT
)"
```

**重要**：
- **不要手动关闭 issue** — GitHub Actions 会自动标记为 fix ready，发布新版本时统一关闭
- **comment 内容必须先给用户 review** — 确认后再发布

## 最佳实践

1. **小步提交**：一次只修复一个问题，避免混杂多个改动
2. **充分测试**：确保回归测试全部通过，验证视觉效果
3. **详细文档**：提交信息要清晰完整，便于代码审查和后续维护
4. **保持沟通**：不确定时在 issue 中与维护者讨论方案
5. **代码审查**：推送前自己先仔细审查所有改动
6. **理解原理**：深入理解代码逻辑，避免临时性的 hack 方案
7. **考虑兼容性**：确保修复不会影响其他功能或破坏向后兼容性
