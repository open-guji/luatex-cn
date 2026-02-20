# 回归测试技能

运行回归测试来验证代码更改是否正确。

## 测试套件

| 套件 | 说明 | 何时运行 |
|------|------|----------|
| `basic` (默认) | 核心功能测试 | 每次修改后 |
| `past_issue` | 历史 issue 回归测试 | 偶尔验证 |
| `complete` | 完整书籍测试 | 发版前 |

## 命令

```bash
# 默认：只运行 basic 套件
python3 test/regression_test.py check

# 运行 past_issue 套件
python3 test/regression_test.py check --past-issues

# 运行 complete 套件
python3 test/regression_test.py check --complete

# 运行所有套件
python3 test/regression_test.py check --all

# 检查特定文件（在当前套件中搜索）
python3 test/regression_test.py check banxin

# 保存新基准（仅当预期更改时使用）
python3 test/regression_test.py save banxin
```

## 使用流程

### 1. 修改代码后，先检查相关文件
```bash
python3 test/regression_test.py check banxin
```

### 2. 提交前，运行 basic 全部测试
```bash
python3 test/regression_test.py check
```

### 3. 发版前，运行所有套件
```bash
python3 test/regression_test.py check --all
```

### 4. 仅当预期更改时，保存新基准
```bash
python3 test/regression_test.py save banxin
```

## 目录结构

```
test/regression_test/
├── basic/          # 核心功能（开发时频繁运行）
│   ├── tex/        # 测试 TeX 源文件
│   └── baseline/   # 基准 PNG 图像
├── past_issue/     # 历史 issue 回归（偶尔运行）
│   ├── tex/
│   └── baseline/
└── complete/       # 完整书籍（发版前运行）
    ├── tex/
    └── baseline/
```

## 注意事项

- `check` 用于验证，不会修改基准文件
- `save` 会覆盖基准文件，仅在确认更改正确时使用
- 省略文件名则测试当前套件中所有文件
- 提交代码前务必运行 `check` 确保 basic 测试通过
