[English Version](EN:Release) | 中文版

# 发布流程

`luatex-cn` 的发布遵循自动化流程，确保符合 CTAN (Comprehensive TeX Archive Network) 的要求。

## 开发工作流

### 测试

```bash
# 1. 运行单元测试（必须先通过）
texlua test/run_all.lua

# 2. 运行回归测试
python3 test/regression_test.py check

# 测试单个回归文件
python3 test/regression_test.py check test/regression_test/basic/tex/shiji.tex

# 更新基线（确认改动正确后）
python3 test/regression_test.py save test/regression_test/basic/tex/shiji.tex
```

### 本地安装

源码目录 `tex/` 可通过 symlink 链接到本地 texmf 目录进行开发测试：

```bash
# macOS/Linux
ln -s $(pwd)/tex ~/texmf/tex/latex/luatex-cn
texhash
```

## 自动化发布 (CI/CD)

通过 GitHub Actions 实现自动化打包：
1. **源码同步**：主分支（`main`）用于稳定代码，`dev` 分支用于日常研发。
2. **打包过程**：
   - 提取 `tex/`、`文档/` 和 `示例/` 文件夹。
   - 根据 `scripts/file_name_translation.json` 将文件夹和文件名转换为 CTAN 推荐的英文格式。
   - 自动生成符合规范的目录结构（doc, example, tex）。
3. **发布分支**：打包后的内容会被推送到 `ctan` 分支并发布到 GitHub Releases。
4. **Gitee 镜像**：通过 GitHub Actions 自动同步主仓库和 Wiki 到 Gitee。

## 版本管理

- 版本号记录在根目录的 `VERSION` 文件中。
- 所有重大变更记录在 [[更新日志 | Changelog]]。
- 遵循语义化版本（SemVer）规范。

## 发布检查清单

1. 确保 `dev` 分支上所有单元测试和回归测试通过
2. 更新 `VERSION` 文件
3. 更新 [[更新日志 | Changelog]]
4. 将 `dev` 合并到 `main`
5. 创建 Git tag：`git tag v0.x.x`
6. Push tag 触发 CI 自动打包发布

---

👉 下一步：查看 [[开发文档 | Development]]。
