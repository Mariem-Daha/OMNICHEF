"""
Function Registry for Cuisinee AI Assistant
Handles function calling for Gemini Live API - all tools the AI can use.
"""

from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, func, desc
import logging

# Database models
from ..models.recipe import Recipe, RecipeStep, NutritionInfo

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# Helper: serialize a Recipe ORM object → dict for the AI
# ─────────────────────────────────────────────────────────────────────────────

def _recipe_to_dict(r: Recipe, include_steps: bool = False) -> Dict[str, Any]:
    d = {
        "id": str(r.id),
        "name": r.name,
        "description": r.description or "A delicious recipe.",
        "image_url": r.image_url or "",
        "cuisine": r.cuisine or "",
        "prep_time": r.prep_time or 0,
        "cook_time": r.cook_time or 0,
        "total_time": (r.prep_time or 0) + (r.cook_time or 0),
        "servings": r.servings or 4,
        "calories": r.calories or 0,
        "difficulty": r.difficulty or "Medium",
        "rating": float(r.rating) if r.rating else 4.5,
        "tags": r.tags or [],
        "ingredients": r.ingredients or [],
    }
    if include_steps and r.steps:
        d["steps"] = [
            {
                "step_number": s.step_number,
                "instruction": s.instruction,
                "duration_minutes": s.duration_minutes,
                "tip": s.tip,
            }
            for s in sorted(r.steps, key=lambda s: s.step_number)
        ]
    return d


# ─────────────────────────────────────────────────────────────────────────────
# Tool 1 – find_recipe
# ─────────────────────────────────────────────────────────────────────────────

async def find_recipe(query: str, db: Session = None) -> Dict[str, Any]:
    """Search recipes by name, description, ingredient, or cuisine keyword."""
    if not db:
        return {"success": False, "error": "Database unavailable"}
    try:
        # Split query into words to match multiple ingredients (e.g. "carrots chicken")
        import re
        words = [w.strip() for w in re.split(r'[\s,]+', query.lower()) if w.strip()]
        
        if not words:
            words = [query.lower()]

        filters = []
        for word in words:
            term = f"%{word}%"
            filters.append(
                or_(
                    func.lower(Recipe.name).like(term),
                    func.lower(Recipe.description).like(term),
                    func.lower(Recipe.cuisine).like(term),
                    # We can also check tags or ingredients if they are text arrays, 
                    # but name/description are heavily weighted.
                )
            )
            
        from sqlalchemy import and_
        recipes = db.query(Recipe).filter(and_(*filters)).order_by(desc(Recipe.rating)).limit(6).all()

        if not recipes:
            # Fallback: return popular recipes so the AI always has something to show
            fallback = db.query(Recipe).order_by(desc(Recipe.rating)).limit(6).all()
            return {
                "success": True,
                "message": f"No exact match for '{query}', but here are some popular alternatives you might love!",
                "recipes": [_recipe_to_dict(r) for r in fallback],
                "is_fallback": True,
            }
        return {
            "success": True,
            "message": f"Found {len(recipes)} recipe(s) for '{query}'.",
            "recipes": [_recipe_to_dict(r) for r in recipes],
        }
    except Exception as e:
        logger.error(f"find_recipe error: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# Tool 2 – get_popular_recipes
# ─────────────────────────────────────────────────────────────────────────────

async def get_popular_recipes(db: Session = None) -> Dict[str, Any]:
    """Return the top-rated recipes from the database."""
    if not db:
        return {"success": False, "error": "Database unavailable"}
    try:
        recipes = db.query(Recipe).order_by(
            desc(Recipe.rating), desc(Recipe.review_count)
        ).limit(6).all()

        return {
            "success": True,
            "message": f"Here are {len(recipes)} popular recipes.",
            "recipes": [_recipe_to_dict(r) for r in recipes],
        }
    except Exception as e:
        logger.error(f"get_popular_recipes error: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# Tool 3 – get_recipes_by_category
# ─────────────────────────────────────────────────────────────────────────────

async def get_recipes_by_category(category: str, db: Session = None) -> Dict[str, Any]:
    """Return recipes filtered by cuisine / category (e.g. 'Mauritanian', 'MENA', 'Moroccan')."""
    if not db:
        return {"success": False, "error": "Database unavailable"}
    try:
        term = f"%{category.lower()}%"
        recipes = db.query(Recipe).filter(
            or_(
                func.lower(Recipe.cuisine).like(term),
                func.lower(Recipe.name).like(term),
            )
        ).order_by(desc(Recipe.rating)).limit(6).all()

        if not recipes:
            # Fallback: return popular recipes so the AI always has something to show
            fallback = db.query(Recipe).order_by(desc(Recipe.rating)).limit(6).all()
            return {
                "success": True,
                "message": f"No exact match for category '{category}', but here are some popular recipes you'll enjoy!",
                "recipes": [_recipe_to_dict(r) for r in fallback],
                "is_fallback": True,
            }
        return {
            "success": True,
            "message": f"Found {len(recipes)} recipe(s) in '{category}'.",
            "recipes": [_recipe_to_dict(r) for r in recipes],
        }
    except Exception as e:
        logger.error(f"get_recipes_by_category error: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# Tool 4 – get_recipe_details
# ─────────────────────────────────────────────────────────────────────────────

async def get_recipe_details(recipe_id: str, db: Session = None) -> Dict[str, Any]:
    """Get full recipe details including all steps and ingredients by recipe ID."""
    if not db:
        return {"success": False, "error": "Database unavailable"}
    try:
        recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
        if not recipe:
            return {"success": False, "error": f"Recipe '{recipe_id}' not found."}
        return {
            "success": True,
            "recipe": _recipe_to_dict(recipe, include_steps=True),
        }
    except Exception as e:
        logger.error(f"get_recipe_details error: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# Tool 5 – set_timer
# ─────────────────────────────────────────────────────────────────────────────

async def set_timer(minutes) -> Dict[str, Any]:
    """Set a cooking countdown timer for a given number of minutes."""
    try:
        minutes = int(round(float(minutes)))
        return {
            "success": True,
            "message": f"Timer set for {minutes} minute{'s' if minutes != 1 else ''}.",
            "timer": {
                "minutes": minutes,
                "seconds": minutes * 60,
            },
        }
    except Exception as e:
        logger.error(f"set_timer error: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# Tool 6 – advance_cooking_step
# ─────────────────────────────────────────────────────────────────────────────

async def advance_cooking_step() -> Dict[str, Any]:
    """Advance the on-screen cooking guide to the next step."""
    return {
        "success": True,
        "action": "next_step",
        "message": "Moving to next step.",
    }


# ─────────────────────────────────────────────────────────────────────────────
# Tool 7 – start_step_timer
# ─────────────────────────────────────────────────────────────────────────────

async def start_step_timer(minutes) -> Dict[str, Any]:
    """Start the inline countdown timer for the current cooking step."""
    try:
        minutes = int(round(float(minutes)))
        return {
            "success": True,
            "message": f"Step timer started for {minutes} minute{'s' if minutes != 1 else ''}.",
            "timer": {
                "minutes": minutes,
                "seconds": minutes * 60,
            },
        }
    except Exception as e:
        logger.error(f"start_step_timer error: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# Registry class
# ─────────────────────────────────────────────────────────────────────────────

class FunctionRegistry:
    """Registry of available tool/function declarations for Gemini Live."""

    @staticmethod
    def get_tools_schema():
        """Return a list[types.Tool] for LiveConnectConfig.tools (google-genai SDK v1.x)."""
        from google.genai import types as _t

        def _schema(type_: str, props: dict = None, required: list = None) -> _t.Schema:
            kwargs: dict = {"type": type_}
            if props:
                kwargs["properties"] = {
                    k: _t.Schema(**v) for k, v in props.items()
                }
            if required:
                kwargs["required"] = required
            return _t.Schema(**kwargs)

        return [
            _t.Tool(
                function_declarations=[
                    _t.FunctionDeclaration(
                        name="find_recipe",
                        description=(
                            "Search the database for recipes matching a name, ingredient, "
                            "cuisine, or cooking style. Use whenever the user asks about "
                            "a specific dish or ingredient."
                        ),
                        parameters=_schema(
                            "OBJECT",
                            props={"query": {"type": "STRING", "description": "The search term: recipe name, ingredient, or cuisine keyword."}},
                            required=["query"],
                        ),
                    ),
                    _t.FunctionDeclaration(
                        name="get_popular_recipes",
                        description=(
                            "Return the top-rated recipes from the database. Use when the user "
                            "asks for recommendations, says 'surprise me', 'what's popular', "
                            "or any open-ended recipe question."
                        ),
                        parameters=_schema("OBJECT"),
                    ),
                    _t.FunctionDeclaration(
                        name="get_recipes_by_category",
                        description=(
                            "Return recipes filtered by cuisine or category, e.g. 'Mauritanian', "
                            "'Moroccan', 'MENA', 'African'. Use when the user asks for a type "
                            "of cuisine rather than a specific dish."
                        ),
                        parameters=_schema(
                            "OBJECT",
                            props={"category": {"type": "STRING", "description": "Cuisine or food category to filter by."}},
                            required=["category"],
                        ),
                    ),
                    _t.FunctionDeclaration(
                        name="get_recipe_details",
                        description=(
                            "Get the full details of a recipe including all cooking steps and "
                            "ingredient list. Use when the user asks 'how do I make it?', "
                            "'what are the ingredients?', or 'tell me more about that recipe'."
                        ),
                        parameters=_schema(
                            "OBJECT",
                            props={"recipe_id": {"type": "STRING", "description": "The UUID of the recipe to retrieve."}},
                            required=["recipe_id"],
                        ),
                    ),
                    _t.FunctionDeclaration(
                        name="set_timer",
                        description=(
                            "Start a cooking countdown timer. Call immediately whenever the "
                            "user mentions a duration: '20 minutes', 'half an hour', etc."
                        ),
                        parameters=_schema(
                            "OBJECT",
                            props={"minutes": {"type": "INTEGER", "description": "Duration of the timer in minutes."}},
                            required=["minutes"],
                        ),
                    ),
                    _t.FunctionDeclaration(
                        name="advance_cooking_step",
                        description=(
                            "Advance the on-screen step-by-step cooking guide to the next step. "
                            "Call this when the user says 'next', 'next step', 'I\'m ready', "
                            "'done', 'continue', 'move on', 'go ahead', 'okay I did that', "
                            "'finished', or anything indicating they have completed the current step. "
                            "Also call it whenever the user asks if they need to press a button — "
                            "respond that you\'ll handle it, then call this function."
                        ),
                        parameters=_schema("OBJECT"),
                    ),                    _t.FunctionDeclaration(
                        name="start_step_timer",
                        description=(
                            "Start the on-screen countdown timer for the current cooking step. "
                            "Call this AFTER you finish narrating a step that includes a cooking duration. "
                            "CRITICAL: Use the EXACT minutes value stated in the step instruction text \u2014 "
                            "NOT the duration_minutes field if it contradicts the text, and NEVER default "
                            "to 6 minutes or any arbitrary value. If the step says '8-10 minutes', "
                            "use 9 (the midpoint). If unsure, ask the user before starting."
                        ),
                        parameters=_schema(
                            "OBJECT",
                            props={"minutes": {"type": "INTEGER", "description": "Timer duration in minutes, derived from the step instruction text."}},
                            required=["minutes"],
                        ),
                    ),                ]
            )
        ]

    @staticmethod
    def get_callable_functions(db: Session) -> Dict[str, Any]:
        """Return a dict of async-callable functions, each bound to the current DB session."""
        return {
            "find_recipe": lambda **kw: find_recipe(db=db, **kw),
            "get_popular_recipes": lambda **kw: get_popular_recipes(db=db, **kw),
            "get_recipes_by_category": lambda **kw: get_recipes_by_category(db=db, **kw),
            "get_recipe_details": lambda **kw: get_recipe_details(db=db, **kw),
            "set_timer": lambda **kw: set_timer(**kw),
            "advance_cooking_step": lambda **kw: advance_cooking_step(**kw),
            "start_step_timer": lambda **kw: start_step_timer(**kw),
        }
