"""
Recipe Import Script for Cuisinee
Imports recipes from JSON files into the PostgreSQL database.
"""

import json
import glob
import os
import random
import sys
from decimal import Decimal

# Add the app to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models.recipe import Recipe, RecipeStep, NutritionInfo

# Mapping of folder structure to cuisine types
FOLDER_TO_CUISINE = {
    "Arabian_Peninsula": "Arabian Peninsula",
    "Yemeni": "Yemeni",
    "Emirates": "Emirati",
    "Saudi": "Saudi Arabian",
    "Gulf": "Gulf",
    "Kuwaiti": "Kuwaiti",
    "Bahraini": "Bahraini",
    "Qatari": "Qatari",
    "Omani": "Omani",
    "Levant": "Levantine",
    "Lebanese": "Lebanese",
    "Syrian": "Syrian",
    "Jordanian": "Jordanian",
    "Palestinian": "Palestinian",
    "North_Africa": "North African",
    "Moroccan": "Moroccan",
    "Algerian": "Algerian",
    "Tunisian": "Tunisian",
    "Libyan": "Libyan",
    "Egyptian": "Egyptian",
    "Middle_East_General": "Middle Eastern",
    "General": "MENA",
    "From_CSV_Dataset": "MENA",
    "From_Full_Dataset": "MENA",
}

# Food image placeholders from Unsplash (food-related)
FOOD_IMAGES = [
    "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800",
    "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800",
    "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=800",
    "https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800",
    "https://images.unsplash.com/photo-1482049016gy?w=800",
    "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=800",
    "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800",
    "https://images.unsplash.com/photo-1547592180-85f173990554?w=800",
    "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800",
    "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=800",
    "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800",
    "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=800",
    "https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=800",
    "https://images.unsplash.com/photo-1499028344343-cd173ffc68a9?w=800",
]

# Health tags based on ingredients
HEALTH_TAG_KEYWORDS = {
    "Heart Healthy": ["olive oil", "fish", "salmon", "nuts", "avocado", "beans", "lentils"],
    "High Protein": ["chicken", "beef", "lamb", "fish", "eggs", "lentils", "chickpeas", "yogurt"],
    "Vegetarian": [],  # Will check for absence of meat
    "Vegan": [],  # Will check for absence of animal products
    "Low Carb": [],  # Will check for absence of bread, rice, pasta
    "Traditional": ["couscous", "tagine", "hummus", "falafel", "shawarma", "kabsa", "mansaf"],
    "Quick & Easy": [],  # Based on number of steps
    "Iron-Rich": ["spinach", "lentils", "beef", "lamb", "chickpeas"],
    "Fiber-Rich": ["lentils", "beans", "chickpeas", "whole wheat", "vegetables"],
}

MEAT_KEYWORDS = ["chicken", "beef", "lamb", "meat", "pork", "fish", "seafood", "shrimp", "turkey"]
ANIMAL_KEYWORDS = MEAT_KEYWORDS + ["egg", "milk", "butter", "cream", "cheese", "yogurt", "honey"]
CARB_KEYWORDS = ["rice", "bread", "pasta", "flour", "couscous", "potato", "noodles"]


def get_cuisine_from_path(filepath: str, recipe_folder: str) -> str:
    """Extract cuisine type from folder path."""
    rel_path = os.path.relpath(filepath, recipe_folder)
    parts = rel_path.split(os.sep)
    
    # Check each part of the path for cuisine mapping
    for part in parts[:-1]:  # Exclude filename
        if part in FOLDER_TO_CUISINE:
            return FOLDER_TO_CUISINE[part]
    
    return "MENA"  # Default


def generate_tags(ingredients: list, directions: list) -> list:
    """Generate health tags based on ingredients."""
    tags = []
    ingredients_lower = " ".join(ingredients).lower()
    
    # Check keyword-based tags
    for tag, keywords in HEALTH_TAG_KEYWORDS.items():
        if keywords:
            if any(kw in ingredients_lower for kw in keywords):
                tags.append(tag)
    
    # Vegetarian check
    if not any(kw in ingredients_lower for kw in MEAT_KEYWORDS):
        tags.append("Vegetarian")
    
    # Quick & Easy check (less than 6 steps)
    if len(directions) <= 5:
        tags.append("Quick & Easy")
    
    # Limit to 4 tags
    return tags[:4] if tags else ["Traditional"]


def estimate_times_from_directions(directions: list) -> tuple:
    """Estimate prep and cook times from directions."""
    # Simple heuristics
    num_steps = len(directions)
    
    # Estimate prep time (5-10 min per prep step, assuming first 1/3 are prep)
    prep_steps = max(1, num_steps // 3)
    prep_time = prep_steps * 8  # 8 minutes per prep step
    
    # Estimate cook time (10-20 min per cooking step)
    cook_steps = num_steps - prep_steps
    cook_time = cook_steps * 15  # 15 minutes per cook step
    
    # Cap times
    prep_time = min(prep_time, 60)
    cook_time = min(cook_time, 120)
    
    return prep_time, cook_time


def estimate_nutrition(ingredients: list) -> dict:
    """Generate estimated nutrition info."""
    # This is a rough estimate - in production you'd use a nutrition API
    # Base values, adjusted by ingredient count
    base_calories = 300 + len(ingredients) * 25
    
    return {
        "calories": min(base_calories, 800),
        "protein": round(random.uniform(15, 45), 1),
        "carbs": round(random.uniform(20, 60), 1),
        "fat": round(random.uniform(10, 35), 1),
        "fiber": round(random.uniform(3, 12), 1),
        "sodium": round(random.uniform(200, 800), 1),
        "sugar": round(random.uniform(2, 15), 1),
    }


def get_difficulty(ingredients: list, directions: list) -> str:
    """Determine difficulty based on complexity."""
    complexity = len(ingredients) + len(directions) * 2
    
    if complexity < 15:
        return "Easy"
    elif complexity < 30:
        return "Medium"
    elif complexity < 45:
        return "Intermediate"
    else:
        return "Advanced"


def import_recipes(recipe_folder: str, limit: int = 500, skip_existing: bool = True):
    """Import recipes from JSON files to database."""
    
    # Find all JSON files
    files = glob.glob(os.path.join(recipe_folder, "**", "*.json"), recursive=True)
    print(f"Found {len(files)} recipe files")
    
    # Shuffle to get variety
    random.shuffle(files)
    
    db = SessionLocal()
    imported = 0
    skipped = 0
    errors = 0
    
    try:
        for filepath in files:
            if imported >= limit:
                break
                
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                title = data.get("title", "").strip()
                ingredients = data.get("ingredients", [])
                directions = data.get("directions", [])
                
                # Skip if missing essential data
                if not title or not ingredients or not directions:
                    skipped += 1
                    continue
                
                # Skip if title is too short or too long
                if len(title) < 5 or len(title) > 200:
                    skipped += 1
                    continue
                
                # Skip if already exists
                if skip_existing:
                    existing = db.query(Recipe).filter(Recipe.name == title).first()
                    if existing:
                        skipped += 1
                        continue
                
                # Extract data
                cuisine = get_cuisine_from_path(filepath, recipe_folder)
                tags = generate_tags(ingredients, directions)
                prep_time, cook_time = estimate_times_from_directions(directions)
                nutrition_data = estimate_nutrition(ingredients)
                difficulty = get_difficulty(ingredients, directions)
                
                # Create recipe
                recipe = Recipe(
                    name=title[:255],
                    description=f"A delicious {cuisine} recipe with {len(ingredients)} ingredients.",
                    image_url=random.choice(FOOD_IMAGES),
                    cuisine=cuisine,
                    prep_time=prep_time,
                    cook_time=cook_time,
                    servings=random.choice([2, 4, 4, 6, 6, 8]),
                    calories=nutrition_data["calories"],
                    tags=tags,
                    ingredients=ingredients[:20],  # Limit ingredients
                    difficulty=difficulty,
                    chef_name=f"Chef {data.get('source', 'Community')[:50]}",
                    rating=round(random.uniform(4.0, 5.0), 1),
                    review_count=random.randint(10, 500),
                )
                
                db.add(recipe)
                db.flush()  # Get recipe ID
                
                # Create steps
                for i, direction in enumerate(directions[:12], 1):  # Limit to 12 steps
                    if direction.strip():
                        step = RecipeStep(
                            recipe_id=recipe.id,
                            step_number=i,
                            instruction=direction.strip()[:1000],
                            duration_minutes=random.randint(5, 20),
                        )
                        db.add(step)
                
                # Create nutrition info
                nutrition = NutritionInfo(
                    recipe_id=recipe.id,
                    calories=nutrition_data["calories"],
                    protein=Decimal(str(nutrition_data["protein"])),
                    carbs=Decimal(str(nutrition_data["carbs"])),
                    fat=Decimal(str(nutrition_data["fat"])),
                    fiber=Decimal(str(nutrition_data["fiber"])),
                    sodium=Decimal(str(nutrition_data["sodium"])),
                    sugar=Decimal(str(nutrition_data["sugar"])),
                )
                db.add(nutrition)
                
                imported += 1
                
                if imported % 50 == 0:
                    print(f"Imported {imported} recipes...")
                    db.commit()
                    
            except Exception as e:
                errors += 1
                if errors < 10:
                    print(f"Error processing {filepath}: {e}")
                continue
        
        db.commit()
        print(f"\n=== Import Complete ===")
        print(f"Imported: {imported}")
        print(f"Skipped: {skipped}")
        print(f"Errors: {errors}")
        
    finally:
        db.close()


if __name__ == "__main__":
    recipe_folder = r"C:\Users\Admin\Downloads\recipes-master\recipes-master\ORGANIZED_RECIPES\ARABIC_RECIPES"
    
    # Import 500 recipes to start
    import_recipes(recipe_folder, limit=500)
