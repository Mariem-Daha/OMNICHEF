"""
CUISINEE SMART IMAGE UPDATER
==============================
1. First tries Google Custom Search with ACCURATE queries
2. Falls back to Imagen 4.0 ULTRA if search fails

Priority: Real photos > AI generated

Usage:
    python smart_image_updater.py --limit 50
    python smart_image_updater.py --dry-run
"""

import os
import sys
import json
import time
import requests
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.recipe import Recipe
from app.config import get_settings

settings = get_settings()

# Try to import Gemini for fallback
try:
    from google import genai
    from google.genai import types
    gemini_client = genai.Client(api_key=settings.gemini_api_key) if settings.gemini_api_key else None
except ImportError:
    gemini_client = None
    print("⚠️ google-genai not installed, AI fallback disabled")

# Configuration
CHECKPOINT_FILE = "smart_image_checkpoint.json"
IMAGE_OUTPUT_DIR = Path("static/recipe_images")
IMAGE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

BATCH_SIZE = 10
SEARCH_DELAY = 1.2  # Seconds between search API calls
AI_DELAY = 4.0  # Seconds between AI generation calls
MAX_RETRIES = 2

# Fallback images to detect
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
        "stats": {"search_success": 0, "ai_success": 0, "failed": 0},
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


def search_recipe_image(recipe_name: str, cuisine: str, ingredients: list) -> Tuple[Optional[str], str]:
    """
    Search for a REAL image using Google Custom Search.
    Uses multiple smart query strategies for accuracy.
    
    Returns: (image_url, method) where method is 'search' or None
    """
    if not settings.search_api or not settings.search_engine_id:
        return None, "no_api"
    
    # Extract key ingredients for more specific search
    key_ingredients = []
    if ingredients:
        # Get first 3 main ingredients (skip amounts/measurements)
        for ing in ingredients[:5]:
            # Extract the main ingredient word (skip numbers, measurements)
            words = ing.lower().split()
            for word in words:
                if len(word) > 3 and word.isalpha() and word not in ['cups', 'cup', 'tbsp', 'tsp', 'tablespoon', 'teaspoon', 'ounce', 'pound', 'gram', 'fresh', 'dried', 'chopped', 'minced', 'sliced', 'large', 'small', 'medium']:
                    key_ingredients.append(word)
                    break
            if len(key_ingredients) >= 2:
                break
    
    ingredient_hint = " ".join(key_ingredients[:2])
    
    # Multiple search strategies - most specific to least specific
    search_queries = [
        # Strategy 1: Exact dish name with "recipe" - most accurate
        f'"{recipe_name}" recipe food photo',
        
        # Strategy 2: Dish name + cuisine
        f'{recipe_name} {cuisine} dish',
        
        # Strategy 3: Dish name with key ingredients
        f'{recipe_name} {ingredient_hint} food',
        
        # Strategy 4: Just the dish name + food
        f'{recipe_name} food dish plated',
    ]
    
    for query in search_queries:
        params = {
            "key": settings.search_api,
            "cx": settings.search_engine_id,
            "q": query,
            "searchType": "image",
            "num": 5,
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
                    break  # Try next query
                
                items = response.json().get("items", [])
                
                # Find a valid image
                for item in items:
                    url = item.get("link", "")
                    if not url or not url.startswith("http"):
                        continue
                    
                    # Skip tiny images
                    info = item.get("image", {})
                    width = info.get("width", 0)
                    height = info.get("height", 0)
                    if width < 400 or height < 300:
                        continue
                    
                    # Skip certain domains that often have wrong images
                    skip_domains = ['pinterest.com', 'shutterstock.com', 'istockphoto.com', 'gettyimages.com']
                    if any(d in url.lower() for d in skip_domains):
                        continue
                    
                    # Validate the URL works
                    if validate_image_url(url):
                        return url, "search"
                
                # If this query returned results but none validated, try next query
                if items:
                    time.sleep(0.3)
                    continue
                    
            except requests.exceptions.Timeout:
                time.sleep(1)
                continue
            except Exception as e:
                break
        
        time.sleep(0.5)  # Small delay between query strategies
    
    return None, "search_failed"


def generate_image_ai(recipe_name: str, cuisine: str, description: str, ingredients: list) -> Tuple[Optional[str], str]:
    """
    Generate an AI image using Imagen 4.0 ULTRA as fallback.
    
    Returns: (image_path, method) where method is 'ai' or None
    """
    if not gemini_client:
        return None, "no_ai"
    
    # Build detailed prompt
    main_ingredients = ", ".join(ingredients[:6]) if ingredients else "traditional ingredients"
    desc_text = (description or "")[:120].strip()
    if desc_text:
        desc_text = f" {desc_text}"
    
    prompt = f"""Hyper-realistic professional food photography of {recipe_name}, an authentic {cuisine} dish.{desc_text}
Main ingredients: {main_ingredients}.
Style: appetizing, beautifully plated, natural lighting, overhead shot, rustic ceramic plate, 
garnished with fresh herbs, culinary magazine quality, photorealistic."""

    try:
        response = gemini_client.models.generate_images(
            model='imagen-4.0-ultra-generate-001',
            prompt=prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                aspect_ratio='4:3',
            )
        )
        
        if response.generated_images:
            img = response.generated_images[0]
            
            # Save locally
            safe_name = "".join(c if c.isalnum() else "_" for c in recipe_name[:40])
            hash_suffix = hashlib.md5(recipe_name.encode()).hexdigest()[:8]
            filename = f"{safe_name}_{hash_suffix}.png"
            filepath = IMAGE_OUTPUT_DIR / filename
            
            img.image.save(str(filepath))
            return f"/static/recipe_images/{filename}", "ai"
        
        return None, "ai_failed"
        
    except Exception as e:
        error_msg = str(e)
        if "quota" in error_msg.lower():
            print("    ⚠️ AI quota exceeded")
        elif "safety" in error_msg.lower():
            print("    ⚠️ Content blocked")
        else:
            print(f"    ⚠️ AI error: {error_msg[:50]}")
        return None, "ai_error"


def update_recipe_images(limit: int = None, dry_run: bool = False, resume: bool = True, ai_fallback: bool = True):
    """Update recipes with smart search + AI fallback."""
    
    has_search = settings.search_api and settings.search_engine_id
    has_ai = gemini_client is not None
    
    if not has_search and not has_ai:
        print("❌ ERROR: No image source configured!")
        print("   Set SEARCH_API + SEARCH_ENGINE_ID for Google Search")
        print("   Or GEMINI_API_KEY for AI generation")
        return
    
    print(f"\n🔧 Image sources:")
    print(f"   📸 Google Search: {'✅ Enabled' if has_search else '❌ Disabled'}")
    print(f"   🎨 AI Generation: {'✅ Enabled' if has_ai and ai_fallback else '❌ Disabled'}")
    
    # Load checkpoint
    checkpoint = load_checkpoint() if resume else {
        "processed_ids": [],
        "failed_ids": [],
        "stats": {"search_success": 0, "ai_success": 0, "failed": 0},
        "started_at": datetime.now().isoformat()
    }
    
    processed_ids = set(checkpoint["processed_ids"])
    failed_ids = set(checkpoint["failed_ids"])
    stats = checkpoint["stats"]
    
    db = SessionLocal()
    
    try:
        # Get recipes needing updates
        all_recipes = db.query(Recipe).order_by(Recipe.created_at.desc()).all()
        
        recipes_to_update = []
        for r in all_recipes:
            rid = str(r.id)
            if rid not in processed_ids and rid not in failed_ids:
                if needs_new_image(r.image_url):
                    recipes_to_update.append(r)
        
        if limit:
            recipes_to_update = recipes_to_update[:limit]
        
        total = len(recipes_to_update)
        print(f"\n📊 Found {total} recipes needing images")
        if dry_run:
            print("🧪 DRY RUN MODE")
        print("=" * 60 + "\n")
        
        if total == 0:
            print("✅ All recipes have proper images!")
            return
        
        batch_count = 0
        start_time = datetime.now()
        
        for i, recipe in enumerate(recipes_to_update):
            recipe_id = str(recipe.id)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            total_done = stats["search_success"] + stats["ai_success"]
            rate = total_done / max(elapsed / 3600, 0.01)
            
            print(f"[{i+1}/{total}] ({rate:.0f}/hr) 🔍 {recipe.name[:45]}...")
            
            if dry_run:
                print(f"    📝 Would search for: {recipe.cuisine}")
                processed_ids.add(recipe_id)
                stats["search_success"] += 1
                continue
            
            # Step 1: Try Google Search first
            image_url, method = None, None
            if has_search:
                image_url, method = search_recipe_image(
                    recipe.name,
                    recipe.cuisine,
                    recipe.ingredients or []
                )
                
                if image_url:
                    recipe.image_url = image_url
                    processed_ids.add(recipe_id)
                    stats["search_success"] += 1
                    print(f"    ✅ [SEARCH] {image_url[:55]}...")
                    time.sleep(SEARCH_DELAY)
                else:
                    print(f"    ⚠️ Search failed, ", end="")
                    time.sleep(SEARCH_DELAY)
            
            # Step 2: AI fallback if search failed
            if not image_url and has_ai and ai_fallback:
                print("trying AI...")
                image_url, method = generate_image_ai(
                    recipe.name,
                    recipe.cuisine,
                    recipe.description or "",
                    recipe.ingredients or []
                )
                
                if image_url:
                    recipe.image_url = image_url
                    processed_ids.add(recipe_id)
                    stats["ai_success"] += 1
                    print(f"    ✅ [AI] {image_url}")
                    time.sleep(AI_DELAY)
                else:
                    failed_ids.add(recipe_id)
                    stats["failed"] += 1
                    print(f"    ❌ Both methods failed")
            elif not image_url:
                if not has_search:
                    print("no search API")
                failed_ids.add(recipe_id)
                stats["failed"] += 1
            
            batch_count += 1
            
            # Checkpoint
            if batch_count >= BATCH_SIZE:
                if not dry_run:
                    db.commit()
                
                checkpoint["processed_ids"] = list(processed_ids)
                checkpoint["failed_ids"] = list(failed_ids)
                checkpoint["stats"] = stats
                save_checkpoint(checkpoint)
                
                print(f"\n💾 Search: {stats['search_success']} | AI: {stats['ai_success']} | Failed: {stats['failed']}\n")
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
    print(f"🎉 IMAGE UPDATE COMPLETE")
    print(f"{'='*60}")
    print(f"📸 Search: {stats['search_success']}")
    print(f"🎨 AI:     {stats['ai_success']}")
    print(f"❌ Failed: {stats['failed']}")
    print(f"⏱️  Time:   {elapsed/60:.1f} min")
    print(f"{'='*60}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Smart image updater with search + AI fallback")
    parser.add_argument("--limit", type=int, default=None, help="Max to update")
    parser.add_argument("--dry-run", action="store_true", help="Preview only")
    parser.add_argument("--no-resume", action="store_true", help="Start fresh")
    parser.add_argument("--no-ai", action="store_true", help="Disable AI fallback")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🖼️  CUISINEE SMART IMAGE UPDATER")
    print("=" * 60)
    print(f"📊 Limit:      {args.limit if args.limit else 'All'}")
    print(f"🧪 Dry Run:    {'Yes' if args.dry_run else 'No'}")
    print(f"📌 Resume:     {'No' if args.no_resume else 'Yes'}")
    print(f"🎨 AI Fallback: {'No' if args.no_ai else 'Yes'}")
    print("=" * 60)
    
    update_recipe_images(
        limit=args.limit,
        dry_run=args.dry_run,
        resume=not args.no_resume,
        ai_fallback=not args.no_ai
    )
