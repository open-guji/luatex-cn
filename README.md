# LuaTeX-CN

[English Version](README-EN.md)

**Version: 0.1.0** | [CTAN](https://ctan.org/pkg/luatex-cn) | [GitHub](https://github.com/open-guji/luatex-cn)

致力于基于 LuaTeX 引擎实现最纯粹、最高质量的中文古籍排版支持，完整覆盖竖排核心逻辑、版心装饰及夹注处理。长期愿景希望完整支持中文排版。

LuaTeX package for sophisticated traditional Chinese vertical typesetting and ancient book layout, with long-term vision to support full Chinese typography.

Dedicated to implementing the purest, highest quality Chinese ancient book typesetting support based on the LuaTeX engine, fully covering vertical typesetting core logic, central column decoration, and interlinear notes processing.

## 功能特性

- **竖排排版（竖排）**：经典竖排布局的强大核心引擎
- **古籍版式（古籍版式）**：完整支持"版心"、"鱼尾"和边框
- **夹注（夹注）**：双栏小注的自动平衡和分段
- **基于网格的定位**：通过 Lua 计算布局精确控制字符位置，无限扩展性

## 安装

详细安装说明请参阅 [INSTALL.md](INSTALL.md)。

快速安装：
```bash
l3build install
```

## 使用方法

推荐通过 `ltc-guji` 文档类使用本宏包：

```latex
\documentclass[四库全书]{ltc-guji}

\begin{document}
\begin{正文}
\chapter{五帝本紀第一}
這是竖排的中文文本示例，包含夹注\夹注{双行小注}的功能演示。

\begin{列表}
    \item 史部
    \item 卷一
\end{列表}

\印章[page=1]{seal.png}
\end{正文}
\end{document}
```

## 系统要求

- LuaTeX (推荐 TeX Live 2024+)
- `luaotfload` 和 `fontspec`
- 选择非系统自带的中文字体需安装（例如 Noto Serif CJK、思源宋体或专门的楷体字体）

## 文档

示例用法请参见 `example.tex`。

联系人(contract): Sheldon Li
邮件（Email）: sheldonli.dev@gmail.com

## 许可证

Apache License 2.0
