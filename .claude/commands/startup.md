---
description: 每次对话开始时必读的项目上下文文档
---

# 项目启动上下文 (Startup Context)

**重要**：在每次新的对话线程开始时，或者当遇到不熟悉的问题时，应该主动阅读以下文档。

## 必读文档

### 1. LEARNING.md - 开发经验总结
**文件**：`ai_must_read/LEARNING.md`

**内容**：
- Lua 与 LaTeX 交互陷阱
- expl3 语法特殊行为
- LuaTeX 节点、属性机制
- PDF 渲染问题（颜色、Z-order、跨页处理）
- 参数传递链路
- 特殊功能实现模式

**何时读取**：
- 新对话开始时
- 遇到 Lua/TeX 交互问题时
- 遇到 PDF 渲染异常时
- 实现新功能前（避免重复踩坑）

### 2. expl3_note.md - expl3 语法详解
**文件**：`ai_must_read/expl3_note.md`

**内容**：
- 参数展开机制（`:n`/`:V`/`:x`/`:e` 区别）
- xparse 可选参数 `[...]` 陷阱
- `\use:x` + `\exp_not:N` 正确模式
- Token list vs 整数展开差异
- `\lua_now:e` 空格处理

**何时读取**：
- 遇到参数展开问题时
- 写 xparse 命令时
- 调试 expl3 代码时

### 3. 项目结构概览
**关键目录**：
```
tex/
├── core/        # 核心渲染引擎（layout, render）
├── guji/        # 古籍特定功能（judou, jiazhu）
├── decorate/    # 装饰元素系统
└── banxin/      # 版心相关

test/regression_test/  # 视觉回归测试
.claude/commands/      # AI 工作流 skills
ai_must_read/          # 开发经验文档
```

### 4. 渲染流程三阶段
```
Stage 1: Flatten      → 展平节点（处理 HLIST/VLIST）
Stage 2: Layout Grid  → 计算位置（填充 layout_map）
Stage 3: Render Page  → 应用坐标、绘制 PDF
```

## 使用方法

### 对话开始时
```
1. 快速浏览 LEARNING.md 目录，了解已知陷阱
2. 如果任务涉及特定功能，精读对应章节
```

### 遇到问题时
```
1. 先在 LEARNING.md 中搜索关键词
2. 如果是新问题且需多次尝试，记得总结经验（使用 /summarize-experience）
```

### 实现新功能时
```
1. 阅读 LEARNING.md 第四章（PDF 渲染）和第五章（参数传递）
2. 参考现有类似功能的实现
3. 遵循三阶段渲染流程
```

## 快速命令

```bash
# 查看经验文档
cat ai_must_read/LEARNING.md | less

# 搜索特定问题
grep -i "color\|颜色" ai_must_read/LEARNING.md

# 查看最近提交（了解最新改动）
git log --oneline -10
```

## 注意事项

- **不要假设**：Lua/TeX 交互有很多反直觉行为，先查文档
- **测试优先**：使用 `python3 test/regression_test.py check <file>` 验证改动
- **小步提交**：每次只修一个问题，便于回滚和审查
- **记录经验**：非平凡问题解决后使用 `/summarize-experience` 总结

## 相关 Skills

- `/fix-github-issue` - 修复 issue 的完整流程
- `/summarize-experience` - 总结并记录经验
- `/verify-examples` - 运行视觉回归测试
- `/update_changelog` - 更新 CHANGELOG
- `/release_process` - 发布新版本流程
