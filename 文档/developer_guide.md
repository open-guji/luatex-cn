# LuaTeX-CN 开发者指南

本文档旨在为参与 `luatex-cn` 开发的成员提供技术指南。

## 本地测试与开发

在开发过程中，为了能够立即看到源码修改的效果，而不必反复重新安装宏包，建议使用 `scripts/link_texmf.lua` 脚本。

### 软链接（Junction）管理

该脚本可以自动在你的 `TEXMFHOME` 目录下创建一个指向本项目 `src` 目录的软链接（在 Windows 上为 Junction）。

#### 开启本地测试链接

运行以下命令，将 `TEXMFHOME/tex/latex/luatex-cn` 指向本仓库的 `src` 目录：

```bash
texlua scripts/link_texmf.lua --on
```

开启后，所有对 `src` 目录的修改都会在下一次 `lualatex` 编译时立即生效。

#### 关闭本地测试链接

如果你希望恢复到正式安装的版本，或者清理开发环境，请运行：

```bash
texlua scripts/link_texmf.lua --off
```

### 脚本说明

- `scripts/link_texmf.lua`: 跨平台脚本（支持 Windows/macOS/Linux），自动检测 `TEXMFHOME` 路径并管理链接。
- `scripts/tag_version.lua`: 用于版本标记的工具。
- `scripts/build_ctan_windows.py`: 用于构建 CTAN 发布包的脚本。

## 目录结构

- `src/`: 核心源代码（Lua 与 TeX）。
- `scripts/`: 开发辅助脚本。
- `test/`: 单元测试。
- `文档/`: 用户及开发者文档。
- `示例/`: 各类排版示例。
