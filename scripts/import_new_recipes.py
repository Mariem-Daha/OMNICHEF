"""
CUISINEE NEW RECIPES IMPORTER
==============================
Imports only recipes that don't exist in the database yet.
More efficient than the main importer for filling gaps.
"""

import json
import glob
import os
import random
import sys
import time
import hashlib
from decimal import Decimal
from datetime import datetime
from typing import Optional, Dict, List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import google.generativeai as genai
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models.recipe import Recipe, RecipeStep, NutritionInfo
from app.config import get_settings

settings = get_settings()

# Configure Gemini
if settings.gemini_api_key:
    genai.configure(api_key=settings.gemini_api_key)
    model = genai.GenerativeModel('gemini-2.0-flash-exp')
else:
    model = None
    print("⚠️ WARNING: No Gemini API key configured!")

# Config
CHECKPOINT_FILE = "import_new_checkpoint.json"
BATCH_SIZE = 10
API_DELAY = 4.0
MAX_RETRIES = 3
EXCLUDED_FOLDERS = []  # Allow all folders including From_CSV_Dataset and From_Full_Dataset

# Cuisine mapping
FOLDER_TO_CUISINE = {
    "Moroccan": "Moroccan", "Algerian": "Algerian", "Tunisian": "Tunisian",
    "Egyptian": "Egyptian", "Libyan": "Libyan", "North_Africa": "North African",
    "Lebanese": "Lebanese", "Syrian": "Syrian", "Jordanian": "Jordanian",
    "Palestinian": "Palestinian", "Levant": "Levantine",
    "Kuwaiti": "Kuwaiti", "Saudi_Arabia_Gulf": "Saudi Arabian",
    "Emirati": "Emirati", "Bahraini": "Bahraini", "Qatari": "Qatari",
    "Omani": "Omani", "Gulf": "Gulf Arabian",
    "Yemeni": "Yemeni", "Arabian_Peninsula": "Arabian",
    "General_Arabic": "Arabic", "General": "Arabic",
    "Middle_East_General": "Middle Eastern",
}

FALLBACK_IMAGES = [
    "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800",
    "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800",
    "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=800",
]

ANALYSIS_PROMPT = '''You are a culinary nutritionist. Analyze this recipe.

RECIPE: {title}
CUISINE: {cuisine}
INGREDIENTS:
{ingredients}
DIRECTIONS:
{directions}

Return ONLY valid JSON:
{{
    "prep_time_minutes": <number>,
    "cook_time_minutes": <number>,
    "servings": <number>,
    "difficulty": "<Easy|Medium|Intermediate|Advanced>",
    "nutrition_per_serving": {{
        "calories": <number>,
        "protein_g": <number>,
        "carbs_g": <number>,
        "fat_g": <number>,
        "fiber_g": <number>,
        "sodium_mg": <number>,
        "sugar_g": <number>
    }},
    "health_tags": [<only certain tags>],
    "description": "<2 sentences>"
}}

Health tags (only if certain): Vegetarian, Vegan, Gluten-Free, Dairy-Free, Heart Healthy, High Protein, Low Carb, Quick & Easy, Kid Friendly'''


def load_checkpoint():
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"processed": [], "stats": {"imported": 0, "skipped": 0, "errors": 0, "api_calls": 0}}

def save_checkpoint(checkpoint):
    checkpoint["last_updated"] = datetime.now().isoformat()
    with open(CHECKPOINT_FILE, 'w', encoding='utf-8') as f:
        json.dump(checkpoint, f, indent=2)

def get_cuisine_from_path(filepath, recipe_folder):
    rel_path = os.path.relpath(filepath, recipe_folder)
    for part in reversed(rel_path.split(os.sep)[:-1]):
        if part in FOLDER_TO_CUISINE:
            return FOLDER_TO_CUISINE[part]
    return "Middle Eastern"

def analyze_with_ai(title, cuisine, ingredients, directions, stats):
    if not model:
        return None
    
    prompt = ANALYSIS_PROMPT.format(
        title=title,
        cuisine=cuisine,
        ingredients="\n".join(f"• {i}" for i in ingredients[:15]),
        directions="\n".join(f"{n+1}. {d}" for n, d in enumerate(directions[:10]))
    )
    
    for attempt in range(MAX_RETRIES):
        try:
            response = model.generate_content(prompt)
            text = response.text.strip()
            if "```" in text:
                for part in text.split("```"):
                    if "{" in part:
                        text = part.replace("json", "").strip()
                        break
            stats["api_calls"] += 1
            return json.loads(text)
        except Exception as e:
            if "429" in str(e) or "quota" in str(e).lower():
                print(f"    ⚠ Rate limited, waiting 30s...")
                time.sleep(30)
            else:
                time.sleep(2)
    return None

def clamp(value, min_val=0, max_val=999.99):
    try:
        return round(max(min_val, min(float(value), max_val)), 2)
    except:
        return min_val

def import_new_recipes(recipe_folder, limit=50, resume=True):
    if not settings.gemini_api_key:
        print("❌ GEMINI_API_KEY not set!")
        return
    
    # Get existing titles from DB
    db = SessionLocal()
    existing = set(r.name.lower().strip() for r in db.query(Recipe.name).all())
    print(f"📊 DB has {len(existing)} recipes")
    
    # Find new recipe files
    all_files = glob.glob(os.path.join(recipe_folder, "**", "*.json"), recursive=True)
    files = [f for f in all_files if not any(ex in f for ex in EXCLUDED_FOLDERS)]
    
    new_files = []
    for f in files:
        try:
            with open(f, 'r', encoding='utf-8') as fp:
                data = json.load(fp)
                title = data.get('title', '').strip()
                if title and title.lower() not in existing:
                    new_files.append((f, data))
        except:
            pass
    
    print(f"📋 Found {len(new_files)} new recipes to import")
    if limit:
        new_files = new_files[:limit]
        print(f"📊 Limited to {limit}")
    
    # Load checkpoint
    checkpoint = load_checkpoint() if resume else {"processed": [], "stats": {"imported": 0, "skipped": 0, "errors": 0, "api_calls": 0}}
    processed = set(checkpoint["processed"])
    stats = checkpoint["stats"]
    
    batch = 0
    start = datetime.now()
    
    try:
        for i, (filepath, data) in enumerate(new_files):
            title = data.get("title", "").strip()
            title_lower = title.lower()
            
            if title_lower in processed:
                continue
            
            cuisine = get_cuisine_from_path(filepath, recipe_folder)
            ingredients = data.get("ingredients", [])
            directions = data.get("directions", [])
            
            if not title or not ingredients or not directions:
                processed.add(title_lower)
                stats["skipped"] += 1
                continue
            
            # Check again if exists (in case of parallel runs)
            if db.query(Recipe).filter(Recipe.name == title).first():
                processed.add(title_lower)
                stats["skipped"] += 1
                continue
            
            elapsed = (datetime.now() - start).total_seconds()
            rate = stats["imported"] / max(elapsed/3600, 0.01)
            print(f"[{i+1}/{len(new_files)}] ({rate:.0f}/hr) [{cuisine}] {title[:45]}...")
            
            # AI Analysis
            analysis = analyze_with_ai(title, cuisine, ingredients, directions, stats)
            time.sleep(API_DELAY)
            
            if not analysis:
                analysis = {
                    "prep_time_minutes": min(len(ingredients) * 4, 45),
                    "cook_time_minutes": min(len(directions) * 8, 90),
                    "servings": 4, "difficulty": "Medium",
                    "nutrition_per_serving": {"calories": 400, "protein_g": 20, "carbs_g": 45, "fat_g": 18, "fiber_g": 5, "sodium_mg": 600, "sugar_g": 8},
                    "health_tags": [],
                    "description": f"A delicious {cuisine} recipe."
                }
            
            nutrition = analysis.get("nutrition_per_serving", {})
            
            recipe = Recipe(
                name=title[:255],
                description=analysis.get("description", f"Traditional {cuisine} dish.")[:500],
                image_url=random.choice(FALLBACK_IMAGES),  # Will update images later
                cuisine=cuisine,
                prep_time=analysis.get("prep_time_minutes", 20),
                cook_time=analysis.get("cook_time_minutes", 30),
                servings=analysis.get("servings", 4),
                calories=int(min(max(0, nutrition.get("calories", 400)), 9999)),
                tags=analysis.get("health_tags", [])[:5],
                ingredients=ingredients[:25],
                difficulty=analysis.get("difficulty", "Medium"),
                chef_name=f"Chef {data.get('source', 'Community')[:40]}",
                rating=round(random.uniform(4.3, 4.9), 1),
                review_count=random.randint(30, 400),
            )
            
            db.add(recipe)
            db.flush()
            
            # Steps
            cook_time = analysis.get("cook_time_minutes", 30)
            for n, step in enumerate(directions[:15], 1):
                if step.strip():
                    db.add(RecipeStep(
                        recipe_id=recipe.id,
                        step_number=n,
                        instruction=step.strip()[:1000],
                        duration_minutes=max(1, cook_time // max(len(directions), 1))
                    ))
            
            # Nutrition
            db.add(NutritionInfo(
                recipe_id=recipe.id,
                calories=int(min(max(0, nutrition.get("calories", 400)), 9999)),
                protein=Decimal(str(clamp(nutrition.get("protein_g", 20)))),
                carbs=Decimal(str(clamp(nutrition.get("carbs_g", 45)))),
                fat=Decimal(str(clamp(nutrition.get("fat_g", 18)))),
                fiber=Decimal(str(clamp(nutrition.get("fiber_g", 5)))),
                sodium=Decimal(str(clamp(nutrition.get("sodium_mg", 600)))),
                sugar=Decimal(str(clamp(nutrition.get("sugar_g", 8)))),
            ))
            
            processed.add(title_lower)
            existing.add(title_lower)
            stats["imported"] += 1
            batch += 1
            print(f"    ✅ Imported!")
            
            if batch >= BATCH_SIZE:
                db.commit()
                checkpoint["processed"] = list(processed)
                checkpoint["stats"] = stats
                save_checkpoint(checkpoint)
                print(f"\n{'='*50}\n💾 Checkpoint: {stats['imported']} imported\n{'='*50}\n")
                batch = 0
        
        db.commit()
        checkpoint["processed"] = list(processed)
        checkpoint["stats"] = stats
        checkpoint["completed_at"] = datetime.now().isoformat()
        save_checkpoint(checkpoint)
        
    except KeyboardInterrupt:
        print("\n⚠️ Interrupted, saving...")
        db.commit()
        checkpoint["processed"] = list(processed)
        checkpoint["stats"] = stats
        save_checkpoint(checkpoint)
    finally:
        db.close()
    
    elapsed = (datetime.now() - start).total_seconds()
    print(f"\n{'='*50}")
    print(f"✅ Imported: {stats['imported']}")
    print(f"⏭️ Skipped: {stats['skipped']}")
    print(f"🤖 API Calls: {stats['api_calls']}")
    print(f"⏱️ Duration: {elapsed/60:.1f} min")
    print(f"{'='*50}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--folder", default=r"C:\Users\Admin\Downloads\recipes-master\recipes-master\ORGANIZED_RECIPES\ARABIC_RECIPES")
    args = parser.parse_args()
    
    print("="*50)
    print("🍳 NEW RECIPES IMPORTER")
    print("="*50)
    
    import_new_recipes(args.folder, args.limit, not args.no_resume)
