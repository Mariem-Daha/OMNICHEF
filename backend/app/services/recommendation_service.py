"""Recommendation service – scores and ranks recipes based on user preferences."""

from __future__ import annotations

from typing import Optional
from sqlalchemy.orm import Session, joinedload

from ..models.recipe import Recipe


# ── Preference term → recipe tag mappings ─────────────────────────────────────
# Health goals from the onboarding quiz
_HEALTH_GOAL_TAGS: dict[str, list[str]] = {
    "weight loss":       ["low-calorie", "light", "weight loss", "low fat", "grilled", "salad"],
    "heart health":      ["heart-healthy", "heart health", "low-sodium", "omega-3", "low fat"],
    "diabetic-friendly": ["diabetic", "diabetic-friendly", "low-sugar", "low-carb", "blood sugar"],
    "high protein":      ["high-protein", "protein-rich", "high protein"],
    "low carb":          ["low-carb", "keto", "no grains"],
    "balanced diet":     ["balanced", "nutritious", "healthy", "wholesome"],
}

# Dietary restrictions
_DIETARY_INCLUDE_TAGS: dict[str, list[str]] = {
    "halal":       ["halal"],
    "vegetarian":  ["vegetarian"],
    "vegan":       ["vegan"],
    "gluten-free": ["gluten-free", "gluten free"],
    "dairy-free":  ["dairy-free", "dairy free"],
    "nut-free":    ["nut-free", "nut free"],
    "gluten free": ["gluten-free", "gluten free"],
    "dairy free":  ["dairy-free", "dairy free"],
}

# Strict diets that penalise recipes WITHOUT the matching tag
_STRICT_DIETS = {"vegetarian", "vegan", "gluten-free", "dairy-free", "nut-free",
                 "gluten free", "dairy free"}

# Favourite ingredient labels → keywords matched against recipe ingredient list
_INGREDIENT_KEYWORDS: dict[str, list[str]] = {
    "chicken":        ["chicken"],
    "lamb & beef":    ["lamb", "beef", "mutton", "veal", "goat"],
    "fish & seafood": ["fish", "seafood", "shrimp", "prawn", "salmon", "tuna", "sardine"],
    "legumes":        ["lentil", "chickpea", "fava", "bean", "pea", "hummus"],
    "rice & grains":  ["rice", "couscous", "bulgur", "freekeh", "wheat", "barley"],
    "fresh vegetables": ["vegetable", "zucchini", "eggplant", "tomato", "spinach", "carrot"],
    "eggs":           ["egg"],
    "dairy":          ["yogurt", "labneh", "cheese", "cream", "milk", "butter"],
}


def _tags_lower(recipe: Recipe) -> list[str]:
    return [t.lower() for t in (recipe.tags or [])]


def _ingredients_lower(recipe: Recipe) -> list[str]:
    return [i.lower() for i in (recipe.ingredients or [])]


def _score_recipe(
    recipe: Recipe,
    preferences: list[str],
    allergies: list[str],
    disliked: list[str],
) -> float:
    """
    Score a single recipe against the user's preferences.

    A large negative value means the recipe is hard-excluded (allergy hit).
    Higher positive scores mean better matches.
    """
    score = 0.0
    tags = _tags_lower(recipe)
    ingredients = _ingredients_lower(recipe)
    prefs_lower = [p.lower() for p in preferences]

    # ── Hard exclusion: ingredients matching an allergy ────────────────────
    for allergy in allergies:
        a = allergy.lower()
        if any(a in ing for ing in ingredients):
            return -9999.0

    # ── Positive: preference terms matched against recipe tags ─────────────
    for pref in prefs_lower:
        # Direct tag match
        matched_tag = any(pref in tag or tag in pref for tag in tags)

        # Via health goal → tag mapping
        health_tags = _HEALTH_GOAL_TAGS.get(pref, [])
        matched_health = any(ht in " ".join(tags) for ht in health_tags)

        # Via dietary include mapping
        diet_tags = _DIETARY_INCLUDE_TAGS.get(pref, [])
        matched_diet = any(dt in " ".join(tags) for dt in diet_tags)

        if matched_tag or matched_health or matched_diet:
            score += 25.0

    # ── Positive: preference terms matched against recipe ingredients ──────
    for pref in prefs_lower:
        keywords = _INGREDIENT_KEYWORDS.get(pref, [pref])
        for kw in keywords:
            if any(kw in ing for ing in ingredients):
                score += 15.0
                break

    # ── Soft penalty: strict dietary restrictions not present in tags ──────
    for pref in prefs_lower:
        if pref in _STRICT_DIETS:
            required = _DIETARY_INCLUDE_TAGS.get(pref, [])
            if required and not any(rt in " ".join(tags) for rt in required):
                score -= 20.0

    # ── Negative: disliked ingredients ────────────────────────────────────
    for word in disliked:
        if any(word.lower() in ing for ing in ingredients):
            score -= 30.0

    # ── Tie-break: recipe rating (0–5 mapped to 0–10) ─────────────────────
    score += float(recipe.rating or 4.0) * 2.0

    return score


def get_recommendations(
    db: Session,
    preferences: list[str],
    allergies: list[str],
    disliked: list[str],
    limit: int = 10,
) -> list[Recipe]:
    """
    Return the top *limit* recipes personalised for the given preferences.

    If the user has no preferences at all, return the highest-rated recipes.
    """
    recipes: list[Recipe] = (
        db.query(Recipe)
        .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
        .all()
    )

    has_prefs = bool(preferences or allergies or disliked)

    if not has_prefs:
        # No preferences yet – return top-rated recipes
        sorted_recipes = sorted(
            recipes,
            key=lambda r: float(r.rating or 0),
            reverse=True,
        )
        return sorted_recipes[:limit]

    scored: list[tuple[float, Recipe]] = []
    for recipe in recipes:
        s = _score_recipe(recipe, preferences, allergies, disliked)
        if s > -100:  # Keep everything except hard-excluded
            scored.append((s, recipe))

    scored.sort(key=lambda x: x[0], reverse=True)
    return [r for _, r in scored[:limit]]
