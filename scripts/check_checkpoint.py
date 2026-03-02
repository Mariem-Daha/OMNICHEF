import json

with open('import_checkpoint_v3.json', 'r') as f:
    data = json.load(f)

print(f"Processed hashes: {len(data.get('processed_hashes', []))}")
print(f"Stats: {data.get('stats', {})}")
