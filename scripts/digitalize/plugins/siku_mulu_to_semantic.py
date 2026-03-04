#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
四库全书简明目录 - Digital → Semantic 转换插件

处理四库全书简明目录特有的命令，如：
- \國朝 标记（\左小列[indent=1]{...}）
- 抬头命令保留（\单抬、\平抬、\相对抬头）
- first-indent 处理
- \校对页 重建
- cfg 名映射
"""

import re
from typing import List, Dict, Optional, Tuple


# 插件基类定义（从 digital_to_semantic.py 复制，保持向后兼容）
class DigitalToSemanticPlugin:
    """插件基类 - 每个模板特有的命令处理"""

    def preprocess_line(self, line: str) -> Optional[str]:
        return None

    def recognize_pattern(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        return None

    def postprocess_content(self, content: str) -> str:
        return content

    def get_cfg_mapping(self) -> Dict[str, str]:
        return {}

    def get_zhu_indent(self) -> int:
        return 2

    def get_an_indent(self) -> int:
        return 4


class SikuMuluToSemanticPlugin(DigitalToSemanticPlugin):
    """四库全书简明目录 Digital → Semantic 转换插件"""

    ZHU_INDENT = 2
    AN_INDENT = 4

    def get_cfg_mapping(self) -> Dict[str, str]:
        return {
            '四库全书文渊阁简明目录数字化': '四库全书文渊阁简明目录',
        }

    def get_zhu_indent(self) -> int:
        return self.ZHU_INDENT

    def get_an_indent(self) -> int:
        return self.AN_INDENT

    def recognize_pattern(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        """识别四库全书特有模式"""
        line = lines[index]

        # 1. \校对页 重建：\begin{空白页} + 3个 \文本框 → \校对页{...}{...}{...}
        if r'\begin{空白页}' in line.strip():
            result = self._try_rebuild_jiaodui(lines, index)
            if result:
                return result

        # 2. 检测 \國朝 模式
        # 模式：\缩进[2]\双列{\右小列{...}\左小列[indent=1]{國朝...}}
        if r'\缩进[2]\双列' in line and r'\左小列[indent=1]' in line:
            result = self._try_parse_guochao(lines, index)
            if result:
                return result

        # 3. 处理抬头命令（保持不变）
        if any(cmd in line for cmd in [r'\单抬', r'\平抬', r'\相对抬头']):
            return line, 1

        # 4. 处理 first-indent=0 的段落
        # 模式：\缩进[2] 后跟 \缩进[1] 行（无 \双列）
        if r'\缩进[2]' in line and r'\双列' not in line:
            result = self._try_parse_first_indent(lines, index)
            if result:
                return result

        return None

    def _try_rebuild_jiaodui(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        r"""尝试重建 \校对页 命令"""
        # 收集 \begin{空白页} ... \end{空白页} 之间的内容
        consumed = 1
        wenben_contents = []

        while index + consumed < len(lines):
            cur = lines[index + consumed].strip()
            consumed += 1

            if r'\end{空白页}' in cur:
                break

            # 提取 \文本框[...]{content} 的 content
            # 可能跨多行，需要收集到 ]{...} 为止
            if r'\文本框[' in cur or (wenben_contents and not cur.startswith(r'\文本框')):
                # 收集到完整的 \文本框 命令
                pass

        # 简单实现：提取所有 ]{...} 格式的内容
        full_block = ''.join(lines[index:index + consumed])
        # 查找所有 ]{content} 模式
        contents = []
        pos = 0
        while True:
            bracket_pos = full_block.find(']{', pos)
            if bracket_pos < 0:
                break
            content, end = self._extract_brace(full_block, bracket_pos + 1)
            if content:
                contents.append(content)
            pos = end

        if len(contents) == 3:
            result = f'\\校对页{{{contents[0]}}}{{{contents[1]}}}{{{contents[2]}}}\n'
            return result, consumed

        return None

    def _extract_brace(self, text: str, start: int) -> Tuple[str, int]:
        """提取花括号内容"""
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

    def _try_parse_guochao(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        r"""解析 \國朝 模式：\缩进[2]\双列 + \左小列[indent=1]{國朝...}"""
        line = lines[index]

        match = re.search(
            r'\\缩进\[2\]\\双列\{\\右小列\{([^}]*)\}\\左小列\[indent=1\]\{([^}]*)\}\}',
            line
        )
        if not match:
            return None

        right_text = match.group(1)
        left_text = match.group(2)

        # 收集后续的 \缩进[2]\双列 行（同一 \注 块的续行）
        consumed = 1
        additional_right = []
        additional_left = []

        while index + consumed < len(lines):
            next_line = lines[index + consumed]
            # 续行必须是 \缩进[2]\双列（不含 \左小列[indent=1]）
            if r'\缩进[2]\双列' not in next_line:
                break
            if r'\左小列[indent=1]' in next_line:
                break  # 另一个 \國朝 块

            next_match = re.search(
                r'\\缩进\[2\]\\双列\{\\右小列\{([^}]*)\}\\左小列\{([^}]*)\}\}',
                next_line
            )
            if next_match:
                additional_right.append(next_match.group(1))
                additional_left.append(next_match.group(2))
                consumed += 1
            else:
                break

        # 组装为 \注{right_text,\n\國朝 left_text + additional...}
        if left_text.startswith('國朝'):
            guochao_text = left_text[2:]  # 去掉 "國朝"
        else:
            guochao_text = left_text

        # 合并续行文本
        all_additional = ''
        for r, l in zip(additional_right, additional_left):
            all_additional += r + l

        result = f'\\注{{{right_text}\n\\國朝 {guochao_text}{all_additional}}}\n'
        return result, consumed

    def _try_parse_first_indent(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        r"""检测 first-indent=0 的段落：\缩进[2] 后跟 \缩进[1] 行"""
        if index + 1 >= len(lines):
            return None

        next_line = lines[index + 1]
        if r'\缩进[1]' not in next_line or r'\双列' in next_line:
            return None

        # 确认当前行是 \缩进[2] 无 \双列
        line = lines[index]
        suojin_match = re.match(r'\\缩进\[2\]\s*(.*)', line.strip())
        if not suojin_match:
            return None

        first_text = suojin_match.group(1).strip()

        # 收集后续的 \缩进[1] 行（跨 \换页）
        text_parts = [first_text + '\n' if first_text else '']
        consumed = 1

        while index + consumed < len(lines):
            curr_line = lines[index + consumed]
            curr_stripped = curr_line.strip()

            # 跳过 \换页
            if curr_stripped == r'\换页':
                consumed += 1
                continue

            if r'\缩进[1]' not in curr_stripped or r'\双列' in curr_stripped:
                break

            text = self._extract_text_after_suojin(curr_line)
            text_parts.append(text)
            consumed += 1

        if len(text_parts) > 1:
            merged_text = ''.join(text_parts)
            result = f'\\begin{{段落}}[indent=1, first-indent=0]\n{merged_text}\\end{{段落}}\n'
            return result, consumed

        return None

    def _extract_text_after_suojin(self, line: str) -> str:
        r"""提取 \缩进[N] 后的文本"""
        match = re.match(r'\\缩进\[\d+\]\s*(.*)', line.strip())
        if match:
            text = match.group(1).strip()
            return text + '\n' if text else ''
        return ''

    def postprocess_content(self, content: str) -> str:
        """后处理：添加空行、清理格式"""
        # 1. 在 \注{...} 和 \按{...} 前后添加空行
        content = re.sub(r'(?<!\n)\n(\\注\{)', r'\n\n\1', content)
        content = re.sub(r'(?<!\n)\n(\\按\{)', r'\n\n\1', content)
        content = re.sub(r'(\\注\{[^}]*\})\n(?!\n)', r'\1\n\n', content)
        content = re.sub(r'(\\按\{[^}]*\})\n(?!\n)', r'\1\n\n', content)

        # 2. 在书名行前添加空行（书名行 = 不以 \ 开头的正文行，后面跟 \注）
        content = re.sub(r'(?<!\n)\n([^\\\n][^\n]*\n\\注)', r'\n\n\1', content)

        # 3. 移除连续的多个空行（保留最多两个换行）
        content = re.sub(r'\n{3,}', '\n\n', content)

        # 4. 在 \newpage 后添加空行
        content = re.sub(r'(\\newpage)\n(?!\n)', r'\1\n\n', content)

        # 5. 在 \chapter 前添加空行
        content = re.sub(r'(?<!\n)\n(\\chapter)', r'\n\n\1', content)

        return content
