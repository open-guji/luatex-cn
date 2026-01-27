#!/bin/bash
# test_downloaded_package.sh
# 测试下载的发布包是否能正常工作

set -e

# Configuration
DOWNLOAD_DIR="/mnt/c/Users/lisdp/Downloads"
PROJECT_DIR="/home/lishaodong/workspace/luatex-cn"
EXAMPLE_DIR="$PROJECT_DIR/示例"
TEMP_DIR="/tmp/luatex-cn-test-$$"

# Auto-detect latest luatex-cn-tex zip file
DOWNLOAD_ZIP=$(ls -t "$DOWNLOAD_DIR"/luatex-cn-tex*.zip 2>/dev/null | head -1)
if [ -z "$DOWNLOAD_ZIP" ]; then
    echo -e "${RED}Error: No luatex-cn-tex*.zip found in $DOWNLOAD_DIR${NC}"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Testing Downloaded Package ===${NC}"
echo "Package: $DOWNLOAD_ZIP"
echo "Temp dir: $TEMP_DIR"
echo ""

# Step 1: Check if zip file exists
if [ ! -f "$DOWNLOAD_ZIP" ]; then
    echo -e "${RED}Error: Package not found at $DOWNLOAD_ZIP${NC}"
    exit 1
fi

# Step 2: Create temp directory and extract
echo -e "${YELLOW}>>> Step 1: Extracting package...${NC}"
mkdir -p "$TEMP_DIR"
unzip -q "$DOWNLOAD_ZIP" -d "$TEMP_DIR"
echo "Extracted to: $TEMP_DIR"

# Find the tex folder in extracted package
TEX_DIR=$(find "$TEMP_DIR" -type d -name "tex" | head -1)
if [ -z "$TEX_DIR" ]; then
    echo -e "${RED}Error: Could not find tex directory in package${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "Found tex dir: $TEX_DIR"

# Step 3: Turn off symlinks
echo ""
echo -e "${YELLOW}>>> Step 2: Disabling development symlinks...${NC}"
cd "$PROJECT_DIR"
texlua scripts/link_texmf.lua --off

# Step 4: Copy example tex files to temp and compile
echo ""
echo -e "${YELLOW}>>> Step 3: Copying examples and compiling...${NC}"

# Create a test directory
TEST_COMPILE_DIR="$TEMP_DIR/test_compile"
mkdir -p "$TEST_COMPILE_DIR"

# Copy tex folder to test directory (so lualatex can find the packages)
cp -r "$TEX_DIR"/* "$TEST_COMPILE_DIR/"

# Find all .tex files in 示例
COMPILE_SUCCESS=0
COMPILE_FAIL=0

for example_dir in "$EXAMPLE_DIR"/*/; do
    # Find .tex file in each example directory
    for tex_file in "$example_dir"*.tex; do
        if [ -f "$tex_file" ]; then
            tex_name=$(basename "$tex_file")
            example_name=$(basename "$example_dir")
            
            echo ""
            echo -e "${YELLOW}Compiling: $example_name/$tex_name${NC}"
            
            # Copy example files directly into the extracted tex folder
            cp -r "$example_dir"* "$TEX_DIR/"
            
            # Compile from within the tex folder
            cd "$TEX_DIR"
            
            if timeout 120 lualatex -interaction=nonstopmode "$tex_name" > /dev/null 2>&1; then
                echo -e "${GREEN}  ✓ Success${NC}"
                ((COMPILE_SUCCESS++)) || true
                # Save PDF immediately after successful compile
                pdf_name="${tex_name%.tex}.pdf"
                if [ -f "$pdf_name" ]; then
                    mkdir -p "$TEMP_DIR/pdfs"
                    cp "$pdf_name" "$TEMP_DIR/pdfs/${example_name}_${pdf_name}"
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
            
            # Clean up example files from tex folder (but PDFs already saved)
            for f in "$example_dir"*; do
                rm -f "$TEX_DIR/$(basename "$f")" 2>/dev/null || true
            done
            # Also clean up generated files
            rm -f "$TEX_DIR/${tex_name%.tex}.pdf" "$TEX_DIR/${tex_name%.tex}.log" "$TEX_DIR/${tex_name%.tex}.aux" 2>/dev/null || true
        fi
    done
done

# Step 5: Copy generated PDFs to test_example
echo ""
echo -e "${YELLOW}>>> Step 4: Copying generated PDFs to test_example...${NC}"
OUTPUT_DIR="$PROJECT_DIR/test_example/package_test_output"
mkdir -p "$OUTPUT_DIR"
if [ -d "$TEMP_DIR/pdfs" ]; then
    cp "$TEMP_DIR/pdfs"/*.pdf "$OUTPUT_DIR/" 2>/dev/null || true
    echo "PDFs copied to: $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR"/*.pdf 2>/dev/null || echo "  (no PDFs found)"
else
    echo "  (no PDFs generated)"
fi

# Step 6: Turn symlinks back on
echo ""
echo -e "${YELLOW}>>> Step 5: Re-enabling development symlinks...${NC}"
cd "$PROJECT_DIR"
texlua scripts/link_texmf.lua --on

# Step 7: Cleanup
echo ""
echo -e "${YELLOW}>>> Step 6: Cleaning up...${NC}"
rm -rf "$TEMP_DIR"

# Summary
echo ""
echo -e "${YELLOW}=== Test Summary ===${NC}"
echo -e "Compiled successfully: ${GREEN}$COMPILE_SUCCESS${NC}"
echo -e "Failed to compile:     ${RED}$COMPILE_FAIL${NC}"

if [ $COMPILE_FAIL -eq 0 ]; then
    echo -e "\n${GREEN}All examples compiled successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some examples failed to compile.${NC}"
    exit 1
fi
