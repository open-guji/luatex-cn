[中文版](Debug) | English Version

# Debug Mode

`luatex-cn` provides comprehensive debugging features to help troubleshoot layout issues.

## Enable/Disable Debug

```latex
\LtcDebugOn    % or \开启调试
\LtcDebugOff   % or \关闭调试
```

## Module-level Debug

Enable debugging for specific modules:

```latex
\LtcDebugModuleOn{vertical}   % or \开启调试模块{vertical}
\LtcDebugModuleOff{vertical}  % or \关闭调试模块{vertical}
```

## Display Helper Tools

### Show Page Frame

```latex
\LtcShowFrame   % or \显示边框
```

### Show Grid Coordinates

Overlay grid coordinates on the page for element positioning:

```latex
% Show grid (default unit: cm)
\LtcShowGrid              % or \显示网格

% Specify unit
\LtcShowGrid[measure=cm]  % or \显示网格[measure=cm]
\LtcShowGrid[measure=pt]
\LtcShowGrid[measure=mm]

% Hide grid
\LtcHideGrid              % or \隐藏网格
```

Supported units: `cm` (default), `pt`, `mm`

### Show Coordinates

`\显示坐标` is an alias for `\显示网格`:

```latex
\显示坐标[measure=pt]
\隐藏坐标
```

## Debug Color Settings

Set different debug colors for different modules:

```latex
\LtcDebugColor{vertical}{blue}
\LtcDebugColor{banxin}{red}
```

## Usage Example

```latex
\documentclass[四库全书彩色]{ltc-guji}

% Enable debug mode
\LtcDebugOn
\LtcShowGrid[measure=cm]

\begin{document}
\begin{正文}
Debug content...
\end{正文}
\end{document}
```

## Debug Output

When debug is enabled, the compilation log outputs detailed layout information including:
- Grid position calculations
- Character positioning
- Banxin rendering process
- Plugin invocation order

---

👉 Back to: [[Features | EN:Features]] | [[Home | EN:Home]]
