#!/usr/bin/env python3
"""
overlay_compare.py — Overlay two documents (PDF or image) with red/blue colouring.

Usage:
    python scripts/overlay_compare.py <file_a> <file_b> [options]

Inputs can be any combination of:
    - PDF files (.pdf)  — automatically converted to PNG pages
    - Image files (.png, .jpg, .jpeg, .tiff, .bmp)

Options:
    --output-dir DIR   Output directory (default: overlay_output/ next to file_a)
    --dpi DPI          Resolution for PDF→PNG conversion (default: 300)
    --pages RANGE      Page range to compare, e.g. "1", "1-3", "2,4,5" (default: all)

Output:
    For each compared page, produces an overlay image:
        <output_dir>/overlay_page_<N>.png

    Colouring:
        Red    = pixels only in file A (reference)
        Blue   = pixels only in file B (current)
        Purple = pixels in both (overlap)
        White  = background in both

Examples:
    # Compare two PDFs, all pages
    python scripts/overlay_compare.py original.pdf compiled.pdf

    # Compare page 1 of a PDF against a reference image
    python scripts/overlay_compare.py reference.png compiled.pdf --pages 1

    # Compare specific pages
    python scripts/overlay_compare.py a.pdf b.pdf --pages 1-3

    # Compare two images directly
    python scripts/overlay_compare.py ref.png current.png
"""

import argparse
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

# image_compare.py lives in the same scripts/ directory
_SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_SCRIPT_DIR))

from image_compare import pdf_to_pngs


def parse_page_range(spec: str, max_pages: int) -> list:
    """Parse a page range specification into a list of 1-based page numbers.

    Supports:
        "1"       → [1]
        "1-3"     → [1, 2, 3]
        "1,3,5"   → [1, 3, 5]
        "2-4,7"   → [2, 3, 4, 7]
    """
    pages = set()
    for part in spec.split(","):
        part = part.strip()
        if "-" in part:
            start, end = part.split("-", 1)
            start, end = int(start), int(end)
            pages.update(range(start, min(end, max_pages) + 1))
        else:
            p = int(part)
            if 1 <= p <= max_pages:
                pages.add(p)
    return sorted(pages)


def load_pages(filepath: Path, dpi: int, tmpdir: Path) -> list:
    """Load a file as a list of PIL Images (one per page).

    PDF files are converted to PNGs via pdftoppm.
    Image files are loaded as a single-page list.
    """
    suffix = filepath.suffix.lower()
    if suffix == ".pdf":
        pngs = pdf_to_pngs(filepath, tmpdir, dpi=dpi)
        if not pngs:
            print(f"ERROR: Failed to convert {filepath}")
            sys.exit(1)
        return [Image.open(p).convert("RGB") for p in pngs]
    elif suffix in (".png", ".jpg", ".jpeg", ".tiff", ".bmp"):
        return [Image.open(filepath).convert("RGB")]
    else:
        print(f"ERROR: Unsupported file format: {suffix}")
        sys.exit(1)


def create_overlay(img_a: Image.Image, img_b: Image.Image) -> Image.Image:
    """Create a red/blue overlay of two images.

    Red    = dark pixels only in A
    Blue   = dark pixels only in B
    Purple = dark pixels in both
    White  = background in both
    """
    # Resize to the same dimensions (use the larger of the two)
    w = max(img_a.width, img_b.width)
    h = max(img_a.height, img_b.height)

    if img_a.size != (w, h):
        img_a = img_a.resize((w, h), Image.LANCZOS)
    if img_b.size != (w, h):
        img_b = img_b.resize((w, h), Image.LANCZOS)

    a = np.array(img_a).astype(float)
    b = np.array(img_b).astype(float)

    # Dark pixel masks (text/ink): mean brightness < 128
    a_dark = np.mean(a, axis=2) < 128
    b_dark = np.mean(b, axis=2) < 128

    # Start with white background
    overlay = np.ones((h, w, 3), dtype=np.uint8) * 255

    # Both dark → purple
    both = a_dark & b_dark
    overlay[both] = [128, 0, 128]

    # Only A dark → red
    only_a = a_dark & ~b_dark
    overlay[only_a] = [255, 0, 0]

    # Only B dark → blue
    only_b = b_dark & ~a_dark
    overlay[only_b] = [0, 0, 255]

    return Image.fromarray(overlay)


def overlay_compare(
    file_a: Path,
    file_b: Path,
    output_dir: Path,
    dpi: int = 300,
    pages_spec: str = None,
) -> None:
    """Compare two files and produce overlay images."""
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"File A (red):  {file_a}")
    print(f"File B (blue): {file_b}")
    print(f"Output: {output_dir}")
    print(f"DPI: {dpi}\n")

    with tempfile.TemporaryDirectory(prefix="overlay_cmp_") as tmp:
        tmp_path = Path(tmp)
        dir_a = tmp_path / "a"
        dir_b = tmp_path / "b"
        dir_a.mkdir()
        dir_b.mkdir()

        print("Loading file A...")
        pages_a = load_pages(file_a, dpi, dir_a)
        print(f"  {len(pages_a)} page(s)")

        print("Loading file B...")
        pages_b = load_pages(file_b, dpi, dir_b)
        print(f"  {len(pages_b)} page(s)")

        n_pages = max(len(pages_a), len(pages_b))

        # If file A is a single image, --pages selects which page of file B to
        # compare against (the image is always treated as page 1 of A).
        # e.g. --pages 2  →  compare image vs page 2 of the PDF.
        a_is_image = file_a.suffix.lower() in (".png", ".jpg", ".jpeg", ".tiff", ".bmp")
        if a_is_image and len(pages_a) == 1:
            b_page = int(pages_spec) if pages_spec and pages_spec.isdigit() else 1
            if b_page < 1 or b_page > len(pages_b):
                print(f"ERROR: --pages {b_page} is out of range (file B has {len(pages_b)} page(s))")
                sys.exit(1)
            # Swap so the comparison loop sees A[0] vs B[b_page-1]
            pages_b = [pages_b[b_page - 1]]
            page_list = [1]
        elif pages_spec:
            page_list = parse_page_range(pages_spec, n_pages)
        else:
            page_list = list(range(1, n_pages + 1))

        print(f"\nComparing {len(page_list)} page(s)...\n")

        for page_num in page_list:
            idx = page_num - 1

            if idx >= len(pages_a):
                print(f"  Page {page_num}: only in file B (skipped)")
                continue
            if idx >= len(pages_b):
                print(f"  Page {page_num}: only in file A (skipped)")
                continue

            overlay = create_overlay(pages_a[idx], pages_b[idx])
            out_path = output_dir / f"overlay_page_{page_num:04d}.png"
            overlay.save(str(out_path))
            print(f"  Page {page_num}: saved → {out_path.name}")

    print(f"\nDone. Output in: {output_dir}")


def main():
    parser = argparse.ArgumentParser(
        description="Overlay two documents (PDF or image) with red/blue colouring.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("file_a", help="First file — shown in RED (reference)")
    parser.add_argument("file_b", help="Second file — shown in BLUE (current)")
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Output directory (default: overlay_output/ next to file_a)",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=300,
        help="Resolution for PDF→PNG conversion (default: 300)",
    )
    parser.add_argument(
        "--pages",
        default=None,
        help='Page range, e.g. "1", "1-3", "2,4,5" (default: all)',
    )
    args = parser.parse_args()

    file_a = Path(args.file_a).resolve()
    file_b = Path(args.file_b).resolve()

    if not file_a.exists():
        print(f"ERROR: File A not found: {file_a}")
        sys.exit(2)
    if not file_b.exists():
        print(f"ERROR: File B not found: {file_b}")
        sys.exit(2)

    if args.output_dir:
        output_dir = Path(args.output_dir).resolve()
    else:
        output_dir = file_a.parent / "overlay_output"

    overlay_compare(
        file_a,
        file_b,
        output_dir,
        dpi=args.dpi,
        pages_spec=args.pages,
    )


if __name__ == "__main__":
    main()
