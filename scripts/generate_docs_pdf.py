import os
import subprocess
import shutil
from pathlib import Path

def generate_pdf(md_file, output_dir):
    md_file = Path(md_file)
    output_dir = Path(output_dir)
    stem = md_file.stem
    tex_file = output_dir / f"tmp_{stem}.tex"
    
    # LaTeX template with Chinese and Markdown support
    tex_content = rf"""\documentclass{{article}}
\usepackage[UTF8, scheme=plain]{{ctex}}
\usepackage{{markdown}}
\usepackage{{geometry}}
\geometry{{a4paper, margin=1in}}
\begin{{document}}
\markdownInput{{{md_file.name}}}
\end{{document}}
"""
    
    with open(tex_file, "w", encoding="utf-8") as f:
        f.write(tex_content)
    
    print(f"Compiling {md_file.name}...")
    try:
        # Run lualatex in the output directory so relative paths in md work
        result = subprocess.run(
            ["lualatex", "-interaction=nonstopmode", tex_file.name],
            cwd=output_dir,
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print(f"Error compiling {md_file.name}:")
            # print(result.stdout)
            # Find last few lines of log if error
            log_file = output_dir / f"tmp_{stem}.log"
            if log_file.exists():
                with open(log_file, "r", encoding="utf-8", errors="ignore") as lf:
                    print("".join(lf.readlines()[-20:]))
            return False
        
        # Move PDF to final name
        final_pdf = output_dir / f"{stem}.pdf"
        generated_pdf = output_dir / f"tmp_{stem}.pdf"
        if generated_pdf.exists():
            if final_pdf.exists():
                os.remove(final_pdf)
            shutil.move(generated_pdf, final_pdf)
            print(f"Successfully generated {final_pdf}")
            return True
        else:
            print(f"PDF was not generated for {md_file.name}")
            return False
            
    finally:
        # Cleanup temporary files
        for ext in [".tex", ".aux", ".log", ".out", ".toc"]:
            tmp_f = output_dir / f"tmp_{stem}{ext}"
            if tmp_f.exists():
                os.remove(tmp_f)
        # Cleanup markdown cache dir
        cache_dir = output_dir / f"_markdown_tmp_{stem}"
        if cache_dir.exists() and cache_dir.is_dir():
            shutil.rmtree(cache_dir)

def main():
    docs_dir = Path(r"c:\Users\lisdp\workspace\luatex-cn\文档")
    if not docs_dir.exists():
        print(f"Directory {docs_dir} does not exist.")
        return

    md_files = list(docs_dir.glob("*.md"))
    if not md_files:
        print("No Markdown files found.")
        return

    success_count = 0
    for md_file in md_files:
        if generate_pdf(md_file, docs_dir):
            success_count += 1
    
    print(f"\nSummary: {success_count}/{len(md_files)} PDFs generated successfully.")

if __name__ == "__main__":
    main()
