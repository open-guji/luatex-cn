# 安装指南 (Installation Guide)

本项目推荐通过以下两种方式安装 `luatex-cn` 宏包。

## 方法 1：通过 CTAN/包管理器安装（推荐）

`luatex-cn` **即将** 发布至 CTAN，你可以直接使用 TeX 发行版自带的包管理器进行安装：

- **TeX Live (Windows/Linux)**: 打开终端并运行 `tlmgr install luatex-cn`。
- **MacTeX (macOS)**: 使用 **TeX Live Utility** 搜索并安装 `luatex-cn`。
- **MiKTeX**: 打开 **MiKTeX Console**，进入 "Packages" 界面，搜索并点击安装 `luatex-cn`。

使用此方法安装后，所有相关依赖会自动配妥，无需手动移动文件。

---

## 方法 2：从 GitHub Release 手动安装

如果你无法访问 CTAN 或需要安装特定版本，可以按以下步骤操作：

1. **下载**: 前往 [GitHub Releases](https://github.com/open-guji/luatex-cn/releases) 页面，下载最新版本的 `luatex-cn-src-v*.zip`。
2. **定位 texmf 目录**:
   - **Windows**: 通常位于 `C:\Users\<用户名>\texmf`。
   - **macOS/Linux**: 通常位于 `~/texmf`。
   - *（如果没有该目录，请手动创建一个）*
3. **放置文件**: 将下载的压缩包解压，将其中的所有文件放入以下路径（建议创建子文件夹）：
   `texmf/tex/latex/luatex-cn/`
4. **刷新数据库**:
   打开终端并运行以下命令以确保 TeX 能够识别新包：
   ```bash
   texhash
   ```

---

## 高阶：使用 l3build 安装

如果你已经克隆了整个项目源码，可以使用 `l3build` 进行安装：

```bash
l3build install
```
该命令会自动将 `src/` 中的文件安装到你的本地 `TEXMFHOME` 目录下。

## 验证安装

创建一个简单的 `.tex` 文件并运行以下命令：
```bash
lualatex test.tex
```
如果编译成功且没有提示找不到 `luatex-cn.sty`，则安装成功。

## 字体要求

本项目依赖中文字体进行渲染。建议安装以下字体以获得最佳效果：
- 思源宋体 (Source Han Serif / Noto Serif CJK SC)
- 仿宋或楷体（用于模拟古籍效果）