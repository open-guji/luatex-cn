# Grid Width/Height Analysis for luatex-cn

## 问题背景

在 `\卷名` 和 `\章节名` 命令中使用了 `grid-width` 参数，但实际没有效果。需要研究 `grid-width`、`grid-height` 和 `column-width` 的实际应用机制。

## 参数定义位置

### TeX 层 (luatex-cn-core-textbox.sty)

```latex
\keys_define:nn { luatexcn / textbox }
  {
    % ... other keys ...
    inner-grid-width .tl_set:N = \l__luatexcn_textbox_inner_gw_tl,
    inner-grid-width .initial:n = {},
    inner-grid-height .tl_set:N = \l__luatexcn_textbox_inner_gh_tl,
    inner-grid-height .initial:n = {},

    % 别名（简写）
    grid-width .tl_set:N = \l__luatexcn_textbox_inner_gw_tl,   % Line 88
    grid-height .tl_set:N = \l__luatexcn_textbox_inner_gh_tl,  % Line 89
  }
```

**关键发现 1**: `grid-width` 是 `inner-grid-width` 的别名，控制的是 **TextBox 内部的字符网格宽度**，而不是 TextBox 本身在外部占据的宽度。

## 参数传递流程

### 1. TeX → Lua 参数传递

```latex
% Line 110-125: Calculate inner grid width
\dim_set:Nn \l__luatexcn_textbox_inner_gw_dim {
  \lua_now:e {
    local tb = require('core.luatex-cn-core-textbox')
    tex.print(tostring(tb.calc_inner_grid_width({
      inner_gw =
        \tl_if_empty:NTF \l__luatexcn_textbox_inner_gw_tl
          { 0 }
          { \dim_to_decimal_in_sp:n { \l__luatexcn_textbox_inner_gw_tl } },
      column_width = \dim_to_decimal_in_sp:n { \g__luatexcn_column_current_width_dim },
      outer_cols = \int_use:N \l__luatexcn_textbox_outer_cols_int,
      n_cols = \int_use:N \l__luatexcn_textbox_n_cols_int,
      content_gw = \dim_to_decimal_in_sp:n { \l__luatexcn_content_grid_width_tl },
    })))
  } sp
}
```

### 2. Lua 侧计算逻辑 (core-textbox.lua:494-508)

```lua
function textbox.calc_inner_grid_width(params)
    -- 优先级 1: 显式指定的 inner_gw (即 grid-width)
    if params.inner_gw and params.inner_gw > 0 then
        return params.inner_gw
    end

    -- 优先级 2: 基于其他参数计算
    local base
    if params.column_width and params.column_width > 0 then
        base = params.column_width
    elseif params.outer_cols and params.outer_cols > 0 then
        base = params.content_gw * params.outer_cols
    else
        base = params.content_gw
    end

    -- 多列 TextBox: 除以列数
    local n = (params.n_cols and params.n_cols > 0) and params.n_cols or 1
    return base / n
end
```

### 3. Grid Height 计算 (textbox.sty:126-128)

```latex
\tl_if_empty:NTF \l__luatexcn_textbox_inner_gh_tl
  { \dim_set:Nn \l__luatexcn_textbox_inner_gh_dim { \l__luatexcn_content_grid_height_tl } }
  { \dim_set:Nn \l__luatexcn_textbox_inner_gh_dim { \l__luatexcn_textbox_inner_gh_tl } }
```

**关键发现 2**:
- 如果指定了 `grid-height`，则使用指定值
- 否则使用 `\l__luatexcn_content_grid_height_tl`（当前环境的默认网格高度）

## 参数实际作用

### grid-width (inner_gw) 的作用

传递给 `vertical_textbox.process_inner_box()` (Line 215):

```latex
\lua_now:e {vertical_textbox.process_inner_box(\int_value:w~\l_tmpa_box,~{
  grid_width~=~\dim_to_decimal_in_sp:n { \l__luatexcn_textbox_inner_gw_dim },
  grid_height~=~\dim_to_decimal_in_sp:n { \l__luatexcn_textbox_inner_gh_dim },
  ...
}) }
```

在 `build_sub_params()` (Line 205) 中传递给布局引擎:

```lua
return {
    grid_width = params.grid_width,   -- 传递给 core.typeset
    grid_height = params.grid_height,
    ...
}
```

**核心作用**: 控制 TextBox **内部** 进行竖排布局时的字符网格尺寸。

### font-size 的作用

当指定 `font-size` 时 (Line 138-151):

```latex
\tl_if_empty:NTF \l__luatexcn_textbox_font_size_tl
  {
    % 默认自动缩放（多列时）
    \int_compare:nNnT \l__luatexcn_textbox_n_cols_int > 1
      {
        \dim_set:Nn \l_tmpa_dim { \l__luatexcn_textbox_inner_gw_dim * 85 / 100 }
        \fontsize{\l_tmpa_dim}{\l__luatexcn_textbox_inner_gw_dim}\selectfont
      }
  }
  {
    % 用户指定字号
    \dim_set:Nn \l_tmpa_dim { \l__luatexcn_textbox_font_size_tl }
    \fontsize{\l_tmpa_dim}{\l_tmpa_dim}\selectfont
  }
```

**关键发现 3**:
- 当显式指定 `font-size` 时，使用该字号
- 当未指定时，多列 TextBox 会自动缩放到 `inner_gw * 85%`
- **`font-size` 和 `grid-width` 是独立的参数**

## column-width 参数

**重要发现**: `column-width` **不是 TextBox 的参数键**！

在 `\keys_define:nn { luatexcn / textbox }` 中没有定义 `column-width`。

但是在 `calc_inner_grid_width()` 中使用了 `\g__luatexcn_column_current_width_dim`：

```latex
column_width = \dim_to_decimal_in_sp:n { \g__luatexcn_column_current_width_dim },
```

这个变量来自于**外部环境**（正文环境），而不是 TextBox 的参数。

## 当前 \卷名 和 \章节名 的问题

```latex
% 当前定义（zhonghuashuju.cfg）
\newcommand{\卷名}[1]{%
  \文本框[font-size=48pt, grid-height=54pt, grid-width=100pt]{#1}%
}

\newcommand{\章节名}[1]{%
  \文本框[font-size=32pt, grid-height=36pt, grid-width=70pt]{#1}%
}
```

### 问题分析

1. **font-size=48pt** ✅ 有效 - 字号确实会设为 48pt
2. **grid-height=54pt** ✅ 有效 - 内部行高设为 54pt
3. **grid-width=100pt** ❌ **部分有效** - 设定了内部字符网格宽度为 100pt

### 为什么 grid-width 看起来"没用"？

因为 **`grid-width` 只影响 TextBox 内部的布局网格，不影响字符实际宽度**。

字符的实际宽度由 **字体的字形宽度** 决定。对于等宽中文字体，48pt 字号的字符宽度约为 48pt。

`grid-width=100pt` 的作用是：
- 如果 TextBox 内部有多列（n-cols > 1），则每列宽度为 100pt
- 如果只有单列（默认），则列宽为 100pt，但字符宽度仍由字体决定

### 正确的列宽控制方式

要真正控制 TextBox 占据的外部列宽，应该使用 **`outer-cols`** 参数：

```latex
% 示例：TextBox 占据外部 3 列
\文本框[outer-cols=3, font-size=48pt]{标题}
```

或者使用 **floating TextBox** 并直接控制位置。

## 总结

| 参数 | 作用域 | 实际效果 |
|------|--------|----------|
| `grid-width` | 内部布局 | 控制 TextBox 内部的字符网格宽度（多列时每列宽度） |
| `grid-height` | 内部布局 | 控制 TextBox 内部的行高（字符高度） |
| `font-size` | 排版 | 控制字体大小（直接影响字符尺寸） |
| `height` | 内外布局 | 控制 TextBox 内容高度（网格单位或 pt），影响外部占据行数 |
| `outer-cols` | 外部布局 | 控制 TextBox 在外部网格中占据的列数 |
| `n-cols` | 内部布局 | 控制 TextBox 内部分为几列 |

## 建议修改

### 方案 1：保持简单（推荐）

```latex
% 只需要 font-size，不需要 grid-width
\newcommand{\卷名}[1]{%
  \文本框[font-size=48pt]{#1}%
}

\newcommand{\章节名}[1]{%
  \文本框[font-size=32pt]{#1}%
}
```

### 方案 2：如果需要特定内部网格

```latex
% 显式设置内部网格（用于多列 TextBox）
\newcommand{\卷名}[1]{%
  \文本框[font-size=48pt, grid-height=54pt]{#1}%
}
```

### 方案 3：控制外部占据列数

```latex
% 让标题占据多列（如果需要）
\newcommand{\卷名}[1]{%
  \文本框[font-size=48pt, outer-cols=2]{#1}%
}
```

## 相关代码位置

- **TeX 参数定义**: [tex/core/luatex-cn-core-textbox.sty:50-99](tex/core/luatex-cn-core-textbox.sty#L50-L99)
- **grid-width 计算**: [tex/core/luatex-cn-core-textbox.lua:494-508](tex/core/luatex-cn-core-textbox.lua#L494-L508)
- **font-size 应用**: [tex/core/luatex-cn-core-textbox.sty:138-151](tex/core/luatex-cn-core-textbox.sty#L138-L151)
- **grid-height 应用**: [tex/core/luatex-cn-core-textbox.sty:126-128](tex/core/luatex-cn-core-textbox.sty#L126-L128)
