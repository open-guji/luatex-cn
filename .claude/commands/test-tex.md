# 测试 TeX 文件

当需要编译并查看某个 TeX 文件的渲染效果时，**必须通过回归测试框架来执行**，避免在工作目录中生成多余的 PDF 文件。

## 参数

- `$ARGUMENTS`：要测试的 tex 文件路径或名称（可选，如果不提供则根据上下文判断）

## 工作流程

### 1. 确定测试文件

- **已有文件**：如果 `test/regression_test/tex/` 下已存在该文件，直接使用
- **临时测试**：如果需要创建临时 tex 文件，将其写入 `test/regression_test/tex/` 目录下，文件名以 `_tmp_` 前缀标记（如 `_tmp_test.tex`）

### 2. 编译并生成 PNG

```bash
python3 test/regression_test.py check test/regression_test/tex/<文件名>.tex
```

这会：
- 编译 TeX 文件生成 PDF
- 将 PDF 所有页面转换为 PNG（300dpi）
- PNG 保存在 `test/regression_test/current/` 目录下
- 如果有基线则进行对比，没有基线也会生成 PNG

### 3. 查看渲染结果

使用 Read 工具读取生成的 PNG 文件来查看效果：

```
test/regression_test/current/<文件名>-1.png  # 第1页
test/regression_test/current/<文件名>-2.png  # 第2页
...
```

### 4. 清理临时文件

测试完成后，**必须删除临时生成的 tex 文件**（以 `_tmp_` 前缀标记的文件）：

```bash
rm test/regression_test/tex/_tmp_*.tex
```

`test/regression_test/tex/` 目录下只保留需要**长期持续回归验证**的测试文件。

## 注意事项

- **禁止**在其他目录中直接运行 `lualatex` 编译生成 PDF
- **禁止**使用 `pdftoppm` 等工具手动转换，统一由回归测试框架处理
- 临时文件用 `_tmp_` 前缀，便于识别和清理
- 如果测试结果正确且需要长期保留，去掉 `_tmp_` 前缀并用 `save` 保存基线
