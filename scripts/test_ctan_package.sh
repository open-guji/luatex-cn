#!/bin/bash
# test_ctan_package.sh
# 测试 CTAN 包 (luatex-cn-ctan.zip) 是否能正常工作
# 与 test_downloaded_package.sh 类似，但适配 CTAN 包的不同结构

set -e

# Configuration
PROJECT_DIR="/home/lishaodong/workspace/luatex-cn"
CTAN_ZIP="$PROJECT_DIR/luatex-cn-ctan.zip"
EXAMPLE_DIR="$PROJECT_DIR/示例"
TEST_EXAMPLE_DIR="$PROJECT_DIR/test_example"
WORK_DIR="$TEST_EXAMPLE_DIR/ctan"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Testing CTAN Package ===${NC}"

# Step 1: Check if zip file exists
if [ ! -f "$CTAN_ZIP" ]; then
    echo -e "${RED}Error: CTAN package not found at $CTAN_ZIP${NC}"
    exit 1
fi

echo "Package: $CTAN_ZIP"
echo "Work dir: $WORK_DIR"
echo ""

# Step 2: Extract to Work directory
echo -e "${YELLOW}>>> Step 1: Extracting CTAN package...${NC}"
rm -rf "$WORK_DIR"
mkdir -p "$TEST_EXAMPLE_DIR"
mkdir -p "$WORK_DIR"
unzip -o -q "$CTAN_ZIP" -d "$WORK_DIR"
echo "Extracted to: $WORK_DIR"

# Find the tex folder in extracted package
# CTAN structure: luatex-cn/tex/...
TEX_DIR=$(find "$WORK_DIR" -type d -path "*/luatex-cn/tex" | head -1)
if [ -z "$TEX_DIR" ]; then
    echo -e "${RED}Error: Could not find luatex-cn/tex directory in package${NC}"
    echo "Directory structure:"
    find "$WORK_DIR" -type d | head -20
    exit 1
fi
echo "Found tex dir: $TEX_DIR"

# Step 3: Turn off symlinks
echo ""
echo -e "${YELLOW}>>> Step 2: Disabling development symlinks...${NC}"
cd "$PROJECT_DIR"
texlua scripts/link_texmf.lua --off

# Step 4: Copy example tex files to extracted folder and compile
echo ""
echo -e "${YELLOW}>>> Step 3: Copying examples and compiling...${NC}"

# Find all .tex files in 示例
COMPILE_SUCCESS=0
COMPILE_FAIL=0

# Create a dir for PDFs inside WORK_DIR for convenience
PDF_COLLECTION_DIR="$WORK_DIR/all_pdfs"
mkdir -p "$PDF_COLLECTION_DIR"

for example_dir in "$EXAMPLE_DIR"/*/; do
    # Find .tex file in each example directory
    for tex_file in "$example_dir"*.tex; do
        if [ -f "$tex_file" ]; then
            tex_name=$(basename "$tex_file")
            example_name=$(basename "$example_dir")

            echo ""
            echo -e "${YELLOW}Compiling: $example_name/$tex_name${NC}"

            # Copy all files from example dir to TEX_DIR (preserving assets)
            cp -r "$example_dir"* "$TEX_DIR/"

            # Compile from within the tex folder
            cd "$TEX_DIR"

            if timeout 120 lualatex -interaction=nonstopmode "$tex_name"; then
                echo -e "${GREEN}  ✓ Success${NC}"
                ((COMPILE_SUCCESS++)) || true
                # Copy PDF to collection
                pdf_name="${tex_name%.tex}.pdf"
                if [ -f "$pdf_name" ]; then
                    cp "$pdf_name" "$PDF_COLLECTION_DIR/${example_name}_${pdf_name}"
                fi
            else
                echo -e "${RED}  ✗ Failed${NC}"
                # Show last few lines of log for debugging
                if [ -f "${tex_name%.tex}.log" ]; then
                    echo "  Last error from log:"
                    tail -10 "${tex_name%.tex}.log" | head -5 | sed 's/^/    /'
                fi
                ((COMPILE_FAIL++)) || true
            fi

            # We DONT clean up anything here, as requested.
        fi
    done
done

# Step 5: Turn symlinks back on
echo ""
echo -e "${YELLOW}>>> Step 4: Re-enabling development symlinks...${NC}"
cd "$PROJECT_DIR"
texlua scripts/link_texmf.lua --on

# Summary
echo ""
echo -e "${YELLOW}=== Test Summary ===${NC}"
echo -e "Compiled successfully: ${GREEN}$COMPILE_SUCCESS${NC}"
echo -e "Failed to compile:     ${RED}$COMPILE_FAIL${NC}"
echo "Results are kept in: $WORK_DIR"

if [ $COMPILE_FAIL -eq 0 ]; then
    echo -e "\n${GREEN}All examples compiled successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some examples failed to compile.${NC}"
    exit 1
fi
