# guji-digital 示例复刻计划

## 完成状态

### 1. 史记五帝本纪 (test/digital_test) ✅
- `史记-digital-phase2.tex` - 语义模式，像素完全匹配
- `史记-digital-layout.tex` - 纯布局模式示例

### 2. 红楼梦甲戌本 ✅
- `红楼梦-digital.tex` - 所有4页像素完全匹配
- 配置文件：`luatex-cn-digital-HongLouMengJiaXuBen.cfg`

### 3. 四库全书简明目录 ✅
- `四库目录-digital.tex` - 所有2页像素完全匹配
- 配置文件：`luatex-cn-digital-SikuWenyuanMulu.cfg`
- 配置文件：`luatex-cn-digital-SiKuQuanShu-colored.cfg`

### 4. 史记五帝本纪 (示例目录) ✅
- `史记五帝-digital.tex` - 所有4页像素完全匹配
- 使用 SiKuQuanShu-colored 配置

### 5. 史记卷六·现代 ⏭️ (跳过)
- 使用 cn-vbook 类（现代竖排），不属于 guji-digital 范畴

## 印章问题 (已知问题，暂缓)
- 部分示例的印章位置有约 13.948pt 的 X 偏移
- 原因：guji.cls 的印章渲染有特殊坐标变换
- 状态：不影响核心功能，暂缓修复

## 关键发现

**guji-digital 可以两种方式使用：**

1. **语义模式** (与 guji.cls 相同):
   ```latex
   \begin{正文}
   \begin{列表}
   \夹注{...}
   \begin{段落}[indent=3]
   ```

2. **布局模式** (数字化专用):
   ```latex
   \begin{DigitalContent}
   \缩进[1]第一列内容
   \缩进[2]第二列内容
   \双列{\右小列{右}\左小列{左}}
   ```

## 原版分析

### 原版结构 (史记-guji.tex)

```
\documentclass[四库全书彩色]{ltc-guji}
├── \title{欽定四庫全書}
├── \chapter{史記\\卷一}
├── \begin{正文}
│   ├── 欽定四庫全書
│   ├── \印章[...]{文渊阁宝印.png}
│   ├── \begin{列表} (书名、作者列表)
│   ├── \begin{段落}[indent=3]
│   │   └── \夹注{...} (大段集解)
│   └── 黄帝者\夹注{...}少典之子...
└── \end{正文}
```

### 关键配置参数

| 参数 | 值 | 说明 |
|------|---|------|
| paper-width | 1136pt (40cm) | 对开页宽度 |
| paper-height | 894.6pt (31.5cm) | 页面高度 |
| n-column | 8 | 每半页列数 |
| n-char-per-col | 21 | 每列字数 |
| font-size | 28pt | 正文字号 |

## 转换策略

### 语义命令 → 布局命令映射

| guji.cls 命令 | guji-digital 等效 | 状态 |
|---------------|------------------|------|
| `\begin{正文}` | `\begin{DigitalContent}` | ✅ 可互换 |
| `\印章[...]` | `\印章[...]` | ✅ 相同 |
| `\begin{列表}` | 手动换行 + `\缩进[N]` | ✅ 可用 |
| `\begin{段落}[indent=N]` | `\缩进[N]` | ✅ 可用 |
| `\夹注{...}` | `\夹注{...}` 或 `\双列{...}` | ✅ 两者可用 |

## 验证方法

```bash
# 编译两个版本
lualatex 史记-guji.tex
lualatex 史记-digital-phase2.tex

# 生成对比图片
pdftoppm -png -r 150 史记-guji.pdf guji
pdftoppm -png -r 150 史记-digital-phase2.pdf digital

# 像素对比
compare -metric AE guji-1.png digital-1.png diff-1.png
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `史记-guji.tex` | 原版 (guji.cls) |
| `史记-digital-phase1.tex` | Phase 1: 纯文本 |
| `史记-digital-phase2.tex` | Phase 2: 语义模式复原 ✅ |
| `史记-digital-layout.tex` | Phase 3: 纯布局模式示例 ✅ |
