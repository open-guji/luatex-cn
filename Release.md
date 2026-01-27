[English Version](EN:Release) | 中文版

# 发布流程

`luatex-cn` 的发布遵循自动化流程，确保符合 CTAN (Comprehensive TeX Archive Network) 的要求。

## 开发工作流

本项目的构建与测试基于 `l3build`：

```bash
# 运行所有 Lua 单元测试
l3build test

# 安装到本地 TEXMFHOME
l3build install

# 打包发布文件（生成 .zip）
l3build bundle
```

## 自动化发布 (CI/CD)

通过 GitHub Actions 实现自动化打包：
1. **源码同步**：主分支（`main`）用于代码研发。
2. **打包过程**：
   - 提取 `src/`, `文档/` 和 `示例/` 文件夹。
   - 根据 `scripts/file_name_translation.json` 将文件夹和文件名转换为 CTAN 推荐的英文格式。
   - 自动生成符合规范的目录结构（doc, example, tex）。
3. **发布分支**：打包后的内容会被推送到 `ctan` 分支并发布到 GitHub Releases。

## 版本管理

- 版本号记录在根目录的 `VERSION` 文件中。
- 所有重大变更记录在 [[更新日志 | Changelog]]。
- 遵循语义化版本（SemVer）规范。

---

👉 下一步：查看 [[开发文档 | Development]]。
