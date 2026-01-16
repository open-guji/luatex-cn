# LuaTeX-CN

**版本: 0.1.0** | [CTAN](https://ctan.org/pkg/luatex-cn) | [GitHub](https://github.com/open-guji/luatex-cn) | [English](README-EN.md)

致力于基于 LuaTeX 引擎实现最纯粹、最高质量的中文古籍排版支持，完整覆盖竖排核心逻辑、版心装饰及夹注处理。长期愿景希望完整支持中文排版。

## 功能特性

- **竖排排版（竖排）**：经典竖排布局的强大核心引擎
- **古籍版式（古籍版式）**：完整支持"版心"、"鱼尾"和边框
- **夹注（夹注）**：双栏小注的自动平衡和分段
- **基于网格的定位**：通过 Lua 计算布局精确控制字符位置
- **现代架构**：基于 `expl3` 和 Lua 代码分离，以实现最大可维护性

## 安装

详细安装说明请参阅 [INSTALL.md](INSTALL.md)。

快速安装：
```bash
make install
```

## 使用方法

推荐通过 `guji` 文档类使用本宏包：

```latex
\documentclass{guji}

% 配置版式和字体
\gujiSetup{
  font-size = 12pt,
  line-limit = 20,
  page-columns = 10,
  banxin = true,
  book-name = {史記}
}

\begin{document}
\chapter{五帝本紀第一}
這是竖排的中文文本示例，包含夹注\jiazhu{双行小注}的功能演示。
\end{document}
```

## 系统要求

- LuaTeX (推荐 TeX Live 2024+)
- `luaotfload` 和 `fontspec`
- 高质量中文字体（例如 Noto Serif CJK、思源宋体或专门的楷体字体）

## 文档

示例用法请参见 `example.tex`。

## 许可证

Apache License 2.0
