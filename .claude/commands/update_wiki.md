# 更新项目 Wiki

每次发布新版本后，需要同步更新 GitHub Wiki 文档。

## 核心原则（必须遵守）

**所有 Wiki 内容必须基于对项目代码的实际查看来编写，绝对不能凭字面理解自己编造。**

在编写任何功能文档之前，必须：
1. **先查看对应的 `.sty` 或 `.lua` 源代码文件**
2. **确认命令的真实语法**（`\NewDocumentCommand` 定义）
3. **确认参数的真实名称和默认值**（`\keys_define:nn` 定义）
4. **确认命令的别名**（`\NewCommandCopy` 定义）

常用代码位置：
- 装饰/改字/下划线：`tex/decorate/luatex-cn-decorate.sty`
- 古籍命令别名：`tex/guji/luatex-cn-guji.sty`
- 句读：`tex/guji/luatex-cn-guji-judou.sty`
- 夹注：`tex/guji/luatex-cn-guji-jiazhu.sty`
- 侧批：`tex/core/luatex-cn-core-sidenote.sty`
- 眉批：`tex/guji/luatex-cn-guji-meipi.sty`

## 1. 克隆 Wiki 仓库

```bash
cd /tmp && rm -rf luatex-cn.wiki
git clone https://github.com/open-guji/luatex-cn.wiki.git
```

## 2. 检查现有 wiki 内容

克隆后**先读取**以下文件，检查当前状态：
- `Changelog.md` 和 `EN:Changelog.md`：确认最新版本号，查看中英文是否同步（英文版可能落后）
- `Home.md` 和 `EN:Home.md`：确认当前版本号

> **注意**：英文 Changelog 有时会落后于中文版，需要补全缺失的版本条目后再添加新版本。

## 3. 需要更新的文件

根据发布内容，通常需要更新以下文件（中英文双语）：

| 文件 | 何时更新 |
|------|----------|
| `Changelog.md` / `EN:Changelog.md` | **每次发布必更新** - 添加版本条目 |
| `Home.md` / `EN:Home.md` | **每次发布必更新** - 更新版本号 |
| `Correction.md` / `EN:Correction.md` | 有新装饰/改字功能时 |
| `Annotation.md` / `EN:Annotation.md` | 有新注释功能时（夹注、批注） |
| `Side-Note.md` / `EN:Side-Note.md` | 有侧批/眉批功能更新时 |
| `Judou.md` / `EN:Judou.md` | 有句读功能更新时 |
| `Features.md` / `EN:Features.md` | 有重要新功能时 |
| `Debug.md` / `EN:Debug.md` | 有调试功能更新时 |

## 4. 更新流程

### 4.1 Changelog 更新格式

```markdown
## [x.y.z] - YYYY-MM-DD

- ✨ **新功能名称**：功能描述 (fix #xx)
- 🐛 **Bug 修复**：修复内容描述 (fix #xx)
- ♻️ **代码重构**：重构内容描述
```

图标约定：
- ✨ 新功能
- 🐛 Bug 修复
- ♻️ 重构
- 📖 文档
- ✅ 测试
- 📦 打包/发布

### 4.2 版本号更新

在 Home.md 中找到：
```markdown
> **当前版本**: [vX.Y.Z](https://github.com/open-guji/luatex-cn/releases)
```
更新为新版本号。

### 4.3 功能文档更新

对于新功能，添加：
- **使用方法** (Usage)：命令语法
- **参数说明** (Parameters)：可选参数表格
- **示例** (Example)：代码示例
- **技术细节** (Technical Details)：实现说明

## 5. 提交并推送

```bash
cd /tmp/luatex-cn.wiki
git add -A
git commit -m "docs: update wiki for vX.Y.Z release

- Add vX.Y.Z changelog entries (CN/EN)
- Update version to vX.Y.Z in Home pages
- [其他更新内容]

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

git push origin master
```

## 6. 验证

更新后在浏览器中访问 Wiki 确认：
- https://github.com/open-guji/luatex-cn/wiki

## 7. 清理

```bash
rm -rf /tmp/luatex-cn.wiki
```
