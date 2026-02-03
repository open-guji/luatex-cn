#!/bin/bash
# 清理 LaTeX 编译产生的临时文件

cd "$(dirname "$0")/.."

# LaTeX 临时文件扩展名
extensions=(
    "log" "aux" "bbl" "blg" "fdb_latexmk" "fls"
    "idx" "ilg" "ind" "lof" "lot" "out"
    "synctex.gz" "toc" "xdy" "glo" "gls" "glg"
    "acn" "acr" "alg" "bcf" "run.xml"
    "figlist" "makefile" "auxlock"
)

count=0
for ext in "${extensions[@]}"; do
    while IFS= read -r -d '' file; do
        rm -f "$file"
        echo "删除: $file"
        ((count++))
    done < <(find . -path "./build" -prune -o -name "*.$ext" -type f -print0 2>/dev/null)
done

echo "---"
echo "共删除 $count 个文件"
