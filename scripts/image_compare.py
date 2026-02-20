#!/usr/bin/env python3
"""
image_compare.py — Shared image comparison utilities for luatex-cn.

Provides:
  - pdf_to_pngs(pdf_file, output_dir, dpi=300)  → list[Path]
  - compare_images(baseline_png, current_png, diff_png) → int (diff pixel count)

Used by:
  - test/regression_test.py
  - scripts/compare_pdfs.py
"""

import re
import subprocess
from pathlib import Path

from PIL import Image
import numpy as np


def pdf_to_pngs(pdf_file: Path, output_dir: Path, dpi: int = 300) -> list:
    """Convert all pages of a PDF to PNG images using pdftoppm.

    Existing images for this PDF stem are removed before conversion.

    Args:
        pdf_file:   Path to the PDF file.
        output_dir: Directory where PNG files will be written.
        dpi:        Resolution in dots per inch (default 300).

    Returns:
        Sorted list of Path objects for the generated PNG files,
        or an empty list if conversion fails.
    """
    output_dir = Path(output_dir)
    pdf_file = Path(pdf_file)

    # Clean up old images for this file
    for old_png in output_dir.glob(f"{pdf_file.stem}-*.png"):
        old_png.unlink()

    output_prefix = str(output_dir / pdf_file.stem)
    result = subprocess.run(
        ["pdftoppm", "-png", "-r", str(dpi), str(pdf_file), output_prefix],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: PDF to PNG conversion failed for {pdf_file.name}")
        print(result.stderr)
        return []

    pngs = sorted(
        list(output_dir.glob(f"{pdf_file.stem}-*.png")),
        key=lambda x: int(re.search(r"-(\d+)\.png$", x.name).group(1)),
    )
    return pngs


def compare_images(baseline_png: Path, current_png: Path, diff_png: Path) -> int:
    """Compare two PNG images and generate a composite diff image.

    Composite colouring:
      - Identical pixels  → grayscale
      - Baseline-only     → blue tint
      - Current-only      → red tint
      - Both differ       → mixed (purple/dark)

    The diff image is written to *diff_png* only when differences exist.

    Args:
        baseline_png: Path to the baseline PNG.
        current_png:  Path to the current PNG.
        diff_png:     Path where the diff image will be saved.

    Returns:
        Number of pixels that differ between the two images.
    """
    baseline_img = Image.open(baseline_png).convert("RGB")
    current_img = Image.open(current_png).convert("RGB")

    # Ensure same size (pad the smaller image with white)
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

    # Pixels that differ in any channel
    diff_mask = np.any(baseline_arr != current_arr, axis=2)
    diff_count = int(np.sum(diff_mask))

    if diff_count > 0:
        b_gray = np.mean(baseline_arr, axis=2)
        c_gray = np.mean(current_arr, axis=2)

        # Start with a grayscale version of the baseline
        result = np.stack([b_gray, b_gray, b_gray], axis=2).astype(np.uint8)

        # Colour differing pixels: blue (baseline) + red (current)
        bs = (255 - b_gray[diff_mask]).astype(np.float32)
        cs = (255 - c_gray[diff_mask]).astype(np.float32)

        result[diff_mask, 0] = np.clip(255 - bs, 0, 255).astype(np.uint8)
        result[diff_mask, 1] = np.clip(255 - bs - cs, 0, 255).astype(np.uint8)
        result[diff_mask, 2] = np.clip(255 - cs, 0, 255).astype(np.uint8)

        diff_img = Image.fromarray(result)
        diff_img.save(str(diff_png))

    return diff_count
