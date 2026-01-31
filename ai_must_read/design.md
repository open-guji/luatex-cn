# 竖排引擎架构设计文档

本文档描述了 `luatex-cn` 中用于竖排排版的“三阶段流水线”架构及核心设计。

## 三阶段流水线 (Three-Stage Pipeline)

### 第一阶段：节点展平 (Stage 1: Flattening)
*   **核心模块**: `luatex-cn-vertical-flatten-nodes.lua`
*   **主要任务**: 将 TeX 传入的嵌套盒子（vbox/hbox）打碎，转换成一维的线性节点流。
*   **关键动作**: 在 TeX 盒子结构被解构前，提取缩进（Indent）等布局信息并转化为节点属性（Attribute）。

### 第二阶段：虚拟网格布局 (Stage 2: Layout)
*   **核心模块**: `luatex-cn-vertical-layout-grid.lua`
*   **主要任务**: 在不修改节点本身的情况下，计算每个节点在虚拟网格中的坐标（页、列、行）。
*   **核心逻辑**:
    *   **占用地图 (Occupancy Map)**: 追踪网格占用情况，防止正文与跳转文本框（Textbox）重叠。
    *   **避让逻辑**: 自动跳过版心列（Gutter）和悬浮块占用的位置。
    *   **文本流控**: 处理夹注（Jiazhu）的双行排列、段落首行缩进等复杂逻辑。
*   **输出**: 生成 `layout_map`（节点指针 -> 坐标位置的映射表）。

### 第三阶段：视觉渲染 (Stage 3: Rendering)
*   **核心模块**: `luatex-cn-vertical-render-page.lua`
*   **主要任务**: 根据布局地图，将坐标应用到节点，并绘制视觉装饰元素。
*   **关键动作**:
    *   **定位应用**: 为字形（Glyph）设置 `xoffset`/`yoffset`，为盒子（Box）插入 `kern`/`shift`。
    *   **视觉绘制**: 使用 PDF Literal 指令绘制边框、背景、版心装饰（如鱼尾）及页码。
    *   **物理转换**: 处理从左向右的 TLT 盒子到从右向左（RTL）竖排视觉的坐标转换。

---

## 常量与属性说明 (`luatex-cn-vertical-base-constants.lua`)

属性（Attribute）是 TeX 与 Lua、以及流水线各阶段之间沟通的“情报系统”。

| 常量名称 | 功能描述 | 使用阶段 |
| :--- | :--- | :--- |
| `ATTR_INDENT` / `RIGHT_INDENT` | 存储字符的左右缩进值（sp）。 | **阶段1** 提取；**阶段2** 决定行起始位置。 |
| `ATTR_TEXTBOX_WIDTH/HEIGHT` | 标记非标准盒子在网格中占用的行列数。 | **阶段2** 用于标记网格占用，防止重叠。 |
| `ATTR_BLOCK_ID` | 段落分组 ID，用于实现首行缩进等逻辑。 | **阶段2** 识别新段落的开始。 |
| `ATTR_JIAZHU` / `SUB` / `MODE` | 夹注（小字双行）的标记及排版模式。 | **阶段2** 触发特殊的双行流分配算法。 |
| `ATTR_DECORATE_ID` / `FONT` | 装饰符标记，如文字旁的红圈、着重号。 | **阶段3** 在对应文字位置叠加绘制装饰字符。 |
| `ATTR_CHAPTER_REG_ID` | 章节追踪 ID。 | **阶段2** 检测页面章节变化以更新版心。 |
| `SIDENOTE_USER_ID` | 侧批（批注）标记。 | **阶段2** 锁定锚点；**阶段3** 绘制在行间空隙。 |
| `JUDOU_USER_ID` | 句读（标点）标记。 | **阶段2/3** 控制标点在字角位置的精准定位。 |
| `BANXIN_USER_ID` | 版心锚点辅助标记。 | **阶段3** 作为绘制版心中央装饰元素的信号。 |

---

---

## 参数体系与标准化规范 (Parameter Hierarchy & Standards)

为了保证复杂排版参数的可维护性和一致性，`luatex-cn` 采用了分层级的参数管理机制。

### 1. 参数层级划分 (Hierarchy)

| 层级 | 适用范围 | 定义位置 | 说明 |
| :--- | :--- | :--- | :--- |
| **A. 全局配置层 (Global/Class)** | 整个文档的纸张、核心字体、全局风格。 | `ltc-guji.cls`, `.cfg` | 决定“书”的大样，如 `paper-width`。 |
| **B. 模块定义层 (Module/Package)** | 竖排引擎、版心渲染等的默认行为。 | `vertical.sty`, `banxin.sty` | 决定“排版引擎”的默认参数。 |
| **C. 环境局部层 (Local/Environment)** | 特定的正文块或多页布局。 | `\begin{正文}[...]` | 实现局部风格切换（如单双栏切换）。 |
| **D. 命令实例层 (Command/Instance)** | 单个文本框、侧批或装饰。 | `\TextBox[...]`, `\SideNode[...]` | 最高优先级，用于微调单个元素。 |

### 2. 传递与继承机制 (Inheritance)

*   **向下穿透**: 高层级定义的参数（如 Class 层的 `grid-height`）应自动作为下层级（如 `vertical` 环境）的默认值。
*   **局部覆盖**: `Command` 层的参数仅在当前命令范围内生效，不应污染全局状态。
*   **同步逻辑**: 
    *   目前使用 `ltc-guji.cls` 在环境初始化时手动同步键值对（Key-Value Sync）。
    *   **未来标准**: 核心包定义 `luatexcn / <module>` 命名空间，上层类通过 `keys_set:nn` 批量分发。

### 3. 命令开发规范 (Development Standards)

*   **命名空间 (Namespace)**:
    *   核心键: `luatexcn / vertical / <key>`
    *   特化键: `luatexcn / v / <command> / <key>`
*   **变量规范**:
    *   全局变量: `\g_luatexcn_<module>_<key>_tl`
    *   局部变量: `\l_luatexcn_<module>_<key>_tl`
*   **参数传递原则**: 
    1.  **先合并再执行**: 命令内部应先将 `Global Setup` + `Local Options` 合并。
    2.  **单位安全**: 所有的距离参数（Dimen）在传入 Lua 前应通过 `\__luatexcn_to_dimen:n` 统一转换为 `sp`。
    3.  **布尔一致性**: TeX 层的 `true/false` 字符串在传入 Lua 时应统一显式转换为 Lua 布尔值。

---

---

## 插件化架构与插件规范 (Plugin-Based Architecture - Engine 2.0)

为了实现核心引擎的“即插即用”和高可扩展性，引擎将演进为基于插件的编排模式。

### 1. 插件核心接口 (Plugin Interface)

每个子模块（如 `judou`, `sidenote`, `textbox`）应实现以下四个生存周期函数：

| 函数名称 | 输入参数 | 职责 | 返回值 |
| :--- | :--- | :--- | :--- |
| **`initialize`** | `params`, `engine_ctx` | 参数解析、设置默认值、注册需求。 | `plugin_ctx` (插件私有状态) |
| **`flatten`** | `head`, `params`, `plugin_ctx` | 节点流预处理（如标点处理、CAPT 缩进）。 | `head` (修改后的节点头) |
| **`layout`** | `node`, `layout_map`, `engine_ctx`, `plugin_ctx` | 逻辑位置计算、标记网格占用。 | 无 (直接修改 `layout_map`) |
| **`render`** | `head`, `layout_map`, `r_params`, `plugin_ctx` | 应用物理偏移、绘制视觉装饰。 | `head` (导出后的节点头) |

### 2. 上下文对象管理 (Context Management)

*   **`engine_ctx` (全局引擎上下文)**:
    *   包含全局物理指标：`grid_height`, `grid_width`, `paper_width`, `margin` 等。
    *   包含布局中间状态：`occupancy` (网格占用图), `banxin_registry` (版心登记表)。
*   **`plugin_ctx` (插件私有上下文)**:
    *   由 `initialize` 返回，引擎保证在后续所有阶段将其传回给该插件。
    *   用于存储特定插件的中间数据（如某插件解析后的特定配置）。

### 3. 重构演进计划 (Evolutionary Path)

1.  **第一步**：在 `core-main` 中引入插件注册表机制，并率先实现 `initialize` 的解耦。
2.  **第二步**：将 `judou` (句读) 模块封装为第一个标准插件。
3.  **第三步**：依次重构 `sidenote` (侧批)、`textbox` (文本框) 和 `banxin` (版心) 模块，消除 `core-main` 中的硬编码调用。

---

## 协作总结
1.  **第一阶段**负责从 TeX 环境中“抢救”逻辑结构信息。
2.  **第二阶段**在理想化的网格坐标系中应用排版规则。
3.  **第三阶段**负责将逻辑网格转化为物理坐标和 PDF 绘图命令。
4.  **参数管理**通过分层继承保证了从全局模板到局部微调的灵活性。
5.  **插件化架构**实现了引擎核心与子功能的完全解耦，模块化能力显著增强。
