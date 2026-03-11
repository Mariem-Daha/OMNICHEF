"""Recipe API endpoints."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, or_, cast
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy import String

from ..database import get_db
from ..models.recipe import Recipe, RecipeStep, NutritionInfo
from ..models.user import User, SavedRecipe
from ..schemas.recipe import RecipeResponse, RecipeListResponse, RecipeCreate
from ..services.auth_service import get_current_user

router = APIRouter()


def recipe_to_response(recipe: Recipe, user: User | None = None) -> RecipeResponse:
    """Convert Recipe model to response schema with is_saved flag."""
    is_saved = False
    if user:
        is_saved = any(sr.recipe_id == recipe.id for sr in user.saved_recipes)
    
    return RecipeResponse(
        id=recipe.id,
        name=recipe.name,
        description=recipe.description,
        image_url=recipe.image_url,
        cuisine=recipe.cuisine,
        prep_time=recipe.prep_time,
        cook_time=recipe.cook_time,
        servings=recipe.servings,
        calories=recipe.calories,
        tags=recipe.tags or [],
        ingredients=recipe.ingredients or [],
        difficulty=recipe.difficulty,
        chef_name=recipe.chef_name,
        rating=recipe.rating,
        review_count=recipe.review_count,
        created_at=recipe.created_at,
        steps=[{
            "step_number": s.step_number,
            "instruction": s.instruction,
            "duration_minutes": s.duration_minutes,
            "tip": s.tip,
        } for s in recipe.steps],
        nutrition={
            "calories": recipe.nutrition.calories,
            "protein": recipe.nutrition.protein,
            "carbs": recipe.nutrition.carbs,
            "fat": recipe.nutrition.fat,
            "fiber": recipe.nutrition.fiber,
            "sodium": recipe.nutrition.sodium,
            "sugar": recipe.nutrition.sugar,
        } if recipe.nutrition else None,
        is_saved=is_saved,
    )


@router.get("", response_model=RecipeListResponse)
def list_recipes(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user),
):
    """Get paginated list of all recipes."""
    mauritanian_cuisines = ['mauritania', 'mauritanian']
    
    total = (
        db.query(func.count(Recipe.id))
        .filter(func.lower(Recipe.cuisine).notin_(mauritanian_cuisines))
        .scalar()
    )
    
    recipes = (
        db.query(Recipe)
        .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
        .filter(func.lower(Recipe.cuisine).notin_(mauritanian_cuisines))
        .order_by(Recipe.created_at.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    
    return RecipeListResponse(
        recipes=[recipe_to_response(r, current_user) for r in recipes],
        total=total,
        page=page,
        per_page=per_page,
        pages=(total + per_page - 1) // per_page,
    )


@router.get("/search", response_model=list[RecipeResponse])
def search_recipes(
    q: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user),
):
    """Search recipes by name or description."""
    search_term = f"%{q.lower()}%"
    
    recipes = (
        db.query(Recipe)
        .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
        .filter(
            or_(
                func.lower(Recipe.name).like(search_term),
                func.lower(Recipe.description).like(search_term),
            )
        )
        .limit(50)
        .all()
    )
    
    return [recipe_to_response(r, current_user) for r in recipes]


@router.get("/cuisine/{cuisine}", response_model=list[RecipeResponse])
def get_recipes_by_cuisine(
    cuisine: str,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user),
):
    """Get recipes filtered by cuisine type."""
    query = db.query(Recipe).options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))

    if cuisine.lower() == 'mauritanian':
        recipes = query.filter(
            func.lower(Recipe.cuisine).in_(['mauritanian', 'mauritania'])
        ).all()
    elif cuisine.lower() == 'mena':
        recipes = query.filter(
            func.lower(Recipe.cuisine).in_([
                'mena', 'middle eastern', 'arabic', 'arabian', 
                'moroccan', 'algerian', 'tunisian', 'egyptian', 
                'libyan', 'lebanese', 'syrian', 'jordanian', 'palestinian', 
                'yemeni', 'saudi', 'kuwaiti', 'qatari', 'bahraini', 'omani', 'emirati'
            ])
        ).all()
    else:
        recipes = query.filter(func.lower(Recipe.cuisine) == cuisine.lower()).all()

    return [recipe_to_response(r, current_user) for r in recipes]


@router.get("/tags", response_model=list[RecipeResponse])
def get_recipes_by_tags(
    tags: list[str] = Query(...),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user),
):
    """Get recipes that have any of the specified health tags."""
    # Get all recipes and filter in Python (more compatible approach)
    all_recipes = (
        db.query(Recipe)
        .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
        .all()
    )
    
    # Filter recipes that have any of the specified tags
    tags_lower = [t.lower() for t in tags]
    matching_recipes = [
        r for r in all_recipes
        if r.tags and any(tag.lower() in tags_lower for tag in r.tags)
    ]
    
    return [recipe_to_response(r, current_user) for r in matching_recipes]


@router.get("/leftovers", response_model=list[RecipeResponse])
def get_recipes_by_ingredients(
    ingredients: list[str] = Query(...),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user),
):
    """Find recipes that can be made with given ingredients."""
    # Get all recipes
    all_recipes = (
        db.query(Recipe)
        .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
        .all()
    )
    
    # Filter recipes by ingredient matching
    matching_recipes = []
    ingredients_lower = [i.lower() for i in ingredients]
    
    for recipe in all_recipes:
        if not recipe.ingredients:
            continue
        
        # Count matching ingredients
        recipe_ingredients_lower = [i.lower() for i in recipe.ingredients]
        matches = sum(
            1 for user_ing in ingredients_lower
            if any(user_ing in recipe_ing for recipe_ing in recipe_ingredients_lower)
        )
        
        # Include if at least 2 ingredients match
        if matches >= min(2, len(ingredients_lower)):
            matching_recipes.append((recipe, matches))
    
    # Sort by number of matches (descending)
    matching_recipes.sort(key=lambda x: x[1], reverse=True)
    
    return [recipe_to_response(r, current_user) for r, _ in matching_recipes[:20]]


@router.get("/{recipe_id}", response_model=RecipeResponse)
def get_recipe(
    recipe_id: UUID,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user),
):
    """Get a single recipe by ID."""
    recipe = (
        db.query(Recipe)
        .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
        .filter(Recipe.id == recipe_id)
        .first()
    )
    
    if not recipe:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recipe not found",
        )
    
    return recipe_to_response(recipe, current_user)
