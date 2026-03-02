"""Script to analyze recipe JSON structure and import to database."""

import json
import glob
import os
from collections import Counter

# Find all JSON files
recipe_folder = r"C:\Users\Admin\Downloads\recipes-master\recipes-master\ORGANIZED_RECIPES\ARABIC_RECIPES"
files = glob.glob(os.path.join(recipe_folder, "**", "*.json"), recursive=True)
print(f"Total recipe files found: {len(files)}")

# Analyze structure from sample of files
all_keys = Counter()
sample_size = min(100, len(files))

for i, filepath in enumerate(files[:sample_size]):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
            for key in data.keys():
                all_keys[key] += 1
    except Exception as e:
        print(f"Error reading {filepath}: {e}")

print("\n=== Keys found in recipes ===")
for key, count in all_keys.most_common():
    print(f"  {key}: {count}/{sample_size} files ({count/sample_size*100:.1f}%)")

# Show a complete example
print("\n=== Sample Recipe ===")
with open(files[50], 'r', encoding='utf-8') as f:
    data = json.load(f)
    print(json.dumps(data, indent=2, ensure_ascii=False))

# Check subfolder structure for cuisine mapping
print("\n=== Subfolder Structure ===")
subfolders = set()
for filepath in files[:1000]:
    rel_path = os.path.relpath(filepath, recipe_folder)
    parts = rel_path.split(os.sep)
    if len(parts) > 1:
        subfolders.add(parts[0])
        if len(parts) > 2:
            subfolders.add(f"{parts[0]}/{parts[1]}")

for sf in sorted(subfolders):
    print(f"  {sf}")
