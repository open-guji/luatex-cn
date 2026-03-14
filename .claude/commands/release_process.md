---
description: 发布新版本的工作流 (Workflow for releasing a new version)
---

# 发布新版本工作流

当准备好发布新版本（如 v0.2.0）时，请严格遵循以下质量检查和发布流程：

## 1. 质量保证 (Quality Assurance)
// turbo
- **运行回归测试**：确保视觉表现没有退化。
  `python3 test/regression_test.py check test/regression_test/tex/*.tex`
// turbo
- **运行核心测试**：运行所有单元测试和集成测试。
  `l3build check`

## 2. 版本准备 (Version Preparation)
- 确保 `VERSION` 文件已更新为目标版本号
- 确保 `README.md` 和 `README-EN.md` 中的版本号已更新
- 确保 `CHANGELOG.md` 已根据 `/update_changelog` 工作流完成总结
- 可使用 `/prepare-next-version` 技能自动更新上述文件

## 3. 文档更新 (Documentation Update)
- **更新 Wiki**：使用 `/update_wiki` 技能更新项目 Wiki（如有新功能文档）
- **生成 Wiki PDF**：
  `cd 文档 && python3 build_wiki_pdf.py`

  生成的 PDF 文件：
  - `luatex-cn-wiki-zh.pdf`（中文文档）
  - `luatex-cn-wiki-en.pdf`（英文文档）

## 4. 打包验证 (Package Validation) - 必须执行
// turbo
- **构建 CTAN 包**：
  `l3build ctan`

  **注意**：此命令会自动调用 `scripts/build/tag_version.lua`，该脚本会：
  - 读取 `VERSION` 文件中的版本号
  - 自动更新所有 `.sty` 和 `.cls` 文件中的版本号和日期
  - 无需手动同步版本号

- 检查生成的 `luatex-cn-ctan.zip` 是否包含所有必需文件。

## 5. Git 发布流程 (Git Release)

### 5.1 提交版本更新
```bash
# 在 dev 分支提交所有版本相关改动
git add -A
git commit -m "Release v0.2.0"
```

### 5.2 创建版本标签
```bash
git tag v0.2.0
```

### 5.3 同步所有分支 (Sync All Branches)
```bash
# 推送 dev 分支和标签到远程
git push origin dev --tags

# 切换到 main 分支并合并
git checkout main
git merge dev

# 如果有合并冲突（通常是 README 版本号）：
# 1. 手动编辑冲突文件，保留 dev 的版本号
# 2. git add <冲突文件>
# 3. git commit --no-edit

# 推送 main 分支到远程
git push origin main

# 切换回 dev 分支并同步 main 的更改
git checkout dev
git merge main

# 推送同步后的 dev 分支
git push origin dev
```

### 5.4 验证同步状态
```bash
# 确认所有分支已同步
git branch -vv
git log --oneline -3 main dev origin/main origin/dev
```

## 6. 完成 (Completion)
- GitHub Release 会由 GitHub Actions 自动创建，**不要手动创建 Release**
- 推送标签后，CI 会自动：
  - 基于标签创建 Release 页面
  - 附带 CHANGELOG 内容
  - 上传构建产物
- 确认 Actions 运行成功即可
