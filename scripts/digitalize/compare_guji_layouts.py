#!/usr/bin/env python3
"""
Guji Layout Compare - 古籍排版一致性比较工具

比较 ltc-guji.cls (原始/语义) 和 ltc-guji-digital.cls (数字化/布局)
两个 TeX 文件的排版一致性，生成详细的 Markdown 差异报告。

Usage:
    # 比较两个 TeX 文件（自动检测编译、比较、生成报告）
    python3 scripts/compare_guji_layouts.py original.tex digital.tex

    # 强制重新编译
    python3 scripts/compare_guji_layouts.py original.tex digital.tex --force

    # 指定报告输出路径
    python3 scripts/compare_guji_layouts.py original.tex digital.tex -o report.md

    # 只比较已有的 JSON（跳过编译）
    python3 scripts/compare_guji_layouts.py original.tex digital.tex --no-compile
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

# Import shared image comparison utilities
_SCRIPTS_DIR = Path(__file__).resolve().parent.parent  # scripts/
sys.path.insert(0, str(_SCRIPTS_DIR))
from image_compare import pdf_to_pngs, compare_images


# ============================================================================
# Utility Functions
# ============================================================================

def get_layout_json_path(tex_path: str) -> str:
    """Get the expected layout JSON path for a TeX file."""
    tex_file = Path(tex_path)
    return str(tex_file.parent / f"{tex_file.stem}-layout.json")


def needs_recompile(tex_path: str, json_path: str) -> tuple[bool, str]:
    """
    Check if TeX file needs recompilation based on timestamps.

    Returns:
        (needs_recompile, reason)
    """
    if not Path(json_path).exists():
        return True, f"JSON 文件不存在：{json_path}"

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            layout_data = json.load(f)

        source_mtime = layout_data.get('source_mtime')
        if source_mtime is None:
            return True, "JSON 缺少 source_mtime 字段（旧版本）"

        tex_mtime = os.path.getmtime(tex_path)

        if abs(tex_mtime - source_mtime) > 1:
            return True, f"TeX 文件已修改（JSON: {source_mtime}, TeX: {tex_mtime:.0f}）"

        return False, "已是最新"

    except Exception as e:
        return True, f"读取 JSON 出错：{e}"


def compile_tex(tex_path: str) -> tuple[bool, str]:
    """
    Compile TeX file with ENABLE_EXPORT=1 to generate layout JSON.

    Returns:
        (success, output/error)
    """
    working_dir = str(Path(tex_path).parent)
    env = os.environ.copy()
    env['ENABLE_EXPORT'] = '1'
    tex_file = Path(tex_path).name

    try:
        result = subprocess.run(
            ['lualatex', '-interaction=nonstopmode', tex_file],
            cwd=working_dir,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        )

        if result.returncode == 0:
            return True, f"编译成功：{tex_file}"
        else:
            error_lines = result.stdout.split('\n')[-20:]
            return False, '\n'.join(['编译失败：', *error_lines])

    except subprocess.TimeoutExpired:
        return False, f"编译超时（>5 分钟）：{tex_file}"
    except Exception as e:
        return False, f"编译出错：{e}"


def convert_pdf_page_to_png(pdf_path: str, page_num: int, output_path: str, dpi: int = 150) -> bool:
    """将 PDF 的指定页面转换为 PNG 图片。"""
    try:
        result = subprocess.run(
            [
                'pdftoppm', '-png',
                '-f', str(page_num), '-l', str(page_num),
                '-r', str(dpi), '-singlefile',
                pdf_path,
                str(Path(output_path).with_suffix(''))
            ],
            capture_output=True, text=True, timeout=30
        )
        return result.returncode == 0
    except Exception:
        return False


def is_spread_page(summary: list[dict] | None, page_idx: int) -> bool:
    """检测是否为筒子页（对开页，未裁剪）。

    Args:
        summary: page_summary 列表（可以为 None）
        page_idx: 当前页索引

    Returns:
        bool - 如果是筒子页返回 True

    Note:
        筒子页类型包括：
        - "spread" (新版)
        - "spread_right" / "spread_left" (旧版，兼容)
    """
    if not summary or page_idx >= len(summary):
        return False

    page = summary[page_idx]
    ptype = page.get('type', 'single')

    return ptype in ('spread', 'spread_right', 'spread_left')


def calculate_pdf_page(summary: list[dict], layout_page_idx: int) -> tuple[int, int]:
    """计算 Layout page 对应的 PDF 页码范围。

    Args:
        summary: page_summary 列表
        layout_page_idx: layout page 的索引（0-indexed）

    Returns:
        (pdf_page_start, pdf_page_end) - PDF 页码（1-indexed）
        - 对于单页: (N, N) - 对应 PDF 第 N 页
        - 对于筒子页: (N, N+1) - 对应 PDF 第 N 和 N+1 页

    规则:
        - single 类型占 1 个 PDF 页
        - spread 类型占 2 个 PDF 页
        - PDF 页码 = sum(之前所有页占用的页数) + 1
    """
    if layout_page_idx >= len(summary):
        return 1, 1

    # 计算偏移量：累加之前所有页面占用的 PDF 页数
    pdf_offset = 0
    for i in range(layout_page_idx):
        ptype = summary[i].get('type', 'single')
        if ptype == 'single':
            pdf_offset += 1
        elif ptype in ('spread', 'spread_right', 'spread_left'):
            pdf_offset += 2

    # 当前页的 PDF 起始页码（1-indexed）
    pdf_start = pdf_offset + 1

    # 判断当前页类型
    ptype = summary[layout_page_idx].get('type', 'single')

    if ptype == 'single':
        return pdf_start, pdf_start
    else:  # spread 类型
        return pdf_start, pdf_start + 1


# ============================================================================
# Page Label Helpers
# ============================================================================

def build_page_label_map_from_summary(summary: list[dict]) -> dict[int, str]:
    """从 page_summary 构建页码标签映射。

    返回格式示例:
        - 单页: "PDF第N页"
        - 筒子页: "PDF第N-M页（筒子页）"

    Note:
        Layout JSON 中的页面类型：
        - "single": 单页（占 1 个 PDF 页）
        - "spread": 筒子页（对开页，未裁剪，占 2 个 PDF 页）
        - 旧版可能有 "spread_right"/"spread_left"（兼容处理，占 2 个 PDF 页）
    """
    label_map = {}

    for i in range(len(summary)):
        pdf_start, pdf_end = calculate_pdf_page(summary, i)
        ptype = summary[i].get('type', 'single')

        if ptype == 'single':
            label_map[i] = f"PDF第{pdf_start}页"
        else:  # spread 类型
            label_map[i] = f"PDF第{pdf_start}-{pdf_end}页（筒子页）"

    return label_map


def build_page_label_map_from_pages(pages: list[dict], summary: list[dict] | None = None) -> dict[int, str]:
    """根据 pages 结构构建 PDF 页码标签映射。

    使用 split_info 来判断页面类型，结合 summary 计算正确的 PDF 页码。

    Args:
        pages: pages 列表（包含 split_info）
        summary: page_summary 列表（用于计算 PDF 页码，如果为 None 则使用简化计算）

    Returns:
        dict - layout_page_idx → PDF 页码标签

    标签格式:
        - 单页: "PDF第N页"
        - 筒子页: "PDF第N-M页（筒子页）"
    """
    label_map = {}

    for page_idx, page in enumerate(pages):
        si = page.get('split_info')

        if summary:
            # 使用正确的 PDF 页码计算
            pdf_start, pdf_end = calculate_pdf_page(summary, page_idx)
            ptype = summary[page_idx].get('type', 'single') if page_idx < len(summary) else 'single'

            if ptype == 'single':
                label_map[page_idx] = f"PDF第{pdf_start}页"
            else:  # spread 类型
                label_map[page_idx] = f"PDF第{pdf_start}-{pdf_end}页（筒子页）"
        else:
            # Fallback: 简化计算（1:1 映射）
            pdf_page = page_idx + 1
            if si is None:
                label_map[page_idx] = f"PDF第{pdf_page}页"
            else:
                # 有 split_info，说明是筒子页
                label_map[page_idx] = f"PDF第{pdf_page}页（筒子页）"

    return label_map


# ============================================================================
# Column Text Helpers
# ============================================================================

def col_all_text(col) -> str:
    """获取列的全部文字（用于统计总字数）。"""
    if isinstance(col, str):
        return col
    if isinstance(col, list):
        parts = []
        for seg in col:
            if isinstance(seg, str):
                parts.append(seg)
            elif isinstance(seg, list):
                parts.extend(seg)
        return ''.join(parts)
    return ''


def format_col_for_display(col) -> str:
    """格式化列内容用于报告显示。"""
    if isinstance(col, str):
        return col if col else "（空）"
    if isinstance(col, list):
        parts = []
        for seg in col:
            if isinstance(seg, str):
                parts.append(seg)
            elif isinstance(seg, list) and len(seg) == 2:
                parts.append(f"[{seg[0]}|{seg[1]}]")
        return ''.join(parts)
    return str(col)


# ============================================================================
# Comparison Logic
# ============================================================================

def _compare_via_summary(
    orig_summary: list[dict],
    dig_summary: list[dict],
    page_label_map: dict[int, str]
) -> dict[str, Any]:
    """基于 page_summary 进行比较。"""
    total_orig = len(orig_summary)
    total_dig = len(dig_summary)

    matching_pages = 0
    differing_pages = []
    page_diffs = {}
    first_diff_page = None
    first_diff_details = None

    total_chars_orig = 0
    total_chars_dig = 0

    for page_idx in range(max(total_orig, total_dig)):
        orig_page = orig_summary[page_idx] if page_idx < total_orig else None
        dig_page = dig_summary[page_idx] if page_idx < total_dig else None

        if orig_page:
            for c in orig_page.get('cols', []):
                total_chars_orig += len(col_all_text(c))
        if dig_page:
            for c in dig_page.get('cols', []):
                total_chars_dig += len(col_all_text(c))

        if orig_page is None or dig_page is None:
            differing_pages.append(page_idx)
            diff = {
                'type': 'page_missing',
                'orig_exists': orig_page is not None,
                'dig_exists': dig_page is not None,
            }
            page_diffs[page_idx] = diff
            if first_diff_page is None:
                first_diff_page = page_idx
                first_diff_details = diff
            continue

        orig_cols = orig_page.get('cols', [])
        dig_cols = dig_page.get('cols', [])

        if len(orig_cols) != len(dig_cols):
            differing_pages.append(page_idx)
            diff = {
                'type': 'column_count_mismatch',
                'orig_cols': len(orig_cols),
                'dig_cols': len(dig_cols),
                'orig_col_data': orig_cols,
                'dig_col_data': dig_cols,
            }
            page_diffs[page_idx] = diff
            if first_diff_page is None:
                first_diff_page = page_idx
                first_diff_details = diff
            continue

        page_has_diff = False
        col_diffs = {}

        for col_idx, (oc, dc) in enumerate(zip(orig_cols, dig_cols)):
            if oc != dc:
                page_has_diff = True
                col_diffs[col_idx] = {'orig': oc, 'dig': dc}

        if page_has_diff:
            differing_pages.append(page_idx)
            diff = {
                'type': 'column_content_mismatch',
                'column_diffs': col_diffs,
                'first_diff_col': min(col_diffs.keys()),
            }
            page_diffs[page_idx] = diff
            if first_diff_page is None:
                first_diff_page = page_idx
                first_diff_details = diff
        else:
            matching_pages += 1

    return {
        'total_pages_orig': total_orig,
        'total_pages_digital': total_dig,
        'total_chars_orig': total_chars_orig,
        'total_chars_digital': total_chars_dig,
        'matching_pages': matching_pages,
        'differing_pages': differing_pages,
        'first_diff_page': first_diff_page,
        'first_diff_details': first_diff_details,
        'page_diffs': page_diffs,
        'page_label_map': page_label_map,
        'used_summary': True,
    }


def _compare_character_positions(
    orig_pages: list[dict],
    dig_pages: list[dict],
    page_label_map: dict[int, str]
) -> dict[str, Any]:
    """比较字符级别的坐标和位置信息。

    当 page_summary 完全一致后，进行更详细的验证。

    Returns:
        dict with keys:
        - total_chars: 总字符数
        - mismatched_chars: 坐标不一致的字符数
        - mismatched_pages: 有差异的页面列表
        - detail_diffs: 详细差异信息
    """
    total_chars = 0
    mismatched_chars = 0
    mismatched_pages = []
    detail_diffs = {}

    for page_idx in range(min(len(orig_pages), len(dig_pages))):
        orig_page = orig_pages[page_idx]
        dig_page = dig_pages[page_idx]

        orig_cols = orig_page.get('columns', [])
        dig_cols = dig_page.get('columns', [])

        if len(orig_cols) != len(dig_cols):
            continue  # 列数不同已在 summary 比较中报告

        page_has_diff = False
        col_diffs = {}

        for col_idx, (orig_col, dig_col) in enumerate(zip(orig_cols, dig_cols)):
            orig_chars = orig_col.get('characters', [])
            dig_chars = dig_col.get('characters', [])

            if len(orig_chars) != len(dig_chars):
                page_has_diff = True
                col_diffs[col_idx] = {
                    'type': 'char_count_mismatch',
                    'orig_count': len(orig_chars),
                    'dig_count': len(dig_chars)
                }
                continue

            char_diffs = []
            for char_idx, (orig_char, dig_char) in enumerate(zip(orig_chars, dig_chars)):
                total_chars += 1

                # 比较字符内容
                if orig_char.get('char') != dig_char.get('char'):
                    mismatched_chars += 1
                    char_diffs.append({
                        'char_idx': char_idx,
                        'type': 'char_mismatch',
                        'orig': orig_char.get('char'),
                        'dig': dig_char.get('char')
                    })
                    continue

                # 比较坐标（允许小误差 0.01sp）
                tolerance = 0.01
                pos_diff = False

                # 获取坐标（在 position 子字典中）
                orig_pos = orig_char.get('position', {})
                dig_pos = dig_char.get('position', {})

                # 比较 x 坐标
                orig_x = orig_pos.get('x', 0)
                dig_x = dig_pos.get('x', 0)
                if abs(orig_x - dig_x) > tolerance:
                    pos_diff = True

                # 比较 y 坐标（使用 y_top，因为 y_bottom 可能因字体大小不同而不同）
                orig_y = orig_pos.get('y_top', 0)
                dig_y = dig_pos.get('y_top', 0)
                if abs(orig_y - dig_y) > tolerance:
                    pos_diff = True

                if pos_diff:
                    mismatched_chars += 1
                    char_diffs.append({
                        'char_idx': char_idx,
                        'type': 'position_mismatch',
                        'char': orig_char.get('char'),
                        'orig_pos': {'x': orig_x, 'y_top': orig_y},
                        'dig_pos': {'x': dig_x, 'y_top': dig_y}
                    })

            if char_diffs:
                page_has_diff = True
                col_diffs[col_idx] = {
                    'type': 'char_diffs',
                    'diff_count': len(char_diffs),
                    'details': char_diffs[:5]  # 只保留前5个差异
                }

        if page_has_diff:
            mismatched_pages.append(page_idx)
            detail_diffs[page_idx] = {
                'page_label': page_label_map.get(page_idx, f'第{page_idx}页'),
                'col_diffs': col_diffs
            }

    return {
        'total_chars': total_chars,
        'mismatched_chars': mismatched_chars,
        'mismatched_pages': mismatched_pages,
        'detail_diffs': detail_diffs
    }


def _compare_via_pages(
    orig_pages: list[dict],
    dig_pages: list[dict],
    page_label_map: dict[int, str]
) -> dict[str, Any]:
    """基于旧版 pages 结构进行比较（兼容无 page_summary 的 JSON）。"""
    total_orig = len(orig_pages)
    total_dig = len(dig_pages)

    matching_pages = 0
    differing_pages = []
    first_diff_page = None
    first_diff_details = None
    page_diffs = {}

    for page_idx in range(min(total_orig, total_dig)):
        orig_page = orig_pages[page_idx]
        dig_page = dig_pages[page_idx]

        orig_cols = orig_page['columns']
        dig_cols = dig_page['columns']

        if len(orig_cols) != len(dig_cols):
            differing_pages.append(page_idx)
            page_diffs[page_idx] = {
                'type': 'column_count_mismatch',
                'orig_cols': len(orig_cols),
                'dig_cols': len(dig_cols),
            }
            if first_diff_page is None:
                first_diff_page = page_idx
                first_diff_details = page_diffs[page_idx]
            continue

        page_has_diff = False
        col_diffs = {}
        for col_idx, (orig_col, dig_col) in enumerate(zip(orig_cols, dig_cols)):
            orig_chars = orig_col['characters']
            dig_chars = dig_col['characters']
            orig_text = ''.join(c['char'] for c in orig_chars)
            dig_text = ''.join(c['char'] for c in dig_chars)
            if orig_text != dig_text:
                page_has_diff = True
                col_diffs[col_idx] = {'orig': orig_text, 'dig': dig_text}

        if page_has_diff:
            differing_pages.append(page_idx)
            page_diffs[page_idx] = {
                'type': 'column_content_mismatch',
                'column_diffs': col_diffs,
                'first_diff_col': min(col_diffs.keys()),
            }
            if first_diff_page is None:
                first_diff_page = page_idx
                first_diff_details = page_diffs[page_idx]
        else:
            matching_pages += 1

    if total_orig != total_dig and first_diff_page is None:
        first_diff_page = min(total_orig, total_dig)
        first_diff_details = {
            'type': 'page_count_mismatch',
            'orig_total': total_orig,
            'dig_total': total_dig,
        }

    return {
        'total_pages_orig': total_orig,
        'total_pages_digital': total_dig,
        'matching_pages': matching_pages,
        'differing_pages': differing_pages,
        'first_diff_page': first_diff_page,
        'first_diff_details': first_diff_details,
        'page_diffs': page_diffs,
        'page_label_map': page_label_map,
        'used_summary': False,
    }


def compare_layouts(orig_json: str, dig_json: str) -> dict[str, Any]:
    """
    Compare two layout JSON files.
    Uses page_summary if available, falls back to pages-based comparison.
    """
    with open(orig_json, 'r', encoding='utf-8') as f:
        orig_data = json.load(f)
    with open(dig_json, 'r', encoding='utf-8') as f:
        dig_data = json.load(f)

    orig_summary = orig_data.get('page_summary')
    dig_summary = dig_data.get('page_summary')

    if orig_summary and dig_summary:
        page_label_map = build_page_label_map_from_summary(orig_summary)
        result = _compare_via_summary(orig_summary, dig_summary, page_label_map)
        # 附加 summary 数据，用于截图比较
        result['_orig_summary'] = orig_summary
        result['_dig_summary'] = dig_summary

        # 如果 page_summary 完全一致，继续进行详细的字符级比较
        if result['matching_pages'] == result['total_pages_orig'] == result['total_pages_digital']:
            orig_pages = orig_data.get('pages', [])
            dig_pages = dig_data.get('pages', [])
            if orig_pages and dig_pages:
                detail_result = _compare_character_positions(orig_pages, dig_pages, page_label_map)
                result['detail_comparison'] = detail_result

        return result
    else:
        orig_pages = orig_data['pages']
        dig_pages = dig_data['pages']
        # 尝试从 pages 构建简化的 summary（用于 PDF 页码计算）
        orig_simple_summary = [{'type': 'spread' if p.get('split_info') else 'single'} for p in orig_pages]
        page_label_map = build_page_label_map_from_pages(orig_pages, orig_simple_summary)
        result = _compare_via_pages(orig_pages, dig_pages, page_label_map)
        # 从 pages 提取 summary 信息
        result['_orig_summary'] = orig_simple_summary
        dig_simple_summary = [{'type': 'spread' if p.get('split_info') else 'single'} for p in dig_pages]
        result['_dig_summary'] = dig_simple_summary
        return result


# ============================================================================
# Pixel-level PDF Comparison
# ============================================================================

PIXEL_DIFF_THRESHOLD = 10


def compare_pdfs_pixel(
    orig_pdf: str,
    dig_pdf: str,
    diff_output_dir: str,
    dpi: int = 150,
    threshold: int = PIXEL_DIFF_THRESHOLD,
) -> dict[str, Any]:
    """像素级比较两个 PDF 的每一页。

    将两个 PDF 分别转为 PNG，逐页做像素 diff。
    有差异的页面保存 diff 图到 diff_output_dir。

    Args:
        orig_pdf: 原始 PDF 路径
        dig_pdf: 数字化 PDF 路径
        diff_output_dir: diff 图输出目录
        dpi: 转换 DPI（默认 150）
        threshold: 像素差异阈值，低于此值视为一致（默认 10）

    Returns:
        dict with keys:
        - total_pages_orig: 原始 PDF 总页数
        - total_pages_digital: 数字化 PDF 总页数
        - compared_pages: 实际比较的页数（取较小值）
        - identical_pages: 像素级一致的页数
        - diff_pages: list[{pdf_page, diff_count, diff_image}]
    """
    diff_dir = Path(diff_output_dir)
    diff_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        orig_png_dir = tmp_path / "orig"
        dig_png_dir = tmp_path / "dig"
        orig_png_dir.mkdir()
        dig_png_dir.mkdir()

        # Convert PDFs to PNGs
        orig_pngs = pdf_to_pngs(Path(orig_pdf), orig_png_dir, dpi=dpi)
        dig_pngs = pdf_to_pngs(Path(dig_pdf), dig_png_dir, dpi=dpi)

        total_orig = len(orig_pngs)
        total_dig = len(dig_pngs)
        compared = min(total_orig, total_dig)

        identical = 0
        diff_pages = []

        for i in range(compared):
            pdf_page = i + 1  # 1-indexed
            diff_png = diff_dir / f"diff_page_{pdf_page:04d}.png"

            diff_count = compare_images(orig_pngs[i], dig_pngs[i], diff_png)

            if diff_count <= threshold:
                identical += 1
                # 删除无差异的 diff 图（compare_images 只在 diff_count > 0 时写入）
                if diff_png.exists():
                    diff_png.unlink()
            else:
                diff_pages.append({
                    'pdf_page': pdf_page,
                    'diff_count': diff_count,
                    'diff_image': str(diff_png),
                })

    return {
        'total_pages_orig': total_orig,
        'total_pages_digital': total_dig,
        'compared_pages': compared,
        'identical_pages': identical,
        'diff_pages': diff_pages,
    }


# ============================================================================
# Report Generation
# ============================================================================

def generate_markdown_report(
    comparison: dict[str, Any],
    orig_json: str,
    dig_json: str,
    output_md: str,
    orig_pdf: str | None = None,
    dig_pdf: str | None = None,
    pixel_comparison: dict[str, Any] | None = None,
) -> str:
    """Generate concise markdown comparison report."""
    output_path = Path(output_md)
    tmp_dir = output_path.parent / ".mcp_tmp" / output_path.stem
    tmp_dir.mkdir(parents=True, exist_ok=True)

    # Load layout data for PDF page calculation
    with open(orig_json, 'r', encoding='utf-8') as f:
        orig_layout_data = json.load(f)
    with open(dig_json, 'r', encoding='utf-8') as f:
        dig_layout_data = json.load(f)

    lines = []
    lines.append("# 古籍排版一致性比较报告\n\n")
    lines.append(f"**生成时间：** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

    # File info
    orig_name = Path(orig_json).stem.replace('-layout', '')
    dig_name = Path(dig_json).stem.replace('-layout', '')
    lines.append(f"**原始文件：** `{orig_name}.tex` / **数字化文件：** `{dig_name}.tex`\n\n")

    page_labels = comparison.get('page_label_map', {})

    # -- 概要 --
    lines.append("## 概要\n\n")
    total_o = comparison['total_pages_orig']
    total_d = comparison['total_pages_digital']
    matching = comparison['matching_pages']
    first_diff = comparison.get('first_diff_page')

    lines.append(f"- 原始 **{total_o}** 页 / 数字化 **{total_d}** 页\n")

    if first_diff is not None and first_diff > 0:
        lines.append(f"- 前 **{first_diff}** 页完全一致\n")
    elif first_diff is None:
        lines.append(f"- 所有 **{matching}** 页完全一致\n")

    if 'total_chars_orig' in comparison:
        co = comparison['total_chars_orig']
        cd = comparison['total_chars_digital']
        if co == cd:
            lines.append(f"- 总字数：原始 {co} / 数字化 {cd}（**一致**）\n")
        else:
            lines.append(f"- 总字数：原始 {co} / 数字化 {cd}（**差 {abs(co - cd)} 字**）\n")

    if first_diff is not None:
        label = page_labels.get(first_diff, f"第{first_diff + 1}页")
        lines.append(f"- 第一处差异：{label}\n")
    else:
        lines.append("- **所有页面完全一致**\n")

    # -- 差异总结表格 --
    diffs = comparison['differing_pages']
    if diffs:
        lines.append("\n## 差异总结\n\n")
        lines.append("| 页码 | 类型 | 说明 |\n")
        lines.append("|------|------|------|\n")

        for page_idx in diffs[:20]:
            diff_info = comparison['page_diffs'].get(page_idx, {})
            label = page_labels.get(page_idx, f"第{page_idx + 1}页")
            diff_type = diff_info.get('type', 'unknown')

            if diff_type == 'column_count_mismatch':
                desc = f"原始 {diff_info['orig_cols']} 列 / 数字化 {diff_info['dig_cols']} 列"
                lines.append(f"| {label} | 列数不匹配 | {desc} |\n")
            elif diff_type == 'column_content_mismatch':
                first_col = diff_info.get('first_diff_col', '?')
                n_cols = len(diff_info.get('column_diffs', {}))
                lines.append(f"| {label} | 内容不同 | 第 {first_col} 列起，共 {n_cols} 列 |\n")
            elif diff_type == 'page_missing':
                side = "数字化缺失" if diff_info.get('orig_exists') else "原始缺失"
                lines.append(f"| {label} | 页面缺失 | {side} |\n")

        if len(diffs) > 20:
            lines.append(f"\n*还有 {len(diffs) - 20} 页差异未列出*\n")

    # -- 差异详情（前 5 处） --
    if diffs:
        max_details = 5
        lines.append(f"\n## 差异详情（前 {min(len(diffs), max_details)} 处）\n")

        for detail_idx, page_idx in enumerate(diffs[:max_details]):
            diff_info = comparison['page_diffs'].get(page_idx, {})
            page_label = page_labels.get(page_idx, f"第{page_idx + 1}页")

            lines.append(f"\n### {detail_idx + 1}. {page_label}\n\n")

            # PDF 截图对比
            if orig_pdf and dig_pdf and Path(orig_pdf).exists() and Path(dig_pdf).exists():
                # 获取正确的 PDF 页码
                orig_summary = orig_layout_data.get('page_summary', [])
                dig_summary = dig_layout_data.get('page_summary', [])

                orig_pdf_start, orig_pdf_end = calculate_pdf_page(orig_summary, page_idx)
                dig_pdf_start, dig_pdf_end = calculate_pdf_page(dig_summary, page_idx)

                is_spread = (orig_pdf_end > orig_pdf_start) or (dig_pdf_end > dig_pdf_start)

                lines.append("**页面对比：**\n\n")

                if is_spread:
                    # 筒子页：分两行显示左右页
                    # 第一行：右页（或第一页）
                    orig_png_r = tmp_dir / f"orig_page_{page_idx}_right.png"
                    dig_png_r = tmp_dir / f"dig_page_{page_idx}_right.png"
                    orig_ok_r = convert_pdf_page_to_png(orig_pdf, orig_pdf_start, str(orig_png_r))
                    dig_ok_r = convert_pdf_page_to_png(dig_pdf, dig_pdf_start, str(dig_png_r))

                    if orig_ok_r and dig_ok_r:
                        rel_orig_r = Path(".mcp_tmp") / output_path.stem / orig_png_r.name
                        rel_dig_r = Path(".mcp_tmp") / output_path.stem / dig_png_r.name
                        lines.append("<table><tr>\n")
                        lines.append(f'<td><b>原始 PDF第{orig_pdf_start}页</b><br/><img src="{rel_orig_r}" width="400"/></td>\n')
                        lines.append(f'<td><b>数字化 PDF第{dig_pdf_start}页</b><br/><img src="{rel_dig_r}" width="400"/></td>\n')
                        lines.append("</tr></table>\n\n")

                    # 第二行：左页（如果存在）
                    if orig_pdf_end > orig_pdf_start or dig_pdf_end > dig_pdf_start:
                        orig_png_l = tmp_dir / f"orig_page_{page_idx}_left.png"
                        dig_png_l = tmp_dir / f"dig_page_{page_idx}_left.png"
                        orig_ok_l = convert_pdf_page_to_png(orig_pdf, orig_pdf_end, str(orig_png_l))
                        dig_ok_l = convert_pdf_page_to_png(dig_pdf, dig_pdf_end, str(dig_png_l))

                        if orig_ok_l and dig_ok_l:
                            rel_orig_l = Path(".mcp_tmp") / output_path.stem / orig_png_l.name
                            rel_dig_l = Path(".mcp_tmp") / output_path.stem / dig_png_l.name
                            lines.append("<table><tr>\n")
                            lines.append(f'<td><b>原始 PDF第{orig_pdf_end}页</b><br/><img src="{rel_orig_l}" width="400"/></td>\n')
                            lines.append(f'<td><b>数字化 PDF第{dig_pdf_end}页</b><br/><img src="{rel_dig_l}" width="400"/></td>\n')
                            lines.append("</tr></table>\n\n")
                else:
                    # 单页：一行显示
                    orig_png = tmp_dir / f"orig_page_{page_idx}.png"
                    dig_png = tmp_dir / f"dig_page_{page_idx}.png"

                    orig_ok = convert_pdf_page_to_png(orig_pdf, orig_pdf_start, str(orig_png))
                    dig_ok = convert_pdf_page_to_png(dig_pdf, dig_pdf_start, str(dig_png))

                    if orig_ok and dig_ok:
                        rel_orig = Path(".mcp_tmp") / output_path.stem / orig_png.name
                        rel_dig = Path(".mcp_tmp") / output_path.stem / dig_png.name
                        lines.append("<table><tr>\n")
                        lines.append(f'<td><b>原始 PDF第{orig_pdf_start}页</b><br/><img src="{rel_orig}" width="400"/></td>\n')
                        lines.append(f'<td><b>数字化 PDF第{dig_pdf_start}页</b><br/><img src="{rel_dig}" width="400"/></td>\n')
                        lines.append("</tr></table>\n\n")

            diff_type = diff_info.get('type')

            if diff_type == 'column_count_mismatch':
                lines.append(f"**列数不匹配：** 原始 {diff_info['orig_cols']} 列 / "
                             f"数字化 {diff_info['dig_cols']} 列\n\n")

                orig_col_data = diff_info.get('orig_col_data')
                dig_col_data = diff_info.get('dig_col_data')
                if orig_col_data and dig_col_data:
                    max_show = max(len(orig_col_data), len(dig_col_data))
                    lines.append(f"**逐列对比（全部 {max_show} 列）：**\n\n")
                    lines.append("| 列 | 原始 | 数字化 |\n")
                    lines.append("|---:|------|--------|\n")
                    for ci in range(max_show):
                        o_text = format_col_for_display(orig_col_data[ci]) if ci < len(orig_col_data) else "—"
                        d_text = format_col_for_display(dig_col_data[ci]) if ci < len(dig_col_data) else "—"
                        marker = "" if o_text == d_text else " **≠**"
                        lines.append(f"| {ci} | {o_text} | {d_text}{marker} |\n")

            elif diff_type == 'column_content_mismatch':
                col_diffs = diff_info.get('column_diffs', {})
                first_col = diff_info.get('first_diff_col', 0)
                lines.append(f"**{len(col_diffs)} 列内容不同**，从第 {first_col} 列开始\n\n")

                lines.append("**差异列详情（全部列）：**\n\n")
                for col_idx in sorted(col_diffs.keys()):
                    diff = col_diffs[col_idx]
                    orig_col = diff.get('orig', '')
                    dig_col = diff.get('dig', '')

                    lines.append(f"**第 {col_idx} 列：**\n")
                    lines.append(f"- 原始：`{format_col_for_display(orig_col)}`\n")
                    lines.append(f"- 数字化：`{format_col_for_display(dig_col)}`\n\n")

            elif diff_type == 'page_missing':
                side = "数字化版本缺失此页" if diff_info.get('orig_exists') else "原始版本缺失此页"
                lines.append(f"**{side}**\n")

    # -- 详细字符级比较结果 --
    detail_comp = comparison.get('detail_comparison')
    if detail_comp:
        lines.append("\n## 详细比较（字符级）\n\n")
        total_chars = detail_comp['total_chars']
        mismatched = detail_comp['mismatched_chars']

        if mismatched == 0:
            lines.append(f"✓ **所有 {total_chars:,} 个字符的位置完全一致**\n\n")
            lines.append("内容相同且排版布局完全一致，数字化版本准确复刻了原始版本。\n")
        else:
            match_rate = (total_chars - mismatched) / total_chars * 100 if total_chars > 0 else 0
            lines.append(f"- 总字符数：{total_chars:,}\n")
            lines.append(f"- 位置不一致：{mismatched:,} 个字符\n")
            lines.append(f"- 匹配率：{match_rate:.2f}%\n\n")

            mismatched_pages = detail_comp['mismatched_pages']
            if mismatched_pages:
                lines.append(f"### 位置差异详情（前 5 页）\n\n")
                for page_idx in mismatched_pages[:5]:
                    page_diff = detail_comp['detail_diffs'][page_idx]
                    page_label = page_diff['page_label']
                    lines.append(f"**{page_label}：**\n\n")

                    for col_idx, col_diff in list(page_diff['col_diffs'].items())[:3]:
                        if col_diff['type'] == 'char_count_mismatch':
                            lines.append(f"- 第 {col_idx} 列：字符数不匹配（原始 {col_diff['orig_count']} / 数字化 {col_diff['dig_count']}）\n")
                        elif col_diff['type'] == 'char_diffs':
                            lines.append(f"- 第 {col_idx} 列：{col_diff['diff_count']} 个字符位置不同\n")
                            for detail in col_diff['details'][:3]:
                                if detail['type'] == 'char_mismatch':
                                    lines.append(f"  - 字符 {detail['char_idx']}: `{detail['orig']}` → `{detail['dig']}`\n")
                                elif detail['type'] == 'position_mismatch':
                                    orig_pos = detail['orig_pos']
                                    dig_pos = detail['dig_pos']
                                    dx = dig_pos['x'] - orig_pos['x']
                                    dy = dig_pos['y_top'] - orig_pos['y_top']
                                    lines.append(f"  - 字符 `{detail['char']}`: 位置偏移 "
                                               f"Δx={dx:.2f}sp, Δy={dy:.2f}sp\n")
                    lines.append("\n")

    # -- 像素级 PDF 比较 --
    if pixel_comparison is not None:
        lines.append("\n## 像素级 PDF 比较\n\n")
        px_orig = pixel_comparison['total_pages_orig']
        px_dig = pixel_comparison['total_pages_digital']
        px_compared = pixel_comparison['compared_pages']
        px_identical = pixel_comparison['identical_pages']
        px_diffs = pixel_comparison['diff_pages']

        lines.append(f"- 原始 PDF：{px_orig} 页 / 数字化 PDF：{px_dig} 页\n")
        lines.append(f"- 比较页数：{px_compared} 页\n")
        lines.append(f"- 完全一致：{px_identical} 页\n")

        if px_diffs:
            lines.append(f"- **有差异：{len(px_diffs)} 页**\n\n")

            lines.append("### 像素差异页面\n\n")
            lines.append("| PDF 页码 | 差异像素数 | 差异图 |\n")
            lines.append("|----------|-----------|--------|\n")

            for d in px_diffs:
                rel_diff = Path(d['diff_image']).name
                diff_rel_path = Path(".mcp_tmp") / output_path.stem / "pixel_diff" / rel_diff
                lines.append(f"| 第{d['pdf_page']}页 | {d['diff_count']:,} | "
                             f"[{rel_diff}]({diff_rel_path}) |\n")

            # 预览前 3 页差异图
            preview_count = min(3, len(px_diffs))
            if preview_count > 0:
                lines.append(f"\n### 差异页面预览（前 {preview_count} 页）\n\n")
                for d in px_diffs[:preview_count]:
                    rel_diff = Path(d['diff_image']).name
                    diff_rel_path = Path(".mcp_tmp") / output_path.stem / "pixel_diff" / rel_diff
                    lines.append(f"**PDF 第{d['pdf_page']}页**（差异 {d['diff_count']:,} 像素）\n\n")
                    lines.append(f'<img src="{diff_rel_path}" width="600"/>\n\n')
        else:
            lines.append("- **所有页面像素级完全一致**\n")

    # Write report
    with open(output_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

    return str(output_path)


# ============================================================================
# Main Entry Point
# ============================================================================

def run_comparison(
    orig_tex: str,
    dig_tex: str,
    force_recompile: bool = False,
    no_compile: bool = False,
    output_md: str | None = None,
    skip_pixel: bool = False,
    pixel_dpi: int = 150,
    pixel_threshold: int = PIXEL_DIFF_THRESHOLD,
) -> int:
    """
    Run the full comparison pipeline: compile → compare → report.

    Returns 0 on success, 1 on error.
    """
    orig_tex_path = Path(orig_tex).resolve()
    dig_tex_path = Path(dig_tex).resolve()

    if not orig_tex_path.exists():
        print(f"错误：原始 TeX 文件不存在：{orig_tex}", file=sys.stderr)
        return 1
    if not dig_tex_path.exists():
        print(f"错误：数字化 TeX 文件不存在：{dig_tex}", file=sys.stderr)
        return 1

    orig_json = get_layout_json_path(str(orig_tex_path))
    dig_json = get_layout_json_path(str(dig_tex_path))

    # Step 1: Compile original
    print("## 步骤一：检查原始 TeX")
    if no_compile:
        if not Path(orig_json).exists():
            print(f"错误：JSON 不存在且跳过了编译：{orig_json}", file=sys.stderr)
            return 1
        # 即使跳过编译，也要检查时间戳
        need, reason = needs_recompile(str(orig_tex_path), orig_json)
        if need:
            print(f"  ⚠ 警告：{reason}")
            print(f"  使用旧的 JSON（可能导致比较结果不准确）")
        else:
            print(f"  使用已有 JSON：{reason}")
    else:
        need, reason = needs_recompile(str(orig_tex_path), orig_json)
        if force_recompile or need:
            print(f"  需要编译：{reason}")
            success, output = compile_tex(str(orig_tex_path))
            if not success:
                print(f"  ✗ 编译失败", file=sys.stderr)
                print(f"  {output}", file=sys.stderr)
                return 1
            print(f"  ✓ {output}")
        else:
            print(f"  ✓ 跳过编译：{reason}")

    # Step 2: Compile digital
    print("\n## 步骤二：检查数字化 TeX")
    if no_compile:
        if not Path(dig_json).exists():
            print(f"错误：JSON 不存在且跳过了编译：{dig_json}", file=sys.stderr)
            return 1
        # 即使跳过编译，也要检查时间戳
        need, reason = needs_recompile(str(dig_tex_path), dig_json)
        if need:
            print(f"  ⚠ 警告：{reason}")
            print(f"  使用旧的 JSON（可能导致比较结果不准确）")
        else:
            print(f"  使用已有 JSON：{reason}")
    else:
        need, reason = needs_recompile(str(dig_tex_path), dig_json)
        if force_recompile or need:
            print(f"  需要编译：{reason}")
            success, output = compile_tex(str(dig_tex_path))
            if not success:
                print(f"  ✗ 编译失败", file=sys.stderr)
                print(f"  {output}", file=sys.stderr)
                return 1
            print(f"  ✓ {output}")
        else:
            print(f"  ✓ 跳过编译：{reason}")

    # Step 3: Compare
    print("\n## 步骤三：比较排版")
    comparison = compare_layouts(orig_json, dig_json)

    total_o = comparison['total_pages_orig']
    total_d = comparison['total_pages_digital']
    matching = comparison['matching_pages']
    first_diff = comparison.get('first_diff_page')
    page_labels = comparison.get('page_label_map', {})

    print(f"  原始 {total_o} 页 / 数字化 {total_d} 页")
    print(f"  匹配页数：{matching}")

    if 'total_chars_orig' in comparison:
        co = comparison['total_chars_orig']
        cd = comparison['total_chars_digital']
        if co == cd:
            print(f"  总字数：{co}（一致）")
        else:
            print(f"  总字数：原始 {co} / 数字化 {cd}（差 {abs(co - cd)} 字）")

    if first_diff is not None:
        if first_diff > 0:
            print(f"  前 {first_diff} 页完全一致")
        label = page_labels.get(first_diff, f"第{first_diff + 1}页")
        print(f"  第一处差异在 {label}")
    else:
        print("  所有页面完全一致！")

    # Step 4: Pixel-level PDF comparison
    orig_pdf = str(orig_tex_path.with_suffix('.pdf'))
    dig_pdf = str(dig_tex_path.with_suffix('.pdf'))
    pixel_comparison = None

    if not skip_pixel and Path(orig_pdf).exists() and Path(dig_pdf).exists():
        print("\n## 步骤四：像素级 PDF 比较")

        if output_md is None:
            output_md_for_dir = str(orig_tex_path.parent / "排版一致性比较报告.md")
        else:
            output_md_for_dir = output_md
        output_path = Path(output_md_for_dir)
        pixel_diff_dir = output_path.parent / ".mcp_tmp" / output_path.stem / "pixel_diff"

        pixel_comparison = compare_pdfs_pixel(
            orig_pdf, dig_pdf,
            str(pixel_diff_dir),
            dpi=pixel_dpi,
            threshold=pixel_threshold,
        )

        px_compared = pixel_comparison['compared_pages']
        px_identical = pixel_comparison['identical_pages']
        px_diffs = pixel_comparison['diff_pages']
        print(f"  比较页数：{px_compared}")
        print(f"  完全一致：{px_identical} 页")
        if px_diffs:
            print(f"  有差异：{len(px_diffs)} 页")
            for d in px_diffs[:5]:
                print(f"    - PDF 第{d['pdf_page']}页：{d['diff_count']:,} 像素差异")
            if len(px_diffs) > 5:
                print(f"    ... 还有 {len(px_diffs) - 5} 页")
        else:
            print("  所有页面像素级完全一致！")
    elif skip_pixel:
        print("\n## 步骤四：像素级 PDF 比较（已跳过）")
    else:
        print("\n## 步骤四：像素级 PDF 比较（PDF 文件不存在，跳过）")

    # Step 5: Generate report
    if output_md is None:
        output_md = str(orig_tex_path.parent / "排版一致性比较报告.md")

    report_path = generate_markdown_report(
        comparison, orig_json, dig_json, output_md,
        orig_pdf=orig_pdf if Path(orig_pdf).exists() else None,
        dig_pdf=dig_pdf if Path(dig_pdf).exists() else None,
        pixel_comparison=pixel_comparison,
    )
    print(f"\n## 步骤五：生成报告")
    print(f"  详细报告已保存至：{report_path}")

    return 0


def main():
    parser = argparse.ArgumentParser(
        description='古籍排版一致性比较工具 - 比较原始和数字化 TeX 文件的排版',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s original.tex digital.tex
  %(prog)s original.tex digital.tex --force
  %(prog)s original.tex digital.tex -o report.md
  %(prog)s original.tex digital.tex --no-compile
        """
    )
    parser.add_argument('original_tex', help='原始 TeX 文件路径 (ltc-guji.cls)')
    parser.add_argument('digital_tex', help='数字化 TeX 文件路径 (ltc-guji-digital.cls)')
    parser.add_argument('--force', '-f', action='store_true',
                        help='强制重新编译，即使 JSON 已是最新')
    parser.add_argument('--no-compile', action='store_true',
                        help='跳过编译，只比较已有的 JSON')
    parser.add_argument('--output', '-o', default=None,
                        help='输出 Markdown 报告路径（默认：TeX 目录下的 排版一致性比较报告.md）')
    parser.add_argument('--skip-pixel', action='store_true',
                        help='跳过像素级 PDF 比较')
    parser.add_argument('--pixel-dpi', type=int, default=150,
                        help='像素比较的 DPI（默认 150）')
    parser.add_argument('--pixel-threshold', type=int, default=PIXEL_DIFF_THRESHOLD,
                        help=f'像素差异阈值，低于此值视为一致（默认 {PIXEL_DIFF_THRESHOLD}）')

    args = parser.parse_args()
    sys.exit(run_comparison(
        args.original_tex,
        args.digital_tex,
        force_recompile=args.force,
        no_compile=args.no_compile,
        output_md=args.output,
        skip_pixel=args.skip_pixel,
        pixel_dpi=args.pixel_dpi,
        pixel_threshold=args.pixel_threshold,
    ))


if __name__ == '__main__':
    main()
