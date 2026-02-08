# LuaTeX-CN

[English Version](README-EN.md)

致力于基于 LuaTeX 引擎实现最纯粹、最高质量的中文排版支持.长期愿景希望完整支持中文排版，包括横排/竖排，古籍/现代版式。目前主要实现古籍复刻，已完整覆盖竖排核心逻辑、版心装饰及夹注处理。

LuaTeX package for Chinese charactor typesetting, covering horizontal/vertical, traditional/modern layout. Currently focus on Ancient Book replication. Implemented core logic of vertical typesetting, decorative elements of traditional Chinese books, and interlinear notes.

CTAN: [v0.1.1](https://ctan.org/pkg/luatex-cn) | GitHub Release: [v0.2.6](https://github.com/open-guji/luatex-cn/releases)

📢 **通知**：维基（Wiki）页面已同步更新详细用户手册，请 [查看](https://github.com/open-guji/luatex-cn/wiki)。


## 路线图
- 已实现：古籍竖排，版心，夹注，侧批，印章，句读，改字等等。
- v0.2.0：进一步重构代码结构。
- v0.2.x: 完整排版红楼梦第一回、史记五帝本纪。实现现代繁体竖排，支持标点符号。完成详细用户文档、开发文档。

## 展示

### 1. 《史记·五帝本纪》 (四库全书排版)
演示了复杂的加注、单鱼尾版心以及馆藏印章的绝对定位。

| 黑白仿真 | 彩色预览 |
| :---: | :---: |
| ![史记黑白](示例/首页展示/shiji-bw.png) | ![史记彩色](示例/首页展示/shiji-color.png) |

> [查看源码](示例/史记五帝本纪/史记.tex) | [查看 PDF](示例/史记五帝本纪/史记.pdf)

### 2. 《红楼梦》（甲戌本排版） 
演示了侧批、眉批、标点、手抄本版式。

| 第二页（标点） | 第一页（眉批） |
| :---: | :---: |
| ![红楼梦2](示例/首页展示/honglou-p2.png) | ![红楼梦1](示例/首页展示/honglou-p1.png) |

> [查看源码](示例/红楼梦甲戌本/石头记.tex) | [查看 PDF](示例/红楼梦甲戌本/石头记.pdf)

## 功能特性

- **竖排排版**：经典竖排布局的强大核心引擎
- **古籍版式**：完整支持"版心"、"鱼尾"和边框
- **夹注**：双栏小注的自动平衡和分列
- **侧批**：两列中间小字批注，自动换列
- **批注**：支持在页面任意位置浮动定位的批注框
- **基于网格的定位**：通过 Lua 计算布局精确控制字符位置，无限扩展性

## 安装

详细安装说明请参阅 [INSTALL.md](INSTALL.md)。

快速安装：
1. 已经发布至CTAN/TeXLive，你可以直接使用 TeX 发行版自带的包管理器进行安装：
    - 注意：目前CTAN版本落后于GitHub，建议使用GitHub Release。
```
tlmgr install luatex-cn
```
2. 从 [GitHub Release](https://github.com/open-guji/luatex-cn/releases) 下载最新版本的 `luatex-cn-tex-v*.zip`。将解压后`tex/`下的内容移动到 `texmf/tex/latex/luatex-cn/`，运行 `texhash`。
3. 下载最新版本，将解压后`tex/`下的内容移动到自己正在编写的.tex文件夹中，直接编译。

## 使用方法

通过 `ltc-guji` 文档类使用本宏包。绝大多数命令都支持中文：

```latex
\documentclass[四库全书]{ltc-guji}
% 如果不指定字体，会使用系统默认中文字体
% \setmainfont{Noto Serif SC}
% \禁用分页裁剪

\title{钦定四库全书}
\chapter{史记\\卷一}

\begin{document}
\begin{正文}

這是古籍竖排的示例，包含夹注\夹注{长夹注自动换列，并且自动平衡，右列可能多一个字}的功能演示。\\ % 强制换列
空格需手动声明\空格[2] 可加入参数。

段落展示：
\begin{段落}[indent=2]
    天地玄黄\\
    宇宙洪荒
\end{段落}

侧批\侧批[yoffset=10pt]{较长的侧批可换列甚至换页}可在任意位置插入，可调整位置。

版心展示书名、章节名、页码。鱼尾可设置。

\批注[x=5cm, y=2cm, height=6, color={1 0 0}]{可在任意位置书写多列批注}

% 印章：绝对定位添加背景图
% \印章[page=1, xshift=2cm, yshift=5cm]{seal.png}
\end{正文}
\end{document}
```

## 系统要求

- LuaTeX (推荐 TeX Live 2024+)
- `luaotfload` 和 `fontspec`
- 选择非系统自带的中文字体需安装（例如 Noto Serif SC、 TW-Kai）

## 文档

[用户文档](文档/README.md) | [示例用法](示例/README.md)

联系人(contract): Sheldon Li

邮件（Email）: sheldonli.dev@gmail.com

## 开发与测试

如果你正在参与开发或希望在本地测试源码更改，请参考 [开发者指南](文档/developer_guide.md)。

## 许可证

Apache License 2.0
