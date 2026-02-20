# 脚注系统文档 / Footnote System Documentation

## 概述 / Overview

`luatex-cn-guji-footnote` 模块提供古籍排版中的脚注/校勘记功能，支持两种模式：

| Mode | 中文名 | 描述 |
|------|--------|------|
| `endnote` | 段末注 | 脚注内容输出在段落末尾 |
| `page` | 页下注 | 脚注内容渲染在页面左侧，带有分隔线 |

## 基本用法 / Basic Usage

### Mode 1: 段末注 (Endnote)

```latex
\documentclass{ltc-guji}
\begin{document}
\begin{正文}
天地玄黃\脚注{「玄」本作「元」，避清聖祖諱改。}。
\输出脚注  % 在此处输出所有脚注
\end{正文}
\end{document}
```

### Mode 2: 页下注 (Page Footnote)

```latex
\documentclass{ltc-guji}
\脚注设置{mode=page}
\begin{document}
\begin{正文}
天地玄黃\脚注{校勘内容}。
% 脚注自动在页面左侧渲染，无需手动输出
\end{正文}
\end{document}
```

## 配置选项 / Configuration

```latex
\脚注设置{
  mode = endnote,        % endnote | page
  number-style = lujiao, % lujiao (〔一〕) | circled (①)
  separator = blank,     % blank | none
  font-size = 0.8em,     % 脚注内容字号
  font-color = {},       % 脚注颜色 (RGB 三元组)
  font = {},             % 自定义字体
}
```

## 与其他注释功能的交互 / Interactions

### 脚注 vs 夹注 (Jiazhu)

| 特性 | 脚注 `\脚注{}` | 夹注 `\夹注{}` |
|------|---------------|---------------|
| 位置 | 段末或页左 | 正文行内 |
| 字号 | 默认 0.8em | 默认主字号的一半 |
| 用途 | 校勘、注释 | 音注、简短解释 |

**建议**：短的音注使用夹注，长的校勘说明使用脚注。

### 脚注 vs 批注 (Pizhu)

| 特性 | 脚注 `\脚注{}` | 批注 `\批注{}` |
|------|---------------|---------------|
| 位置 | 正文左侧列 | 指定位置的浮动框 |
| 编号 | 自动编号 | 无编号 |
| 用途 | 校勘记 | 眉批、旁批 |

**建议**：编号校勘用脚注，非编号评论用批注。

## 跨页处理 / Cross-Page Handling

Mode 2 (页下注) 支持自动跨页：
- 当脚注内容超出页面行数限制时，自动延续到下一页
- 延续的脚注排在下一页脚注区域的最前面

## 技术说明 / Technical Notes

- Mode 1 使用纯 TeX (expl3) 实现
- Mode 2 使用 WHATSIT 锚点 + Lua 插件渲染
- 脚注编号可选 `lujiao` (六角括号) 或 `circled` (圈码) 样式
