[English Version](EN:Installation) | 中文版

# 安装指南

本页面手把手教你完成安装，包括 TeX 环境本身和 `luatex-cn` 宏包。

---

## 前提条件：安装 TeX Live

`luatex-cn` 运行在 **LuaTeX** 引擎上，需要安装 **TeX Live**（推荐 2024 或更新版本）。如果你已经安装了 TeX Live，可以跳过此节。

### Windows

1. 访问 [TeX Live 安装页面](https://tug.org/texlive/acquire-netinstall.html)，下载 `install-tl-windows.exe`
2. 运行安装程序，选择"完整安装"（Full scheme），或至少确保勾选了 `luatex`、`fontspec`、`luaotfload` 等包
3. 安装完成后，打开命令提示符（CMD），输入 `lualatex --version`，看到版本号即表示安装成功

### macOS

1. 下载 [MacTeX](https://tug.org/mactex/)（约 4GB，包含完整 TeX Live）
2. 双击 `.pkg` 文件安装
3. 打开终端，输入 `lualatex --version` 验证

### Linux

```bash
# Ubuntu / Debian
sudo apt install texlive-full

# Fedora
sudo dnf install texlive-scheme-full

# Arch Linux
sudo pacman -S texlive
```

安装后运行 `lualatex --version` 验证。

> **提示**：如果不想安装完整版，最小依赖包括：`texlive-base`、`texlive-luatex`、`texlive-latex-extra`、`texlive-fonts-recommended`、`texlive-lang-chinese`。但推荐使用完整安装以避免缺包问题。

---

## 安装 luatex-cn

### 方法 1：从 GitHub Release 安装（推荐）

1. **下载**：前往 [GitHub Releases](https://github.com/open-guji/luatex-cn/releases) 下载最新版本的 `luatex-cn-tex-v*.zip`

2. **定位 texmf 目录**：
   - **Windows**: `C:\Users\<你的用户名>\texmf`（如果不存在则手动创建）
   - **macOS/Linux**: `~/texmf`（如果不存在则运行 `mkdir -p ~/texmf`）

3. **放置文件**：将压缩包中 `tex/` 下的所有内容放入：
   ```
   texmf/tex/latex/luatex-cn/
   ```

4. **刷新 TeX 数据库**：
   ```bash
   texhash
   ```

### 方法 2：通过 CTAN 包管理器安装

```bash
# TeX Live (Windows/Linux)
tlmgr install luatex-cn

# MiKTeX
# 打开 MiKTeX Console → Packages → 搜索 luatex-cn → 安装
```

> **注意**：目前 CTAN 版本（v0.1.1）落后于 GitHub（v0.2.8），建议使用方法 1。

### 方法 3：直接放到项目目录

如果只是想快速试用，可以将 `tex/` 下的内容直接放到你的 `.tex` 文件所在的同一目录下，无需安装到 texmf。

---

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

编译（注意：必须使用 **`lualatex`**，不是 `pdflatex` 或 `xelatex`）：

```bash
lualatex test.tex
```

如果编译成功并生成 `test.pdf`，恭喜你安装完成！打开 PDF 应该能看到竖排的文字。

> 如果遇到 `File 'ltc-guji.cls' not found` 错误，说明 luatex-cn 没有正确安装，请检查文件路径和 `texhash` 是否已执行。

---

## 字体说明

`luatex-cn` 会**自动检测**你系统上已安装的中文字体。大多数情况下无需额外配置。

如果你希望获得更好的古籍效果，推荐安装：
- **思源宋体** (Noto Serif CJK SC / Source Han Serif) — 开源高质量宋体
- **楷体** (KaiTi) — 模拟手抄本效果
- **仿宋** (FangSong) — 模拟刻本效果

安装字体后，可在 `.tex` 文件中指定：
```latex
\设置字体{Noto Serif SC}
```

更多字体配置请参阅 [[字体设置 | Fonts]]。

---

## 下一步

安装完成后，前往 **[[快速入门 | Quick-Start]]** 学习基本命令和排版流程。
