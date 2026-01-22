
下面我们来记录一下后面要做的一些事情
https://github.com/open-guji/luatex-cn/issues/28

see the picture in this issue. try to replicate that. we alredy have titlepage. continue this feature

## 进度记录 (2026-02-09)

### 已完成
1. **outer-cols 功能** - 已实现并测试通过
   - TextBox 新增 `outer-cols` 参数，控制外部占用的网格列数
   - 文件: `tex/core/luatex-cn-core-textbox.sty`, `tex/core/luatex-cn-core-textbox.lua`
   - 测试: `test_example/progress/outer-cols-test.tex`

2. **书名页样式原型** - 可以使用 outer-cols 实现不同列宽
   - 测试文件: `test_example/progress/titlepage-issue28-v3.tex`
   - 效果：日期(右上)、书名(中央大字)、出版信息(左下) ✓

### 待完成
1. 将 outer-cols 集成到 `书名页` 环境，支持 `column-widths` 参数
2. 添加书名页装饰边框支持
3. 页面居中布局选项


 


