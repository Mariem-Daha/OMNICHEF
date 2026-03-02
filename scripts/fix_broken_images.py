"""Fix broken recipe images by re-searching or using fallbacks."""

import requests
from app.database import SessionLocal
from app.models.recipe import Recipe
from app.config import get_settings

settings = get_settings()

# Google Custom Search API endpoint
GOOGLE_SEARCH_URL = "https://www.googleapis.com/customsearch/v1"

# High-quality fallback images by cuisine
FALLBACK_IMAGES = {
    "Lebanese": "https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=800",
    "Moroccan": "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=800",
    "Middle Eastern": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800",
    "Arabic": "https://images.unsplash.com/photo-1547592180-85f173990554?w=800",
    "default": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800",
}


def check_image_valid(url):
    """Check if image URL is accessible and returns actual image content."""
    try:
        resp = requests.head(url, timeout=5, allow_redirects=True)
        if resp.status_code != 200:
            return False
        content_type = resp.headers.get('content-type', '')
        if 'image' not in content_type.lower() and 'jpeg' not in content_type.lower() and 'png' not in content_type.lower():
            return False
        return True
    except:
        return False


def search_new_image(recipe_name, cuisine):
    """Search for a new image using Google Custom Search."""
    if not settings.search_api or not settings.search_engine_id:
        return None
    
    params = {
        "key": settings.search_api,
        "cx": settings.search_engine_id,
        "q": f"{recipe_name} {cuisine} food dish",
        "searchType": "image",
        "num": 10,
        "imgSize": "large",
        "imgType": "photo",
        "safe": "active",
    }
    
    try:
        response = requests.get(GOOGLE_SEARCH_URL, params=params, timeout=10)
        if response.status_code != 200:
            return None
        
        data = response.json()
        items = data.get("items", [])
        
        for item in items:
            image_url = item.get("link", "")
            if check_image_valid(image_url):
                return image_url
        
        return None
    except:
        return None


def fix_broken_images():
    """Find and fix all broken recipe images."""
    db = SessionLocal()
    
    try:
        recipes = db.query(Recipe).all()
        print(f"Checking {len(recipes)} recipes for broken images...\n")
        
        broken = []
        
        for i, r in enumerate(recipes):
            if i % 50 == 0:
                print(f"Checking {i}/{len(recipes)}...")
            
            if not check_image_valid(r.image_url):
                broken.append(r)
        
        print(f"\nFound {len(broken)} recipes with broken images.\n")
        
        if not broken:
            print("All images are working!")
            return
        
        # Fix each broken image
        for r in broken:
            print(f"Fixing: {r.name[:40]}...")
            
            # Try to search for a new image
            new_url = search_new_image(r.name, r.cuisine)
            
            if new_url:
                r.image_url = new_url
                print(f"  ✅ Found new image")
            else:
                # Use fallback
                fallback = FALLBACK_IMAGES.get(r.cuisine, FALLBACK_IMAGES["default"])
                r.image_url = fallback
                print(f"  ⚠️ Using fallback")
        
        db.commit()
        print(f"\n✅ Fixed {len(broken)} recipes!")
        
    finally:
        db.close()


if __name__ == "__main__":
    print("=" * 50)
    print("🔧 FIXING BROKEN RECIPE IMAGES")
    print("=" * 50 + "\n")
    fix_broken_images()
