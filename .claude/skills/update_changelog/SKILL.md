---
name: update_changelog
description: 如何高效总结并更新项目的 CHANGELOG.md (How to update CHANGELOG.md)
---

# 更新 CHANGELOG.md 工作流

本工作流旨在指导如何快速总结项目阶段性改动并录入 `CHANGELOG.md`。

## 1. 提取改动记录 (Extract Changes)
- 运行命令：`git log v[上一个tag]..HEAD --oneline` (例如 `git log v0.1.4..HEAD --oneline`)。
- **必须执行**：列出所有带 `fix-ready` 标签的 open issue —— 这些是已合并、待发版的修复：
  `gh issue list --label fix-ready --state open`
  （PR 合并时 issue 不会被关闭，而是由 `.github/workflows/fix-ready-label.yml` 加上 `fix-ready` 标签。）
- 重点关注以下内容：
  - 带 `fix-ready` 标签的 issue，以及标题/正文带 `(#xxx)`、`Refs #xxx` 的提交。
  - 带有 `feat`, `added`, `refactor` 等功能性描述。

## 2. 编写更新条目 (Write Entries)
- **CRITICAL - Issue 完整性**：每个 `fix-ready` issue 都必须在 CHANGELOG 里有一条 `(fix #xxx)`，绝对不可遗漏。发版时 Release 说明取自 CHANGELOG，Release 发布后 workflow 会关闭说明里 `fix #xxx` 提到的 issue 并去掉 `fix-ready` 标签；漏写的 issue 会一直挂着。
- **只写做了什么，不写怎么做**：CHANGELOG 的版本段会原样成为 GitHub Release 说明，读者是使用者，不是开发者。每条一行，说清「新增了什么功能／修好了什么现象」即可：
  - 新增：功能名 + 最常用的写法（一个命令或一个 key），不列全部取值、默认值、可调参数、适用范围与例外。
  - 修复：用户看到的现象（「夹注换列后超出版框」），不写原因与修法（「后续列可用高度没扣段落缩进」「改为行内实现」）。
  - 不写：实现方式、内部文件路径、测试文件名、「此前……」的来龙去脉、引入版本。这些留在 PR 与 issue 里。
  - 维护类（重构、CI、测试）合成一条，一句话带过。
  - 反例：「书耳：`\banxinSetup{书耳=true}` 在版框左上角外侧画一个小框，竖排写本页篇名（随 `\chapter` 变化），也可 `书耳=<文字>` 指定；`位置 = 左（默认）| 右 | 两侧`，筒子页拆分后默认只落在左半叶……」
  - 正例：「书耳：`\banxinSetup{书耳=true}` 在版框外上角显示本页篇名 (fix #87)」
- **简洁性**：将同类改动合并；每条一行，写不进一行就是写了「怎么做」。
- **纯文本**：不要使用粗体（着重号），确保列表整洁。
- **关联 Issue**：在条目末尾使用 `(fix #xxx)` 标注对应的 Issue 编号。

## 3. 更新文件内容
- 在 `CHANGELOG.md` 顶部插入新版本号和日期，格式为：`## [版本号] - YYYY-MM-DD`。
- 将总结好的条目以无序列表形式填入其下方。

## 4. 验证完整性 (Verification) - 必须执行
更新完成后，**必须**执行以下验证：
```bash
# 列出所有待发版的修复
gh issue list --label fix-ready --state open

# 检查 CHANGELOG 中是否包含所有 fix
grep "fix #" CHANGELOG.md | head -20
```
逐一对比两个输出，确保每个 `fix-ready` issue 都有对应的 `fix #xx` 条目。如有遗漏，立即补充。