#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将 column1.json 转换为 LaTeX 格式的 column1_auto.tex 文件

参考 column1.tex 的格式：
- 书名作为正文大字
- detail 用 \注{...} 包裹
- comment 用 \按{...} 包裹
"""

import json
import re
from pathlib import Path


def process_pingtai(text):
    """
    处理需要使用 \平抬 命令的文本
    识别书名、朝代名等需要顶格显示的内容
    """
    # 识别《书名》并在前面添加 \平抬
    # 例如：《御定易经通注》 -> \平抬《御定易经通注》
    imperial_books = [
        '御定易经通注', '御纂周易折中', '御纂周易述义',
        '御定周易述义', '御定易经', '御纂易经'
    ]

    for book in imperial_books:
        # 在书名前添加 \平抬，但不在行首
        pattern = r'(?<!^)(?<!\\平抬)《' + re.escape(book) + r'》'
        text = re.sub(pattern, r'\\平抬《' + book + r'》', text)

    # 识别特殊词语，如"圣度"、"彝训"等需要平抬的词
    special_terms = ['聖度', '彞訓']
    for term in special_terms:
        if term in text and not text.startswith(term):
            # 在特殊词前添加 \平抬（如果不在行首）
            pattern = r'(?<!^)(?<!\\平抬 )' + re.escape(term)
            text = re.sub(pattern, r'\\平抬 ' + term, text, count=1)

    return text


def escape_latex_special_chars(text):
    """
    转义 LaTeX 特殊字符
    但保留已经存在的命令（如 \平抬）
    """
    # 不转义的字符列表（因为这些是中文内容，通常不需要转义）
    # 主要转义 % $ & # _ { }
    special_chars = {
        '%': r'\%',
        '$': r'\$',
        '&': r'\&',
        '#': r'\#',
        '_': r'\_',
    }

    result = text
    for char, escaped in special_chars.items():
        if char in result and '\\' + char not in result:
            result = result.replace(char, escaped)

    return result


def split_long_text(text, max_length=200):
    """
    如果文本过长，在合适的位置添加换行
    在 \注 和 \按 中，可以使用 \\ 换行
    """
    if len(text) <= max_length:
        return text

    # 在句号、问号、感叹号后分割
    sentences = re.split(r'([。！？])', text)

    result = []
    current_line = ""

    for i in range(0, len(sentences), 2):
        sentence = sentences[i]
        punctuation = sentences[i + 1] if i + 1 < len(sentences) else ""

        if len(current_line + sentence + punctuation) > max_length and current_line:
            result.append(current_line)
            current_line = sentence + punctuation
        else:
            current_line += sentence + punctuation

    if current_line:
        result.append(current_line)

    return '\\\\\n'.join(result) if len(result) > 1 else text


def format_zhu(text, process_pt=True):
    """
    格式化 \注 的内容
    """
    if not text:
        return ""

    # 处理平抬
    if process_pt:
        text = process_pingtai(text)

    # 转义特殊字符
    text = escape_latex_special_chars(text)

    return f"\\注{{{text}}}"


def format_an(text, process_pt=True):
    """
    格式化 \按 的内容
    """
    if not text:
        return ""

    # 处理平抬
    if process_pt:
        text = process_pingtai(text)

    # 转义特殊字符
    text = escape_latex_special_chars(text)

    # 移除开头的"謹案："或"謹按："，因为在排版时会自动显示
    text = re.sub(r'^謹[案按]：', '', text)

    return f"\\按{{{text}}}"


def json_to_tex(json_file, output_file, template_file=None):
    """
    将 JSON 文件转换为 LaTeX 文件
    """
    # 读取 JSON 数据
    with open(json_file, 'r', encoding='utf-8') as f:
        books = json.load(f)

    # 读取模板（如果提供）
    template_header = ""
    template_footer = ""

    if template_file and template_file.exists():
        with open(template_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # 提取文档头和文档尾
        begin_match = re.search(r'\\begin\{正文\}', content)
        end_match = re.search(r'\\end\{正文\}', content)

        if begin_match and end_match:
            template_header = content[:begin_match.end()]
            template_footer = content[end_match.start():]

    # 如果没有模板，使用默认模板
    if not template_header:
        template_header = r'''\documentclass[四库全书文渊阁简明目录]{ltc-guji}

\usepackage{enumitem} % For better list control if needed
\usepackage{tikz}
% \禁用分页裁剪
\无标点模式
\setmainfont{TW-Kai}


\title{欽定四庫全書簡明目錄}

\chapter{經部 易類\\卷一}

\begin{document}
\begin{正文}
欽定四庫全書簡明目錄卷一

\条目[1]{經部一}
\条目[2]{易類}

'''

    if not template_footer:
        template_footer = r'''
\end{正文}
\end{document}
'''

    # 生成书目内容
    book_entries = []

    for i, book in enumerate(books):
        entry_parts = []

        # 添加书名（正文大字）
        title = book.get('title', '')
        if title:
            entry_parts.append(title)

        # 添加空行
        entry_parts.append('')

        # 添加 \注（详细描述）
        detail = book.get('detail', '')
        if detail:
            entry_parts.append(format_zhu(detail))
            entry_parts.append('')

        # 添加 \按（评论）
        comment = book.get('comment', '')
        if comment:
            entry_parts.append(format_an(comment))
            entry_parts.append('')

        book_entries.append('\n'.join(entry_parts))

    # 组合完整文档
    full_content = template_header + '\n'.join(book_entries) + template_footer

    # 写入输出文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(full_content)


def main():
    # 文件路径
    base_dir = Path(__file__).parent
    json_file = base_dir / 'source' / 'column1.json'
    output_file = base_dir / 'tex' / 'column1_auto.tex'
    template_file = base_dir / 'tex' / 'column1.tex'

    print(f"读取 JSON: {json_file}")
    print(f"参考模板: {template_file}")

    # 转换
    json_to_tex(json_file, output_file, template_file)

    print(f"已生成: {output_file}")
    print("\n提示：")
    print("- 生成的文件为 column1_auto.tex")
    print("- 请检查生成的内容，特别是 \\平抬 命令的位置")
    print("- 可以手动调整格式后使用")
    print("\n编译命令：")
    print(f"  cd {base_dir / 'tex'}")
    print(f"  lualatex column1_auto.tex")


if __name__ == '__main__':
    main()
