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

    for line in lines:
        line = line.strip()
        
        # Skip empty lines and compiler flags
        if not line or line.startswith('+') or line.startswith('-'):
            continue

        # Extract the relative path starting from the 'cva6' directory
        if '/cva6/' in line:
            parts = line.split('/cva6/')
            relative_path = parts[1]
        else:
            # Ignore files outside the cva6 scope
            continue 

        dest_file_path = os.path.join(dest_root, relative_path)

        # Create parent directories if they don't exist
        os.makedirs(os.path.dirname(dest_file_path), exist_ok=True)

        # Copy the file if it exists on the system
        if os.path.exists(line):
            shutil.copy2(line, dest_file_path)
            copied += 1
        else:
            print(f"[Not Found - Skipped] {line}")
            skipped += 1

    print("-" * 40)
    print(f"Total Copied: {copied}")
    print(f"Total Skipped/Missing: {skipped}")
    if copied > 0:
        print(f"Check your new folder at: {dest_root}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 copy_tree.py <path_to_f_file> [dest_dir_name]")
        sys.exit(1)

    f_path = sys.argv[1]
    dest_name = sys.argv[2] if len(sys.argv) > 2 else "cva6_copied"

    copy_files_from_f(f_path, dest_name)
