---
description: 准备下一个补丁版本 (Prepare next patch version release)
---

# 准备下一个版本发布工作流

本工作流用于智能地基于最后一个 git tag 推断下一个版本号，并更新所有相关文件。

## 工作流

### 1. 从上一个 tag 推断版本升级类型

```bash
# 获取最后一个 tag（格式 vX.Y.Z）
git tag -l | grep "^v" | sort -V | tail -1

# 例如：v0.2.9
```

推断规则：
- 如果 CHANGELOG 中有新版本（大于 tag 版本），则检查升级类型
- **Major 升级**（0.2.9 → 0.3.0）：CHANGELOG 中出现新的 minor 版本号
- **Minor 升级**（0.2.8 → 0.2.9）：CHANGELOG 中只有 patch 升级
- 默认：计算补丁版本（X.Y.Z → X.Y.(Z+1)）

### 2. 检查 VERSION 和 CHANGELOG 状态

```bash
# 查看 VERSION 文件内容
cat VERSION

# 查看 CHANGELOG 第一个版本号
head -10 CHANGELOG.md
```

**三种情况**：

| 情况 | VERSION | CHANGELOG | 操作 |
|------|---------|-----------|------|
| A | 已更新为 0.3.0 | 已更新为 0.3.0 | 无需改动，直接更新 README |
| B | 还是 0.2.9 | 还是 0.2.9 | 执行 update_changelog，然后更新 VERSION |
| C | 0.2.9 | 0.3.0 | 异常，询问用户 |

### 3. 如果 VERSION/CHANGELOG 未更新（情况B）

#### 3a. 执行 update_changelog skill
```bash
# 这会：
# - 从 git log 提取改动
# - 自动生成 CHANGELOG 条目
# - 插入新版本号和日期
```

#### 3b. 根据 CHANGELOG 更新 VERSION
```bash
# 读取 CHANGELOG 中的第一个版本号（跳过占位符）
# 更新 VERSION 文件为该版本号

# 例如：如果 CHANGELOG 中是 [0.3.0]
# 则 VERSION = 0.3.0
```

### 4. 更新 README 和 README-EN

确保 GitHub Release 链接指向当前版本：

```markdown
GitHub Release: [v0.3.0](https://github.com/open-guji/luatex-cn/releases)
```

### 5. 为下一个版本创建占位符

在 CHANGELOG 顶部插入新占位符：

```markdown
## [X.Y.(Z+1)] - 待定
- （待填写）
```

### 6. 验证更改

```bash
git diff VERSION README.md README-EN.md CHANGELOG.md
```

## 后续步骤

完成版本准备后，继续使用 `/release_process` 技能进行完整发布流程：
1. 运行单元测试：`texlua test/run_all.lua`
2. 运行回归测试：`python3 test/regression_test.py check`
3. **运行 l3build ctan**：`l3build ctan` （会自动更新所有 .sty 文件的版本号）
4. 提交、打标签、推送
