#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
guji-digital → guji 逆向转换引擎

将使用 ltc-guji-digital（布局模式）编写的古籍排版文件转换回 ltc-guji（语义模式）格式。
支持插件机制，允许模板特有命令的扩展处理。

用法:
    python3 reverse_converter.py --input INPUT-digital.tex --output OUTPUT.tex [--plugin PLUGIN.py]
    python3 reverse_converter.py --input 冊一-digital.tex --output 冊一.tex --plugin plugins/siku_mulu.py
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

FULL_WIDTH_SPACE = '　'  # 全角空格 U+3000
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


def extract_optional_arg(text: str, start: int = 0) -> Tuple[str, int]:
    """提取可选参数 [...]，返回 (content, end_pos)"""
    match = re.match(r'\s*\[([^\]]*)\]', text[start:])
    if match:
        return match.group(1), start + match.end()
    return '', start


def count_leading_fullwidth_spaces(line: str) -> int:
    """计算行首全角空格数量"""
    count = 0
    for ch in line:
        if ch == FULL_WIDTH_SPACE:
            count += 1
        else:
            break
    return count


# =============================================================================
# 核心转换器
# =============================================================================

class ReverseConverter:
    """digital → semantic 逆向转换器"""

    def __init__(self, plugin: Optional[DigitalToSemanticPlugin] = None):
        self.plugin = plugin
        self.in_bodytext = False  # 是否在 \begin{正文} 内

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
                return [converted_text], consumed

        # 1. documentclass 转换
        if line.strip().startswith(r'\documentclass'):
            converted = line.replace('ltc-guji-digital', 'ltc-guji')
            # 移除 \usepackage{comment} 行（如果下一行是）
            return [converted], 1

        # 2. 删除多余的 \usepackage{comment}
        if r'\usepackage{comment}' in line and index > 0:
            prev_line = lines[index - 1]
            if r'\documentclass' in prev_line:
                return [], 1  # 跳过这行

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

        # 5. \换页 → \newpage
        if line.strip() == r'\换页':
            return [r'\newpage' + '\n'], 1

        # 6. 处理 \缩进 命令（可能需要合并多行）
        if r'\缩进' in line and self.in_bodytext:
            return self.convert_indented_blocks(lines, index)

        # 7. 处理条目列表（全角空格缩进）
        if line.startswith(FULL_WIDTH_SPACE) and not r'\缩进' in line:
            return self.convert_tiaommu(line), 1

        # 8. 其他行保持不变
        return [line], 1

    def convert_indented_blocks(self, lines: List[str], start_index: int) -> Tuple[List[str], int]:
        r"""
        转换 \缩进 块，可能合并多行为 \begin{段落}...\end{段落} 或 \注{...}/\按{...}
        """
        # 解析第一行
        first_line = lines[start_index]
        indent_level, has_shuanglie, right_text, left_text, trailing = self.parse_suojin_line(first_line)

        # 情况 1: \缩进[N]\双列{...} → \注{...} 或 \按{...}
        if has_shuanglie:
            # 收集连续的同类 \缩进[N]\双列 行（缩进级别必须相同）
            collected_lines = [(indent_level, right_text, left_text, trailing)]
            consumed = 1

            while start_index + consumed < len(lines):
                next_line = lines[start_index + consumed]
                if not r'\缩进' in next_line:
                    break
                next_indent, next_shuanglie, next_right, next_left, next_trailing = self.parse_suojin_line(next_line)
                if not next_shuanglie:
                    break
                # 关键修复：缩进级别必须相同，否则结束当前块
                if next_indent != indent_level:
                    break
                collected_lines.append((next_indent, next_right, next_left, next_trailing))
                consumed += 1

            # 合并文本
            all_text = []
            for ind, right, left, trail in collected_lines:
                all_text.append(right + left)

            merged_text = ''.join(all_text)

            # 判断是 \注 还是 \按
            if indent_level >= 4:
                # \按 命令
                result = f'\\按{{{merged_text}}}\n'
            else:
                # \注 命令
                result = f'\\注{{{merged_text}}}\n'

            return [result], consumed

        # 情况 2: \缩进[N] 文本（无 \双列）→ 合并为 \begin{段落}...\end{段落}
        # 收集连续的相同缩进级别的行
        collected_text = [trailing] if trailing else []
        consumed = 1

        while start_index + consumed < len(lines):
            next_line = lines[start_index + consumed]
            if not r'\缩进' in next_line:
                break
            next_indent, next_shuanglie, _, _, next_trailing = self.parse_suojin_line(next_line)
            if next_shuanglie:
                break
            if next_indent != indent_level:
                break
            if next_trailing:
                collected_text.append(next_trailing)
            consumed += 1

        # 如果收集到多行，合并为段落
        if collected_text:
            merged = ''.join(collected_text)
            # 检查 first_indent（第一行是否有额外缩进）
            # 简化处理：使用 \begin{段落}[indent=N]
            result = f'\\begin{{段落}}[indent={indent_level}]\n{merged}\\end{{段落}}\n'
            return [result], consumed
        else:
            # 只有一个 \缩进[N]，没有内容
            return [first_line], 1

    def parse_suojin_line(self, line: str) -> Tuple[int, bool, str, str, str]:
        r"""
        解析 \缩进 行，返回 (缩进级别, 是否有\双列, 右小列, 左小列, 尾随文本)
        """
        # 匹配 \缩进[N]
        match = re.match(r'\\缩进\[(\d+)\]\s*', line)
        if not match:
            return 0, False, '', '', line.strip() + '\n'

        indent_level = int(match.group(1))
        rest = line[match.end():]

        # 检查是否有 \双列
        if r'\双列' in rest:
            # 提取 \右小列{...}\左小列{...}
            shuanglie_match = re.search(r'\\双列\{\\右小列\{([^}]*)\}\\左小列(?:\[([^\]]*)\])?\{([^}]*)\}\}', rest)
            if shuanglie_match:
                right_text = shuanglie_match.group(1)
                left_optional = shuanglie_match.group(2)  # 可选参数（如 indent=1）
                left_text = shuanglie_match.group(3)

                # 处理左小列的可选参数（如 \國朝）
                if left_optional and 'indent=1' in left_optional:
                    # 特殊处理：\左小列[indent=1]{國朝...} → 标记为特殊命令
                    left_text = f'{{GUOCHAO}}{left_text}'

                trailing = rest[shuanglie_match.end():].strip()
                return indent_level, True, right_text, left_text, trailing + '\n' if trailing else ''

        # 没有 \双列，只有普通文本
        return indent_level, False, '', '', rest

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
            # 检查是否有必要的方法
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
