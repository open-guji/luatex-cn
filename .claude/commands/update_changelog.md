---
description: 如何高效总结并更新项目的 CHANGELOG.md (How to update CHANGELOG.md)
---

# 更新 CHANGELOG.md 工作流

本工作流旨在指导如何快速总结项目阶段性改动并录入 `CHANGELOG.md`。

## 1. 提取改动记录 (Extract Changes)
- 运行命令：`git log v[上一个tag]..HEAD --oneline` (例如 `git log v0.1.4..HEAD --oneline`)。
- **必须执行**：`git log v[上一个tag]..HEAD --oneline | grep -i "fix #"` 单独列出所有 fix 提交。
- 重点关注以下内容：
  - 带有 `fix #xxx` 标记的提交（关联 Issue 修复）。
  - 带有 `feat`, `added`, `refactor` 等功能性描述。

## 2. 编写更新条目 (Write Entries)
- **CRITICAL - Issue 完整性**：必须列出所有带 `fix #xxx` 的提交，绝对不可遗漏任何已关闭的 Issue。在编写完成后，对照 grep 结果逐一核对，确保每个 fix #xxx 都有对应条目。
- **简洁性**：将同类改动合并，总量控制在 5-6 个条目以内。
- **纯文本**：不要使用粗体（着重号），确保列表整洁。
- **关联 Issue**：在条目末尾使用 `(fix #xxx)` 标注对应的 Issue 编号。

## 3. 更新文件内容
- 在 `CHANGELOG.md` 顶部插入新版本号和日期，格式为：`## [版本号] - YYYY-MM-DD`。
- 将总结好的条目以无序列表形式填入其下方。

## 4. 验证完整性 (Verification) - 必须执行
更新完成后，**必须**执行以下验证：
```bash
# 列出所有 fix 提交
git log v[上一个tag]..HEAD --oneline | grep -i "fix #"

# 检查 CHANGELOG 中是否包含所有 fix
grep "fix #" CHANGELOG.md | head -20
```
逐一对比两个输出，确保每个 `fix #xx` 都有对应条目。如有遗漏，立即补充。