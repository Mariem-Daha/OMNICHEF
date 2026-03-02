import requests
resp = requests.get('http://localhost:8000/api/recipes?page=1&per_page=5')
data = resp.json()
for r in data['recipes']:
    print(f"{r['name'][:35]}: {r['image_url'][:70]}...")
