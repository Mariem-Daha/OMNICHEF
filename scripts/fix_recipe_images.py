"""
CUISINEE SMART IMAGE FIXER
============================
Fixes recipe images by searching for accurate photos based on recipe name.
Uses Google Custom Search API.

Usage:
    python fix_recipe_images.py --limit 10
    python fix_recipe_images.py --dry-run
"""

import os
import sys
import json
import time
import requests
from datetime import datetime
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.recipe import Recipe
from app.config import get_settings

settings = get_settings()

# Configuration
CHECKPOINT_FILE = "image_fix_checkpoint.json"
BATCH_SIZE = 10
API_DELAY = 1.1  # Google allows ~100 queries/day free
MAX_RETRIES = 2

# Fallback images that indicate a recipe needs updating
FALLBACK_PATTERNS = [
    "unsplash.com/photo-1504674900247",
    "unsplash.com/photo-1540189549336",
    "unsplash.com/photo-1565299624946",
    "unsplash.com/photo-1567620905732",
]


def load_checkpoint() -> dict:
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {
        "processed_ids": [],
        "failed_ids": [],
        "stats": {"fixed": 0, "failed": 0, "skipped": 0},
        "started_at": datetime.now().isoformat()
    }


def save_checkpoint(checkpoint: dict):
    checkpoint["last_updated"] = datetime.now().isoformat()
    with open(CHECKPOINT_FILE, 'w', encoding='utf-8') as f:
        json.dump(checkpoint, f, indent=2)


def needs_new_image(image_url: str) -> bool:
    """Check if the current image is a generic fallback."""
    if not image_url:
        return True
    return any(pattern in image_url for pattern in FALLBACK_PATTERNS)


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


def search_recipe_image(recipe_name: str, cuisine: str) -> Optional[str]:
    """
    Search for a REAL image of the dish using Google Custom Search.
    Returns the URL of the best matching image.
    """
    # Build search query - be very specific to get the actual dish
    # Include key terms to get food photos
    search_terms = [
        f"{recipe_name} {cuisine} dish",
        f"{recipe_name} recipe photo",
        f"{recipe_name} food plated",
    ]
    
    for search_query in search_terms:
        params = {
            "key": settings.search_api,
            "cx": settings.search_engine_id,
            "q": search_query,
            "searchType": "image",
            "num": 5,  # Get top 5 results
            "imgSize": "large",
            "imgType": "photo",
            "safe": "active",
        }
        
        for attempt in range(MAX_RETRIES):
            try:
                response = requests.get(
                    "https://www.googleapis.com/customsearch/v1",
                    params=params,
                    timeout=10
                )
                
                if response.status_code == 429:
                    print("    ⏳ Rate limit, waiting 60s...")
                    time.sleep(60)
                    continue
                
                if response.status_code != 200:
                    return None
                
                items = response.json().get("items", [])
                
                # Find the best valid image
                for item in items:
                    url = item.get("link", "")
                    
                    if not url or not url.startswith("http"):
                        continue
                    
                    # Skip tiny images
                    info = item.get("image", {})
                    if info.get("width", 0) < 300:
                        continue
                    
                    # Validate the URL actually works
                    if validate_image_url(url):
                        return url
                
                # If we got results but none validated, use first one
                if items:
                    return items[0].get("link")
                    
            except requests.exceptions.Timeout:
                time.sleep(2)
                continue
            except Exception as e:
                if attempt < MAX_RETRIES - 1:
                    time.sleep(2)
                    continue
                return None
        
        # Try next search term
        time.sleep(0.5)
    
    return None


def fix_recipe_images(limit: int = None, dry_run: bool = False, resume: bool = True):
    """Fix recipes with incorrect fallback images."""
    
    if not settings.search_api or not settings.search_engine_id:
        print("❌ ERROR: Google Search API not configured!")
        print("   Set SEARCH_API and SEARCH_ENGINE_ID in .env")
        print("\n   To get API credentials:")
        print("   1. Go to https://console.developers.google.com/")
        print("   2. Enable 'Custom Search API'")
        print("   3. Create an API key")
        print("   4. Go to https://programmablesearchengine.google.com/")
        print("   5. Create a search engine with 'Image search' enabled")
        return
    
    # Load checkpoint
    checkpoint = load_checkpoint() if resume else {
        "processed_ids": [],
        "failed_ids": [],
        "stats": {"fixed": 0, "failed": 0, "skipped": 0},
        "started_at": datetime.now().isoformat()
    }
    
    processed_ids = set(checkpoint["processed_ids"])
    failed_ids = set(checkpoint["failed_ids"])
    stats = checkpoint["stats"]
    
    db = SessionLocal()
    
    try:
        # Get ALL recipes
        all_recipes = db.query(Recipe).order_by(Recipe.name).all()
        
        # Filter to only those needing updates
        recipes_to_fix = []
        for r in all_recipes:
            rid = str(r.id)
            if rid not in processed_ids and rid not in failed_ids:
                if needs_new_image(r.image_url):
                    recipes_to_fix.append(r)
        
        if limit:
            recipes_to_fix = recipes_to_fix[:limit]
        
        total = len(recipes_to_fix)
        print(f"\n📊 Found {total} recipes with fallback images")
        if dry_run:
            print("🧪 DRY RUN MODE - no changes saved")
        print("=" * 60 + "\n")
        
        if total == 0:
            print("✅ All recipes already have proper images!")
            return
        
        batch_count = 0
        start_time = datetime.now()
        
        for i, recipe in enumerate(recipes_to_fix):
            recipe_id = str(recipe.id)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            rate = stats["fixed"] / max(elapsed / 3600, 0.01)
            
            print(f"[{i+1}/{total}] ({rate:.0f}/hr) 🔍 {recipe.name[:45]}...")
            
            # Search for image
            new_url = search_recipe_image(recipe.name, recipe.cuisine)
            
            if new_url:
                if not dry_run:
                    recipe.image_url = new_url
                
                processed_ids.add(recipe_id)
                stats["fixed"] += 1
                print(f"    ✅ {new_url[:60]}...")
            else:
                failed_ids.add(recipe_id)
                stats["failed"] += 1
                print(f"    ❌ No image found")
            
            batch_count += 1
            time.sleep(API_DELAY)
            
            # Checkpoint periodically
            if batch_count >= BATCH_SIZE:
                if not dry_run:
                    db.commit()
                
                checkpoint["processed_ids"] = list(processed_ids)
                checkpoint["failed_ids"] = list(failed_ids)
                checkpoint["stats"] = stats
                save_checkpoint(checkpoint)
                
                print(f"\n💾 Saved: {stats['fixed']} fixed | {stats['failed']} failed\n")
                batch_count = 0
        
        # Final save
        if not dry_run:
            db.commit()
        
        checkpoint["processed_ids"] = list(processed_ids)
        checkpoint["failed_ids"] = list(failed_ids)
        checkpoint["stats"] = stats
        checkpoint["completed_at"] = datetime.now().isoformat()
        save_checkpoint(checkpoint)
        
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted! Saving...")
        if not dry_run:
            db.commit()
        checkpoint["processed_ids"] = list(processed_ids)
        checkpoint["failed_ids"] = list(failed_ids)
        checkpoint["stats"] = stats
        save_checkpoint(checkpoint)
        
    finally:
        db.close()
    
    elapsed = (datetime.now() - start_time).total_seconds()
    print(f"\n{'='*60}")
    print(f"🎉 DONE")
    print(f"✅ Fixed:   {stats['fixed']}")
    print(f"❌ Failed:  {stats['failed']}")
    print(f"⏱️ Time:    {elapsed/60:.1f} min")
    print(f"{'='*60}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Fix recipe images")
    parser.add_argument("--limit", type=int, default=None, help="Max to fix")
    parser.add_argument("--dry-run", action="store_true", help="Preview only")
    parser.add_argument("--no-resume", action="store_true", help="Start fresh")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🖼️  CUISINEE IMAGE FIXER")
    print("=" * 60)
    print(f"📊 Limit:   {args.limit if args.limit else 'All'}")
    print(f"🧪 Dry Run: {'Yes' if args.dry_run else 'No'}")
    print(f"📌 Resume:  {'No' if args.no_resume else 'Yes'}")
    print("=" * 60)
    
    fix_recipe_images(
        limit=args.limit,
        dry_run=args.dry_run,
        resume=not args.no_resume
    )
