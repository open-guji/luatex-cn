# 将维基文库的格式转化为tex
#
# Usage / 用法示例:
#   python3 scripts/wiki_to_tex.py input.txt              # Auto-generates input.tex
#   python3 scripts/wiki_to_tex.py input.txt -o out.tex   # Explicit output
#   cat input.txt | python3 scripts/wiki_to_tex.py > out.tex
#
# 转换规则:
# 1. [数字] 是脚注，全部删掉
# 2. [文字] 转为 \侧批{文字}
# 3. 【文字】 转为 \批注{文字}
# 4. 移除所有标点符号 ，。：！？、「」『』（）《》.

import re
import sys
import argparse

def convert_wiki_to_tex(text):
    # 1. [数字] 是脚注，全部删掉
    # Remove footnotes first: [1], [12], etc.
    text = re.sub(r'\[\d+\]', '', text)
    
    # 2. [文字] 转为 \侧批{文字} 
    # Convert remaining brackets [text] to \侧批{text}
    # Use non-greedy match .*? to handle multiple occurrences on one line
    text = re.sub(r'\[([^\]]*)\]', r'\\侧批{\1}', text)
    
    # 3. 【文字】 转为 \批注{文字}
    # Convert lenticular brackets 【text】 to \批注{text}
    text = re.sub(r'【([^】]*)】', r'\\批注{\1}', text)
    
    # 4. 移除所有标点符号 ，。！？、「」『』（）《》.
    # Note: Added \. to capture the period. Added full-width parenthesis （） if implied by context, 
    # though prompt only listed specific ones. Prompt list: ，。！？、「」『』（）《》.
    punctuation_pattern = r'[，。！？：、「」『』（）《》\.]'
    text = re.sub(punctuation_pattern, '', text)
    
    # 5. Remove leading whitespace (including full-width spaces) from each line
    # 移除每段段首的空格（包括全角空格）
    text = re.sub(r'^[ \t\u3000]+', '', text, flags=re.MULTILINE)

    # 6. Replace □ with \空格
    # 替换 □ 为 \空格
    text = text.replace('□', r'\空格 ')
    
    return text

def main():
    parser = argparse.ArgumentParser(description='Convert WikiSource format to TeX for luatex-cn.')
    parser.add_argument('input_file', nargs='?', help='Input file path (default: stdin)')
    parser.add_argument('-o', '--output', help='Output file path (default: stdout)')
    
    args = parser.parse_args()
    
    # Read input
    if args.input_file:
        try:
            with open(args.input_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            sys.stderr.write(f"Error reading input file: {e}\n")
            sys.exit(1)
    else:
        # Read from stdin
        content = sys.stdin.read()
        
    # Process content
    converted_content = convert_wiki_to_tex(content)
    
    # Determine output destination
    output_file = args.output
    if not output_file and args.input_file:
        # Default to same filename with .tex extension
        import os
        base_name = os.path.splitext(args.input_file)[0]
        output_file = base_name + ".tex"
        # If input was already .tex, maybe append _converted to avoid overwrite?
        # But user request says "generate tex file with same file name", assuming conversion from .txt etc.
        # If input is file.txt, output is file.tex.
        # If input is file.tex, output is file.tex (overwrite).
        # Let's add a safety check or just do what requested. 
        # "Generate tex file with same file name" usually implies file.txt -> file.tex.

    # Write output
    if output_file:
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(converted_content)
            # Only print message if not writing to stdout
            print(f"Successfully converted '{args.input_file}' to '{output_file}'")
        except Exception as e:
            sys.stderr.write(f"Error writing output file: {e}\n")
            sys.exit(1)
    else:
        sys.stdout.write(converted_content)

if __name__ == "__main__":
    main()