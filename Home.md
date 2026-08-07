[English Version](EN:Home) | 中文版

# LuaTeX-CN Wiki

欢迎来到 LuaTeX-CN 的用户手册。本 Wiki 涵盖了从安装到高级排版的完整文档，帮助你用 LuaTeX-CN 排版高质量的中文古籍、现代竖排书籍与符合 clreq 的现代横排文档。

> **当前版本**: [v0.4.1](https://github.com/open-guji/luatex-cn/releases) | **CTAN**: [v0.4.1](https://ctan.org/pkg/luatex-cn)

---

## 从这里开始

1. **[[安装指南 | Installation]]** — 从零安装 TeX Live 和 luatex-cn
2. **[[快速入门 | Quick-Start]]** — 5 分钟跑通你的第一个排版示例
3. **[[示例 | Examples]]** — 浏览《史记》、《红楼梦》等完整复刻

---

## 排版模式

### 竖排：四个文档类

| 文档类 | 用途 | 详情 |
|--------|------|------|
| **`ltc-guji`** | 传统古籍排版（版心、鱼尾、丝栏） | [[快速入门 \| Quick-Start]] |
| **`ltc-guji-digital`** | 古籍数字化录入：一行源码 = 一个竖排列，手工指定每列内容以精确复刻底本版面 | [源码示例](https://github.com/open-guji/luatex-cn/tree/main/test/digital_test) |
| **`ltc-cn-vbook`** | 现代中国大陆竖排书籍（标点挤压、脚注） | [[ltc-book \| ltc-book]] |
| **`ltc-tw-vbook`** | 现代台湾竖排书籍（居中标点） | [[ltc-book \| ltc-book]] |

> `ltc-book` 仍可使用，但推荐使用上述新名称。

### 横排：一个宏包

| 宏包 | 用途 | 详情 |
|------|------|------|
| **`\usepackage{luatex-cn}`（横排）** | 按 W3C clreq 排版的现代中文横排：中西间距、四级禁则、行内挤压／拉伸、行间标号与拼音、段落与孤行控制。加载到 `article` 等任意横排文档类之上，非文档类 | [[现代横排 \| Horizontal]] |

## 核心文档

### 排版基础
- [[版心与鱼尾 | Templates]] — 理解古籍排版的核心"版心"概念，预设模板与自定义
- [[字体设置 | Fonts]] — 自动探测、手动设置、字体递补链
- [[布局与功能 | Features]] — 章节标题、目录条目及布局控制
- [[现代横排 | Horizontal]] — `\usepackage{luatex-cn}`：clreq 横排管道、选项与命令
- [clreq 符合度矩阵](https://github.com/open-guji/luatex-cn/blob/main/docs/CLREQ-CONFORMANCE.md) — 逐条款的横竖排符合状态、证据与有意偏离

### 标点与句读
- [[标点系统 | Punctuation]] — 现代标点挤压、禁则处理，中国大陆/台湾风格
- [[句读 | Judou]] — 传统句读标记（句/读/白文三种模式）

### 注释系统
- [[夹注与侧批 | Side-Note]] — 双行小字注、行间侧批
- [[批注与眉批 | Annotation]] — 页面浮动批注、顶部眉批

### 装饰与辅助
- [[改字与装饰 | Correction]] — 勘误改字、专名号、书名号、着重号
- [[抬头 | Taitou]] — 敬语抬头格式（单抬、双抬、三抬、平抬）
- [[文本框 | Textbox]] — 独立文本框、绝对定位
- [[印章 | Seal]] — 电子印章叠加

### 调试与参考
- [[调试模式 | Debug]] — 网格可视化与排版调试
- **[[命令索引 | Command-Reference]]** — 全部命令、环境及参数的速查表

---

## 开发者文档

- [[架构与开发 | Development]] — 三阶段渲染引擎、源码结构
- [[版本发布规范 | Release]] — 发布流程与 CI/CD
- [[更新日志 | Changelog]] — 版本历史

---

## 联系方式

- **联系人**: Sheldon Li（sheldonli.dev@gmail.com）、Frank Lin（ctan@linshuang.info）
- **Issue**: [GitHub Issues](https://github.com/open-guji/luatex-cn/issues)
