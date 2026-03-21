# LuaTeX-cn 项目文档 (Documentation)

本目录包含从 [GitHub Wiki](https://github.com/open-guji/luatex-cn/wiki) 自动生成的离线 PDF 文档。

## PDF 文档

| 文件 | 说明 |
|------|------|
| **luatex-cn-wiki-zh.pdf** | 中文完整文档（安装、入门、功能、调试、开发等） |
| **luatex-cn-wiki-en.pdf** | English documentation (install, quickstart, features, debug, dev, etc.) |

## 生成方式 (How PDFs Are Generated)

两份 PDF 由 `build_wiki_pdf.py` 脚本从 `luatex-cn.wiki` 仓库的 Markdown 文件自动合并生成。

### 依赖 (Requirements)

```bash
pip install markdown-it-py weasyprint
```

### 步骤 (Steps)

1. 确保 Wiki 仓库已克隆到与 `luatex-cn` 同级目录：

   ```
   workspace/
   ├── luatex-cn/          # 主仓库
   └── luatex-cn.wiki/     # Wiki 仓库 (git clone https://github.com/open-guji/luatex-cn.wiki.git)
   ```

2. 在项目根目录运行脚本：

   ```bash
   python3 文档/build_wiki_pdf.py
   ```

3. 生成的 PDF 会输出到当前目录（`文档/`）。

### 脚本工作原理

`build_wiki_pdf.py` 执行以下步骤：

1. 按照 Wiki 侧边栏 (`_Sidebar.md`) 的章节顺序读取 Markdown 文件
2. 将 Wiki 内部链接 (`[[显示文字 | 页面名]]`) 转换为 PDF 内锚点
3. 使用 `markdown-it-py` 渲染 Markdown 为 HTML
4. 使用 `weasyprint` 将 HTML 转换为带目录和分页的 PDF
5. 中文版和英文版分别处理，各生成一份独立 PDF
