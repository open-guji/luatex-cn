# 命名规范：选项名、取值与中文译名（issue #85）

> 新增或修改任何 key（`\keys_define:nn`）之前先读本文。
> 取值对照表的唯一来源是 `tex/shared/luatex-cn-zh-values.sty`，本文只摘要。

## 1. 三层名字

| 层 | 规范 | 例子 |
|----|------|------|
| 英文 key | 小写 kebab-case，名词或名词短语；它是规范名，Lua 侧与文档以它为准 | `page-number-position`、`outer-border` |
| 中文 key | 简体、繁体各一个（同形只写一次）；尽量用 `.meta:n = { 英文key = {#1} }` 转发 | `页码位置` / `頁碼位置` |
| 取值 | 英文值是规范值；中文值**不在模块里手写**，统一走对照表 | `页码位置=外侧` → `outer` |

### 中文 key 的两种写法

- 选项（choice）、长度、颜色等：一律 `.meta:n` 转发到英文 key，这样中文取值、默认值、
  校验都只在英文 key 上维护一次。
- 布尔开关：可以 `.bool_set:N` 直接绑同一个变量（这样单写 `\设置{边框}` 不带值仍是 true；
  `.meta:n` 转发时若无值会传空串）。这类中文 key 要一起登记到取值启用列表里。

## 2. 中文取值：一张表 + 一行启用

```latex
% 模块文件末尾（\endinput 之前）
\ExplSyntaxOn
\RequirePackage{shared/luatex-cn-zh-values}
\luatexcn_zh_values_enable:nn { luatexcn / column }
  { align , last , auto-width , 末行 , 自动宽度 , 自動寬度 }
\ExplSyntaxOff
```

- 给列出的 choice / 布尔 key 装上 `unknown` 兜底：英文值照常直达；其他值查对照表，
  取第一个该 key 真正接受的候选英文值（`\keys_if_choice_exist:nnnT`）；查不到报
  `选项 'x' 不接受值 'y'` 错误。
- 同一个中文词可以对应多个候选，按 key 自动挑：`无` → `none`（单列、标点风格）或
  `false`（布尔开关）；`撑满` → `stretch`（行对齐）或 `justify`（末行对齐）。
- **新增 choice / 布尔 key 必须登记**，`python3 test/zh_value_test.py` 会扫源码检查。
- **新增中文取值只改对照表**，不要写 `key / 中文 .code:n`（#85 之前书耳、横对齐、
  反白断口、封面小字位置各写了一份，已统一删除）。
- 自由文本 key（`.tl_set:N`，如 textflow 的 `align`）不经过此机制。

## 3. 取值对照表（摘要）

| 中文写法（简 / 繁 / 同义） | 英文值 |
|------|------|
| 是、真、开/開、开启/開啟、启用/啟用 | `true` |
| 否、假、关/關、关闭/關閉、禁用 | `false` |
| 无/無 | `none`，否则 `false` |
| 上、顶/頂、顶部/頂部、顶端/頂端 | `top` |
| 下、底、底部、底端 | `bottom` |
| 左、居左、左侧/左側 | `left` |
| 右、居右、右侧/右側 | `right` |
| 中、居中、中间/中間 | `center` |
| 两侧/兩側、两边/兩邊 | `both` |
| 撑满/撐滿、拉伸、分散 | `stretch`，否则 `justify` |
| 两端对齐/兩端對齊 | `justify` |
| 内侧/內側、内/內、书脊侧/書脊側 | `inner` |
| 外侧/外側、外、切口侧/切口側 | `outer` |
| 纸张/紙張、纸/紙、页面/頁面 | `paper` |
| 内容区/內容區 | `content` |
| 随后/隨後、紧随/緊隨 | `follow` |
| 直角、方、方形 | `square` |
| 八角、八角形 | `octagon` |
| 大陆/大陸、内地/內地 | `mainland` |
| 台湾/臺灣/台灣 | `taiwan` |
| 旧式/舊式、无条件/無條件 | `legacy` |
| 上下文、按上下文 | `context` |
| 自然、不调整/不調整 | `natural` |
| 压缩/壓縮、挤压/擠壓 | `compress` |
| 缩减/縮減 | `trim` |
| 基本 / 国标/國標 / 严格/嚴格 | `basic` / `gb` / `strict` |
| 保持、不变/不變、原样/原樣 | `keep` |
| 自动/自動 | `auto` |
| 弯引号/彎引號 / 直角引号/直角引號 | `curly` / `corner` |

## 4. 术语依据

译名优先取国家/行业标准，其次取古籍版本学通行用语，避免各模块各译各的。

| 来源 | 用途 |
|------|------|
| CY/T 50-2008《出版术语》 | 版心、页边、天头、地脚、书眉、页码、扉页、书名页、竖排、分栏、通栏 |
| CY/T 121-2015 学术出版规范·注释 | 夹注（interlinear note）、边注/旁注（side note）、脚注 |
| CY/T 124-2015 学术出版规范·古籍整理 | 断句/句读、标点 |
| W3C clreq《中文排版需求》 | 标点挤压、禁则、中西间距、行首行尾、夹注符号、点号 |
| 瞿冕良《中国古籍版刻辞典》 | 鱼尾、象鼻、书耳、版框/边栏、四周双边、牌记、墨围、眉批 |

项目内已定的对应（新增功能沿用，不要另造）：

| 中文 | 英文 key / 命令前缀 | 备注 |
|------|------|------|
| 版心 | `banxin` | 古籍书口；不要与 CY/T 50 的 print area 混用 |
| 鱼尾 / 上鱼尾 / 下鱼尾 | `yuwei` / `upper-yuwei` / `lower-yuwei` | |
| 书耳 | `book-ear` | 边栏外上角小框（#87） |
| 夹注 | `jiazhu`（引擎层 `textflow`） | 双行小注 |
| 批注 / 眉批 / 侧批 | `pizhu` / `meipi` / `sidenote` | |
| 句读 | `judou` | |
| 边框 / 外边框 | `border` / `outer-border` | 即版框、边栏 |
| 页码 / 页眉（书眉） | `page-number` / `header` | 横排书的书眉在 vbook 里叫页眉 |
| 内侧 / 外侧 | `inner` / `outer` | 内侧 = 书脊侧，外侧 = 切口侧 |
| 标点风格 | `style`（`punct-style`） | 大陆 / 台湾 / 无 |
| 禁则 | `kinsoku` / `kinsoku-level` | clreq 用语 |
| 中西间距 | `western-space`（竖排）/ `cjk-latin-space`（横排） | 历史原因两名并存，中文名统一 |
