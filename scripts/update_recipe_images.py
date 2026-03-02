"""
CUISINEE RECIPE IMAGE UPDATER
==============================
Updates all existing recipes in the database with real images
using Google Custom Search API.

Features:
- Searches for actual images of each recipe dish
- Validates image URLs before saving
- Checkpointing to resume interrupted runs
- Rate limiting to respect API quotas

Usage:
    python update_recipe_images.py
    python update_recipe_images.py --limit 50
    python update_recipe_images.py --dry-run
"""

import os
import sys
import json
import time
import requests
from datetime import datetime
from typing import Optional

# Add the app to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.recipe import Recipe
from app.config import get_settings

settings = get_settings()

# ============================================================================
# CONFIGURATION
# ============================================================================

CHECKPOINT_FILE = "image_update_checkpoint.json"
API_DELAY = 1.0  # Seconds between API calls (Google allows 100 queries/day free)
MAX_RETRIES = 2
BATCH_SIZE = 10  # Save progress every N recipes

# Google Custom Search API endpoint
GOOGLE_SEARCH_URL = "https://www.googleapis.com/customsearch/v1"

# ============================================================================
# CHECKPOINT FUNCTIONS
# ============================================================================

def load_checkpoint() -> dict:
    """Load checkpoint file if it exists."""
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {
        "updated_ids": [],
        "failed_ids": [],
        "stats": {"updated": 0, "failed": 0, "skipped": 0},
        "started_at": datetime.now().isoformat()
    }


def save_checkpoint(checkpoint: dict):
    """Save current progress to checkpoint file."""
    checkpoint["last_updated"] = datetime.now().isoformat()
    with open(CHECKPOINT_FILE, 'w', encoding='utf-8') as f:
        json.dump(checkpoint, f, indent=2)


# ============================================================================
# IMAGE SEARCH FUNCTIONS
# ============================================================================

def search_recipe_image(recipe_name: str, cuisine: str) -> Optional[str]:
    """
    Search for a real image of the recipe using Google Custom Search API.
    Returns the URL of the best matching image, or None if not found.
    """
    if not settings.search_api or not settings.search_engine_id:
        print("  ⚠️ Google Search API not configured!")
        return None
    
    # Build search query - be specific to get the actual dish
    search_query = f"{recipe_name} {cuisine} food recipe dish"
    
    params = {
        "key": settings.search_api,
        "cx": settings.search_engine_id,
        "q": search_query,
        "searchType": "image",
        "num": 5,  # Get top 5 results to pick the best
        "imgSize": "large",  # Prefer large images
        "imgType": "photo",  # Only photos, not clipart
        "safe": "active",  # Safe search
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            response = requests.get(GOOGLE_SEARCH_URL, params=params, timeout=10)
            
            if response.status_code == 429:
                print("  ⚠️ Rate limit hit, waiting 60s...")
                time.sleep(60)
                continue
            
            if response.status_code != 200:
                print(f"  ⚠️ API error: {response.status_code}")
                return None
            
            data = response.json()
            items = data.get("items", [])
            
            if not items:
                print("  ⚠️ No images found")
                return None
            
            # Find the best image (prefer larger, valid URLs)
            for item in items:
                image_url = item.get("link", "")
                
                # Validate URL
                if not image_url or not image_url.startswith("http"):
                    continue
                
                # Skip tiny or problematic images
                image_info = item.get("image", {})
                width = image_info.get("width", 0)
                height = image_info.get("height", 0)
                
                if width < 300 or height < 200:
                    continue
                
                # Verify image is accessible
                if validate_image_url(image_url):
                    return image_url
            
            # If no valid images found, return first one anyway
            if items:
                return items[0].get("link")
            
            return None
            
        except requests.exceptions.Timeout:
            print(f"  ⚠️ Timeout (attempt {attempt + 1})")
            time.sleep(2)
            continue
            
        except Exception as e:
            print(f"  ⚠️ Error: {str(e)[:50]}")
            if attempt < MAX_RETRIES - 1:
                time.sleep(2)
                continue
            return None
    
    return None


def validate_image_url(url: str) -> bool:
    """Check if the image URL is accessible and returns valid content."""
    try:
        # Just do a HEAD request to check if image exists
        response = requests.head(url, timeout=5, allow_redirects=True)
        
        if response.status_code != 200:
            return False
        
        content_type = response.headers.get("content-type", "")
        if not any(img_type in content_type.lower() for img_type in ["image", "jpeg", "jpg", "png", "webp"]):
            return False
        
        return True
        
    except:
        return False


# ============================================================================
# MAIN UPDATE FUNCTION
# ============================================================================

def update_all_recipe_images(limit: int = None, dry_run: bool = False, resume: bool = True):
    """
    Update all recipes in the database with real images from Google Search.
    """
    
    # Check API configuration
    if not settings.search_api:
        print("❌ ERROR: SEARCH_API not set in .env file!")
        print("   Please add: SEARCH_API=your-google-api-key")
        return
    
    if not settings.search_engine_id:
        print("❌ ERROR: SEARCH_ENGINE_ID not set in .env file!")
        print("   Please add: SEARCH_ENGINE_ID=your-cx-id")
        print("\n   To get a Search Engine ID:")
        print("   1. Go to https://programmablesearchengine.google.com/")
        print("   2. Create a new search engine")
        print("   3. Enable 'Image search' and 'Search the entire web'")
        print("   4. Copy the 'cx' Search Engine ID")
        return
    
    # Load checkpoint
    if resume:
        checkpoint = load_checkpoint()
        print(f"📌 Resuming from checkpoint: {checkpoint['stats']}")
    else:
        checkpoint = {
            "updated_ids": [],
            "failed_ids": [],
            "stats": {"updated": 0, "failed": 0, "skipped": 0},
            "started_at": datetime.now().isoformat()
        }
    
    updated_ids = set(checkpoint["updated_ids"])
    failed_ids = set(checkpoint["failed_ids"])
    stats = checkpoint["stats"]
    
    # Get all recipes from database
    db = SessionLocal()
    
    try:
        query = db.query(Recipe).order_by(Recipe.created_at.desc())
        
        if limit:
            query = query.limit(limit)
        
        recipes = query.all()
        total = len(recipes)
        
        print(f"\n📊 Found {total:,} recipes to update")
        print(f"🔍 Using Google Custom Search API")
        if dry_run:
            print("🧪 DRY RUN MODE - no changes will be saved")
        print("=" * 60 + "\n")
        
        batch_count = 0
        start_time = datetime.now()
        
        for i, recipe in enumerate(recipes):
            recipe_id_str = str(recipe.id)
            
            # Skip if already processed
            if recipe_id_str in updated_ids or recipe_id_str in failed_ids:
                print(f"[{i+1}/{total}] ⏭️ {recipe.name[:40]}... (already processed)")
                continue
            
            # Progress info
            elapsed = (datetime.now() - start_time).total_seconds()
            rate = (stats["updated"] + stats["failed"]) / max(elapsed, 1) * 3600
            
            print(f"[{i+1}/{total}] ({rate:.0f}/hr) 🔍 {recipe.name[:45]}...")
            
            # Search for image
            image_url = search_recipe_image(recipe.name, recipe.cuisine)
            
            if image_url:
                if not dry_run:
                    recipe.image_url = image_url
                
                updated_ids.add(recipe_id_str)
                stats["updated"] += 1
                print(f"  ✅ Found: {image_url[:60]}...")
            else:
                failed_ids.add(recipe_id_str)
                stats["failed"] += 1
                print(f"  ❌ No image found")
            
            batch_count += 1
            
            # Rate limiting
            time.sleep(API_DELAY)
            
            # Save checkpoint periodically
            if batch_count >= BATCH_SIZE:
                if not dry_run:
                    db.commit()
                
                checkpoint["updated_ids"] = list(updated_ids)
                checkpoint["failed_ids"] = list(failed_ids)
                checkpoint["stats"] = stats
                save_checkpoint(checkpoint)
                
                print(f"\n{'='*60}")
                print(f"💾 CHECKPOINT SAVED")
                print(f"   Updated: {stats['updated']} | Failed: {stats['failed']}")
                print(f"{'='*60}\n")
                
                batch_count = 0
        
        # Final save
        if not dry_run:
            db.commit()
        
        checkpoint["updated_ids"] = list(updated_ids)
        checkpoint["failed_ids"] = list(failed_ids)
        checkpoint["stats"] = stats
        checkpoint["completed_at"] = datetime.now().isoformat()
        save_checkpoint(checkpoint)
        
    except KeyboardInterrupt:
        print("\n\n⚠️ Interrupted! Saving progress...")
        if not dry_run:
            db.commit()
        checkpoint["updated_ids"] = list(updated_ids)
        checkpoint["failed_ids"] = list(failed_ids)
        checkpoint["stats"] = stats
        save_checkpoint(checkpoint)
        print("💾 Progress saved. Run again to resume.")
        
    finally:
        db.close()
    
    # Final summary
    elapsed = (datetime.now() - start_time).total_seconds()
    print(f"\n{'='*60}")
    print(f"🎉 IMAGE UPDATE COMPLETE")
    print(f"{'='*60}")
    print(f"✅ Updated:  {stats['updated']:,}")
    print(f"❌ Failed:   {stats['failed']:,}")
    print(f"⏱️  Duration: {elapsed/60:.1f} minutes")
    print(f"{'='*60}")


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Update recipe images using Google Search")
    parser.add_argument("--limit", type=int, default=None, help="Max recipes to update")
    parser.add_argument("--dry-run", action="store_true", help="Preview without saving")
    parser.add_argument("--no-resume", action="store_true", help="Start fresh (ignore checkpoint)")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🖼️  CUISINEE RECIPE IMAGE UPDATER")
    print("=" * 60)
    print(f"📊 Limit:    {args.limit if args.limit else 'All'}")
    print(f"🧪 Dry Run:  {'Yes' if args.dry_run else 'No'}")
    print(f"📌 Resume:   {'No' if args.no_resume else 'Yes'}")
    print("=" * 60 + "\n")
    
    update_all_recipe_images(
        limit=args.limit,
        dry_run=args.dry_run,
        resume=not args.no_resume
    )
