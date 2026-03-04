#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
guji-digital → guji 逆向转换引擎

将使用 ltc-guji-digital（布局模式）编写的古籍排版文件转换回 ltc-guji（语义模式）格式。
支持插件机制，允许模板特有命令的扩展处理。

用法:
    python3 digital_to_semantic.py --input INPUT-digital.tex --output OUTPUT.tex [--plugin PLUGIN.py]
    python3 digital_to_semantic.py --input 冊一-digital.tex --output 冊一.tex --plugin plugins/siku_mulu_to_semantic.py
"""

import argparse
import importlib.util
import re
import sys
from pathlib import Path
from typing import List, Dict, Optional, Tuple


# =============================================================================
# 常量
# =============================================================================

FULL_WIDTH_SPACE = '\u3000'  # 全角空格 U+3000
PUNCTUATION = "，。、；：「」『』《》〈〉·？！（）〔〕"


# =============================================================================
# 插件基类
# =============================================================================

class DigitalToSemanticPlugin:
    """插件基类 - 每个模板特有的命令处理"""

    def preprocess_line(self, line: str) -> Optional[str]:
        """预处理单行。返回处理后的行，或 None 表示不处理（交给核心引擎）"""
        return None

    def recognize_pattern(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        """
        识别模板特有的模式。
        返回 (转换后的内容, 消耗的行数) 或 None 表示不识别
        """
        return None

    def postprocess_content(self, content: str) -> str:
        """后处理转换后的内容（可选）"""
        return content

    def get_cfg_mapping(self) -> Dict[str, str]:
        """返回 cfg 文件名映射 {digital_cfg: semantic_cfg}"""
        return {}

    def get_zhu_indent(self) -> int:
        r"""返回 \注 命令的 indent 级别（默认 2）"""
        return 2

    def get_an_indent(self) -> int:
        r"""返回 \按 命令的 indent 级别（默认 4）"""
        return 4


# =============================================================================
# 文本工具
# =============================================================================

def extract_brace_content(text: str, start: int = 0) -> Tuple[str, int]:
    """从 start 位置提取花括号内的内容，支持嵌套。返回 (content, end_pos)"""
    if start >= len(text) or text[start] != '{':
        return '', start
    depth = 0
    begin = start + 1
    for i in range(start, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return text[begin:i], i + 1
    return text[begin:], len(text)


def strip_yangshi(text: str) -> str:
    r"""移除 \样式[...]{content} 包装，保留 content"""
    while r'\样式[' in text:
        m = re.search(r'\\样式\[[^\]]*\]\{', text)
        if not m:
            break
        content, end = extract_brace_content(text, m.end() - 1)
        text = text[:m.start()] + content + text[end:]
    return text


def count_leading_fullwidth_spaces(line: str) -> int:
    """计算行首全角空格数量"""
    count = 0
    for ch in line:
        if ch == FULL_WIDTH_SPACE:
            count += 1
        else:
            break
    return count


def is_shuanglie_line(line: str) -> bool:
    r"""判断是否是 \双列 相关行（含 \缩进[N]\双列 和 \双列 续行）"""
    stripped = line.strip()
    if stripped.startswith(r'\双列'):
        return True
    # \缩进[N]\双列 或 \缩进[N] \双列
    if r'\缩进' in stripped and r'\双列' in stripped:
        return True
    return False


def parse_line_indent(line: str) -> Tuple[Optional[int], str]:
    r"""提取行首 \缩进[N]，返回 (indent_level, rest_of_line)。
    如果没有 \缩进 前缀，返回 (None, original_line)。
    """
    match = re.match(r'\\缩进\[(-?\d+)\]\s*', line.strip())
    if match:
        indent = int(match.group(1))
        rest = line.strip()[match.end():]
        return indent, rest
    return None, line.strip()


def parse_subcol_indent(text: str) -> Tuple[Optional[int], str]:
    r"""提取小列内容开头的 \缩进[N]，返回 (indent, clean_text)。"""
    match = re.match(r'\\缩进\[(-?\d+)\]\s*', text)
    if match:
        return int(match.group(1)), text[match.end():]
    return None, text


def parse_shuanglie_from_line(line: str) -> Optional[Dict]:
    r"""解析一行 \双列{...}，返回 subcol 信息。
    返回 {'line_indent': N, 'right': (text, indent), 'left': (text, indent, optional_arg)}
    或 None
    """
    stripped = line.strip()

    # 提取行级 \缩进[N]
    line_indent, rest = parse_line_indent(stripped)

    # 提取 \样式[...]{...} 包装（如果有）
    style_prefix = ''
    style_suffix = ''
    style_match = re.match(r'(\\样式\[[^\]]*\]\{)', rest)
    if style_match and rest.endswith('}'):
        style_prefix = style_match.group(1)
        rest = rest[style_match.end():]
        if rest.endswith('}'):
            rest = rest[:-1]
            style_suffix = '}'

    # 必须有 \双列
    if not rest.startswith(r'\双列'):
        return None

    # 处理多行 \双列{%\n  \右小列{...}%\n  \左小列{...}%\n}
    # 简单情况：单行 \双列{...}
    shuanglie_start = rest.find('{')
    if shuanglie_start < 0:
        return None

    shuanglie_content, _ = extract_brace_content(rest, shuanglie_start)
    if not shuanglie_content:
        return None

    # 检查 \双列{...} 内容开头是否有块级 \缩进[N]（在 \右小列 之前）
    block_indent, _ = parse_subcol_indent(shuanglie_content.strip())

    # 解析 \右小列{...}
    right_pos = shuanglie_content.find(r'\右小列')
    if right_pos < 0:
        return None

    # 右小列可能有可选参数
    right_after = shuanglie_content[right_pos + len(r'\右小列'):]
    right_opt = None
    right_opt_match = re.match(r'\[([^\]]*)\]', right_after)
    if right_opt_match:
        right_opt = right_opt_match.group(1)
        right_after = right_after[right_opt_match.end():]

    if not right_after.startswith('{'):
        return None
    right_text, right_end_rel = extract_brace_content(right_after, 0)

    # 解析 \左小列{...}（可能有可选参数）
    left_rest = right_after[right_end_rel:]
    left_pos = left_rest.find(r'\左小列')
    if left_pos < 0:
        return None

    left_after = left_rest[left_pos + len(r'\左小列'):]
    left_opt = None
    left_opt_match = re.match(r'\[([^\]]*)\]', left_after)
    if left_opt_match:
        left_opt = left_opt_match.group(1)
        left_after = left_after[left_opt_match.end():]

    if not left_after.startswith('{'):
        return None
    left_text, _ = extract_brace_content(left_after, 0)

    # 提取小列内部的 \缩进[N]
    right_subcol_indent, right_clean = parse_subcol_indent(right_text)
    left_subcol_indent, left_clean = parse_subcol_indent(left_text)

    # 如果左小列有 [indent=N] 可选参数
    left_indent_from_opt = None
    if left_opt:
        indent_match = re.search(r'indent=(-?\d+)', left_opt)
        if indent_match:
            left_indent_from_opt = int(indent_match.group(1))

    # 确定每个小列的有效 indent（优先级: subcol > left_opt > block > line）
    right_effective = right_subcol_indent if right_subcol_indent is not None else (block_indent if block_indent is not None else line_indent)
    left_effective = left_subcol_indent if left_subcol_indent is not None else (left_indent_from_opt if left_indent_from_opt is not None else (block_indent if block_indent is not None else line_indent))

    return {
        'line_indent': line_indent,
        'right': (right_clean, right_effective),
        'left': (left_clean, left_effective, left_opt),
        'style_prefix': style_prefix,
        'style_suffix': style_suffix,
    }


# =============================================================================
# 核心转换器
# =============================================================================

class ReverseConverter:
    r"""digital → semantic 逆向转换器"""

    def __init__(self, plugin: Optional[DigitalToSemanticPlugin] = None):
        self.plugin = plugin
        self.in_bodytext = False
        self.zhu_indent = plugin.get_zhu_indent() if plugin and hasattr(plugin, 'get_zhu_indent') else 2
        self.an_indent = plugin.get_an_indent() if plugin and hasattr(plugin, 'get_an_indent') else 4

    def convert_file(self, input_path: Path, output_path: Path):
        """转换整个文件"""
        with open(input_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        output_lines = []
        i = 0
        while i < len(lines):
            line = lines[i]

            # 插件预处理
            if self.plugin:
                processed = self.plugin.preprocess_line(line)
                if processed is not None:
                    output_lines.append(processed)
                    i += 1
                    continue

            # 核心转换
            converted, consumed = self.convert_line(lines, i)
            output_lines.extend(converted)
            i += consumed

        # 后处理
        content = ''.join(output_lines)
        if self.plugin:
            content = self.plugin.postprocess_content(content)

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(content)

    def convert_line(self, lines: List[str], index: int) -> Tuple[List[str], int]:
        """
        转换一行或多行（如果需要合并）
        返回 (转换后的行列表, 消耗的行数)
        """
        line = lines[index]

        # 插件模式识别（优先级最高）
        if self.plugin:
            result = self.plugin.recognize_pattern(lines, index)
            if result:
                converted_text, consumed = result
                if isinstance(converted_text, list):
                    return converted_text, consumed
                return [converted_text], consumed

        # 1. documentclass 转换（含 cfg 名映射）
        if line.strip().startswith(r'\documentclass'):
            converted = line.replace('ltc-guji-digital', 'ltc-guji')
            if self.plugin and hasattr(self.plugin, 'get_cfg_mapping'):
                for digital_cfg, semantic_cfg in self.plugin.get_cfg_mapping().items():
                    converted = converted.replace(digital_cfg, semantic_cfg)
            return [converted], 1

        # 2. 删除多余的 \usepackage{comment}
        if r'\usepackage{comment}' in line and index > 0:
            prev_line = lines[index - 1]
            if r'\documentclass' in prev_line:
                return [], 1

        # 3. \begin{正文} / \end{正文}
        if r'\begin{正文}' in line:
            self.in_bodytext = True
            return [line], 1
        if r'\end{正文}' in line:
            self.in_bodytext = False
            return [line], 1

        # 4. \chapter{...} 保持不变
        if line.strip().startswith(r'\chapter'):
            return [line], 1

        # 5. \换页 处理：只在 \chapter 前转为 \newpage，其他位置丢弃
        if line.strip() == r'\换页':
            # 查看下一个非空行是否是 \chapter
            j = index + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and lines[j].strip().startswith(r'\chapter'):
                return ['\\newpage\n'], 1
            else:
                return [], 1  # 丢弃

        # 6. 处理 \缩进 和 \双列（在正文内）
        if self.in_bodytext:
            stripped = line.strip()
            if r'\缩进' in stripped or stripped.startswith(r'\双列'):
                return self.convert_indented_blocks(lines, index)

        # 7. 检测 first-indent=0 段落（纯文本行 + 3+ 行同缩进 \缩进[N]）
        if self.in_bodytext:
            stripped = line.strip()
            if stripped and not stripped.startswith('\\'):
                result = self._try_first_indent_paragraph(lines, index)
                if result:
                    return result

        # 8. 处理条目列表（全角空格缩进）
        if line.startswith(FULL_WIDTH_SPACE) and r'\缩进' not in line:
            return self.convert_tiaommu(line), 1

        # 9. 其他行保持不变
        return [line], 1

    # =========================================================================
    # \缩进 和 \双列 块的转换
    # =========================================================================

    def convert_indented_blocks(self, lines: List[str], start_index: int) -> Tuple[List[str], int]:
        r"""
        处理 \缩进 和 \双列 相关的行。根据模式分派到不同的转换逻辑：
        - \缩进[N]\双列{...} → \注{...} 或 \按{...}
        - \缩进[N]text\双列{...} → \条目[N]{text\夹注[...]{...}}
        - \缩进[N] text → \条目[N]{text} 或 \begin{段落}
        - \双列{...}（续行） → 合并到前面的块
        """
        first_line = lines[start_index]
        stripped = first_line.strip()

        # Case A: 以 \双列 开头（续行，不应该在这里出现，做防御处理）
        if stripped.startswith(r'\双列'):
            return self._convert_shuanglie_block(lines, start_index)

        # 提取行级 indent
        line_indent, rest = parse_line_indent(stripped)
        if line_indent is None:
            return [first_line], 1

        # Case B: \缩进[N]后面有 \双列（可能紧跟或间隔空格）
        if r'\双列' in rest:
            # 检查是否是 \缩进[N]text\双列{...} (条目内嵌夹注)
            shuanglie_pos = rest.find(r'\双列')
            text_before = rest[:shuanglie_pos].strip()
            if text_before and not text_before.startswith(r'\样式'):
                # 条目 + 夹注模式: \缩进[N]別集類一\双列{\右小列{漢至五代}\左小列{}}
                return self._convert_tiaommu_with_jiazhu(
                    first_line, line_indent, text_before, rest[shuanglie_pos:]), 1

            # 纯 \缩进[N]\双列{...} → \注 或 \按
            return self._convert_shuanglie_block(lines, start_index)

        # Case C: \缩进[N] text（无 \双列）→ \条目 或 \段落
        return self._convert_suojin_text(lines, start_index, line_indent)

    def _convert_shuanglie_block(self, lines: List[str], start_index: int) -> Tuple[List[str], int]:
        r"""收集并转换一组 \双列 行为 \注{...} 和/或 \按{...}"""

        # Step 1: 收集所有连续的 \双列 相关行（支持多行 \双列{%...}）
        block_data = []  # [(right_text, right_indent, left_text, left_indent, left_opt, style_prefix, style_suffix)]
        consumed = 0

        while start_index + consumed < len(lines):
            cur_line = lines[start_index + consumed]
            cur_stripped = cur_line.strip()

            # 跳过空行
            if not cur_stripped:
                break

            # \换页: 跳过（跨页合并 \注/\按）
            if cur_stripped == r'\换页':
                consumed += 1
                continue

            # 是 \双列 相关行？
            if is_shuanglie_line(cur_stripped):
                # 检查多行 \双列{% 模式
                if cur_stripped.endswith('{%') or cur_stripped.endswith(r'\双列{%'):
                    merged, extra = self._collect_multiline_shuanglie(lines, start_index + consumed)
                    if merged:
                        parsed = parse_shuanglie_from_line(merged)
                        if parsed:
                            r_text, r_indent = parsed['right']
                            l_text, l_indent, l_opt = parsed['left']
                            block_data.append((
                                r_text, r_indent,
                                l_text, l_indent, l_opt,
                                parsed.get('style_prefix', ''),
                                parsed.get('style_suffix', ''),
                            ))
                            consumed += extra
                            continue

                parsed = parse_shuanglie_from_line(cur_stripped)
                if parsed:
                    r_text, r_indent = parsed['right']
                    l_text, l_indent, l_opt = parsed['left']
                    block_data.append((
                        r_text, r_indent,
                        l_text, l_indent, l_opt,
                        parsed.get('style_prefix', ''),
                        parsed.get('style_suffix', ''),
                    ))
                    consumed += 1
                    continue
                else:
                    # 无法解析的 \双列 行，停止收集
                    break
            else:
                # 不是 \双列 行，停止收集
                break

        if not block_data:
            return [lines[start_index]], 1

        # Step 2: 将 subcol 对扁平化为 subcol 流（保留 \样式 包装）
        subcol_flow = []  # [(text, indent, optional_arg)]
        line_style = ''  # 行级 \样式 包装（如 \样式[grid-height=24pt]{ ）
        for r_text, r_indent, l_text, l_indent, l_opt, style_pre, style_suf in block_data:
            subcol_flow.append((r_text, r_indent, None))
            subcol_flow.append((l_text, l_indent, l_opt))
            if style_pre and not line_style:
                line_style = style_pre  # 记录行级 \样式

        # Step 3: 按 base indent 分组
        groups = self._group_subcols(subcol_flow)

        # Step 4: 生成输出
        output = []
        for base_indent, subcol_texts in groups:
            merged = ''.join(subcol_texts)
            if not merged:
                continue
            # 行级 \样式 包装（如果有）
            if line_style:
                merged = f'{line_style}{merged}}}'
                line_style = ''  # 只用一次
            if base_indent >= self.an_indent:
                output.append(f'\\按{{{merged}}}\n')
            else:
                output.append(f'\\注{{{merged}}}\n')

        if not output:
            return [lines[start_index]], 1

        return output, consumed

    def _group_subcols(self, subcol_flow: List[Tuple[str, Optional[int], Optional[str]]]) -> List[Tuple[int, List[str]]]:
        r"""将 subcol 流按 base indent 分组，并重建抬头命令。
        indent=2 → \注 组，indent=4 → \按 组。
        其他 indent（-1, 0, 1, 3）视为抬头命令。
        """
        if not subcol_flow:
            return []

        groups = []  # [(base_indent, [text, ...])]
        current_base = None
        current_texts = []

        for text, indent, opt_arg in subcol_flow:
            if not text and not opt_arg:
                continue  # 跳过空 subcol

            # 确定这个 subcol 属于哪个 base indent
            if indent is not None and indent in (self.zhu_indent, self.an_indent):
                # 明确的 base indent → 正常文本
                if current_base is not None and indent != current_base:
                    groups.append((current_base, current_texts))
                    current_texts = []
                current_base = indent
                current_texts.append(text)
            elif current_base is None:
                # 没有当前 base，使用第一个有效 indent
                is_taitou = False
                if indent is not None:
                    if indent == self.zhu_indent:
                        current_base = self.zhu_indent
                    elif indent >= self.an_indent:
                        current_base = self.an_indent
                    else:
                        # 非 base indent（如 1, -1, 0）→ 推断 base，应用抬头
                        current_base = self.zhu_indent
                        is_taitou = True
                else:
                    current_base = self.zhu_indent  # 默认
                    is_taitou = True
                if is_taitou:
                    current_texts.append(self._apply_taitou(text, indent, current_base))
                else:
                    current_texts.append(text)
            else:
                # 非 base indent → 可能是抬头命令
                taitou_text = self._apply_taitou(text, indent, current_base)
                current_texts.append(taitou_text)

        # 保存最后一组
        if current_texts and current_base is not None:
            groups.append((current_base, current_texts))

        return groups

    def _apply_taitou(self, text: str, indent: Optional[int], base_indent: int) -> str:
        r"""根据 indent 和 base_indent 应用抬头命令。
        在 \注 和 \按 上下文中都适用。
        \按 上下文中抬头命令前加换行（匹配目标格式）。
        """
        # \按 上下文中抬头命令在新行，\注 上下文中内联
        nl = '\n' if base_indent >= self.an_indent else ''
        if indent == -1:
            return f'{nl}\\单抬 {text}'
        elif indent is None or indent == 0:
            return f'{nl}\\平抬 {text}'
        elif 0 < indent < base_indent:
            keyword = self._extract_taitou_keyword(text)
            if keyword:
                diff = base_indent - indent
                rest = text[len(keyword):]
                if keyword == '國朝' and diff == 1:
                    return f'{nl}\\國朝 {rest}' if rest else f'{nl}\\國朝'
                else:
                    return f'{nl}\\相对抬头[{diff}]{{{keyword}}} {rest}'
            else:
                return f'{nl}\\平抬 {text}'
        return text

    def _has_continuation(self, lines: List[str], from_index: int, target_indent: int) -> bool:
        r"""检查 from_index 之后是否还有 \缩进[target_indent] 行（跳过 \换页）"""
        j = from_index
        while j < len(lines):
            js = lines[j].strip()
            if js == r'\换页':
                j += 1
                continue
            ji, _ = parse_line_indent(js)
            return ji == target_indent and r'\双列' not in js
        return False

    def _extract_taitou_keyword(self, text: str) -> Optional[str]:
        r"""提取抬头关键词（如 "國朝"）"""
        known_keywords = ['國朝']
        for kw in known_keywords:
            if text.startswith(kw):
                return kw
        return None

    def _collect_multiline_shuanglie(self, lines: List[str], start: int) -> Tuple[Optional[str], int]:
        r"""收集多行 \双列{%\n...\n} 并合并为单行。返回 (merged_line, lines_consumed) 或 (None, 0)"""
        parts = []
        depth = 0
        consumed = 0

        while start + consumed < len(lines):
            line = lines[start + consumed].strip()
            # 去掉行末 %
            clean = line.rstrip('%').rstrip()
            parts.append(clean)
            consumed += 1

            # 计算花括号深度
            for ch in clean:
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1

            if depth <= 0:
                break

        if depth == 0:
            merged = ' '.join(parts)
            return merged, consumed

        return None, 0

    def _try_first_indent_paragraph(self, lines: List[str], index: int) -> Optional[Tuple[List[str], int]]:
        r"""检测 first-indent=0 段落：纯文本行 + 3+ 行 \缩进[N]（无 \双列）"""
        if index + 1 >= len(lines):
            return None

        next_stripped = lines[index + 1].strip()
        next_indent, _ = parse_line_indent(next_stripped)
        if next_indent is None or r'\双列' in next_stripped:
            return None

        # 计算有多少连续同缩进行
        count = 0
        j = index + 1
        while j < len(lines):
            js = lines[j].strip()
            if js == r'\换页':
                j += 1
                continue
            ji, _ = parse_line_indent(js)
            if ji == next_indent and r'\双列' not in js:
                count += 1
                j += 1
            else:
                break

        if count < 3:
            return None

        # 收集所有内容
        first_text = lines[index].strip()
        collected = [first_text + '\n']
        consumed = 1

        while index + consumed < len(lines):
            cur = lines[index + consumed].strip()
            if cur == r'\换页':
                if self._has_continuation(lines, index + consumed + 1, next_indent):
                    consumed += 1
                    continue
                else:
                    break
            ci, cr = parse_line_indent(cur)
            if ci == next_indent and r'\双列' not in cur:
                collected.append(cr + '\n')
                consumed += 1
            else:
                break

        merged = ''.join(collected)
        return [f'\\begin{{段落}}[indent={next_indent}, first-indent=0]\n{merged}\\end{{段落}}\n'], consumed

    def _convert_suojin_text(self, lines: List[str], start_index: int, first_indent: int) -> Tuple[List[str], int]:
        r"""转换 \缩进[N] text 行（无 \双列）为 \条目 或 \begin{段落}"""

        # 收集连续同 indent 的行（跨 \换页）
        collected_texts = []
        consumed = 0

        while start_index + consumed < len(lines):
            cur_line = lines[start_index + consumed]
            cur_stripped = cur_line.strip()

            # \换页: 只在段落继续时跳过，否则停止（让主循环处理）
            if cur_stripped == r'\换页':
                if self._has_continuation(lines, start_index + consumed + 1, first_indent):
                    consumed += 1
                    continue
                else:
                    break

            # 解析 indent
            cur_indent, cur_rest = parse_line_indent(cur_stripped)
            if cur_indent is None:
                break

            # indent 不同 → 停止
            if cur_indent != first_indent:
                break

            # 有 \双列 → 停止
            if r'\双列' in cur_rest:
                break

            collected_texts.append(cur_rest)
            consumed += 1

        if not collected_texts:
            return [lines[start_index]], 1

        # 判断是 \条目（单行）还是 \段落（多行）
        if len(collected_texts) == 1:
            # 单行 → \条目（即使中间有 \换页 也只有一行文本）
            return [f'\\条目[{first_indent}]{{{collected_texts[0]}}}\n'], consumed
        else:
            # 多行 → \段落
            merged = '\n'.join(collected_texts) + '\n'
            return [f'\\begin{{段落}}[indent={first_indent}]\n{merged}\\end{{段落}}\n'], consumed

    def _convert_tiaommu_with_jiazhu(self, line: str, indent: int, text: str, shuanglie_rest: str) -> List[str]:
        r"""转换 \缩进[N]text\双列{\右小列{X}\左小列{}} → \条目[N]{text\夹注[...]{X}}"""

        # 解析 \双列 部分
        parsed = parse_shuanglie_from_line(f'\\双列{shuanglie_rest[len(r"\\双列"):]}' if not shuanglie_rest.startswith(r'\双列') else shuanglie_rest)
        if not parsed:
            # 尝试直接从原行解析
            parsed = parse_shuanglie_from_line(line.strip())

        if parsed:
            r_text = parsed['right'][0]
            l_text = parsed['left'][0]

            if not l_text:
                # 左小列为空 → 条目内嵌夹注
                if r_text:
                    return [f'\\条目[{indent}]{{{text}\\夹注[自动均衡=false]{{{r_text}}}}}\n']

            # 左小列不为空 → 不是简单的条目夹注，回退到普通条目
            full_text = text + r_text + l_text
            return [f'\\条目[{indent}]{{{full_text}}}\n']

        # 解析失败，保留原行
        return [f'\\条目[{indent}]{{{text}}}\n']

    def convert_tiaommu(self, line: str) -> List[str]:
        r"""转换条目列表（全角空格缩进 → \条目[N]{...}）"""
        spaces = count_leading_fullwidth_spaces(line)
        content = line[spaces:].strip()
        if content:
            return [f'\\条目[{spaces}]{{{content}}}\n']
        return [line]


# =============================================================================
# 主程序
# =============================================================================

def load_plugin(plugin_path: str) -> Optional[DigitalToSemanticPlugin]:
    """动态加载插件"""
    if not plugin_path:
        return None

    plugin_file = Path(plugin_path)
    if not plugin_file.exists():
        print(f"错误：插件文件不存在: {plugin_path}", file=sys.stderr)
        return None

    spec = importlib.util.spec_from_file_location("plugin_module", plugin_file)
    if not spec or not spec.loader:
        print(f"错误：无法加载插件: {plugin_path}", file=sys.stderr)
        return None

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    # 查找插件类（使用鸭子类型 - 检查是否有必要的方法）
    for name in dir(module):
        obj = getattr(module, name)
        if isinstance(obj, type) and name.endswith('Plugin') and name != 'DigitalToSemanticPlugin':
            if hasattr(obj, 'recognize_pattern') and hasattr(obj, 'postprocess_content'):
                return obj()

    print(f"警告：插件文件中未找到有效的插件类，将不使用插件", file=sys.stderr)
    return None


def main():
    parser = argparse.ArgumentParser(
        description='将 ltc-guji-digital 文件转换回 ltc-guji 格式'
    )
    parser.add_argument('--input', '-i', required=True, help='输入文件（digital 格式）')
    parser.add_argument('--output', '-o', required=True, help='输出文件（guji 格式）')
    parser.add_argument('--plugin', '-p', help='插件文件路径（可选）')

    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"错误：输入文件不存在: {args.input}", file=sys.stderr)
        sys.exit(1)

    # 加载插件
    plugin = load_plugin(args.plugin) if args.plugin else None

    # 转换
    converter = ReverseConverter(plugin=plugin)
    converter.convert_file(input_path, output_path)

    print(f"✓ 转换完成: {output_path}")


if __name__ == '__main__':
    main()
