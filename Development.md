[English Version](EN:Development) | 中文版

# 开发文档

本文档总结了 `luatex-cn` 排版引擎的核心设计理念与模块化架构，并介绍了参与项目开发的完整流程。

## 1. 核心架构：三层设计

`luatex-cn` 采用三层架构以解耦布局逻辑与渲染表示：

1. **LaTeX 接口层 (`.sty`, `.cls`)**：定义用户命令，通过 `luatexbase` 设置属性及参数。
2. **协作层 (`core_*.lua`)**：协调逻辑流，如 `core_main` 负责主流程，`core_textflow` 负责夹注分列。
3. **处理层 (`layout_*.lua`, `render_*.lua`)**：
   - **展平 (`flatten`)**：将 TeX 节点链表转换为线性的 Lua 表。
   - **布局 (`layout`)**：计算每个字符及其附属元素的网格坐标。
   - **渲染 (`render`)**：根据坐标将内容重新组装并输出 PDF 指令。

## 2. 参与开发

我们欢迎任何形式的贡献和 Pull Request (PR)。

### 2.1 Fork 与开发
1. **Fork 仓库**：点击 GitHub 右上角的 Fork 按钮。
2. **Clone**：将 Fork 后的仓库克隆到本地。
3. **编写代码**：主要的 TeX 宏包源码位于 `tex/` 目录下。

> [!TIP]
> 推荐使用 VS Code 配合 LaTeX Workshop 插件进行开发。

### 2.2 测试

在提交 PR 之前，请务必运行测试以确保代码稳定性。

1. **安装依赖**：你需要安装 `l3build`。
2. **单元测试 (Unit Tests)**：
   针对 Lua 模块的单元测试：
   ```bash
   # 运行所有 Lua 单元测试
   l3build test
   ```
   这会自动调用 `test/run_all.lua`。

3. **回归测试 (Regression Tests)**：
   我们引入了基于 PDF 渲染对比的回归测试自动化程序，用于防止排版布局回退。
   ```bash
   l3build check
   ```
   该命令会编译 `testfiles/` 下的 `.lvt` 文件，并将其生成的日志 (`.tlg`) 与基准文件进行比对。如果涉及排版引擎的更改，请确保所有测试通过。如果你的修改预期会改变排版结果，请更新基准文件：
   ```bash
   l3build save test-name
   ```

### 2.3 发布
详细的发布流程请参考 [[发布流程 | Release]]。

## 3. 关键技术细节

### 竖排流向 (RTT)
利用 LuaTeX 的 `dir RTT` 属性。在 RTT 模式下，文本从上到下流动，行从右到左堆叠。

### 属性管理
使用 LuaTeX 属性（Attributes）来跨语言传递元数据（如“这是一个夹注字符”）。
> [!WARNING]
> \selectfont 会清除所有已设置的属性。请务必在设置字体大小后重新设置属性。

### 节点所有权
在 Lua 中通过 `tex.box[n] = node` 将节点交给 TeX。如果需要重用节点，必须调用 `node.copy_list()`。

## 4. 开发经验 (LEARNING)
- **颜色指令**：必须使用归一化 RGB（如 `0 0 0 rg`），不能用名称。
- **绘制顺序**：PDF 遵循画家模型，后画的覆盖先画的。背景背景颜色应在最底层插入。
- **模块加载**：统一使用 `require()` 并通过 `package.loaded` 缓存。
