[English Version](EN:Examples) | 中文版

# 示例

以下示例展示了 `luatex-cn` 从传统古籍到现代竖排的排版能力。每个示例都可以直接下载源码编译。

> 如果你还没跑通第一个示例，建议先看 [[快速入门 | Quick-Start]]。

---

## 1. 史记·五帝本纪 — 四库全书排版

**文档类**: `guji` | **模板**: `四库全书` / `四库全书彩色`

| 黑白仿真 | 彩色预览 |
| :---: | :---: |
| ![史记黑白](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/shiji-bw.png) | ![史记彩色](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/shiji-color.png) |

**演示功能**：
- 版心与单鱼尾（`\banxinSetup`）
- 复杂夹注（`\夹注{...}`）— 自动平衡、跨列跨页
- 印章绝对定位（`\印章[page=1]{...}`）
- 乌丝栏边框与排版缩进

📂 [查看源码](https://github.com/open-guji/luatex-cn/tree/main/示例/史记五帝本纪) ｜ 📄 [查看 PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/史记五帝本纪/史记.pdf)

---

## 2. 史记目录 — 四库全书目录页

**文档类**: `guji` | **模板**: `四库全书`

**演示功能**：
- 标准古籍目录布局（`\条目` 命令）
- "八行二十一字"的行款限制
- 白口、四周双边、单鱼尾版式

📂 [查看源码](https://github.com/open-guji/luatex-cn/tree/main/示例/史记目录)

---

## 3. 红楼梦甲戌本 — 手抄批改本

**文档类**: `guji` | **模板**: `红楼梦甲戌本`

| 第二页（标点） | 第一页（眉批） |
| :---: | :---: |
| ![红楼梦2](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/honglou-p2.png) | ![红楼梦1](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/honglou-p1.png) |

**演示功能**：
- 侧批（`\侧批{...}`）— 行间红色批注
- 眉批（`\眉批{...}`）— 页面顶部批注，自动排列
- 夹注（`\夹注{...}`）— 双行小字
- 句读模式（`\句读模式`）— 传统句/读标记
- 无鱼尾版心，底部页号

📂 [查看源码](https://github.com/open-guji/luatex-cn/tree/main/示例/红楼梦甲戌本) ｜ 📄 [查看 PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/红楼梦甲戌本/石头记.pdf)

---

## 4. 史记·秦楚之际月表 — 现代繁体竖排

**文档类**: `cn-vbook` | **模板**: `中华书局`

| 第一页 | 第二页 |
| :---: | :---: |
| ![卷十六第一页](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/juan16-p1.png) | ![卷十六第二页](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/juan16-p2.png) |

**演示功能**：
- 现代标点挤压（`\punctSetup{punct-squeeze=true}`）
- 禁则处理（`\punctSetup{kinsoku=true}`）
- 脚注系统（`\脚注{...}`）— 鹿角编号
- 段落缩进（`\begin{段落}[indent=2]`）
- 大陆标点风格

📂 [查看源码](https://github.com/open-guji/luatex-cn/tree/main/示例/史记卷六·现代) ｜ 📄 [查看 PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/史记卷六·现代/卷十六.pdf)

---

## 功能对照表

| 功能 | 史记五帝本纪 | 史记目录 | 红楼梦甲戌本 | 现代竖排 |
|------|:-----------:|:-------:|:-----------:|:-------:|
| 版心/鱼尾 | ✅ | ✅ | ✅(无鱼尾) | — |
| 夹注 | ✅ | — | ✅ | — |
| 侧批 | — | — | ✅ | — |
| 眉批 | — | — | ✅ | — |
| 印章 | ✅ | — | — | — |
| 句读 | — | — | ✅ | — |
| 现代标点 | — | — | — | ✅ |
| 脚注 | — | — | — | ✅ |
| 目录条目 | — | ✅ | — | — |

---

## 如何运行示例

1. 下载或克隆项目仓库
2. 进入示例目录，如 `示例/史记五帝本纪/`
3. 运行 `lualatex 史记.tex`
4. 打开生成的 PDF 查看效果

```bash
cd 示例/史记五帝本纪
lualatex 史记.tex
```

---

*所有古籍示例均基于历史文献扫描件进行数字重构，旨在展示 `luatex-cn` 对各种复杂竖排场景的适配能力。*
