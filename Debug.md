[English Version](EN:Debug) | 中文版

# 调试模式

`luatex-cn` 提供了完整的调试功能，帮助排查排版问题。

## 开启/关闭调试

```latex
\LtcDebugOn    % 或 \开启调试
\LtcDebugOff   % 或 \关闭调试
```

## 模块级调试

可以针对特定模块开启调试：

```latex
\LtcDebugModuleOn{vertical}   % 或 \开启调试模块{vertical}
\LtcDebugModuleOff{vertical}  % 或 \关闭调试模块{vertical}
```

## 显示辅助工具

### 显示页面边框

```latex
\LtcShowFrame   % 或 \显示边框
```

### 显示网格坐标

在页面上叠加网格坐标，方便定位元素：

```latex
% 显示网格（默认单位 cm）
\LtcShowGrid              % 或 \显示网格

% 指定单位
\LtcShowGrid[measure=cm]  % 或 \显示网格[measure=cm]
\LtcShowGrid[measure=pt]
\LtcShowGrid[measure=mm]

% 隐藏网格
\LtcHideGrid              % 或 \隐藏网格
```

支持的单位：`cm`（默认）、`pt`、`mm`

### 显示坐标

`\显示坐标` 是 `\显示网格` 的别名：

```latex
\显示坐标[measure=pt]
\隐藏坐标
```

## 调试颜色设置

可以为不同模块设置不同的调试颜色：

```latex
\LtcDebugColor{vertical}{blue}
\LtcDebugColor{banxin}{red}
```

## 使用示例

```latex
\documentclass[四库全书彩色]{ltc-guji}

% 开启调试模式
\LtcDebugOn
\LtcShowGrid[measure=cm]

\begin{document}
\begin{正文}
调试内容...
\end{正文}
\end{document}
```

## 调试输出

开启调试后，编译日志中会输出详细的排版信息，包括：
- 网格位置计算
- 字符定位
- 版心渲染过程
- 插件调用顺序

---

👉 返回：[[功能详解 | Features]] | [[首页 | Home]]
