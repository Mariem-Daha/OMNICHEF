"""
CUISINEE AI IMAGE GENERATOR
============================
Uses Gemini AI to generate accurate images for recipes.
Much better than random fallback images!

Usage:
    python generate_recipe_images.py --limit 10
    python generate_recipe_images.py --dry-run
"""

import os
import sys
import json
import time
import requests
import hashlib
from datetime import datetime
from typing import Optional
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.recipe import Recipe
from app.config import get_settings
import google.generativeai as genai

settings = get_settings()

# Configuration
CHECKPOINT_FILE = "image_gen_checkpoint.json"
BATCH_SIZE = 5
API_DELAY = 5.0  # Seconds between API calls
IMAGE_FOLDER = Path("generated_images")
IMAGE_FOLDER.mkdir(exist_ok=True)

# Fallback images that indicate a recipe needs updating
FALLBACK_PATTERNS = [
    "unsplash.com/photo-1504674900247",
    "unsplash.com/photo-1540189549336",
    "unsplash.com/photo-1565299624946",
    "unsplash.com/photo-1567620905732",
]

# Configure Gemini for image generation
if settings.gemini_api_key:
    genai.configure(api_key=settings.gemini_api_key)


def load_checkpoint() -> dict:
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {
        "processed_ids": [],
        "failed_ids": [],
        "stats": {"generated": 0, "failed": 0, "skipped": 0},
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


def search_image_google(query: str) -> Optional[str]:
    """
    Search for a real image using Google Custom Search API.
    Returns image URL or None.
    """
    if not settings.search_api or not settings.search_engine_id:
        return None
    
    params = {
        "key": settings.search_api,
        "cx": settings.search_engine_id,
        "q": f"{query} food dish recipe photo",
        "searchType": "image",
        "num": 3,
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
            return None
        
        items = response.json().get("items", [])
        
        # Try each result until we find a valid one
        for item in items:
            url = item.get("link")
            if url and validate_image_url(url):
                return url
        
        return items[0].get("link") if items else None
        
    except Exception as e:
        print(f"    ⚠️ Search error: {str(e)[:50]}")
        return None


def generate_image_with_gemini(recipe_name: str, cuisine: str, ingredients: list) -> Optional[str]:
    """
    Use Gemini to generate an image for the recipe.
    Returns a URL to a generated image hosted on Gemini's servers.
    """
    try:
        # Use Imagen 4.0 for image generation (latest available)
        imagen = genai.ImageGenerationModel("imagen-4.0-generate-001")
        
        # Craft a detailed prompt for accurate food photography
        main_ingredients = ", ".join(ingredients[:5]) if ingredients else ""
        prompt = f"""Professional food photography of {recipe_name}, a {cuisine} dish.
The dish contains: {main_ingredients}.
Style: overhead shot, appetizing, well-plated, natural lighting, on a rustic wooden table, garnished beautifully.
Make it look delicious and authentic to {cuisine} cuisine."""

        result = imagen.generate_images(
            prompt=prompt,
            number_of_images=1,
            aspect_ratio="4:3",
            safety_filter_level="block_only_high",
        )
        
        if result.images:
            # Save the image locally first
            image = result.images[0]
            
            # Create a unique filename based on recipe name
            safe_name = "".join(c if c.isalnum() else "_" for c in recipe_name[:50])
            filename = f"{safe_name}_{hashlib.md5(recipe_name.encode()).hexdigest()[:8]}.png"
            filepath = IMAGE_FOLDER / filename
            
            # Save the image
            image._pil_image.save(str(filepath))
            
            # Return a local path - you'll need to serve these images
            # For now, return placeholders that indicate generation worked
            return f"/generated_images/{filename}"
        
        return None
        
    except Exception as e:
        error_msg = str(e)
        if "not available" in error_msg.lower() or "not supported" in error_msg.lower():
            print(f"    ⚠️ Image generation not available in this region/plan")
        else:
            print(f"    ⚠️ Generation error: {error_msg[:60]}")
        return None


def find_image_for_recipe(recipe: Recipe) -> Optional[str]:
    """
    Try multiple methods to find an image for the recipe.
    Priority: Google Search > Gemini Generation > Keep existing
    """
    # Method 1: Google Custom Search (if configured)
    if settings.search_api and settings.search_engine_id:
        print(f"    🔍 Trying Google Search...")
        url = search_image_google(f"{recipe.name} {recipe.cuisine}")
        if url:
            return url
    
    # Method 2: Gemini Image Generation
    print(f"    🎨 Trying Gemini image generation...")
    url = generate_image_with_gemini(
        recipe.name,
        recipe.cuisine,
        recipe.ingredients or []
    )
    if url:
        return url
    
    return None


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


def update_recipe_images(limit: int = None, dry_run: bool = False, resume: bool = True):
    """Update recipes with fallback images to have real images."""
    
    if not settings.gemini_api_key and not (settings.search_api and settings.search_engine_id):
        print("❌ ERROR: No image source configured!")
        print("   Either set GEMINI_API_KEY or SEARCH_API + SEARCH_ENGINE_ID")
        return
    
    # Load checkpoint
    checkpoint = load_checkpoint() if resume else {
        "processed_ids": [],
        "failed_ids": [],
        "stats": {"generated": 0, "failed": 0, "skipped": 0},
        "started_at": datetime.now().isoformat()
    }
    
    processed_ids = set(checkpoint["processed_ids"])
    failed_ids = set(checkpoint["failed_ids"])
    stats = checkpoint["stats"]
    
    db = SessionLocal()
    
    try:
        # Get recipes that need images - ordered by name for consistency
        query = db.query(Recipe).order_by(Recipe.name)
        
        if limit:
            query = query.limit(limit * 2)  # Get extra in case some are already done
        
        recipes = query.all()
        
        # Filter to only recipes that need updating
        recipes_to_update = []
        for r in recipes:
            if str(r.id) not in processed_ids and str(r.id) not in failed_ids:
                if needs_new_image(r.image_url):
                    recipes_to_update.append(r)
        
        if limit:
            recipes_to_update = recipes_to_update[:limit]
        
        total = len(recipes_to_update)
        print(f"\n📊 Found {total} recipes needing images")
        if dry_run:
            print("🧪 DRY RUN MODE - no changes will be saved")
        print("=" * 60 + "\n")
        
        batch_count = 0
        start_time = datetime.now()
        
        for i, recipe in enumerate(recipes_to_update):
            recipe_id_str = str(recipe.id)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            rate = stats["generated"] / max(elapsed / 3600, 0.01)
            
            print(f"[{i+1}/{total}] ({rate:.0f}/hr) 🖼️ {recipe.name[:45]}...")
            print(f"    Current: {recipe.image_url[:50] if recipe.image_url else 'None'}...")
            
            # Find new image
            new_url = find_image_for_recipe(recipe)
            
            if new_url:
                if not dry_run:
                    recipe.image_url = new_url
                
                processed_ids.add(recipe_id_str)
                stats["generated"] += 1
                print(f"    ✅ New: {new_url[:60]}...")
            else:
                failed_ids.add(recipe_id_str)
                stats["failed"] += 1
                print(f"    ❌ No image found")
            
            batch_count += 1
            time.sleep(API_DELAY)
            
            # Save checkpoint periodically
            if batch_count >= BATCH_SIZE:
                if not dry_run:
                    db.commit()
                
                checkpoint["processed_ids"] = list(processed_ids)
                checkpoint["failed_ids"] = list(failed_ids)
                checkpoint["stats"] = stats
                save_checkpoint(checkpoint)
                
                print(f"\n{'='*60}")
                print(f"💾 CHECKPOINT: Generated {stats['generated']} | Failed {stats['failed']}")
                print(f"{'='*60}\n")
                
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
        print("\n\n⚠️ Interrupted! Saving progress...")
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
    print(f"✅ Generated: {stats['generated']:,}")
    print(f"❌ Failed:    {stats['failed']:,}")
    print(f"⏱️  Duration:  {elapsed/60:.1f} minutes")
    print(f"{'='*60}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate/find images for recipes")
    parser.add_argument("--limit", type=int, default=None, help="Max recipes to update")
    parser.add_argument("--dry-run", action="store_true", help="Preview without saving")
    parser.add_argument("--no-resume", action="store_true", help="Start fresh")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🖼️  CUISINEE AI IMAGE GENERATOR")
    print("=" * 60)
    
    sources = []
    if settings.search_api:
        sources.append("Google Search")
    if settings.gemini_api_key:
        sources.append("Gemini AI")
    
    print(f"📊 Limit:    {args.limit if args.limit else 'All'}")
    print(f"🧪 Dry Run:  {'Yes' if args.dry_run else 'No'}")
    print(f"📌 Resume:   {'No' if args.no_resume else 'Yes'}")
    print(f"🔧 Sources:  {', '.join(sources) if sources else 'None!'}")
    print("=" * 60 + "\n")
    
    update_recipe_images(
        limit=args.limit,
        dry_run=args.dry_run,
        resume=not args.no_resume
    )
