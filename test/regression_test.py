#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys
import argparse
import re
from pathlib import Path
from PIL import Image
import numpy as np

# Paths relative to the project root
BASE_DIR = Path(__file__).parent.parent.resolve()
REG_DIR = BASE_DIR / "test" / "regression_test"
TEX_DIR = REG_DIR / "tex"
PDF_DIR = REG_DIR / "pdf"
BASELINE_DIR = REG_DIR / "baseline"
CURRENT_DIR = REG_DIR / "current"
DIFF_DIR = REG_DIR / "diff"
DIFF_THRESHOLD = 10

import concurrent.futures
import multiprocessing

def run_command(cmd, cwd=None, capture=True, log_list=None):
    msg = f"Running: {' '.join(cmd)}"
    if log_list is not None:
        log_list.append(msg)
    else:
        print(msg)
        
    if capture:
        result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    else:
        result = subprocess.run(cmd, cwd=cwd)
    return result

def compile_tex(tex_file, log_list):
    """Compile TeX file to PDF in the PDF_DIR."""
    ex_name = tex_file.name
    pdf_name = tex_file.stem + ".pdf"
    
    # We run lualatex twice to ensure correct layout (typical for guji)
    for i in range(2):
        log_list.append(f"Compilation pass {i+1} for {ex_name}...")
        res = run_command([
            "lualatex", 
            "-interaction=nonstopmode", 
            f"-output-directory={PDF_DIR}",
            str(tex_file.name)
        ], cwd=tex_file.parent, log_list=log_list)
        
        if res.returncode != 0:
            log_list.append(f"ERROR: Compilation failed for {ex_name}")
            return False
            
    return PDF_DIR / pdf_name

def pdf_to_pngs(pdf_file, output_dir, log_list):
    """Convert all pages of PDF to PNG images using pdftoppm."""
    # Clean up old images for this file
    for old_png in output_dir.glob(f"{pdf_file.stem}-*.png"):
        old_png.unlink()
    
    output_prefix = str(output_dir / pdf_file.stem)
    res = run_command([
        "pdftoppm", "-png", "-r", "300", 
        str(pdf_file), output_prefix
    ], log_list=log_list)
    if res.returncode != 0:
        log_list.append(f"ERROR: PDF to PNG conversion failed for {pdf_file.name}")
        return []
    
    # pdftoppm outputs files like name-1.png, name-2.png... (or name-01.png depending on page count)
    # We'll just glob them.
    pngs = sorted(list(output_dir.glob(f"{pdf_file.stem}-*.png")), 
                  key=lambda x: int(re.search(r'-(\d+)\.png$', x.name).group(1)))
    return pngs

def compare_images(baseline_png, current_png, diff_png, log_list):
    """Compare two PNG images and generate a single composite diff image.

    Composite: identical pixels in gray, baseline-only diffs in blue,
    current-only diffs in red, overlapping diffs in purple/dark.
    """
    baseline_img = Image.open(baseline_png).convert("RGB")
    current_img = Image.open(current_png).convert("RGB")

    # Ensure same size (pad smaller if needed)
    w = max(baseline_img.width, current_img.width)
    h = max(baseline_img.height, current_img.height)
    if baseline_img.size != (w, h):
        padded = Image.new("RGB", (w, h), (255, 255, 255))
        padded.paste(baseline_img, (0, 0))
        baseline_img = padded
    if current_img.size != (w, h):
        padded = Image.new("RGB", (w, h), (255, 255, 255))
        padded.paste(current_img, (0, 0))
        current_img = padded

    baseline_arr = np.array(baseline_img)
    current_arr = np.array(current_img)

    # Find pixels that differ (any channel)
    diff_mask = np.any(baseline_arr != current_arr, axis=2)
    diff_count = int(np.sum(diff_mask))

    if diff_count > 0:
        # Grayscale luminance
        b_gray = np.mean(baseline_arr, axis=2)
        c_gray = np.mean(current_arr, axis=2)

        # Same pixels: grayscale
        result = np.stack([b_gray, b_gray, b_gray], axis=2).astype(np.uint8)

        # Different pixels: blue (baseline) + red (current) on white background
        # Darkness = content strength: 0 = white/empty, 255 = black/full
        bs = (255 - b_gray[diff_mask]).astype(np.float32)
        cs = (255 - c_gray[diff_mask]).astype(np.float32)

        # Blue subtracts from R,G; Red subtracts from G,B
        result[diff_mask, 0] = np.clip(255 - bs, 0, 255).astype(np.uint8)
        result[diff_mask, 1] = np.clip(255 - bs - cs, 0, 255).astype(np.uint8)
        result[diff_mask, 2] = np.clip(255 - cs, 0, 255).astype(np.uint8)

        diff_img = Image.fromarray(result)
        diff_img.save(str(diff_png))

    return diff_count

def process_file(tex_file, mode):
    log_list = [f"\nProcessing {tex_file.name}..."]
    
    # 1. Compile
    pdf_file = compile_tex(tex_file, log_list)
    if not pdf_file or not pdf_file.exists():
        return False, "Compilation failed", log_list
    
    if mode == "save":
        # 2. Convert to PNGs in a temp location first (use CURRENT_DIR as temp)
        new_pngs = pdf_to_pngs(pdf_file, CURRENT_DIR, log_list)
        if not new_pngs:
            return False, "PNG conversion failed", log_list
        
        # 3. Check if baselines already exist and compare
        existing_baselines = sorted(list(BASELINE_DIR.glob(f"{pdf_file.stem}-*.png")), 
                                    key=lambda x: int(re.search(r'-(\d+)\.png$', x.name).group(1)))
        
        images_match = False
        if len(existing_baselines) == len(new_pngs):
            # Compare all pages
            all_match = True
            for b_png, n_png in zip(existing_baselines, new_pngs):
                diff_png = DIFF_DIR / f"temp_diff_{n_png.name}"
                diff_count = compare_images(b_png, n_png, diff_png, log_list)
                if diff_png.exists(): 
                    diff_png.unlink()
                if diff_count != 0:
                    all_match = False
                    break
            images_match = all_match
        
        if images_match:
            # Images are identical - delete PDF and current PNGs
            log_list.append(f"No visual changes - deleting PDF for {tex_file.name}")
            # Delete temp PNGs
            for png in new_pngs:
                png.unlink()
            # Clean up corresponding diff files (from previous failed checks)
            for diff_png in DIFF_DIR.glob(f"diff_{pdf_file.stem}-*.png"):
                diff_png.unlink()
            # Delete PDF (we already have PNG files)
            if pdf_file.exists():
                pdf_file.unlink()
            return True, f"No changes ({len(existing_baselines)} pages)", log_list
        else:
            # Images differ - move new PNGs to baseline and keep new PDF
            # Clean up old baselines
            for old_png in existing_baselines:
                old_png.unlink()
            # Move new PNGs to baseline
            for png in new_pngs:
                shutil.move(str(png), str(BASELINE_DIR / png.name))
            # Clean up corresponding diff files
            for diff_png in DIFF_DIR.glob(f"diff_{pdf_file.stem}-*.png"):
                diff_png.unlink()
            log_list.append(f"Saved {len(new_pngs)} baseline pages.")
            return True, f"Saved {len(new_pngs)} pages", log_list
        
    elif mode == "check":
        # 2. Convert to PNGs in current
        current_pngs = pdf_to_pngs(pdf_file, CURRENT_DIR, log_list)
        if not current_pngs:
            return False, "PNG conversion failed", log_list
            
        baseline_pngs = sorted(list(BASELINE_DIR.glob(f"{pdf_file.stem}-*.png")), 
                               key=lambda x: int(re.search(r'-(\d+)\.png$', x.name).group(1)))
        
        if len(current_pngs) != len(baseline_pngs):
            return False, f"Page count mismatch: current={len(current_pngs)}, baseline={len(baseline_pngs)}", log_list
            
        total_diff_pixels = 0
        failing_pages = []
        
        for i, (b_png, c_png) in enumerate(zip(baseline_pngs, current_pngs)):
            diff_png = DIFF_DIR / f"diff_{c_png.name}"
            diff_count = compare_images(b_png, c_png, diff_png, log_list)
            
            if diff_count > 0:
                total_diff_pixels += diff_count
                failing_pages.append(i + 1)
                log_list.append(f"  Page {i+1} fails: {diff_count} pixels difference.")
            elif diff_count == 0:
                if diff_png.exists(): diff_png.unlink()
            else:
                return False, f"Comparison error on page {i+1}", log_list
        
        if total_diff_pixels == 0:
            log_list.append(f"SUCCESS: {tex_file.name} matches baseline (all {len(current_pngs)} pages).")
            # Delete current PNGs (same as baseline, no need to store)
            for png in current_pngs:
                png.unlink()
            # Delete PDF (we already have PNG files)
            if pdf_file.exists():
                pdf_file.unlink()
            return True, 0, log_list
        elif total_diff_pixels < DIFF_THRESHOLD:
            log_list.append(f"WARNING: {tex_file.name} has minor differences ({total_diff_pixels} pixels), but they are below threshold ({DIFF_THRESHOLD}). Marking as PASSED.")
            # Delete current PNGs and diff images as we consider this a pass
            for png in current_pngs:
                png.unlink()
            for i in range(len(baseline_pngs)):
                diff_png = DIFF_DIR / f"diff_{pdf_file.stem}-{i+1}.png"
                if diff_png.exists(): diff_png.unlink()
            # Delete PDF (test passed, we already have PNG files)
            if pdf_file.exists():
                pdf_file.unlink()
            return True, f"{total_diff_pixels} pixels (ignored)", log_list
        else:
            log_list.append(f"FAIL: {tex_file.name} differs on pages: {failing_pages}")
            return False, f"{total_diff_pixels} total pixels diff", log_list

def main():
    parser = argparse.ArgumentParser(description="Multi-page Visual Regression Test for luatex-cn")
    parser.add_argument("command", choices=["save", "check"], help="Command to run")
    parser.add_argument("files", nargs="*", help="Specific TeX files to process (optional)")
    parser.add_argument("-j", "--jobs", type=int, default=multiprocessing.cpu_count(), 
                        help="Number of parallel jobs (default: number of CPUs)")
    args = parser.parse_args()

    # Ensure directories exist
    for d in [PDF_DIR, BASELINE_DIR, CURRENT_DIR, DIFF_DIR]:
        d.mkdir(parents=True, exist_ok=True)

    # Find TeX files
    if args.files:
        tex_files = []
        for f in args.files:
            # 1. Try as direct path (absolute or relative to CWD)
            p = Path(f)
            if p.exists() and p.is_file():
                tex_files.append(p.resolve())
                continue
            
            # 2. Try as relative to TEX_DIR
            p_in_tex = TEX_DIR / f
            if p_in_tex.exists() and p_in_tex.is_file():
                tex_files.append(p_in_tex)
                continue
                
            # 3. Search recursively in TEX_DIR
            found = list(TEX_DIR.rglob(f))
            if not found and not f.endswith(".tex"):
                found = list(TEX_DIR.rglob(f + ".tex"))
            
            if found:
                tex_files.extend(found)
            else:
                print(f"Warning: File '{f}' not found as direct path or in {TEX_DIR}")
    else:
        tex_files = list(TEX_DIR.glob("*.tex"))

    if not tex_files:
        print(f"No TeX files found in {TEX_DIR}")
        return

    results = []
    all_passed = True
    
    print(f"Running with {args.jobs} parallel jobs...")
    
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.jobs) as executor:
        future_to_file = {executor.submit(process_file, f, args.command): f for f in tex_files}
        for future in concurrent.futures.as_completed(future_to_file):
            tex_file = future_to_file[future]
            try:
                success, info, log = future.result()
                # Print the buffered log at once to keep it together
                print("\n".join(log))
                results.append((tex_file.name, success, info))
                if not success:
                    all_passed = False
            except Exception as exc:
                print(f"{tex_file.name} generated an exception: {exc}")
                results.append((tex_file.name, False, f"Exception: {exc}"))
                all_passed = False

    print("\n" + "="*40)
    print(f"REGRESSION {args.command.upper()} SUMMARY")
    print("="*40)
    # Sort results by name for consistency
    results.sort(key=lambda x: x[0])
    for name, success, info in results:
        status = "PASSED" if success else "FAILED"
        print(f"{status:8} {name:20} (Info: {info})")
    print("="*40)

    # Clean up: delete all files in PDF_DIR after save or check
    for f in PDF_DIR.iterdir():
        if f.is_file():
            f.unlink()
    print(f"Cleaned up {PDF_DIR}")

    if not all_passed:
        sys.exit(1)

if __name__ == "__main__":
    main()
