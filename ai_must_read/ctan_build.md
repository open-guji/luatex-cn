总是使用l3build

创建一个github action。把整个项目按照CTAN标准去打包。打包过程中，只保留下面几个文件夹，并且把所有的路径都转换为中文。。

- src
- 文档 -> doc
- 示例 -> example

文件名的翻译按照 scripts/file_name_translation.json 严格转换。

转换完成之后的内容，以及打包的zip文件，推送到ctan分支下面