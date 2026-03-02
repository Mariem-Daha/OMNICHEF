"""
CUISINEE AI IMAGE GENERATOR (Imagen 4.0)
=========================================
Uses Google's Imagen 4.0 to generate accurate, beautiful recipe images.
No more random stock photos - every recipe gets a custom AI-generated image!

Usage:
    python ai_generate_images.py --limit 10
    python ai_generate_images.py --dry-run
"""

import os
import sys
import json
import time
import hashlib
import base64
from datetime import datetime
from pathlib import Path
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from google import genai
from google.genai import types
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.recipe import Recipe
from app.config import get_settings

settings = get_settings()

# Configuration
CHECKPOINT_FILE = "ai_image_gen_checkpoint.json"
IMAGE_OUTPUT_DIR = Path("static/recipe_images")
IMAGE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

BATCH_SIZE = 5
API_DELAY = 3.0  # Seconds between API calls

# Initialize Gemini client
client = None
if settings.gemini_api_key:
    client = genai.Client(api_key=settings.gemini_api_key)

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
        "stats": {"generated": 0, "failed": 0},
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


def generate_recipe_image(recipe_name: str, cuisine: str, description: str, ingredients: list) -> Optional[str]:
    """
    Generate a photorealistic AI image for the recipe using Imagen 4.0 ULTRA.
    Returns the local file path to the saved image.
    """
    if not client:
        print("    ❌ No Gemini client initialized")
        return None
    
    # Build a detailed, photorealistic prompt
    main_ingredients = ", ".join(ingredients[:6]) if ingredients else "traditional ingredients"
    
    # Clean description
    desc_text = (description or "")[:150].strip()
    if desc_text:
        desc_text = f" {desc_text}"
    
    prompt = f"""Hyper-realistic professional food photography of {recipe_name}, an authentic {cuisine} dish.{desc_text}
Main ingredients visible: {main_ingredients}.

Photography style:
- Shot with professional DSLR camera, 85mm lens
- Shallow depth of field with bokeh background
- Natural daylight from window, soft shadows
- Overhead angle or 45-degree hero shot
- Ultra high resolution, 8K quality
- Food styled by professional food stylist
- On rustic ceramic plate or traditional {cuisine} serving dish
- Garnished with fresh herbs and spices
- Appetizing, mouth-watering presentation
- Culinary magazine cover quality
- Photorealistic, indistinguishable from real photograph"""

    try:
        response = client.models.generate_images(
            model='imagen-4.0-ultra-generate-001',  # ULTRA for best quality!
            prompt=prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                aspect_ratio='4:3',
            )
        )
        
        if response.generated_images:
            img = response.generated_images[0]
            
            # Create unique filename
            safe_name = "".join(c if c.isalnum() else "_" for c in recipe_name[:40])
            hash_suffix = hashlib.md5(recipe_name.encode()).hexdigest()[:8]
            filename = f"{safe_name}_{hash_suffix}.png"
            filepath = IMAGE_OUTPUT_DIR / filename
            
            # Save the image
            img.image.save(str(filepath))
            
            # Return relative URL for serving
            return f"/static/recipe_images/{filename}"
        
        return None
        
    except Exception as e:
        error_msg = str(e)
        if "quota" in error_msg.lower():
            print("    ⚠️ API quota exceeded")
        elif "safety" in error_msg.lower():
            print("    ⚠️ Content blocked by safety filter")
        else:
            print(f"    ❌ Error: {error_msg[:80]}")
        return None


def generate_all_images(limit: int = None, dry_run: bool = False, resume: bool = True):
    """Generate AI images for all recipes that need them."""
    
    if not client:
        print("❌ ERROR: GEMINI_API_KEY not set!")
        return
    
    # Load checkpoint
    checkpoint = load_checkpoint() if resume else {
        "processed_ids": [],
        "failed_ids": [],
        "stats": {"generated": 0, "failed": 0},
        "started_at": datetime.now().isoformat()
    }
    
    processed_ids = set(checkpoint["processed_ids"])
    failed_ids = set(checkpoint["failed_ids"])
    stats = checkpoint["stats"]
    
    db = SessionLocal()
    
    try:
        # Get recipes that need new images
        all_recipes = db.query(Recipe).order_by(Recipe.created_at.desc()).all()
        
        recipes_to_process = []
        for r in all_recipes:
            rid = str(r.id)
            if rid not in processed_ids and rid not in failed_ids:
                if needs_new_image(r.image_url):
                    recipes_to_process.append(r)
        
        if limit:
            recipes_to_process = recipes_to_process[:limit]
        
        total = len(recipes_to_process)
        print(f"\n🎨 Found {total} recipes needing AI-generated images")
        if dry_run:
            print("🧪 DRY RUN MODE - no changes saved")
        print("=" * 60 + "\n")
        
        if total == 0:
            print("✅ All recipes already have proper images!")
            return
        
        batch_count = 0
        start_time = datetime.now()
        
        for i, recipe in enumerate(recipes_to_process):
            recipe_id = str(recipe.id)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            rate = stats["generated"] / max(elapsed / 3600, 0.01)
            
            print(f"[{i+1}/{total}] ({rate:.0f}/hr) 🎨 {recipe.name[:45]}...")
            
            if dry_run:
                print(f"    📝 Would generate image for: {recipe.cuisine}")
                processed_ids.add(recipe_id)
                stats["generated"] += 1
            else:
                # Generate image with ULTRA quality
                image_path = generate_recipe_image(
                    recipe.name,
                    recipe.cuisine,
                    recipe.description or "",
                    recipe.ingredients or []
                )
                
                if image_path:
                    recipe.image_url = image_path
                    processed_ids.add(recipe_id)
                    stats["generated"] += 1
                    print(f"    ✅ Saved: {image_path}")
                else:
                    failed_ids.add(recipe_id)
                    stats["failed"] += 1
            
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
                
                print(f"\n💾 Checkpoint: {stats['generated']} generated | {stats['failed']} failed\n")
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
    print(f"🎉 AI IMAGE GENERATION COMPLETE")
    print(f"{'='*60}")
    print(f"✅ Generated: {stats['generated']}")
    print(f"❌ Failed:    {stats['failed']}")
    print(f"⏱️  Duration:  {elapsed/60:.1f} minutes")
    print(f"📁 Output:    {IMAGE_OUTPUT_DIR.absolute()}")
    print(f"{'='*60}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate AI images for recipes")
    parser.add_argument("--limit", type=int, default=None, help="Max to generate")
    parser.add_argument("--dry-run", action="store_true", help="Preview only")
    parser.add_argument("--no-resume", action="store_true", help="Start fresh")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🎨 CUISINEE AI IMAGE GENERATOR (Imagen 4.0)")
    print("=" * 60)
    print(f"📊 Limit:   {args.limit if args.limit else 'All'}")
    print(f"🧪 Dry Run: {'Yes' if args.dry_run else 'No'}")
    print(f"📌 Resume:  {'No' if args.no_resume else 'Yes'}")
    print(f"🤖 Model:   imagen-4.0-ultra-generate-001 (BEST QUALITY)")
    print("=" * 60)
    
    generate_all_images(
        limit=args.limit,
        dry_run=args.dry_run,
        resume=not args.no_resume
    )
