#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
解析四库全书简明目录 column1.txt 文件，转换为 JSON 格式

结构说明：
- title: 书名（如《周易鄭康成注》一卷）
- detail: 详细描述（普通段落）
- comment: 评论（以"謹案："或"謹按："开头的段落）
"""

import re
import json
from pathlib import Path


def clean_text(text):
    """清理文本，移除 XML 标签和特殊标记"""
    # 移除 <scanbreak>, <scanbegin>, <scanend> 等扫描标记
    text = re.sub(r'<scan[^>]*>', '', text)
    # 移除 <entity> 标签，保留内容
    text = re.sub(r'<entity[^>]*>([^<]*)</entity>', r'\1', text)
    # 移除其他可能的 XML 标签
    text = re.sub(r'<[^>]+>', '', text)
    # 移除多余空白
    text = re.sub(r'\s+', '', text)
    return text.strip()


def extract_title(line):
    """从标题行提取书名"""
    # 匹配 ***《书名》卷数
    match = re.search(r'\*\*\*《([^》]+)》(.+)', line)
    if match:
        book_name = clean_text(match.group(1))
        volume_info = clean_text(match.group(2))
        return f"《{book_name}》{volume_info}"
    return None


def is_comment_line(text):
    """判断是否是评论行（以"謹案："或"謹按："开头）"""
    cleaned = clean_text(text)
    return cleaned.startswith('謹案：') or cleaned.startswith('謹按：')


def parse_column1_txt(input_file):
    """解析 column1.txt 文件"""
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 按行分割
    lines = content.split('\n')

    books = []
    current_book = None
    detail_lines = []
    comment_lines = []
    in_detail = False
    in_comment = False

    for line in lines:
        line = line.strip()
        if not line:
            continue

        # 跳过部类和类别标题
        if line.startswith('*經部') or line.startswith('**易類'):
            continue

        # 检查是否是新书标题
        if line.startswith('***《'):
            # 保存前一本书
            if current_book:
                current_book['detail'] = clean_text(''.join(detail_lines))
                current_book['comment'] = clean_text(''.join(comment_lines))
                books.append(current_book)

            # 开始新书
            title = extract_title(line)
            if title:
                current_book = {
                    'title': title,
                    'detail': '',
                    'comment': ''
                }
                detail_lines = []
                comment_lines = []
                in_detail = False
                in_comment = False

        # 如果已经有当前书，处理内容
        elif current_book:
            # 检查是否是评论
            if is_comment_line(line):
                in_comment = True
                in_detail = False
                comment_lines.append(line)
            # 如果已经在评论中，继续添加到评论
            elif in_comment:
                comment_lines.append(line)
            # 否则是详细描述
            else:
                in_detail = True
                detail_lines.append(line)

    # 保存最后一本书
    if current_book:
        current_book['detail'] = clean_text(''.join(detail_lines))
        current_book['comment'] = clean_text(''.join(comment_lines))
        books.append(current_book)

    return books


def main():
    # 文件路径
    base_dir = Path(__file__).parent
    input_file = base_dir / 'source' / 'column1.txt'
    output_file = base_dir / 'source' / 'column1.json'

    print(f"读取文件: {input_file}")

    # 解析文件
    books = parse_column1_txt(input_file)

    print(f"共解析 {len(books)} 本书籍")

    # 输出为 JSON
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(books, f, ensure_ascii=False, indent=2)

    print(f"已保存到: {output_file}")

    # 显示前3条作为示例
    print("\n前3条示例：")
    for i, book in enumerate(books[:3], 1):
        print(f"\n[{i}] {book['title']}")
        print(f"    详细: {book['detail'][:100]}..." if len(book['detail']) > 100 else f"    详细: {book['detail']}")
        print(f"    评论: {book['comment'][:100]}..." if len(book['comment']) > 100 else f"    评论: {book['comment']}")


if __name__ == '__main__':
    main()
