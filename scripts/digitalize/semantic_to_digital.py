#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Semantic → Digital 转换引擎

将使用 ltc-guji（语义模式）编写的古籍排版文件转换为 ltc-guji-digital（布局模式）格式。
支持插件机制，允许模板特有命令的扩展处理。

用法:
    python3 semantic_to_digital.py --input INPUT.tex --output OUTPUT.tex [--plugin PLUGIN.py]
    python3 semantic_to_digital.py --input INPUT.tex --output OUTPUT.tex --plugin plugins/siku_mulu.py
"""

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path


# =============================================================================
# 常量
# =============================================================================

PUNCTUATION = "，。、；：「」『』《》〈〉·？！（）〔〕"
DEFAULT_N_CHAR_PER_COL = 21
DEFAULT_N_COLUMN = 8

# 注：已弃用模板名映射，现在直接保留原模板名
# converter 只替换 documentclass 名称（ltc-guji → ltc-guji-digital），
# 不修改模板参数，确保 digital 版本使用与原文件完全相同的配置

# 应该被去掉的 \usepackage 行
REMOVE_USEPACKAGE = {"enumitem", "tikz"}


# =============================================================================
# 插件基类
# =============================================================================

class ConverterPlugin:
    """插件基类 - 每个模板特有的命令处理"""

    def get_template_mapping(self) -> dict:
        """返回模板名映射 {guji名: digital名}"""
        return {}

    def preprocess_line(self, line: str) -> str | None:
        """预处理单行。返回处理后的行，或 None 表示不处理（交给核心引擎）"""
        return None

    def parse_command(self, cmd_name: str, args: str, context: dict) -> list[dict] | None:
        """解析模板特有命令为语义块列表。返回 None 表示不识别"""
        return None

    def expand_in_jiazhu(self, text: str) -> list[dict]:
        """在夹注文字流中展开特殊命令。返回段落列表 [{text, indent_delta}]"""
        return [{"text": text, "indent_delta": 0}]

    def postprocess_blocks(self, blocks: list[dict]) -> list[dict]:
        """后处理语义块列表（可选）"""
        return blocks


# =============================================================================
# 文本工具
# =============================================================================

def strip_punct(text: str) -> str:
    """去除标点符号"""
    return ''.join(c for c in text if c not in PUNCTUATION)


def strip_book_markers(text: str) -> str:
    """去除书名号《》"""
    return text.replace('《', '').replace('》', '')


def char_len(text: str) -> int:
    """计算文字的显示字符数（一个中文字 = 1，忽略空格）"""
    return len(text.replace(' ', ''))


def extract_brace_content(text: str, start: int = 0) -> tuple[str, int]:
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


def load_patch_file(input_path: Path) -> list[dict]:
    """
    加载手动调整文件（patch file）

    Patch 文件格式 (JSON):
    {
      "patches": [
        {
          "source_pattern": "\\注{\\样式[grid-height=24pt]{宋趙彥肅撰",
          "reason": "grid-height=24pt 导致容量增加",
          "replacement": [
            "\\缩进[2] 宋趙彥肅撰。其說推尋卦畫，即象數以求其理。朱子《語錄》",
            "\\缩进[2] 頗病其取義太密；然研索於《易》中，完勝支離於易外也。"
          ]
        }
      ]
    }

    返回: [{"source_pattern": str, "replacement": [str], "reason": str}, ...]
    """
    patch_path = input_path.parent / f"{input_path.stem}.patch.json"
    if not patch_path.exists():
        return []

    try:
        with open(patch_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        patches = []
        if data and 'patches' in data:
            for patch in data['patches']:
                source_pattern = patch.get('source_pattern')
                replacement = patch.get('replacement', [])
                reason = patch.get('reason', '')
                if source_pattern and replacement:
                    patches.append({
                        'source_pattern': source_pattern,
                        'replacement': replacement,
                        'reason': reason,
                    })
                    print(f"  Loaded patch: {source_pattern[:40]}... → {len(replacement)} lines")

        if patches:
            print(f"✓ Loaded {len(patches)} patches from {patch_path.name}")
        return patches
    except Exception as e:
        print(f"⚠ Failed to load patch file {patch_path}: {e}")
        return []


def extract_optional_arg(text: str, start: int = 0) -> tuple[str | None, int]:
    """提取可选参数 [...]。返回 (content_or_None, end_pos)"""
    s = text[start:].lstrip()
    offset = len(text[start:]) - len(s)
    pos = start + offset
    if pos >= len(text) or text[pos] != '[':
        return None, start
    depth = 0
    begin = pos + 1
    for i in range(pos, len(text)):
        if text[i] == '[':
            depth += 1
        elif text[i] == ']':
            depth -= 1
            if depth == 0:
                return text[begin:i], i + 1
    return text[begin:], len(text)


# =============================================================================
# Stage 1: 解析 guji TeX → 语义块
# =============================================================================

class Parser:
    """解析 guji.cls TeX 文件为语义块列表"""

    def __init__(self, plugin: ConverterPlugin | None = None,
                 n_char_per_col: int = DEFAULT_N_CHAR_PER_COL,
                 patches: list[dict] | None = None):
        self.plugin = plugin
        self.n_char_per_col = n_char_per_col
        self.patches = patches or []
        self.blocks: list[dict] = []

    def parse(self, content: str) -> tuple[str, str, str, list[dict], str]:
        """
        解析完整的 TeX 文件。
        返回 (preamble, preserved_before, blocks, preserved_after, footer)

        preamble = 文档头（documentclass 到 \\begin{document}）
        preserved_before = \\begin{正文} 之前的封面/空白页（原样保留）
        blocks = 正文解析后的语义块
        preserved_after = \\end{正文} 之后的封面/空白页（原样保留）
        footer = \\end{document}
        """
        # 分离文档各部分
        preamble, body, footer = self._split_document(content)
        preserved_before, main_content, preserved_after = self._split_body(body)

        # 解析正文内容
        self.blocks = []
        self._parse_body(main_content)

        # 插件后处理
        if self.plugin:
            self.blocks = self.plugin.postprocess_blocks(self.blocks)

        return preamble, preserved_before, self.blocks, preserved_after, footer

    def _split_document(self, content: str) -> tuple[str, str, str]:
        """分离 preamble、body、footer"""
        m_begin = re.search(r'\\begin\{document\}', content)
        m_end = re.search(r'\\end\{document\}', content)
        if not m_begin or not m_end:
            raise ValueError("无法找到 \\begin{document} 或 \\end{document}")

        preamble = content[:m_begin.end()]
        body = content[m_begin.end():m_end.start()]
        footer = content[m_end.start():]
        return preamble, body, footer

    def _split_body(self, body: str) -> tuple[str, str, str]:
        """分离前置环境、正文、后置环境

        返回: (preserved_before, main_content, preserved_after)
        - preserved_before: \begin{正文} 之前的内容（封面、空白页等）
        - main_content: \begin{正文}...\end{正文} 的完整内容
        - preserved_after: \end{正文} 之后的内容（结尾的封面、空白页等）
        """
        # 查找 \begin{正文} 和 \end{正文}
        m_begin = re.search(r'\\begin\{(正文|BodyText)\}', body)
        m_end = re.search(r'\\end\{(正文|BodyText)\}', body)

        if not m_begin:
            return '', body, ''

        if not m_end:
            # 只有 begin 没有 end（不应该发生，但防御性处理）
            preserved_before = body[:m_begin.start()]
            main_content = body[m_begin.start():]
            return preserved_before, main_content, ''

        preserved_before = body[:m_begin.start()]
        main_content = body[m_begin.start():m_end.end()]
        preserved_after = body[m_end.end():]

        return preserved_before, main_content, preserved_after

    def _parse_body(self, content: str):
        """解析 \\begin{正文}...\\end{正文} 内的内容"""
        # 去掉 \begin{正文} 和 \end{正文}
        content = re.sub(r'\\begin\{(正文|BodyText)\}\s*', '', content, count=1)
        content = re.sub(r'\\end\{(正文|BodyText)\}\s*$', '', content, count=1)

        lines = content.split('\n')
        i = 0
        while i < len(lines):
            line = lines[i].rstrip()

            # 空行 → 跳过（guji 中空行是段落分隔符，不产生列）
            if not line.strip():
                i += 1
                continue

            # 纯注释行 → 跳过
            if line.strip().startswith('%'):
                i += 1
                continue

            # 插件预处理
            if self.plugin:
                preprocessed = self.plugin.preprocess_line(line)
                if preprocessed is not None:
                    line = preprocessed

            # 尝试解析各种命令
            consumed = self._try_parse_line(line, lines, i)
            if consumed > 0:
                i += consumed
            else:
                i += 1

    def _try_parse_line(self, line: str, lines: list[str], idx: int) -> int:
        """尝试解析一行，返回消耗的行数（0=未识别，>0=已消耗）"""
        stripped = line.strip()

        # \chapter{...}
        m = re.match(r'\\chapter\{(.+)\}', stripped)
        if m:
            self.blocks.append({"type": "chapter", "text": m.group(1)})
            return 1

        # \newpage
        if stripped == '\\newpage':
            self.blocks.append({"type": "newpage"})
            return 1

        # \印章[...]{...} — 可能跨行
        m = re.match(r'\\印章\s*\[', stripped)
        if m:
            return self._parse_yinzhang(lines, idx)

        # \begin{段落}[...] ... \end{段落} — 多行块
        m = re.match(r'\\begin\{段落\}(\[.*?\])?', stripped)
        if m:
            return self._parse_paragraph(lines, idx, m.group(1))

        # \条目[N]{text}
        m = re.match(r'\\条目\[(\d+)\]\{(.+)\}', stripped)
        if m:
            level = int(m.group(1))
            text = m.group(2)
            # 去标点和书名号
            text = strip_punct(strip_book_markers(text))
            # 处理条目内的 \夹注
            jiazhu_m = re.search(r'\\夹注\[.*?\]\{(.+?)\}', text)
            if jiazhu_m:
                # 条目中有夹注，保留夹注内容为独立部分
                main_text = text[:jiazhu_m.start()].strip()
                jz_text = strip_punct(jiazhu_m.group(1))
                text = main_text + jz_text
            self.blocks.append({"type": "tiaumu", "level": level, "text": text})
            return 1

        # \注{...} — 等同于 indent=2 的夹注
        m = re.match(r'\\注\{', stripped)
        if m:
            # 检查是否有 patch 匹配
            for patch in self.patches:
                if patch['source_pattern'] in line:
                    print(f"  ✓ Applied patch at line {idx+1}: {patch.get('reason', '')}")
                    self.blocks.append({
                        "type": "patch",
                        "lines": patch['replacement'],
                    })
                    # 消耗完整的 \注{...} 块（跳过多行）
                    return self._count_brace_block_lines(lines, idx)

            # 没有 patch，正常解析
            return self._parse_zhu_or_an(lines, idx, "zhu", indent=2)

        # \按{...} — 等同于 indent=4 的夹注（可能跨多行）
        m = re.match(r'\\按\{', stripped)
        if m:
            return self._parse_zhu_or_an(lines, idx, "an", indent=4)

        # 插件命令处理
        if self.plugin:
            # 检测命令名
            cmd_m = re.match(r'\\(\S+?)[\[{\s]', stripped)
            if not cmd_m:
                cmd_m = re.match(r'\\(\S+)$', stripped)
            if cmd_m:
                cmd_name = cmd_m.group(1)
                result = self.plugin.parse_command(cmd_name, stripped, {
                    "lines": lines, "idx": idx, "parser": self
                })
                if result is not None:
                    for block in result:
                        self.blocks.append(block)
                    return result[0].get("_consumed_lines", 1) if result else 1

        # 纯文本行（包括书名行 《书名》N卷）
        if stripped and not stripped.startswith('\\'):
            text = strip_punct(strip_book_markers(stripped))
            if text:
                self.blocks.append({"type": "text", "text": text})
            return 1

        # 以 \样式 开头的行（可能是独立文本行）
        m = re.match(r'\\样式\[.*?\]\{(.+)\}', stripped)
        if m:
            text = strip_punct(strip_book_markers(m.group(1)))
            self.blocks.append({"type": "text", "text": text, "has_style": True})
            return 1

        # 未识别的行 → 当作文本
        if stripped:
            text = strip_punct(strip_book_markers(stripped))
            if text:
                self.blocks.append({"type": "text", "text": text})
        return 1

    def _parse_yinzhang(self, lines: list[str], idx: int) -> int:
        """解析 \\印章[...]{...}，可能跨多行"""
        combined = ''
        consumed = 0
        for i in range(idx, len(lines)):
            combined += lines[i].strip() + ' '
            consumed += 1
            if '{' in combined and '}' in combined:
                # 检查花括号是否闭合
                brace_depth = 0
                for ch in combined:
                    if ch == '{':
                        brace_depth += 1
                    elif ch == '}':
                        brace_depth -= 1
                if brace_depth == 0:
                    break

        # 重新格式化为单行
        combined = combined.strip()
        # 简化印章参数（去掉换行和多余空格）
        combined = re.sub(r'\s+', '', combined)
        # 还原为可读格式
        m = re.match(r'\\印章\[(.+?)\]\{(.+?)\}', combined)
        if m:
            opts = m.group(1)
            filename = m.group(2)
            raw = f"\\印章[{opts}]{{{filename}}}"
            self.blocks.append({"type": "yinzhang", "raw": raw})
        else:
            self.blocks.append({"type": "yinzhang", "raw": combined})
        return consumed

    def _parse_paragraph(self, lines: list[str], idx: int, opts_str: str | None) -> int:
        """解析 \\begin{段落}[...] ... \\end{段落}"""
        indent = 0
        first_indent = None
        if opts_str:
            # 解析 [indent=N, first-indent=M]
            m = re.search(r'indent\s*=\s*(\d+)', opts_str)
            if m:
                indent = int(m.group(1))
            m = re.search(r'first-indent\s*=\s*(\d+)', opts_str)
            if m:
                first_indent = int(m.group(1))

        # 收集段落内容
        content_lines = []
        consumed = 1  # \begin{段落} 行
        for i in range(idx + 1, len(lines)):
            consumed += 1
            if '\\end{段落}' in lines[i]:
                break
            content_lines.append(lines[i])

        # 合并行（去掉行尾 % 注释）
        text = ''
        for cl in content_lines:
            cl = cl.strip()
            if cl.startswith('%'):
                continue
            # 去掉行尾 % 及之后的内容
            cl = re.sub(r'%.*$', '', cl)
            text += cl

        # 去标点
        text = strip_punct(text)

        if text:
            self.blocks.append({
                "type": "paragraph",
                "indent": indent,
                "first_indent": first_indent if first_indent is not None else indent,
                "text": text,
            })

        return consumed

    def _count_brace_block_lines(self, lines: list[str], idx: int) -> int:
        """计算一个花括号块跨越的行数（用于跳过 patch 的源行）"""
        depth = 0
        consumed = 0

        for i in range(idx, len(lines)):
            line = lines[i]
            consumed += 1

            for ch in line:
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        return consumed

        return consumed

    def _parse_zhu_or_an(self, lines: list[str], idx: int, zhu_type: str, indent: int) -> int:
        """解析 \\注{...} 或 \\按{...}，可能跨多行，内容包含复杂命令"""
        # 收集完整的 {...} 内容
        combined = ''
        consumed = 0
        depth = 0
        found_opening = False

        for i in range(idx, len(lines)):
            line = lines[i].strip()
            combined += line + ' '
            consumed += 1

            # 计算花括号深度
            for ch in line:
                if ch == '{':
                    depth += 1
                    found_opening = True
                elif ch == '}':
                    depth -= 1
                    if found_opening and depth == 0:
                        # 找到完整的 {...}
                        brace_start = combined.find('{')
                        content, end_pos = extract_brace_content(combined, brace_start)

                        # 检查是否包含 \國朝 命令（需要特殊处理）
                        if r'\國朝' in content:
                            # 将内容按 \國朝 分段
                            segments = self._split_by_guochao(content, indent)
                            if segments:
                                self.blocks.append({
                                    "type": "jiazhu",
                                    "indent": indent,
                                    "segments": segments,
                                    "zhu_type": zhu_type,
                                    "standalone": True,
                                })
                        else:
                            # 正常处理
                            content = self._expand_special_commands(content)
                            content = strip_punct(content)
                            if content:
                                self.blocks.append({
                                    "type": "jiazhu",
                                    "indent": indent,
                                    "text": content,
                                    "zhu_type": zhu_type,
                                    "standalone": True,
                                })
                        return consumed

        # 如果没有找到完整的 {...}，返回消耗的行数
        return consumed

    def _split_by_guochao(self, text: str, base_indent: int) -> list[dict]:
        """
        将包含 \\國朝 的文本分段

        \\國朝 = \\相对抬头[1]{國朝}，效果：
        - 触发换行（开始新段）
        - 新段 indent = base_indent - 1

        返回: [{"text": ..., "indent_delta": ..., "force_break": ...}, ...]
        """
        segments = []
        parts = re.split(r'(\\國朝\s*)', text)  # 保留分隔符

        for i, part in enumerate(parts):
            if not part.strip():
                continue

            if part.strip().startswith(r'\國朝'):
                # 这是 \國朝 命令本身，跳过（已包含在下一段的开头）
                continue

            # 确定 indent_delta
            if i == 0:
                # 第一段：使用原始 indent
                indent_delta = 0
                force_break = False
            else:
                # \國朝 后的段：indent - 1（相对抬头[1]）
                indent_delta = -1
                force_break = True

            # 如果这是 \國朝 后的段，在开头添加"國朝"
            if i > 0 and i % 2 == 0 and parts[i-1].strip().startswith(r'\國朝'):
                part = '國朝' + part

            # 展开其他特殊命令
            expanded = self._expand_special_commands(part)
            expanded = strip_punct(expanded)

            if expanded:
                segments.append({
                    "text": expanded,
                    "indent_delta": indent_delta,
                    "force_break": force_break,
                })

        return segments

    def _expand_special_commands(self, text: str) -> str:
        """展开文本中的特殊命令，提取实际文本内容"""
        # \单抬{...} - 去掉命令，保留内容
        text = re.sub(r'\\单抬\{([^}]+)\}', r'\1', text)
        # \单抬 - 去掉命令本身（后面可能有0个或多个空格）
        text = re.sub(r'\\单抬\s*', '', text)

        # \平抬{...} - 去掉命令，保留内容
        text = re.sub(r'\\平抬\{([^}]+)\}', r'\1', text)
        # \平抬 - 去掉命令本身
        text = re.sub(r'\\平抬\s*', '', text)

        # \相对抬头[N]{...} - 去掉命令，保留内容
        text = re.sub(r'\\相对抬头\[\d+\]\{([^}]+)\}', r'\1', text)

        # \國朝 - 保留文本
        text = re.sub(r'\\國朝\s*', '國朝', text)

        # \样式[...]{...} - 去掉命令，保留内容
        # 使用非贪婪匹配，处理嵌套的花括号
        text = re.sub(r'\\样式\[[^\]]*\]\{([^}]+)\}', r'\1', text)

        # \\ - 去掉 LaTeX 换行符（在 digital 的 obeylines 模式下不需要）
        text = re.sub(r'\\\\\s*', '', text)

        # 去掉书名号
        text = strip_book_markers(text)
        return text


# =============================================================================
# Stage 2: 语义块 → 列数据
# =============================================================================

class Layouter:
    """将语义块按网格参数分栏为列序列

    核心算法：连续的 jiazhu 块合并为统一的"小列流"（subcol stream），
    每个小列根据当前 indent 独立计算 chars_per_subcol = n_char_per_col - indent。
    每两个连续的小列组成一个"大列"（dual column）。
    """

    def __init__(self, n_char_per_col: int = DEFAULT_N_CHAR_PER_COL,
                 plugin: ConverterPlugin | None = None,
                 n_column_per_page: int = 16):
        self.n_char_per_col = n_char_per_col
        self.plugin = plugin
        self.n_column_per_page = n_column_per_page  # 每页的列数（左右合计）

    def layout(self, blocks: list[dict]) -> list[dict]:
        """将语义块列表转换为列数据列表，并在页面满时自动插入换页"""
        columns = []
        current_page_columns = 0  # 当前页已生成的列数
        i = 0
        while i < len(blocks):
            block = blocks[i]
            btype = block["type"]

            # 存储本次迭代新增的列
            new_cols = []

            if btype == "patch":
                # 手动 patch：直接插入预定义的 digital 行
                for line in block["lines"]:
                    new_cols.append({"type": "patch_line", "text": line})
            elif btype == "chapter":
                new_cols.append({"type": "chapter", "text": block["text"]})
            elif btype == "newpage":
                # 手动换页，重置计数器
                new_cols.append({"type": "newpage"})
                current_page_columns = 0
            elif btype == "yinzhang":
                new_cols.append({"type": "yinzhang", "raw": block["raw"]})
            elif btype == "text":
                new_cols.append({
                    "type": "single",
                    "indent": block.get("indent", 0),
                    "text": block["text"],
                })
            elif btype == "tiaumu":
                new_cols.append({
                    "type": "single",
                    "indent": block["level"],
                    "text": block["text"],
                    "source": "tiaumu",  # Mark source for Generator
                })
            elif btype == "paragraph":
                new_cols = self._layout_paragraph(block)
            elif btype == "jiazhu":
                # 收集连续的 jiazhu 块，合并为统一的小列流
                # 但如果当前块是 standalone，则不合并
                if block.get("standalone", False):
                    # 独立的 jiazhu 块，不与其他合并
                    new_cols = self._layout_jiazhu_run([block])
                else:
                    # 收集连续的非 standalone jiazhu 块
                    jiazhu_run = [block]
                    j = i + 1
                    while j < len(blocks) and blocks[j]["type"] == "jiazhu" and not blocks[j].get("standalone", False):
                        jiazhu_run.append(blocks[j])
                        j += 1
                    new_cols = self._layout_jiazhu_run(jiazhu_run)
                    i = j - 1  # 跳过已消耗的块（外层 i += 1 会再加1）
            else:
                if "text" in block:
                    new_cols.append({
                        "type": "single",
                        "indent": block.get("indent", 0),
                        "text": block["text"],
                    })

            # 添加新列并检查是否需要换页
            for col in new_cols:
                # 计算本列的实际列数（dual 类型算 1 列，single 类型也算 1 列）
                col_count = 1
                if col["type"] in ("chapter", "yinzhang"):
                    col_count = 0  # 不占用列数

                # 检查是否会超出当前页
                if current_page_columns > 0 and current_page_columns + col_count > self.n_column_per_page:
                    # 需要换页
                    columns.append({"type": "newpage"})
                    current_page_columns = 0

                columns.append(col)
                if col["type"] == "newpage":
                    current_page_columns = 0
                else:
                    current_page_columns += col_count

            i += 1

        return columns

    def _layout_paragraph(self, block: dict) -> list[dict]:
        """段落 → 按每列可用字数切分为多列"""
        text = block["text"]
        indent = block["indent"]
        first_indent = block.get("first_indent", indent)
        columns = []

        pos = 0
        is_first = True
        while pos < len(text):
            cur_indent = first_indent if is_first else indent
            chars_per_col = self.n_char_per_col - cur_indent
            chunk = text[pos:pos + chars_per_col]
            columns.append({
                "type": "single",
                "indent": cur_indent,
                "text": chunk,
            })
            pos += chars_per_col
            is_first = False

        return columns

    def _layout_jiazhu_run(self, jiazhu_blocks: list[dict]) -> list[dict]:
        """
        将连续的 jiazhu 块合并为统一的小列流，然后分栏。

        小列流 = [(text, indent, force_break), ...]，每个元素是一个"段落"，
        其 indent 决定该段文字在小列中的 chars_per_subcol。
        force_break=True 表示该段必须开始一个新的小列。
        """
        # Step 1: 展开所有 jiazhu 块为统一的分段流
        all_segments = []  # [(text, absolute_indent, force_break)]

        for block in jiazhu_blocks:
            base_indent = block["indent"]
            segments = block.get("segments", None)

            if segments:
                for seg in segments:
                    delta = seg.get("indent_delta", 0)
                    actual_indent = base_indent + delta
                    force_break = seg.get("force_break", False)
                    if seg["text"]:
                        all_segments.append((seg["text"], actual_indent, force_break))
            else:
                if block.get("text"):
                    all_segments.append((block["text"], base_indent, False))

        if not all_segments:
            return []

        # Step 2: 逐小列填充
        # 每个小列有自己的 indent，从第一个未消耗的段落的 indent 决定
        subcols = []  # [(text, indent)]  每个小列
        seg_idx = 0
        seg_pos = 0  # 当前段落内的字符位置

        while seg_idx < len(all_segments):
            seg_text, seg_indent, seg_force = all_segments[seg_idx]
            if seg_pos >= len(seg_text):
                seg_idx += 1
                seg_pos = 0
                continue

            # 本小列的 indent = 当前段落的 indent
            col_indent = seg_indent
            chars_per_subcol = self.n_char_per_col - col_indent

            # 填充本小列
            col_text = ''
            remaining = chars_per_subcol

            while remaining > 0 and seg_idx < len(all_segments):
                seg_text, seg_indent, seg_force = all_segments[seg_idx]
                available = len(seg_text) - seg_pos
                take = min(remaining, available)
                col_text += seg_text[seg_pos:seg_pos + take]
                seg_pos += take
                remaining -= take

                if seg_pos >= len(seg_text):
                    seg_idx += 1
                    seg_pos = 0
                    # 如果还有剩余空间且下一段需要强制分列或 indent 不同，停止填充
                    if remaining > 0 and seg_idx < len(all_segments):
                        next_text, next_indent, next_force = all_segments[seg_idx]
                        if next_indent != col_indent or next_force:
                            break

            subcols.append((col_text, col_indent))

        # Step 3: 每两个小列组成一个大列
        columns = []
        for k in range(0, len(subcols), 2):
            right_text, right_indent = subcols[k]
            if k + 1 < len(subcols):
                left_text, left_indent = subcols[k + 1]
            else:
                left_text, left_indent = '', right_indent

            # 大列的 indent = 右小列的 indent
            col_indent = right_indent

            columns.append({
                "type": "dual",
                "indent": col_indent,
                "right": right_text,
                "left": left_text,
                "right_indent": None,
                "left_indent": left_indent if left_indent != col_indent else None,
            })

        return columns


# =============================================================================
# Stage 3: 列数据 → digital TeX
# =============================================================================

class Generator:
    """将列数据生成 digital TeX 代码"""

    def __init__(self, plugin: ConverterPlugin | None = None):
        self.plugin = plugin

    def generate(self, preamble: str, preserved_before: str, columns: list[dict],
                 preserved_after: str, footer: str) -> str:
        """生成完整的 digital TeX 文件"""
        parts = []

        # 转换 preamble
        parts.append(self._convert_preamble(preamble))
        parts.append('')

        # 前置环境（\begin{正文} 之前的封面、书名页）
        if preserved_before.strip():
            parts.append(preserved_before.rstrip())
            parts.append('')

        # 正文环境 (ltc-guji-digital 中自动启用 digital-mode)
        parts.append('\\begin{正文}')

        # 第一个 chapter 也在正文环境内输出（避免在环境外触发换页产生空白页）
        first_chapter = None
        for col in columns:
            if col["type"] == "chapter":
                first_chapter = col["text"]
                break

        if first_chapter:
            parts.append(f'\\chapter{{{first_chapter}}}')

        # 生成列
        chapter_count = 0
        for col in columns:
            ctype = col["type"]

            if ctype == "chapter":
                chapter_count += 1
                if chapter_count == 1:
                    # 第一个 chapter 已在上面输出，跳过
                    continue
                # 后续 chapter：直接在 \正文 环境内输出
                # digital 模式下 \chapter 在环境内可正常工作，不需要关闭再重开
                parts.append(f'\\chapter{{{col["text"]}}}')
                continue

            if ctype == "newpage":
                # 直接输出换页命令，保留原文件的所有换页
                parts.append('\\换页')
                continue

            if ctype == "yinzhang":
                parts.append(col["raw"] + '%')
                continue

            if ctype == "patch_line":
                # 手动 patch 行：直接输出预定义的内容
                parts.append(col["text"])
                continue

            if ctype == "single":
                indent = col.get("indent", 0)
                text = col["text"]
                source = col.get("source", "")

                # Different indent handling for different sources:
                # - tiaumu (\条目): output actual spaces (guji.cls uses \Column{　text})
                # - paragraph (\begin{段落}): use \缩进[N] (guji.cls uses attributes only)
                if source == "tiaumu":
                    # 条目: output actual full-width spaces
                    indent_str = '　' * indent
                    parts.append(f'{indent_str}{text}')
                else:
                    # 段落: use \缩进[N] command
                    if indent != 0:
                        parts.append(f'\\缩进[{indent}] {text}')
                    else:
                        parts.append(text)
                continue

            if ctype == "dual":
                indent = col.get("indent", 0)
                right = col.get("right", "")
                left = col.get("left", "")
                r_opt = f'[indent={col["right_indent"]}]' if col.get("right_indent") is not None else ''
                l_opt = f'[indent={col["left_indent"]}]' if col.get("left_indent") is not None else ''
                # Use \缩进[N] command (always output, even if N=0) for explicit indent control
                prefix = f'\\缩进[{indent}]' if indent != 0 else ''
                line = f'{prefix}\\双列{{\\右小列{r_opt}{{{right}}}\\左小列{l_opt}{{{left}}}}}'
                parts.append(line)
                continue

        parts.append('')
        parts.append('\\end{正文}')

        # 后置环境（\end{正文} 之后的封面、空白页）
        if preserved_after.strip():
            parts.append(preserved_after.rstrip())

        parts.append(footer.rstrip())
        parts.append('')

        return '\n'.join(parts)

    def _convert_preamble(self, preamble: str) -> str:
        """转换文档头"""
        lines = preamble.split('\n')
        result = []

        for line in lines:
            # documentclass 替换：只替换 class 名，保留原模板名
            # 例：\documentclass[四库全书文渊阁简明目录]{ltc-guji}
            #  → \documentclass[四库全书文渊阁简明目录]{ltc-guji-digital}
            m = re.match(r'(\\documentclass)\[(.+?)\]\{(ltc-guji|guji)\}', line)
            if m:
                template_name = m.group(2)
                # 直接保留原模板名，不做映射
                result.append(f'\\documentclass[{template_name}]{{ltc-guji-digital}}')
                continue

            # 去掉不需要的 \usepackage
            if re.match(r'\\usepackage\{(' + '|'.join(REMOVE_USEPACKAGE) + r')\}', line.strip()):
                continue

            # 去掉纯注释行
            if line.strip().startswith('%'):
                continue

            # 保留其他行
            result.append(line)

        # 去掉连续空行（保留最多一个空行）
        cleaned = []
        prev_empty = False
        for line in result:
            is_empty = not line.strip()
            if is_empty and prev_empty:
                continue
            cleaned.append(line)
            prev_empty = is_empty

        return '\n'.join(cleaned)


# =============================================================================
# 主流程
# =============================================================================

def load_plugin(plugin_path: str) -> ConverterPlugin:
    """动态加载插件"""
    # 确保 converter 模块在 sys.modules 中（插件会 from converter import ...）
    converter_dir = str(Path(__file__).parent)
    if converter_dir not in sys.path:
        sys.path.insert(0, converter_dir)
    # 注册当前模块为 'converter'，这样插件的 from converter import 能找到正确的类
    import importlib
    current_module = sys.modules.get('__main__')
    if current_module and not sys.modules.get('converter'):
        sys.modules['converter'] = current_module

    spec = importlib.util.spec_from_file_location("plugin", plugin_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    # 查找 ConverterPlugin 的子类
    for name in dir(module):
        obj = getattr(module, name)
        if (isinstance(obj, type) and issubclass(obj, ConverterPlugin)
                and obj is not ConverterPlugin):
            return obj()

    raise ValueError(f"插件 {plugin_path} 中未找到 ConverterPlugin 的子类")


def convert(input_path: str, output_path: str, plugin_path: str | None = None,
            n_char_per_col: int = DEFAULT_N_CHAR_PER_COL):
    """主转换流程"""
    # 加载插件
    plugin = None
    if plugin_path:
        # 需要让插件能导入 converter 中的基类
        sys.path.insert(0, str(Path(__file__).parent))
        plugin = load_plugin(plugin_path)
        print(f"已加载插件: {plugin_path}")

    # 读取输入文件
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()

    print(f"读取输入: {input_path} ({len(content)} 字符)")

    # 加载 patch 文件（如果存在）
    patches = load_patch_file(Path(input_path))

    # Stage 1: 解析
    parser = Parser(plugin=plugin, n_char_per_col=n_char_per_col, patches=patches)
    preamble, preserved_before, blocks, preserved_after, footer = parser.parse(content)
    print(f"Stage 1 完成: 解析到 {len(blocks)} 个语义块")

    # 统计语义块类型
    type_counts = {}
    for b in blocks:
        t = b["type"]
        type_counts[t] = type_counts.get(t, 0) + 1
    for t, c in sorted(type_counts.items()):
        print(f"  {t}: {c}")

    # Stage 2: 布局
    layouter = Layouter(n_char_per_col=n_char_per_col, plugin=plugin)
    columns = layouter.layout(blocks)
    print(f"Stage 2 完成: 生成 {len(columns)} 列")

    # Stage 3: 生成
    generator = Generator(plugin=plugin)
    output = generator.generate(preamble, preserved_before, columns, preserved_after, footer)
    print(f"Stage 3 完成: 输出 {len(output)} 字符")

    # 写入输出文件
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(output)

    print(f"已写入: {output_path}")


def main():
    parser = argparse.ArgumentParser(description='guji → guji-digital 转换引擎')
    parser.add_argument('--input', '-i', required=True, help='输入 guji.cls TeX 文件')
    parser.add_argument('--output', '-o', required=True, help='输出 guji-digital TeX 文件')
    parser.add_argument('--plugin', '-p', help='插件 Python 文件路径')
    parser.add_argument('--n-char-per-col', type=int, default=DEFAULT_N_CHAR_PER_COL,
                        help=f'每列字数 (默认 {DEFAULT_N_CHAR_PER_COL})')
    args = parser.parse_args()

    convert(args.input, args.output, args.plugin, args.n_char_per_col)


if __name__ == '__main__':
    main()
