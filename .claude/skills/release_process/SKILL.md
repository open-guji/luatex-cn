---
name: release_process
description: 发布新版本的工作流 (Workflow for releasing a new version)
---

# 发布新版本工作流

当准备好发布新版本（如 v0.4.0）时，请严格遵循以下质量检查和发布流程。

**核心时序**：CTAN 包会内嵌 `文档/luatex-cn-wiki-{zh,en}.pdf`，而 CI 在 push tag
时立即打包。因此 Wiki 更新与 Wiki PDF 再生成**必须发生在打 tag 之前**，且 PDF
要并入发布准备 PR 一起合并——否则 Release 会带上旧版 Wiki PDF（race）。

整体顺序：

1. 质量保证 → 2. 生成发布准备 PR → 3. 更新 Wiki（按 PR 已合并的状态编写）
→ 4. 基于 Wiki 生成 PDF 并加入同一 PR → 5. 合并 PR → 6. 打 tag，CI 自动发布

## 1. 质量保证 (Quality Assurance)
// turbo
- **运行回归测试**：确保视觉表现没有退化。必须使用 `--all` 参数运行所有 suite。
  `python3 test/regression_test.py check --all`
// turbo
- **运行核心测试**：运行所有单元测试和集成测试。
  `l3build check`

## 2. 生成发布准备 PR (Release-Prep PR)

- 确保 `VERSION` 文件已更新为目标版本号
- 运行 `texlua scripts/build/tag_version.lua` 同步所有 `.sty` / `.cls` 的版本号与日期
- 确保 `README.md` 和 `README-EN.md` 中的版本号已更新
- 确保 `CHANGELOG.md` 已根据 `/update_changelog` 工作流完成总结，
  并把 `[未发布]` 定版为 `[X.Y.Z] - YYYY-MM-DD`
- 可使用 `/prepare-next-version` 技能自动更新上述文件
// turbo
- **打包验证（必须执行）**：`texlua build.lua ctan`
  检查生成的 `luatex-cn-v<version>.zip`（即上传 CTAN 的文件，CI 也用同一份）：
  - 解包后顶层是唯一目录 `luatex-cn/`，其下为 `README.md` + `tex/` + `doc/`
    （CTAN 硬性要求：README.md 必须在顶层，不能只放在 `doc/` 下）
  - 包含所有必需文件、无中文文件名残留
    （新增示例需在 `build.lua` 的 `translation_map` 补映射）
- 从 main 切出 `release/vX.Y.Z` 分支，提交以上改动，push 并创建发布准备 PR。
  **此时先不要合并**——等 Wiki PDF（第 4 步）加入后一起合并

## 3. 更新 Wiki (Wiki Update)

- 使用 `/update_wiki` 技能更新项目 Wiki（Wiki 是独立的 `.wiki.git` 仓库，
  可直接推送，不经 PR）
- **以发布准备 PR 已合并后的状态为准**编写内容：新版本号、CHANGELOG 条目、
  新功能文档都按 PR 中的定稿写，不要写「未发布」字样

## 4. 生成 Wiki PDF 并加入 PR (Wiki PDF into the PR)

- 在发布准备分支上生成：
  `python3 文档/build_wiki_pdf.py`

  生成的文件（连同 `文档/wiki-pdf-stamp.json` 一并提交）：
  - `文档/luatex-cn-wiki-zh.pdf`（中文文档）
  - `文档/luatex-cn-wiki-en.pdf`（英文文档）
- 提交到发布准备分支并 push，使 PDF 进入**同一个发布准备 PR**
- 本地缺 weasyprint 等依赖时，可在 Actions 页手动触发 `wiki-pdf.yml`
  workflow，把它产出的 PDF 更新合入发布准备分支（不要单独合入 main）

> 平时（非发布期）Wiki 有零散修订时，才用 `wiki-pdf.yml` 的独立 PR 路径。

## 5. 合并发布准备 PR (Merge)

- 确认 PR 上的 CI（unit + regression）全绿后合并到 main

## 6. 打标签并由 CI 发布 (Tag & CI Release)

```bash
git checkout main
git pull origin main
git tag vX.Y.Z
git push origin vX.Y.Z
```

- GitHub Release 会由 GitHub Actions（`build.yml`，tag 触发）自动创建，
  **不要手动创建 Release**。CI 会：
  - 构建 CTAN 包（此时已含新 Wiki PDF）并推送 ctan 分支
  - 基于标签创建 Release 页面、附带 CHANGELOG 内容、上传构建产物
- **CI 建的是草稿（draft）Release**，不会自动发布。草稿没有正常的 tag 链接
  （地址是 `releases/tag/untagged-…`，每次编辑都会变），只在
  https://github.com/open-guji/luatex-cn/releases 顶部对有写权限的人可见。
  确认 Actions 成功后，把草稿位置告诉用户：
  `gh release view vX.Y.Z --json isDraft,url,body`
- 核对草稿说明是否简洁（只写做了什么，见 `/update_changelog`）。需要改时用
  `gh release edit vX.Y.Z --notes-file <file>` 只改说明，不动 draft 状态、tag 与附件；
  同时把 `CHANGELOG.md` 与 Wiki Changelog 改成同样的文字，否则重新生成时会回到旧版
- 发布（Publish）会公开 Release，并触发关闭 `fix #xxx` 提到的 issue，
  由用户确认后再点，不要自行发布

## 7. 发布后 (Post-release)

- 若仓库仍维护 dev 分支，把 main 同步回 dev：
  `git checkout dev && git merge main && git push origin dev`
- 可用 `/prepare-next-version` 开启下一个补丁版本的 `[未发布]` 段
