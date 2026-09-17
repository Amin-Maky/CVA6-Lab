import os
import shutil
import sys

def copy_files_from_f(f_file, dest_dir_name="cva6_copied"):
    copied = 0
    skipped = 0

    try:
        with open(f_file, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: Could not find file {f_file}")
        return

    # Determine the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Set the destination root path relative to the script location
    dest_root = os.path.join(script_dir, dest_dir_name)

    # Prepare new .f file name
    base_name = os.path.splitext(os.path.basename(f_file))[0]
    if base_name.endswith("_New"):
        base_name = base_name[:-4]
    
    new_f_file = os.path.join(script_dir, f"{base_name}_New.f")

    with open(new_f_file, 'w') as new_f:
        for line in lines:
            stripped_line = line.strip()
            
            # Skip empty lines entirely for logic, but keep in new file
            if not stripped_line:
                new_f.write(line)
                continue

            if '/cva6/' in stripped_line:
                # Extract the relative path starting after /cva6/
                idx = stripped_line.find('/cva6/')
                relative_path = stripped_line[idx + len('/cva6/'):]
                
                # Check if it's a compiler flag (+incdir+, -v, etc.)
                if stripped_line.startswith('+') or stripped_line.startswith('-'):
                    idx_slash = stripped_line.find('/')
                    if idx_slash != -1:
                        # Extract the flag part (e.g., '+incdir+', '-v ')
                        flag_part = stripped_line[:idx_slash]
                        new_f.write(f"{flag_part}${{CVA6_ROOT}}/{relative_path}\n")
                    else:
                        new_f.write(f"${{CVA6_ROOT}}/{relative_path}\n")
                else:
                    # It's a normal file path, rewrite it with ${CVA6_ROOT}
                    new_f.write(f"${{CVA6_ROOT}}/{relative_path}\n")
                    
                    # Proceed to copy the file
                    dest_file_path = os.path.join(dest_root, relative_path)
                    os.makedirs(os.path.dirname(dest_file_path), exist_ok=True)

                    if os.path.exists(stripped_line):
                        shutil.copy2(stripped_line, dest_file_path)
                        copied += 1
                    else:
                        print(f"[Not Found - Skipped] {stripped_line}")
                        skipped += 1
            else:
                # Keep lines that don't contain /cva6/ as they are
                new_f.write(line)

    print("-" * 40)
    print(f"Total Copied: {copied}")
    print(f"Total Skipped/Missing: {skipped}")
    print(f"New .f file created at: {new_f_file}")
    if copied > 0:
        print(f"Check your new folder at: {dest_root}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 f-maker.py <path_to_f_file> [dest_dir_name]")
        sys.exit(1)

    f_path = sys.argv[1]
    dest_name = sys.argv[2] if len(sys.argv) > 2 else "cva6_copied"

    copy_files_from_f(f_path, dest_name)
