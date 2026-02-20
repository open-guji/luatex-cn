import re
import os

def clean_latex(text):
    # Remove environments like \begin{段落}[...] and \end{段落}
    text = re.sub(r'\\begin\{段落\}(?:\[[^\]]*\])?', '', text)
    text = text.replace(r'\end{段落}', '')
    
    # Remove \样式[...]{ } or \样式{ } wrapping, keeping only the content
    # We use a non-greedy match for the content until the next '}'
    # This assumes simple styles without nested braces of the same type
    text = re.sub(r'\\样式(?:\[[^\]]*\])?\{([^\}]*)\}', r'\1', text)
    
    # Convert \夹注[...]{ } to ( )
    text = re.sub(r'\\夹注(?:\[[^\]]*\])?\{([^\}]*)\}', r'（\1）', text)
    
    # Remove \相对抬头[...]{ } wrapping
    text = re.sub(r'\\相对抬头(?:\[[^\]]*\])?\{([^\}]*)\}', r'\1', text)
    
    # Handle \\ (line breaks) and replace with space or nothing? 
    # Usually in this context it's just a line break within a paragraph
    text = text.replace(r'\\', '')
    
    # Handle specific commands
    text = text.replace(r'\单抬', '')
    text = text.replace(r'\平抬', '')
    text = text.replace(r'\挪抬', '')
    
    # Handle \國朝: should result in "國朝" and remove the space after it
    text = re.sub(r'\\國朝\s*', '國朝', text)
    
    text = text.replace(r'\臣', '臣')
    text = text.replace(r'\節', '節')
    text = text.replace(r'\空格', '')
    text = re.sub(r'\[[^\]]*\]', '', text) # Remove leftover brackets
    
    # Remove any leftover braces that might have been part of unsupported commands
    text = text.replace('{', '').replace('}', '')
    
    # Clean up whitespace
    # Replace multiple spaces with one space, but preserve Chinese layout if possible
    # For this specific task, trimming is usually enough
    text = text.strip()
    return text

def process_tex(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Extract content inside \begin{正文} ... \end{正文}
    match = re.search(r'\\begin\{正文\}(.*?)\\end\{正文\}', content, re.DOTALL)
    if not match:
        print("Could not find \begin{正文} section.")
        return
    
    body = match.group(1)
    
    # Split into lines
    lines = body.split('\n')
    
    results = []
    
    def extract_braces_content(start_index):
        line = lines[start_index].strip()
        if '{' not in line:
            return "", start_index
        
        start_pos = line.find('{') + 1
        content_lines = []
        
        # Simple brace counting
        depth = 1
        current_idx = start_index
        current_line = line[start_pos:]
        
        while depth > 0:
            for i, char in enumerate(current_line):
                if char == '{':
                    depth += 1
                elif char == '}':
                    depth -= 1
                    if depth == 0:
                        content_lines.append(current_line[:i])
                        return "".join(content_lines), current_idx
            
            content_lines.append(current_line)
            current_idx += 1
            if current_idx >= len(lines):
                break
            current_line = lines[current_idx]
            
        return "".join(content_lines), current_idx

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty lines or metadata
        if not line or line.startswith('\\chapter') or line.startswith('\\newpage') or line.startswith('\\印章') or line.startswith('\\条目'):
            i += 1
            continue
            
        # Check for book title like 《...》...卷
        title_match = re.search(r'《([^》]+)》([^ \n\d]+卷|[^ \n\d]+)', line)
        if title_match and not line.startswith('\\'):
            title = line.strip()
            results.append(f"==={title}===")
            i += 1
            continue
            
        # Handle \注{...} and \按{...}
        if line.startswith('\\注{') or line.startswith('\\按{'):
            block_content, end_idx = extract_braces_content(i)
            i = end_idx + 1
            
            cleaned = clean_latex(block_content)
            
            if cleaned:
                # If we have consecutive notes/commentaries, we might want to join them
                # or keep them as separate paragraphs. The user joined "焉。"
                # If the previous item was not a title, and was a separator, we might join.
                if results and results[-1] == "" and len(results) > 1 and not results[-2].startswith('==='):
                    results[-2] = results[-2] + cleaned
                else:
                    results.append(cleaned)
                    results.append("")
            continue

        # Handle other text lines (including environments)
        cleaned = clean_latex(line)
        if cleaned:
            if results and results[-1] == "":
                # Join with previous block if it was non-empty
                if len(results) > 1 and not results[-2].startswith('==='):
                    results[-2] = results[-2] + cleaned
                else:
                    results.append(cleaned)
            elif results:
                results.append(cleaned)
            else:
                results.append(cleaned)

        i += 1

    with open(output_file, 'w', encoding='utf-8') as f:
        # Join with double newlines if it's not a title
        f.write('\n'.join(results))

if __name__ == "__main__":
    tex_path = "/home/lishaodong/workspace/luatex-cn/全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一.tex"
    out_path = "/home/lishaodong/workspace/luatex-cn/全书复刻/欽定四庫全書簡明目錄/source/wikisource_full.txt"
    process_tex(tex_path, out_path)
    print(f"Processed to {out_path}")
