---
description: 清理重构代码 (Code cleanup and refactoring)
---

# 代码清理与重构

以资深程序架构师的视角审视项目代码，使其更整洁、更模块化、更易维护。

## 重构原则

按优先级排列：

### 1. 删除死代码
- 找出未被调用的函数和未使用的变量
- 搜索方式：用 Grep 搜索函数名/变量名，确认只有定义没有调用
- **Lua 文件**：检查 `local function` 和 module 导出的函数
- **STY 文件**：检查 `\cs_new` 定义的命令是否被使用

### 2. 提取重复代码
- 在同一文件或相关文件中找到高度相似的代码段
- 提取为通用函数，放到合适的工具模块中
- 命名清晰，参数明确

### 3. 逻辑迁移：STY → Lua
- 复杂逻辑应放在 Lua 中，STY 只负责命令定义和参数解析
- STY 文件应尽量薄：定义命令 → 调用 Lua 函数
- 模式：
  ```latex
  % STY 中：只做参数解析和 Lua 调用
  \NewDocumentCommand{\MyCmd}{O{} m}{
    \lua_now:e { my_module.my_func("\exp_not:n{#1}", "\exp_not:n{#2}") }
  }
  ```

### 4. 使用 Style Stack 管理样式
- 格式和样式的设置应通过 style stack 来管理
- 避免全局变量传递样式参数
- 查看 `tex/core/` 中 style stack 的现有用法作为参考

### 5. 模块职责单一
- 每个模块（文件）负责一个独立功能
- 与该功能相关的所有代码都应集中在该模块中
- 如果发现某个功能的代码散落在多个不相关的文件中，应该收拢

### 6. 文件大小控制
- 单个文件超过 400~600 行时，必须考虑拆分
- 按子功能拆分为多个文件
- 通过 `require` (Lua) 或 `\RequirePackage` (STY) 组织

### 7. 命令复用
- 如果一个命令可以由其他命令组合实现，优先复用
- 避免重复实现已有功能

## 执行流程

### Phase 1: 分析 (不改代码)

1. **扫描目标模块**
   - 读取目标文件，理解其功能和结构
   - 统计行数，标记过大的文件

2. **识别问题**
   - 用 Grep 搜索未使用的函数/变量
   - 找出重复代码段
   - 标记可以迁移到 Lua 的 STY 逻辑
   - 检查模块职责是否单一

3. **制定计划**
   - 列出所有要做的重构项
   - 按风险从低到高排序
   - 每个重构项作为独立的一步
   - 使用 EnterPlanMode 让用户审批计划

### Phase 2: 逐步执行

对每一步重构：

1. **修改代码**
   - 只做当前这一步的改动
   - 保持功能不变

2. **回归测试**
   ```bash
   python3 test/regression_test.py check
   ```
   - 所有测试必须 PASSED
   - 如果失败，立即修复或回滚

3. **提交**
   ```bash
   git add <changed-files>
   git commit -m "refactor: <描述这一步做了什么>

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
   ```

4. **继续下一步**

### Phase 3: 最终验证

```bash
# 运行完整回归测试
python3 test/regression_test.py check --all
```

## 如何选择重构目标

如果用户没有指定目标模块，按以下顺序扫描：

```bash
# 找出最大的文件
find tex/ -name '*.lua' -o -name '*.sty' | xargs wc -l | sort -rn | head -20
```

优先处理：
1. 行数最多的文件
2. 最近频繁修改的文件 (`git log --format='%H' --since='2 weeks ago' -- tex/ | head`)
3. 已知有技术债的模块

## 注意事项

- **不要一次改太多** — 每步只做一个类型的重构
- **测试优先** — 每步改完必须跑回归测试
- **保持功能不变** — 重构不改变外部行为
- **先读 LEARNING.md** — 避免踩已知的坑
- **STY 中的 expl3** — 遇到展开问题先读 `ai_must_read/expl3_note.md`
- **不要改测试文件** — 除非测试本身有问题
