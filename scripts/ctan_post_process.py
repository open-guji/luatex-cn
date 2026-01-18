import os
import json
import sys
import shutil

def post_process(build_dir):
    translation_file = "scripts/file_name_translation.json"
    if not os.path.exists(translation_file):
        print(f"Error: {translation_file} not found")
        return

    with open(translation_file, 'r', encoding='utf-8') as f:
        translation_map = json.load(f)

    print(f"Starting CTAN post-processing in: {build_dir}")

    # We need to traverse bottom-up to rename children before parents
    for root, dirs, files in os.walk(build_dir, topdown=False):
        for name in dirs + files:
            if name in translation_map:
                old_name = name
                new_name = translation_map[name]
                old_path = os.path.join(root, old_name)
                new_path = os.path.join(root, new_name)
                
                print(f"Renaming: {old_path} -> {new_path}")
                
                # If it's a file that might be referenced (like an image), 
                # we should update references in .tex files
                if os.path.isfile(old_path) and not old_name.endswith('.tex'):
                    # Search and replace in all .tex files in the build directory
                    for tex_root, _, tex_files in os.walk(build_dir):
                        for tex_file in tex_files:
                            if tex_file.endswith('.tex'):
                                tex_path = os.path.join(tex_root, tex_file)
                                with open(tex_path, 'r', encoding='utf-8') as f:
                                    content = f.read()
                                if old_name in content:
                                    print(f"  Updating reference in {tex_path}: {old_name} -> {new_name}")
                                    new_content = content.replace(old_name, new_name)
                                    with open(tex_path, 'w', encoding='utf-8') as f:
                                        f.write(new_content)

                if os.path.exists(new_path):
                    if os.path.isdir(new_path):
                        shutil.rmtree(new_path)
                    else:
                        os.remove(new_path)
                os.rename(old_path, new_path)

    print("CTAN post-processing complete.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/ctan_post_process.py [build_dir]")
        sys.exit(1)
    post_process(sys.argv[1])
