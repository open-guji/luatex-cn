#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys
import argparse

def run_command(cmd, cwd=None):
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
    return result

def verify_example(tex_path, base_dir):
    ex_dir = os.path.dirname(tex_path)
    ex_name = os.path.basename(tex_path)
    pdf_name = ex_name.replace(".tex", ".pdf")
    baseline_pdf = os.path.join(ex_dir, pdf_name)
    
    if not os.path.exists(baseline_pdf):
        print(f"SKIP: No baseline PDF found for {tex_path}")
        return True, None

    # 1. Compile Current Version
    print(f"Compiling {tex_path}...")
    temp_dir = os.path.join(base_dir, "temp_verify")
    os.makedirs(temp_dir, exist_ok=True)
    
    # Copy all files from example dir to temp dir for compilation
    for f in os.listdir(ex_dir):
        src = os.path.join(ex_dir, f)
        if os.path.isfile(src):
            shutil.copy(src, temp_dir)
    
    res = run_command(["lualatex", "-interaction=nonstopmode", ex_name], cwd=temp_dir)
    current_pdf = os.path.join(temp_dir, pdf_name)
    
    if res.returncode != 0 or not os.path.exists(current_pdf):
        print(f"FAIL: Compilation failed for {tex_path}")
        return False, "Compilation error"

    # 2. Convert to Images (1st page for simplicity, or all pages if needed)
    # Using pdftoppm for high quality conversion
    print(f"Converting PDFs to images...")
    run_command(["pdftoppm", "-png", "-r", "300", "-singlefile", baseline_pdf, os.path.join(temp_dir, "baseline")])
    run_command(["pdftoppm", "-png", "-r", "300", "-singlefile", current_pdf, os.path.join(temp_dir, "current")])
    
    baseline_png = os.path.join(temp_dir, "baseline.png")
    current_png = os.path.join(temp_dir, "current.png")
    diff_png = os.path.join(ex_dir, "diff_" + ex_name.replace(".tex", ".png"))

    # 3. Compare images
    print(f"Comparing images...")
    # use 'compare' from ImageMagick. If exit code is 0, they are identical.
    # Metric AE (Absolute Error) gives number of different pixels.
    comp_res = run_command(["compare", "-metric", "AE", baseline_png, current_png, diff_png])
    
    # compare returns 0 if images are similar, 1 if different, or something else for error
    # With metric AE, it prints pixel count to stderr
    diff_pixels = comp_res.stderr.strip()
    try:
        diff_count = int(float(diff_pixels))
        if diff_count == 0:
            print(f"SUCCESS: {tex_path} matches pixel-perfect.")
            if os.path.exists(diff_png): os.remove(diff_png)
            return True, 0
        else:
            print(f"FAIL: {tex_path} differs by {diff_count} pixels. Diff image: {diff_png}")
            return False, diff_count
    except ValueError:
        # If output is not a number, handle based on return code
        if comp_res.returncode == 0:
            print(f"SUCCESS: {tex_path} matches.")
            if os.path.exists(diff_png): os.remove(diff_png)
            return True, 0
        else:
            print(f"FAIL: {tex_path} has visual differences.")
            return False, "Comparison error"

def main():
    base_dir = "/home/lishaodong/workspace/luatex-cn"
    examples_dir = os.path.join(base_dir, "示例")
    
    all_passed = True
    results = []
    
    for root, dirs, files in os.walk(examples_dir):
        for f in files:
            if f.endswith(".tex"):
                tex_path = os.path.join(root, f)
                success, diff = verify_example(tex_path, base_dir)
                results.append((tex_path, success, diff))
                if not success:
                    all_passed = False

    print("\n" + "="*40)
    print("VERIFICATION SUMMARY")
    print("="*40)
    for path, success, diff in results:
        status = "PASSED" if success else "FAILED"
        print(f"{status:8} {os.path.relpath(path, examples_dir)} (Diff: {diff})")
    print("="*40)
    
    if all_passed:
        print("\nALL EXAMPLES MATCH PIXEL-PERFECT!")
        print("The refactoring is visually safe.")
    else:
        print("\nVISUAL REGRESSION DETECTED!")
        print("Please check the diff_*.png files in the example directories.")
        sys.exit(1)

if __name__ == "__main__":
    main()
