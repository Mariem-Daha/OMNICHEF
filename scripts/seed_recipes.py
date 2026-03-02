"""Seed script to populate database with initial recipes from dummy data."""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine, Base
from app.models import Recipe, RecipeStep, NutritionInfo

# Create tables
Base.metadata.create_all(bind=engine)

# Recipe data matching dummy_recipes.dart
RECIPES = [
    {
        "name": "Thieboudienne",
        "description": "The national dish of Senegal - a flavorful one-pot meal featuring fish, rice, and vegetables cooked in a rich tomato sauce with traditional spices.",
        "image_url": "https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=800",
        "cuisine": "Mauritanian",
        "prep_time": 30,
        "cook_time": 60,
        "servings": 6,
        "calories": 520,
        "tags": ["Heart Healthy", "Protein-Rich", "Traditional"],
        "ingredients": [
            "2 lbs white fish (grouper or snapper)",
            "2 cups broken rice",
            "1 large eggplant, quartered",
            "2 large carrots, halved",
            "1 small cabbage, quartered",
            "2 cups tomato paste",
            "1 large onion, diced",
            "4 cloves garlic, minced",
            "1/4 cup vegetable oil",
            "2 tbsp tamarind paste",
            "Salt and pepper to taste",
        ],
        "difficulty": "Intermediate",
        "chef_name": "Chef Aminata",
        "rating": 4.8,
        "review_count": 156,
        "steps": [
            {"step_number": 1, "instruction": "Season the fish with salt, pepper, and minced garlic. Let it marinate for 15 minutes.", "duration_minutes": 15, "tip": "Score the fish for better flavor absorption"},
            {"step_number": 2, "instruction": "Heat oil in a large pot over medium-high heat. Fry the fish until golden on both sides, about 3 minutes per side. Remove and set aside.", "duration_minutes": 8},
            {"step_number": 3, "instruction": "In the same pot, sauté the onions until translucent. Add tomato paste and cook for 5 minutes, stirring frequently.", "duration_minutes": 10},
            {"step_number": 4, "instruction": "Add 6 cups of water, tamarind paste, and bring to a boil. Add the vegetables and cook until tender, about 20 minutes.", "duration_minutes": 25},
            {"step_number": 5, "instruction": "Remove vegetables and set aside. Add the rice to the pot, ensuring it's covered with liquid. Cook covered on low heat for 25 minutes.", "duration_minutes": 25},
            {"step_number": 6, "instruction": "Return the fish and vegetables to the pot for the last 5 minutes of cooking. Serve hot with the rice on a large platter.", "duration_minutes": 5},
        ],
        "nutrition": {"calories": 520, "protein": 42, "carbs": 58, "fat": 12, "fiber": 6, "sodium": 680, "sugar": 8},
    },
    {
        "name": "Méchoui",
        "description": "Traditional Mauritanian slow-roasted lamb, seasoned with cumin and coriander, cooked until the meat falls off the bone.",
        "image_url": "https://images.unsplash.com/photo-1514516345957-556ca7d90a29?w=800",
        "cuisine": "Mauritanian",
        "prep_time": 45,
        "cook_time": 180,
        "servings": 8,
        "calories": 680,
        "tags": ["Protein-Rich", "Low-Carb", "Traditional"],
        "ingredients": [
            "1 whole lamb shoulder (about 5 lbs)",
            "1/4 cup olive oil",
            "4 cloves garlic, minced",
            "2 tbsp ground cumin",
            "1 tbsp ground coriander",
            "1 tsp paprika",
            "Salt and black pepper",
            "Fresh mint for garnish",
        ],
        "difficulty": "Advanced",
        "chef_name": "Chef Hassan",
        "rating": 4.9,
        "review_count": 89,
        "steps": [
            {"step_number": 1, "instruction": "Mix olive oil with garlic, cumin, coriander, paprika, salt, and pepper to create a marinade.", "duration_minutes": 10},
            {"step_number": 2, "instruction": "Score the lamb shoulder and rub the marinade all over, including into the cuts. Let marinate for at least 2 hours or overnight.", "duration_minutes": 120},
            {"step_number": 3, "instruction": "Preheat oven to 325°F (165°C). Place lamb in a large roasting pan with 1 cup water at the bottom.", "duration_minutes": 5},
            {"step_number": 4, "instruction": "Cover tightly with foil and roast for 3 hours, basting every 45 minutes.", "duration_minutes": 180},
            {"step_number": 5, "instruction": "Remove foil for the last 30 minutes to brown the exterior. The meat should be falling off the bone.", "duration_minutes": 30},
            {"step_number": 6, "instruction": "Let rest for 15 minutes before serving. Garnish with fresh mint.", "duration_minutes": 15},
        ],
        "nutrition": {"calories": 680, "protein": 58, "carbs": 2, "fat": 48, "fiber": 0, "sodium": 520, "sugar": 0},
    },
    {
        "name": "Couscous Royal",
        "description": "A festive North African dish featuring fluffy couscous topped with lamb, chicken, merguez sausage, and seven vegetables.",
        "image_url": "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=800",
        "cuisine": "MENA",
        "prep_time": 40,
        "cook_time": 90,
        "servings": 8,
        "calories": 620,
        "tags": ["Heart Healthy", "Balanced", "Traditional"],
        "ingredients": [
            "500g couscous",
            "500g lamb shoulder, cubed",
            "4 chicken thighs",
            "4 merguez sausages",
            "2 carrots, large chunks",
            "2 zucchini, large chunks",
            "1 turnip, quartered",
            "1 can chickpeas, drained",
            "1 onion, quartered",
            "2 tbsp ras el hanout",
            "Fresh cilantro",
        ],
        "difficulty": "Intermediate",
        "chef_name": "Chef Fatima",
        "rating": 4.7,
        "review_count": 234,
        "steps": [
            {"step_number": 1, "instruction": "In a large pot or couscoussier, brown the lamb cubes in olive oil. Add onion and cook until soft.", "duration_minutes": 15},
            {"step_number": 2, "instruction": "Add ras el hanout and stir for 1 minute. Pour in 8 cups of water and bring to a boil.", "duration_minutes": 5},
            {"step_number": 3, "instruction": "Add chicken thighs and simmer for 30 minutes. Add harder vegetables (carrots, turnip) first.", "duration_minutes": 35},
            {"step_number": 4, "instruction": "Add zucchini and chickpeas. In a separate pan, grill the merguez sausages.", "duration_minutes": 20},
            {"step_number": 5, "instruction": "Prepare couscous according to package, fluffing with fork. Season with butter and a ladle of broth.", "duration_minutes": 10},
            {"step_number": 6, "instruction": "Mound couscous on a large platter. Arrange meats and vegetables on top. Serve with broth on the side.", "duration_minutes": 5},
        ],
        "nutrition": {"calories": 620, "protein": 45, "carbs": 52, "fat": 26, "fiber": 8, "sodium": 890, "sugar": 6},
    },
    {
        "name": "Shakshuka",
        "description": "A vibrant Middle Eastern breakfast of eggs poached in spiced tomato and pepper sauce, perfect for any time of day.",
        "image_url": "https://images.unsplash.com/photo-1590947132387-155cc02f3212?w=800",
        "cuisine": "MENA",
        "prep_time": 10,
        "cook_time": 25,
        "servings": 4,
        "calories": 285,
        "tags": ["Quick Meal", "Vegetarian", "Diabetes-Friendly"],
        "ingredients": [
            "6 large eggs",
            "2 cans diced tomatoes",
            "2 red bell peppers, diced",
            "1 onion, diced",
            "4 cloves garlic, minced",
            "2 tsp cumin",
            "1 tsp paprika",
            "1/2 tsp cayenne pepper",
            "Fresh parsley",
            "Crusty bread for serving",
        ],
        "difficulty": "Easy",
        "chef_name": "Chef Leila",
        "rating": 4.6,
        "review_count": 312,
        "steps": [
            {"step_number": 1, "instruction": "Heat olive oil in a large skillet over medium heat. Sauté onion and peppers until softened, about 8 minutes.", "duration_minutes": 8},
            {"step_number": 2, "instruction": "Add garlic, cumin, paprika, and cayenne. Cook for 1 minute until fragrant.", "duration_minutes": 2},
            {"step_number": 3, "instruction": "Pour in the diced tomatoes with their juice. Simmer for 10 minutes until slightly thickened.", "duration_minutes": 10},
            {"step_number": 4, "instruction": "Make 6 wells in the sauce and crack an egg into each well.", "duration_minutes": 2},
            {"step_number": 5, "instruction": "Cover and cook on low heat for 5-8 minutes until egg whites are set but yolks remain runny.", "duration_minutes": 8, "tip": "Check eggs frequently to avoid overcooking"},
            {"step_number": 6, "instruction": "Sprinkle with fresh parsley and serve immediately with crusty bread.", "duration_minutes": 1},
        ],
        "nutrition": {"calories": 285, "protein": 16, "carbs": 18, "fat": 18, "fiber": 4, "sodium": 420, "sugar": 10},
    },
    {
        "name": "Maafe",
        "description": "A hearty West African peanut stew with tender beef, sweet potatoes, and a rich, creamy groundnut sauce.",
        "image_url": "https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800",
        "cuisine": "Mauritanian",
        "prep_time": 20,
        "cook_time": 60,
        "servings": 6,
        "calories": 485,
        "tags": ["Protein-Rich", "Iron-Rich", "Traditional"],
        "ingredients": [
            "1.5 lbs beef stew meat, cubed",
            "1 cup natural peanut butter",
            "2 sweet potatoes, cubed",
            "2 tomatoes, diced",
            "1 onion, diced",
            "3 cloves garlic, minced",
            "1 inch ginger, grated",
            "2 cups beef broth",
            "2 tbsp tomato paste",
            "Salt and pepper",
            "Rice for serving",
        ],
        "difficulty": "Intermediate",
        "chef_name": "Chef Oumar",
        "rating": 4.7,
        "review_count": 178,
        "steps": [
            {"step_number": 1, "instruction": "Season beef with salt and pepper. Brown in batches in a large pot with oil. Set aside.", "duration_minutes": 12},
            {"step_number": 2, "instruction": "Sauté onion, garlic, and ginger in the same pot until fragrant, about 3 minutes.", "duration_minutes": 5},
            {"step_number": 3, "instruction": "Add tomatoes and tomato paste. Cook for 5 minutes.", "duration_minutes": 5},
            {"step_number": 4, "instruction": "Whisk peanut butter with beef broth until smooth. Add to pot with the beef.", "duration_minutes": 5},
            {"step_number": 5, "instruction": "Simmer covered for 30 minutes. Add sweet potatoes and cook another 20 minutes until tender.", "duration_minutes": 50},
            {"step_number": 6, "instruction": "Adjust seasoning and serve hot over steamed rice.", "duration_minutes": 3},
        ],
        "nutrition": {"calories": 485, "protein": 32, "carbs": 28, "fat": 28, "fiber": 5, "sodium": 580, "sugar": 8},
    },
    {
        "name": "Hummus",
        "description": "Creamy, smooth chickpea dip with tahini, lemon, and garlic. A MENA staple perfect for sharing.",
        "image_url": "https://images.unsplash.com/photo-1577805947697-89e18249d767?w=800",
        "cuisine": "MENA",
        "prep_time": 15,
        "cook_time": 0,
        "servings": 6,
        "calories": 165,
        "tags": ["Quick Meal", "Vegan", "Heart Healthy"],
        "ingredients": [
            "2 cans chickpeas, drained (reserve liquid)",
            "1/3 cup tahini",
            "1/4 cup lemon juice",
            "2 cloves garlic",
            "1/2 tsp cumin",
            "3 tbsp olive oil",
            "Salt to taste",
            "Paprika and olive oil for garnish",
            "Pita bread for serving",
        ],
        "difficulty": "Easy",
        "chef_name": "Chef Mariam",
        "rating": 4.5,
        "review_count": 445,
        "steps": [
            {"step_number": 1, "instruction": "Add tahini and lemon juice to a food processor. Blend for 1 minute until light and creamy.", "duration_minutes": 2},
            {"step_number": 2, "instruction": "Add garlic, cumin, and salt. Blend for 30 seconds.", "duration_minutes": 1},
            {"step_number": 3, "instruction": "Add half the chickpeas and blend. Scrape down sides and add remaining chickpeas.", "duration_minutes": 2},
            {"step_number": 4, "instruction": "With processor running, slowly drizzle in 2-3 tbsp of reserved chickpea liquid until smooth.", "duration_minutes": 3, "tip": "Add more liquid for a thinner consistency"},
            {"step_number": 5, "instruction": "Taste and adjust salt and lemon as needed.", "duration_minutes": 1},
            {"step_number": 6, "instruction": "Transfer to bowl, create a well, drizzle with olive oil and sprinkle paprika. Serve with warm pita.", "duration_minutes": 2},
        ],
        "nutrition": {"calories": 165, "protein": 6, "carbs": 14, "fat": 10, "fiber": 4, "sodium": 280, "sugar": 2},
    },
    {
        "name": "Falafel",
        "description": "Crispy, herb-packed chickpea fritters - a beloved street food throughout the Middle East.",
        "image_url": "https://images.unsplash.com/photo-1593001874117-c99c800e3eb7?w=800",
        "cuisine": "MENA",
        "prep_time": 20,
        "cook_time": 15,
        "servings": 6,
        "calories": 290,
        "tags": ["Vegan", "Protein-Rich", "Quick Meal"],
        "ingredients": [
            "2 cups dried chickpeas, soaked overnight",
            "1 onion, quartered",
            "4 cloves garlic",
            "1 cup fresh parsley",
            "1/2 cup fresh cilantro",
            "1 tsp cumin",
            "1/2 tsp cayenne",
            "1 tsp baking powder",
            "Oil for frying",
            "Pita, tahini, pickled vegetables for serving",
        ],
        "difficulty": "Intermediate",
        "chef_name": "Chef Youssef",
        "rating": 4.8,
        "review_count": 289,
        "steps": [
            {"step_number": 1, "instruction": "Drain soaked chickpeas thoroughly. Pat dry with paper towels.", "duration_minutes": 5, "tip": "Never use canned chickpeas - they're too wet"},
            {"step_number": 2, "instruction": "Add chickpeas, onion, garlic, and herbs to food processor. Pulse until finely ground but not pureed.", "duration_minutes": 5},
            {"step_number": 3, "instruction": "Transfer to bowl, add spices, salt, and baking powder. Mix well. Refrigerate 1 hour.", "duration_minutes": 60},
            {"step_number": 4, "instruction": "Heat oil to 350°F (175°C). Form mixture into small patties or balls.", "duration_minutes": 10},
            {"step_number": 5, "instruction": "Fry in batches for 3-4 minutes until deep golden brown. Drain on paper towels.", "duration_minutes": 15},
            {"step_number": 6, "instruction": "Serve immediately in pita with tahini, pickled turnips, and fresh vegetables.", "duration_minutes": 2},
        ],
        "nutrition": {"calories": 290, "protein": 12, "carbs": 32, "fat": 14, "fiber": 8, "sodium": 320, "sugar": 4},
    },
    {
        "name": "Thiakry",
        "description": "A refreshing Mauritanian dessert made with couscous, yogurt, and dried fruits - perfect for hot days.",
        "image_url": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800",
        "cuisine": "Mauritanian",
        "prep_time": 15,
        "cook_time": 10,
        "servings": 6,
        "calories": 245,
        "tags": ["Quick Meal", "Vegetarian", "Diabetes-Friendly"],
        "ingredients": [
            "2 cups fine couscous",
            "2 cups plain yogurt",
            "1 cup sweetened condensed milk",
            "1/2 cup raisins",
            "1/4 cup dried dates, chopped",
            "1/2 tsp vanilla extract",
            "1/4 tsp nutmeg",
            "Fresh mint for garnish",
        ],
        "difficulty": "Easy",
        "chef_name": "Chef Aissata",
        "rating": 4.4,
        "review_count": 98,
        "steps": [
            {"step_number": 1, "instruction": "Prepare couscous according to package directions. Fluff with fork and let cool to room temperature.", "duration_minutes": 10},
            {"step_number": 2, "instruction": "In a large bowl, whisk together yogurt, condensed milk, vanilla, and nutmeg.", "duration_minutes": 3},
            {"step_number": 3, "instruction": "Add cooled couscous to the yogurt mixture. Stir until well combined.", "duration_minutes": 3},
            {"step_number": 4, "instruction": "Fold in raisins and dates.", "duration_minutes": 2},
            {"step_number": 5, "instruction": "Refrigerate for at least 1 hour or until well chilled.", "duration_minutes": 60},
            {"step_number": 6, "instruction": "Serve in individual bowls, garnished with fresh mint leaves.", "duration_minutes": 2},
        ],
        "nutrition": {"calories": 245, "protein": 8, "carbs": 42, "fat": 6, "fiber": 2, "sodium": 95, "sugar": 24},
    },
    {
        "name": "Lamb Tagine",
        "description": "Slow-cooked Moroccan lamb with apricots, almonds, and warm spices in a traditional clay pot.",
        "image_url": "https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=800",
        "cuisine": "MENA",
        "prep_time": 25,
        "cook_time": 120,
        "servings": 6,
        "calories": 520,
        "tags": ["Heart Healthy", "Iron-Rich", "Traditional"],
        "ingredients": [
            "2 lbs lamb shoulder, cubed",
            "1 cup dried apricots",
            "1/2 cup blanched almonds",
            "2 onions, sliced",
            "3 cloves garlic, minced",
            "2 tsp ras el hanout",
            "1 tsp cinnamon",
            "1 tsp ginger",
            "2 tbsp honey",
            "Fresh cilantro",
            "Couscous for serving",
        ],
        "difficulty": "Intermediate",
        "chef_name": "Chef Karima",
        "rating": 4.9,
        "review_count": 267,
        "steps": [
            {"step_number": 1, "instruction": "Season lamb with ras el hanout, cinnamon, ginger, salt, and pepper. Let marinate 30 minutes.", "duration_minutes": 35},
            {"step_number": 2, "instruction": "Brown lamb in batches in the tagine base or heavy pot. Set aside.", "duration_minutes": 12},
            {"step_number": 3, "instruction": "Cook onions until caramelized, about 15 minutes. Add garlic and cook 1 minute more.", "duration_minutes": 16},
            {"step_number": 4, "instruction": "Return lamb to pot with 2 cups water. Cover and simmer on low for 1.5 hours.", "duration_minutes": 90},
            {"step_number": 5, "instruction": "Add apricots, almonds, and honey. Cook 30 minutes more until lamb is tender.", "duration_minutes": 30},
            {"step_number": 6, "instruction": "Garnish with cilantro and serve over fluffy couscous.", "duration_minutes": 3},
        ],
        "nutrition": {"calories": 520, "protein": 38, "carbs": 32, "fat": 28, "fiber": 4, "sodium": 420, "sugar": 22},
    },
    {
        "name": "Tabbouleh",
        "description": "Fresh Lebanese parsley salad with bulgur, tomatoes, mint, and a bright lemon dressing.",
        "image_url": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800",
        "cuisine": "MENA",
        "prep_time": 20,
        "cook_time": 0,
        "servings": 6,
        "calories": 145,
        "tags": ["Vegan", "Quick Meal", "Low-Calorie", "Heart Healthy"],
        "ingredients": [
            "3 bunches fresh parsley, finely chopped",
            "1/2 cup fine bulgur",
            "3 tomatoes, finely diced",
            "1 bunch fresh mint, chopped",
            "4 green onions, sliced",
            "1/3 cup extra virgin olive oil",
            "1/4 cup fresh lemon juice",
            "Salt and pepper",
            "Romaine lettuce leaves for serving",
        ],
        "difficulty": "Easy",
        "chef_name": "Chef Nadia",
        "rating": 4.5,
        "review_count": 198,
        "steps": [
            {"step_number": 1, "instruction": "Soak bulgur in hot water for 15 minutes. Drain and squeeze out excess water.", "duration_minutes": 18},
            {"step_number": 2, "instruction": "Finely chop the parsley - it should be the star of the dish, not the bulgur.", "duration_minutes": 10, "tip": "Use a sharp knife; food processor makes it mushy"},
            {"step_number": 3, "instruction": "Combine bulgur, parsley, mint, tomatoes, and green onions in a large bowl.", "duration_minutes": 3},
            {"step_number": 4, "instruction": "Whisk together olive oil, lemon juice, salt, and pepper.", "duration_minutes": 2},
            {"step_number": 5, "instruction": "Pour dressing over salad and toss gently to combine.", "duration_minutes": 2},
            {"step_number": 6, "instruction": "Let sit 15 minutes for flavors to meld. Serve with romaine leaves for scooping.", "duration_minutes": 15},
        ],
        "nutrition": {"calories": 145, "protein": 3, "carbs": 14, "fat": 10, "fiber": 4, "sodium": 180, "sugar": 2},
    },
]


def seed_database():
    """Seed the database with initial recipes."""
    db = SessionLocal()
    
    try:
        # Check if recipes already exist
        existing_count = db.query(Recipe).count()
        if existing_count > 0:
            print(f"Database already has {existing_count} recipes. Skipping seed.")
            return
        
        print("Seeding database with recipes...")
        
        for recipe_data in RECIPES:
            # Extract nested data
            steps_data = recipe_data.pop("steps", [])
            nutrition_data = recipe_data.pop("nutrition", None)
            
            # Create recipe
            recipe = Recipe(**recipe_data)
            db.add(recipe)
            db.flush()  # Get the recipe ID
            
            # Add steps
            for step_data in steps_data:
                step = RecipeStep(recipe_id=recipe.id, **step_data)
                db.add(step)
            
            # Add nutrition
            if nutrition_data:
                nutrition = NutritionInfo(recipe_id=recipe.id, **nutrition_data)
                db.add(nutrition)
            
            print(f"  ✓ Added: {recipe.name}")
        
        db.commit()
        print(f"\n✅ Successfully seeded {len(RECIPES)} recipes!")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
