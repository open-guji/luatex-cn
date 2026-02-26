# luatex-cn 数字化工具集

本目录包含古籍数字化转换和验证的完整工具链。

## 工具列表

| 工具 | 用途 | 文档 |
|------|------|------|
| `semantic_to_digital.py` | 语义 TeX → 数字化 TeX 转换 | 见下方 "Semantic → Digital" 章节 |
| `digital_to_semantic.py` | 数字化 TeX → 语义 TeX 逆向转换 | 见下方 "Digital → Semantic" 章节 |
| `compare_guji_layouts.py` | 编译 + 比较 + 生成一致性报告 | ✅ **推荐**用于转换验证 |
| `plugins/` | 转换插件（如四库全书特有命令） | 见插件章节 |

---

# Digital → Semantic 转换器

## 概述

`digital_to_semantic.py` 将 `ltc-guji-digital`（布局模式）格式的古籍文件转换回 `ltc-guji`（语义模式）格式。

这个工具专为**第 2-10 册的 OCR + 文字合并**工作流设计：
```
OCR 扫描 → digital TeX (布局模式) → digital_to_semantic.py → semantic TeX (语义模式)
```

## 用法

### 基本用法

```bash
python3 scripts/digitalize/digital_to_semantic.py \
  --input 冊一-digital.tex \
  --output 冊一.tex
```

### 使用插件（推荐）

```bash
python3 scripts/digitalize/digital_to_semantic.py \
  --input 冊一-digital.tex \
  --output 冊一.tex \
  --plugin scripts/digitalize/plugins/siku_mulu_to_semantic.py
```

## 转换规则

### 1. 文档类声明
```tex
\documentclass[...]{ltc-guji-digital}  →  \documentclass[...]{ltc-guji}
```

### 2. 夹注转换

#### \注（indent=2）
**Digital 格式：**
```tex
\缩进[2]\双列{\右小列{舊本題卜子夏撰實後人輾轉依托}\左小列{非其原書然唐宋以來流傳已久}}
\缩进[2]\双列{\右小列{今仍錄冠易類之首}\左小列{}}
```

**转换为 Semantic 格式：**
```tex
\注{舊本題卜子夏撰實後人輾轉依托非其原書然唐宋以來流傳已久今仍錄冠易類之首}
```

#### \按（indent=4）
**Digital 格式：**
```tex
\缩进[4]\双列{\右小列{謹按唐徐堅初學記以太宗御制}\左小列{升列歷代之前蓋尊尊之大義}}
\缩进[4]\双列{\右小列{焦竑國史經籍志朱彞尊經義考}\左小列{並踵前規}}
```

**转换为 Semantic 格式：**
```tex
\按{謹按唐徐堅初學記以太宗御制升列歷代之前蓋尊尊之大義焦竑國史經籍志朱彞尊經義考並踵前規}
```

### 3. 条目列表

**Digital 格式（全角空格缩进）：**
```tex
　卷一
　　經部一
　　　易類
```

**转换为 Semantic 格式：**
```tex
\条目[1]{卷一}
\条目[2]{經部一}
\条目[3]{易類}
```

### 4. 段落

**Digital 格式：**
```tex
\缩进[1] 及應存書名三項各條下俱經撰有提要將一書原
\缩进[1] 委撮舉大凡并詳著書人世次爵里可以一覽了然
```

**转换为 Semantic 格式：**
```tex
\begin{段落}[indent=1]
及應存書名三項各條下俱經撰有提要將一書原
委撮舉大凡并詳著書人世次爵里可以一覽了然
\end{段落}
```

### 5. 换页
```tex
\换页  →  \newpage
```

## 插件机制

### 四库全书简明目录插件（reverse_siku_mulu.py）

处理四库全书特有的命令：

#### \國朝 命令
**Digital 格式：**
```tex
\缩进[2]\双列{\右小列{漢鄭元撰 }\左小列[indent=1]{國朝惠棟編因王應麟之本}}
\缩进[1]\双列{\右小列{採摭未備又不註其所出}\左小列{因重為補正}}
```

**转换为 Semantic 格式：**
```tex
\注{漢鄭元撰 }

\國朝 惠棟編因王應麟之本採摭未備又不註其所出因重為補正
```

**关键处理：**
- 检测 `\左小列[indent=1]{國朝...}`
- 将开头的 "國朝" 两个字替换为 `\國朝` 命令
- 合并后续的 `\缩进[1]\双列` 行

### 创建自定义插件

```python
#!/usr/bin/env python3
from typing import List, Optional, Tuple

class DigitalToSemanticPlugin:
    """插件基类"""

    def preprocess_line(self, line: str) -> Optional[str]:
        """预处理单行（可选）"""
        return None

    def recognize_pattern(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        """
        识别模板特有的模式。
        返回 (转换后的内容, 消耗的行数) 或 None
        """
        return None

    def postprocess_content(self, content: str) -> str:
        """后处理转换后的内容（可选）"""
        return content

class MyCustomPlugin(DigitalToSemanticPlugin):
    def recognize_pattern(self, lines, index):
        line = lines[index]
        # 你的自定义逻辑
        if '特殊模式' in line:
            return '转换后的内容\n', 1
        return None
```

## 已知限制

### 1. 跨页的 \注 会被分割
**Digital 格式：**
```tex
\缩进[2]\双列{\右小列{文頗簡略蓋無可發揮新義者}\左小列{即不橫生枝節強為敷衍}}
\换页
\缩进[2]\双列{\右小列{猶有先儒篤實之遺}\左小列{}}
```

**当前转换结果：**
```tex
\注{文頗簡略蓋無可發揮新義者即不橫生枝節強為敷衍}
\newpage
\注{猶有先儒篤實之遺}
```

**期望结果：**
```tex
\注{文頗簡略蓋無可發揮新義者即不橫生枝節強為敷衍猶有先儒篤實之遺}
```

**解决方案：** 需要实现跨 `\换页` 的 \注 合并逻辑（TODO）

### 2. 抬头命令保留原样
`\单抬`、`\平抬`、`\相对抬头` 等命令在 digital 和 semantic 格式中完全相同，直接保留。

## 测试

### 完整测试（四库全书简明目录冊一）

```bash
# Digital → Semantic 转换
python3 scripts/digitalize/digital_to_semantic.py \
  --input "全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一-digital.tex" \
  --output "/tmp/冊一-reversed.tex" \
  --plugin scripts/digitalize/plugins/siku_mulu_to_semantic.py

# 检查关键转换
grep -n "\\\\注{" /tmp/冊一-reversed.tex | wc -l   # \注 数量
grep -n "\\\\按{" /tmp/冊一-reversed.tex | wc -l   # \按 数量
grep -n "\\\\條目" /tmp/冊一-reversed.tex | head   # 条目列表
grep -n "\\\\國朝" /tmp/冊一-reversed.tex          # \國朝 命令
```

### 验证转换质量

```bash
# 对比原始 semantic 文件与转换结果
diff -u \
  "全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一.tex" \
  "/tmp/冊一-reversed.tex" \
  | less
```

## 双向转换关系

| 方向 | 工具 | 输入 | 输出 |
|------|------|------|------|
| **Semantic → Digital** | `semantic_to_digital.py` | 语义 TeX (ltc-guji.cls) | Digital TeX (ltc-guji-digital.cls) |
| **Digital → Semantic** | `digital_to_semantic.py` | Digital TeX (ltc-guji-digital.cls) | 语义 TeX (ltc-guji.cls) |

**应用场景：**
- **正向**：第 1 册手工排版 → digital 版本（用于验证）
- **逆向**：第 2-10 册 OCR 生成 digital TeX → semantic TeX（用于后续编辑）

## 未来改进

- [ ] 实现跨 `\换页` 的 \注/\按 合并
- [ ] 支持 `first-indent=0` 的段落检测
- [ ] 添加单元测试
- [ ] 改进错误处理和日志输出
- [ ] 支持更多古籍模板（如诗词、史书等）
