[English Version](EN:Installation) | 中文版

# 安装指南

本页面介绍如何安装 `luatex-cn` 宏包。

## 方法 1：通过 CTAN/包管理器安装（推荐）

使用 TeX 发行版自带的包管理器进行安装：

```bash
# TeX Live (Windows/Linux)
tlmgr install luatex-cn

# MiKTeX
# 打开 MiKTeX Console → Packages → 搜索 luatex-cn
```

> ⚠️ **注意**：目前 CTAN 版本落后于 GitHub，建议使用 GitHub Release。

## 方法 2：从 GitHub Release 手动安装

1. **下载**: 前往 [GitHub Releases](https://github.com/open-guji/luatex-cn/releases) 下载最新版本的 `luatex-cn-tex-v*.zip`

2. **定位 texmf 目录**:
   - **Windows**: `C:\Users\<用户名>\texmf`
   - **macOS/Linux**: `~/texmf`

3. **放置文件**: 将 `tex/` 下的内容放入：
   ```
   texmf/tex/latex/luatex-cn/
   ```

4. **刷新数据库**:
   ```bash
   texhash
   ```

## 方法 3：直接使用

将 `tex/` 下的内容放到你的 `.tex` 文件同一目录即可直接编译。

## 验证安装

创建测试文件 `test.tex`：

```latex
\documentclass[四库全书]{ltc-guji}
\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。
\end{正文}
\end{document}
```

运行：
```bash
lualatex test.tex
```

如果编译成功则安装完成。

## 系统要求

- LuaTeX (推荐 TeX Live 2024+)
- `luaotfload` 和 `fontspec`

## 字体要求

建议安装以下字体以获得最佳效果：
- 思源宋体 (Noto Serif CJK SC)
- 仿宋或楷体（用于模拟古籍效果）
