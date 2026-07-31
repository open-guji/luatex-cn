[English Version](EN:Fonts) | 中文版

# 字体设置 (Fonts)

`luatex-cn` 提供了智能的跨平台字体探测机制，以及强大的多字体递补（Fallback）功能，确保生僻字和缺字情况能够被优雅处理。

## 1. 自动字体探测

在默认情况下，使用 `ltc-guji`（或 `ltc-cn-vbook` / `ltc-tw-vbook`）文档类会自动根据操作系统选择最合适的已安装字体：

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

### 注册表别名与字体文件（免安装）

`\设置字体族` 还接受**注册表别名**和**字体文件名/路径**，三种规格可混用，字体无需装进系统：

```latex
\设置字体族{Jigmo}                      % 别名：自动展开为 Jigmo + Jigmo2 回退链
\设置字体族{fonts/MyFont.ttf, TW-Kai}   % 文件路径与字体名混搭
\设置字体族{TW-Kai, Jigmo2.ttf}         % 裸文件名也可以
```

每个字体按三级顺序解析：

1. **系统已装** → 按名字使用系统字体；
2. **本地文件** → 依次查 `./fonts/`、文档目录、kpse（覆盖 TEXMFHOME 与 OSFONTDIR）；
3. **都没有** → 报错中断编译，并给出下载脚本的完整命令（见 §4），避免缺字渲染成豆腐块。

系统与本地文件可逐字体混搭——例如系统装了 Jigmo 而本地只有 `Jigmo2.ttf`，别名 `{Jigmo}` 仍能正确组链。目前注册表内置别名：`Jigmo`（Jigmo + Jigmo2）。

> 对于竖排文档，手动设置字体时，通常无需额外添加竖排特性（`RawFeature={+vert}`），`luatex-cn` 底层通常会自动处理。但在某些极端自定义场景下，你可能需要手动指定 `Renderer=Harfbuzz` 或相关特性。

## 4. 免安装字体：下载脚本

不想（或没有权限）把字体装进系统字体库？LuaTeX 本身就支持**按文件加载字体**——只要 `.ttf`/`.otf` 文件在文档目录、`./fonts/` 子目录或 TEXMFHOME 里，写文件名即可使用。

仓库自带下载脚本（需要 Python 3），按 `scripts/font-manifest.json` 清单获取推荐的开源字体（TW-Kai 楷体系列、Jigmo 字面、京華老宋体、朱雀仿宋等，均校验 SHA-256）：

```bash
# 方式一：安装到 TeX 个人目录（推荐，一次下载全局可用）
# 位置为 TEXMFHOME/fonts/truetype/luatex-cn/，免管理员权限、不进系统字体库
python3 scripts/download_fonts.py --all --user

# 方式二：下载到文档项目目录（文档与字体可整体打包分发）
python3 scripts/download_fonts.py --all --dest ./fonts
```

之后在文档中直接按**文件名**引用：

```latex
% 字体在 TEXMFHOME 或文档同目录时，裸文件名即可
\setmainfont{TW-Kai-98_1.ttf}

% 字体在子目录时，用 Path 指定
\setmainfont{TW-Kai-98_1.ttf}[Path=./fonts/]
```

> [!NOTE]
> - `--user` 安装后如需按**字体名**（而非文件名）引用，再执行一次 `luaotfload-tool --update` 更新字体索引。
> - 朱雀仿宋等来自 npm woff2 切片的字体，脚本会自动下载并用 fonttools 合并为单个 TTF（竖排特性保留），需要先 `pip install fonttools brotli`。

---

👉 下一步：查看 [[改字与装饰 | Correction]] 或 [[功能详解 | Features]]。
