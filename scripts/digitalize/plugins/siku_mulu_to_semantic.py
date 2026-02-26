#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
四库全书简明目录 - Digital → Semantic 转换插件

处理四库全书简明目录特有的命令，如：
- \國朝 标记（\左小列[indent=1]{...}）
- 抬头命令保留（\单抬、\平抬、\相对抬头）
- first-indent 处理
"""

import re
from typing import List, Optional, Tuple


# 插件基类定义（从 digital_to_semantic.py 复制）
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


class SikuMuluToSemanticPlugin(DigitalToSemanticPlugin):
    """四库全书简明目录 Digital → Semantic 转换插件"""

    def __init__(self):
        self.in_zhu_block = False  # 标记当前是否在 \注 块中
        self.in_an_block = False   # 标记当前是否在 \按 块中

    def recognize_pattern(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        """识别四库全书特有模式"""
        line = lines[index]

        # 1. 检测 \國朝 模式（需要检查多行）
        # 模式：\缩进[2]\双列{\右小列{...}\左小列[indent=1]{國朝...}}
        if r'\缩进[2]\双列' in line and r'\左小列[indent=1]' in line:
            # 解析这个特殊的夹注块
            match = re.search(
                r'\\缩进\[2\]\\双列\{\\右小列\{([^}]*)\}\\左小列\[indent=1\]\{([^}]*)\}\}',
                line
            )
            if match:
                right_text = match.group(1)
                left_text = match.group(2)

                # 收集后续的 \缩进[1]\双列 行（可能跨行）
                consumed = 1
                additional_text = []

                while index + consumed < len(lines):
                    next_line = lines[index + consumed]
                    if not r'\缩进[1]\双列' in next_line:
                        break

                    next_match = re.search(
                        r'\\缩进\[1\]\\双列\{\\右小列\{([^}]*)\}\\左小列\{([^}]*)\}\}',
                        next_line
                    )
                    if next_match:
                        additional_text.append(next_match.group(1) + next_match.group(2))
                        consumed += 1
                    else:
                        break

                # 组装为 \注{...} + \國朝 + 后续文本
                # 注意：left_text 开头的 "國朝" 两个字需要去掉，替换为 \國朝 命令
                if left_text.startswith('國朝'):
                    left_text = left_text[2:]  # 去掉开头的 "國朝"

                result = f'\\注{{{right_text}}}\n\n'
                result += f'\\國朝 {left_text}{"".join(additional_text)}\n'

                return result, consumed

        # 2. 处理抬头命令（保持不变）
        if any(cmd in line for cmd in [r'\单抬', r'\平抬', r'\相对抬头']):
            # 这些命令在 digital 和 guji 中格式相同，保持不变
            return line, 1

        # 3. 处理 first-indent=0 的段落
        # 模式：连续的 \缩进[1] 行（第一行缩进2，后续缩进1）
        if r'\缩进[2]' in line and index + 1 < len(lines):
            next_line = lines[index + 1]
            if r'\缩进[1]' in next_line and not r'\双列' in next_line:
                # 这是一个 first-indent=0 的段落
                # 收集所有 \缩进[1] 行
                text_parts = [self._extract_text_after_suojin(line)]
                consumed = 1

                while index + consumed < len(lines):
                    curr_line = lines[index + consumed]
                    if not r'\缩进[1]' in curr_line or r'\双列' in curr_line:
                        break
                    text_parts.append(self._extract_text_after_suojin(curr_line))
                    consumed += 1

                # 合并为 \begin{段落}[indent=1, first-indent=0]
                merged_text = ''.join(text_parts)
                result = f'\\begin{{段落}}[indent=1, first-indent=0]\n{merged_text}\\end{{段落}}\n'
                return result, consumed

        return None

    def _extract_text_after_suojin(self, line: str) -> str:
        """提取 \缩进[N] 后的文本"""
        match = re.match(r'\\缩进\[\d+\]\s*(.*)', line)
        if match:
            text = match.group(1).strip()
            return text + '\n' if text else ''
        return ''

    def postprocess_content(self, content: str) -> str:
        """后处理：清理多余空行，修复格式"""
        # 1. 移除连续的多个空行（保留最多两个换行）
        content = re.sub(r'\n{3,}', '\n\n', content)

        # 2. 修复 \注 和 \按 与正文之间的空行
        content = re.sub(r'(\\注\{[^}]+\})\n{2,}', r'\1\n\n', content)
        content = re.sub(r'(\\按\{[^}]+\})\n{2,}', r'\1\n\n', content)

        # 3. 修复 \國朝 前的空行
        content = re.sub(r'\n{2,}(\\國朝)', r'\n\n\1', content)

        return content
