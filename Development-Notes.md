[English Version](EN:Development-Notes) | 中文版

# 开发须知

面向贡献者的实操注意事项，重点是**测试字体与基线的可复现性**。架构与测试体系的完整介绍见 [[架构与开发 | Development]]。

---

## 1. 测试字体是「钉定」的，不来自你的系统

- 唯一事实来源是 `scripts/font-manifest.json`：每个字体的固定下载 URL、SHA-256、版本、授权都在这里。
- `python3 scripts/download_fonts.py --all` 按 manifest 下载到 `test/fonts/`（gitignored），**从不安装进系统字体库**。
- `regression_test.py` 会把 `OSFONTDIR` 指向 `test/fonts/`，让 luaotfload 找到这些文件。
- 回归比较是**逐像素零容差**：字体钉定后，mac 与 CI (Linux) 的渲染逐字节一致，任何像素差都是真回归。

## 2. ⚠️ 本机装过同名字体时，版本必须与 manifest 一致

这是最容易踩、症状最迷惑的坑。

**机制**：测试 .tex 里按**名字**引用的字体（如 `\setmainfont{Source Han Serif SC}`），luaotfload 名字索引会**优先命中你系统里已装的副本**（如 `~/Library/Fonts/SourceHanSerif.ttc`），而不是 `test/fonts/` 里钉定的文件。若两者版本不同，你本机存出的基线就和 CI 对不上。

**真实案例（2026-08）**：开发机装的思源宋体是 2.002，manifest 钉定 2.003。Adobe 在两版之间修改了 91 个基本区汉字的轮廓（含「大」「天」「女」），在 2.002 下重存的基线推上去后，CI 在用到这些字的页面上报出 0.005% 级像素差（笔画边缘一圈灰度不同）。

**症状特征**：CI 失败但差异极小（<0.01%）；diff 图上肉眼几乎看不出；差异像素集中在个别汉字的笔画边缘。

**诊断**：

```bash
# 本机名字解析落到了哪个文件
luaotfload-tool --find="Source Han Serif SC"

# 对比版本（fontTools）
python3 -c "
from fontTools.ttLib import TTCollection
tc = TTCollection('$HOME/Library/Fonts/SourceHanSerif.ttc')
print(tc.fonts[12]['name'].getDebugName(5))"
python3 -c "
from fontTools.ttLib import TTFont
print(TTFont('test/fonts/SourceHanSerifSC-Regular.otf')['name'].getDebugName(5))"
```

**处理**：把本机字体升级/替换为与 manifest 同版（当前要求：**思源宋体 2.003R**，Super OTC 在 [adobe-fonts/source-han-serif 2.003R release](https://github.com/adobe-fonts/source-han-serif/releases/tag/2.003R) 的 `01_SourceHanSerif.ttc.zip`），然后 `luaotfload-tool --update` 刷新索引。没装同名系统字体的机器不受影响。

> 按**文件名**引用的用例（如 `hori.tex` 的 `\setmainfont{SourceHanSerifSC-Regular.otf}`）不受此影响——文件查找只会命中 `test/fonts/` 里钉定的那份。

## 3. 更新基线（save）的规矩

- `save` 支持显式传文件，且会按文件所属套件自动路由（basic / past_issue / complete），基线存进对应套件的 `baseline/`：

  ```bash
  python3 test/regression_test.py save test/regression_test/complete/tex/font.tex
  ```

- **save 之前先想清楚差异从哪来**：是你的改动应有的效果，还是环境（字体版本！）造成的漂移。只有前者才应该重存。
- 重存后跑一遍全量确认：`python3 test/regression_test.py check --all`。
- **CI 只跑 basic 套件**——past_issue 和 complete 的基线只有本地 `--all` 能守住，改动渲染路径后务必本地全量跑过再提交。

## 4. 测试顺序（必须遵守）

```bash
texlua test/run_all.lua                      # 1. unit test（先）
python3 test/regression_test.py check --all  # 2. 回归（后）
python3 test/clreq_test.py                   # 3. clreq 度量断言（横排/竖排规范符合性）
python3 test/geometry_test.py                # 4. 几何自校验（不依赖基线）
```

改动会影响 unit test 结果时，必须同步更新对应测试；不允许跳过 unit test 直接跑回归。

## 5. 字体授权底线

- 测试与示例只使用**来源与授权可确认**的字体（OFL、Arphic PL、CC0、政府开放授权等），一律经 manifest 钉定。
- 示例 PDF 会内嵌字体子集并随仓库分发——**入库前用 `pdffonts` 检查内嵌字体**，确认没有授权不明的字体混入。
- 新增字体：在 manifest 加条目（URL 需不可变、附 SHA-256 与授权），不要手工复制文件。授权评估参考 `ai_must_read/docs/font-metrics.md`。
