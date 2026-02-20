#!/bin/bash
set -e

GIT_USER_NAME=${1:-"github-actions[bot]"}
GIT_USER_EMAIL=${2:-"github-actions[bot]@users.noreply.github.com"}

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

# Create and switch to gitee branch
git checkout -b gitee || git checkout gitee
git reset --hard main

# Create temporary file with header and original README
cat <<EOF > README.md.temp
# lu·atex-cn (Gitee 镜像)

这是 luatex-cn 项目的 Gitee 镜像仓库。由于平台限制，完整的文档与更新指引请参考 GitHub 同名仓库。

EOF

cat README.md >> README.md.temp

# Process the entire file to replace GitHub with Gitee
# 1. Replace github.com with gitee.com in URLs
# 2. Replace GitHub with Gitee in text
# 3. Replace github with gitee in lowercase text
sed -e 's|github.com|gitee.com|g' \
    -e 's|GitHub|Gitee|g' \
    -e 's|github|gitee|g' README.md.temp > README.md

rm README.md.temp

# Remove README variants to keep the mirror root clean
rm -f README-CN.md README-EN.md

# Update index
git add README.md
git rm --cached README-CN.md README-EN.md 2>/dev/null || true

# Commit changes
if git diff --staged --quiet; then
  echo "No changes to commit"
else
  git commit -m "Sync to Gitee (replace GitHub with Gitee in README)"
fi
