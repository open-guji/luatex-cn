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
- **简洁性**：将同类改动合并，总量控制在 5-6 个条目以内。
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