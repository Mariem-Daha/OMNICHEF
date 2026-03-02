"""
MAURITANIAN RECIPES IMAGE SEARCH
================================
Searches for images for the Mauritanian recipes from the JSON file
using Google Custom Search API.

Usage:
    python search_mauritanian_images.py
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.config import get_settings

settings = get_settings()

# Configuration
JSON_FILE = Path("data/mauritanian_recipes_raw.json")
OUTPUT_FILE = Path("data/mauritanian_recipes_with_images.json")
API_DELAY = 1.5  # Seconds between API calls to avoid rate limits


def validate_image_url(url: str) -> bool:
    """Check if URL returns a valid image."""
    try:
        response = requests.head(url, timeout=5, allow_redirects=True)
        if response.status_code != 200:
            return False
        content_type = response.headers.get("content-type", "")
        return any(t in content_type.lower() for t in ["image", "jpeg", "png", "webp"])
    except:
        return False


def search_image_google(query: str) -> Optional[dict]:
    """
    Search for a real image using Google Custom Search API.
    Returns image URL and metadata or None.
    """
    if not settings.search_api or not settings.search_engine_id:
        print("    ❌ Search API not configured!")
        return None
    
    params = {
        "key": settings.search_api,
        "cx": settings.search_engine_id,
        "q": f"{query} traditional food dish recipe photo",
        "searchType": "image",
        "num": 5,
        "imgSize": "large",
        "imgType": "photo",
        "safe": "active",
    }
    
    try:
        response = requests.get(
            "https://www.googleapis.com/customsearch/v1",
            params=params,
            timeout=10
        )
        
        if response.status_code != 200:
            error = response.json().get("error", {})
            print(f"    ⚠️ API Error: {error.get('message', 'Unknown')[:50]}")
            return None
        
        items = response.json().get("items", [])
        
        # Try each result until we find a valid one
        for item in items:
            url = item.get("link")
            if url and validate_image_url(url):
                return {
                    "url": url,
                    "source": item.get("displayLink", ""),
                    "title": item.get("title", ""),
                    "width": item.get("image", {}).get("width"),
                    "height": item.get("image", {}).get("height"),
                }
        
        # Return first result even if validation failed
        if items:
            item = items[0]
            return {
                "url": item.get("link"),
                "source": item.get("displayLink", ""),
                "title": item.get("title", ""),
                "width": item.get("image", {}).get("width"),
                "height": item.get("image", {}).get("height"),
                "validated": False
            }
        
        return None
        
    except Exception as e:
        print(f"    ⚠️ Search error: {str(e)[:50]}")
        return None


def search_mauritanian_images():
    """Search for images for all Mauritanian recipes."""
    
    # Check API configuration
    if not settings.search_api:
        print("❌ ERROR: SEARCH_API not configured in .env")
        return
    if not settings.search_engine_id:
        print("❌ ERROR: SEARCH_ENGINE_ID not configured in .env")
        return
    
    # Load recipes
    if not JSON_FILE.exists():
        print(f"❌ ERROR: {JSON_FILE} not found!")
        return
    
    with open(JSON_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    recipes = data.get("recipes", [])
    total = len(recipes)
    
    print("=" * 60)
    print("🖼️  MAURITANIAN RECIPES IMAGE SEARCH")
    print("=" * 60)
    print(f"📂 Source: {JSON_FILE}")
    print(f"📄 Recipes: {total}")
    print("=" * 60 + "\n")
    
    found = 0
    failed = 0
    
    for i, recipe in enumerate(recipes):
        name_ar = recipe.get("name", "")
        name_en = recipe.get("name_en", "")
        
        print(f"[{i+1}/{total}] 🔍 {name_en} ({name_ar})")
        
        # Search with English name + Mauritanian cuisine
        search_query = f"{name_en} Mauritanian"
        result = search_image_google(search_query)
        
        if not result:
            # Try with different search terms
            print(f"    Trying alternative search...")
            search_query = f"{name_en} North African dish"
            result = search_image_google(search_query)
        
        if result:
            recipe["image_search_result"] = result
            print(f"    ✅ Found: {result['url'][:60]}...")
            print(f"       Source: {result['source']}")
            found += 1
        else:
            recipe["image_search_result"] = None
            print(f"    ❌ No image found")
            failed += 1
        
        time.sleep(API_DELAY)
    
    # Update status
    data["image_search_completed"] = True
    data["image_search_stats"] = {
        "found": found,
        "failed": failed,
        "total": total
    }
    
    # Save results
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("\n" + "=" * 60)
    print("🎉 IMAGE SEARCH COMPLETE")
    print("=" * 60)
    print(f"✅ Found:  {found}/{total}")
    print(f"❌ Failed: {failed}/{total}")
    print(f"📄 Output: {OUTPUT_FILE}")
    print("=" * 60)


if __name__ == "__main__":
    search_mauritanian_images()
