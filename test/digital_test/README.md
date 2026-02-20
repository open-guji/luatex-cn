# guji-digital 复原测试

本目录用于测试 guji-digital 文档类复原 guji.cls 排版效果。

## 目标

以 `示例/史记五帝本纪/史记.tex` 为原型，用 guji-digital 重新排版，逐步达到：

1. **Phase 1**: 文字内容相同
2. **Phase 2**: 分页、分列、缩进相同
3. **Phase 3**: 夹注（双列）复原
4. **Phase 4**: 字体、字号、边距、版心完全一致

## 文件说明

| 文件 | 说明 |
|------|------|
| `史记-guji.tex` | 原版 guji.cls 版本（复制自示例） |
| `史记-digital-phase1.tex` | Phase 1: 纯文本内容 |
| `史记-digital-phase2.tex` | Phase 2: 布局结构（分页分列） |
| `史记-digital-phase3.tex` | Phase 3: 夹注双列 |
| `史记-digital-final.tex` | Phase 4: 完全复原 |

## 运行测试

```bash
cd test/digital_test
lualatex 史记-guji.tex
lualatex 史记-digital-final.tex
```

## 对比方法

1. 视觉对比：并排查看 PDF
2. 像素对比：`pdftoppm` 转图片后用 `compare` 工具
