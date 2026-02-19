[English Version](EN:Fonts) | 中文版

# 字体设置 (Fonts)

`luatex-cn` 提供了智能的跨平台字体探测机制，以及强大的多字体递补（Fallback）功能，确保生僻字和缺字情况能够被优雅处理。

## 1. 自动字体探测

在默认情况下，使用 `guji`（或 `cn-vbook` / `tw-vbook`）文档类会自动根据操作系统选择最合适的已安装字体：

- **Windows**: 优先使用中易宋体 (SimSun)、中易黑体 (SimHei) 等。
- **macOS**: 优先使用宋体-简 (Songti SC)、苹方-简 (PingFang SC) 等。
- **Linux**: 优先使用 Fandol 系列或 Noto CJK 系列。

如果需要手动触发自动探测并应用：
```latex
\ApplyAutoFont
```

### 中文字体名称支持（v0.2.2+）

v0.2.2 起，字体探测支持使用简体或繁体中文字体名称：

```latex
\设置字体{宋体}          % 简体中文名称
\设置字体{標楷體}        % 繁体中文名称
\设置字体{思源宋体}      % 开源字体中文名
```

系统会自动将中文字体名称映射到对应的系统字体。

## 2. 标准字体设置

如果你只需要设置单一字体，可以使用标准命令或别名：

```latex    
\设置字体{KaiTi}
% 等同于 \setmainfont{KaiTi}
```

## 3. 设置字体族 (Font Family & Fallback)

v0.1.5 新增了**字体族**（Font Family）的概念。通过设置字体族，系统会建立一个“字体递补链”。当主字体缺少某个字符（如生僻字）时，会自动到链中的下一个字体里查找。

### `\设置字体族`

该命令接受一个字体列表（逗号分隔）。列表中的第一个字体将被设为主字体，其余字体作为后备。

```latex
% 将 "Source Han Serif SC" 设为主字体
% 如果缺字，则尝试 "SimSun"，再缺字尝试 "SimHei"
\设置字体族{Source Han Serif SC, SimSun, SimHei}
```

英名别名：
```latex
\setFontFamily{Source Han Serif SC, SimSun, SimHei}
```

> 对于竖排文档，手动设置字体时，通常无需额外添加竖排特性（`RawFeature={+vert}`），`luatex-cn` 底层通常会自动处理。但在某些极端自定义场景下，你可能需要手动指定 `Renderer=Harfbuzz` 或相关特性。

---

👉 下一步：查看 [[改字与装饰 | Correction]] 或 [[功能详解 | Features]]。
