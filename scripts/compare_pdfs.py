#!/usr/bin/env python3
"""
compare_pdfs.py — Compare two PDF files page by page using visual diff.

Usage:
    python scripts/compare_pdfs.py <pdf_a> <pdf_b> [options]

Options:
    --output-dir DIR   Directory for output images (default: compare_output/
                       next to pdf_a)
    --dpi DPI          Resolution for PNG conversion (default: 150)
    --threshold N      Pixel difference threshold to consider a page changed
                       (default: 10)
    --stop-on-first    Stop after the first differing page is found

Output:
    - Prints a summary of which pages differ and how many pixels changed.
    - For each differing page, saves a side-by-side comparison image:
        <output_dir>/compare_page_<N>.png
      Left panel:  pdf_a page
      Right panel: pdf_b page
      Middle panel: diff (identical pixels grey, A-only blue, B-only red)
    - Exits with code 0 if no differences, 1 if differences found.

The script uses test/image_compare.py as a shared library.
"""

import argparse
import sys
import tempfile
from pathlib import Path

# image_compare.py lives in the same scripts/ directory
_SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_SCRIPT_DIR))

from image_compare import compare_images, pdf_to_pngs
from PIL import Image


def make_side_by_side(img_a: Path, img_b: Path, diff_img: Path, out: Path) -> None:
    """Create a three-panel side-by-side comparison image.

    Panels: [A | diff | B]
    """
    a = Image.open(img_a).convert("RGB")
    b = Image.open(img_b).convert("RGB")
    d = Image.open(diff_img).convert("RGB")

    # Normalise heights
    h = max(a.height, b.height, d.height)

    def pad_height(img, target_h):
        if img.height < target_h:
            padded = Image.new("RGB", (img.width, target_h), (255, 255, 255))
            padded.paste(img, (0, 0))
            return padded
        return img

    a = pad_height(a, h)
    b = pad_height(b, h)
    d = pad_height(d, h)

    gap = 10  # white gap between panels
    total_w = a.width + gap + d.width + gap + b.width
    canvas = Image.new("RGB", (total_w, h), (200, 200, 200))
    canvas.paste(a, (0, 0))
    canvas.paste(d, (a.width + gap, 0))
    canvas.paste(b, (a.width + gap + d.width + gap, 0))
    canvas.save(str(out))


def compare_pdfs(
    pdf_a: Path,
    pdf_b: Path,
    output_dir: Path,
    dpi: int = 150,
    threshold: int = 10,
    stop_on_first: bool = False,
) -> bool:
    """Compare two PDFs page by page.

    Returns True if the PDFs are visually identical (within threshold),
    False if differences are found.

    If stop_on_first is True, stops after the first differing page.
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"PDF A: {pdf_a}")
    print(f"PDF B: {pdf_b}")
    print(f"Output: {output_dir}")
    print(f"DPI: {dpi}  Threshold: {threshold} pixels\n")

    with tempfile.TemporaryDirectory(prefix="compare_pdfs_") as tmp:
        tmp_path = Path(tmp)
        dir_a = tmp_path / "a"
        dir_b = tmp_path / "b"
        dir_diff = tmp_path / "diff"
        for d in [dir_a, dir_b, dir_diff]:
            d.mkdir()

        print("Converting PDF A to PNGs…")
        pngs_a = pdf_to_pngs(pdf_a, dir_a, dpi=dpi)
        if not pngs_a:
            print("ERROR: Failed to convert PDF A.")
            return False

        print("Converting PDF B to PNGs…")
        pngs_b = pdf_to_pngs(pdf_b, dir_b, dpi=dpi)
        if not pngs_b:
            print("ERROR: Failed to convert PDF B.")
            return False

        n_a, n_b = len(pngs_a), len(pngs_b)
        print(f"PDF A: {n_a} pages   PDF B: {n_b} pages\n")

        if n_a != n_b:
            print(f"WARNING: Page count differs (A={n_a}, B={n_b}).")
            print("Comparing the first", min(n_a, n_b), "pages.\n")

        n_pages = min(n_a, n_b)
        first_diff_page = None
        diff_pages = []

        for i in range(n_pages):
            page_num = i + 1
            diff_tmp = dir_diff / f"diff_{page_num:04d}.png"
            diff_count = compare_images(pngs_a[i], pngs_b[i], diff_tmp)

            if diff_count > threshold:
                if first_diff_page is None:
                    first_diff_page = page_num
                diff_pages.append((page_num, diff_count))

                # Build side-by-side comparison
                out_path = output_dir / f"compare_page_{page_num:04d}.png"
                make_side_by_side(pngs_a[i], pngs_b[i], diff_tmp, out_path)
                print(f"  Page {page_num:4d}: {diff_count:>10,} pixels differ  →  {out_path.name}")

                if stop_on_first:
                    print(f"\n  (--stop-on-first: stopping after page {page_num})")
                    break
            elif diff_count > 0:
                print(f"  Page {page_num:4d}: {diff_count:>10,} pixels differ  (below threshold, ignored)")
            else:
                print(f"  Page {page_num:4d}: identical")

        # Handle page count mismatch tail
        if n_a != n_b:
            extra_label = "A" if n_a > n_b else "B"
            extra_start = n_pages + 1
            extra_end = max(n_a, n_b)
            print(f"\n  Pages {extra_start}–{extra_end} exist only in PDF {extra_label}.")
            if first_diff_page is None:
                first_diff_page = extra_start

        print("\n" + "=" * 60)
        if not diff_pages and n_a == n_b:
            print("RESULT: PDFs are visually identical.")
            return True
        else:
            if first_diff_page is not None:
                print(f"RESULT: First difference on page {first_diff_page}.")
            if diff_pages:
                print(f"        {len(diff_pages)} page(s) differ: "
                      + ", ".join(str(p) for p, _ in diff_pages))
            if n_a != n_b:
                print(f"        Page count mismatch: A={n_a}, B={n_b}.")
            print(f"\nDiff images saved to: {output_dir}")
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Compare two PDF files page by page using visual diff.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("pdf_a", help="First PDF file (baseline)")
    parser.add_argument("pdf_b", help="Second PDF file (current)")
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Directory for output images (default: compare_output/ next to pdf_a)",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=150,
        help="Resolution for PNG conversion (default: 150)",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=10,
        help="Pixel difference threshold (default: 10)",
    )
    parser.add_argument(
        "--stop-on-first",
        action="store_true",
        help="Stop after the first differing page is found",
    )
    args = parser.parse_args()

    pdf_a = Path(args.pdf_a).resolve()
    pdf_b = Path(args.pdf_b).resolve()

    if not pdf_a.exists():
        print(f"ERROR: PDF A not found: {pdf_a}")
        sys.exit(2)
    if not pdf_b.exists():
        print(f"ERROR: PDF B not found: {pdf_b}")
        sys.exit(2)

    if args.output_dir:
        output_dir = Path(args.output_dir).resolve()
    else:
        output_dir = pdf_a.parent / "compare_output"

    identical = compare_pdfs(
        pdf_a, pdf_b, output_dir,
        dpi=args.dpi,
        threshold=args.threshold,
        stop_on_first=args.stop_on_first,
    )
    sys.exit(0 if identical else 1)


if __name__ == "__main__":
    main()
