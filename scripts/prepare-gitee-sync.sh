#!/bin/bash
set -e

GIT_USER_NAME=${1:-"github-actions[bot]"}
GIT_USER_EMAIL=${2:-"github-actions[bot]@users.noreply.github.com"}

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

# Save main branch SHA before switching
MAIN_SHA=$(git rev-parse main)

# Create a clean orphan branch (no history)
git checkout --orphan gitee-sync

# Remove all staged files from the orphan index
git rm -rf . 2>/dev/null || true

# Restore all files from main using the saved SHA
git checkout "$MAIN_SHA" -- .

# Remove README variants to keep the mirror root clean
git rm -f README-CN.md README-EN.md 2>/dev/null || true

# Prepend mirror notice and replace GitHub references with Gitee in README
{
  cat <<'EOF'
# lu·atex-cn (Gitee 镜像)

这是 luatex-cn 项目的 Gitee 镜像仓库。由于平台限制，完整的文档与更新指引请参考 GitHub 同名仓库：https://github.com/open-guji/luatex-cn

---

EOF
  cat README.md
} > README.md.new

# Replace GitHub with Gitee in URLs and text
sed -e 's|github.com|gitee.com|g' \
    -e 's|GitHub|Gitee|g' \
    -e 's|github|gitee|g' README.md.new > README.md

rm README.md.new
git add README.md

# Commit
git commit -m "Sync current version to Gitee (fresh history)"
