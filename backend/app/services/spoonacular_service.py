"""Spoonacular API integration service for global recipes with full nutrition support."""

import re
import httpx
from typing import Optional
from ..config import get_settings

SPOONACULAR_BASE = "https://api.spoonacular.com"

# Map our app's health tags to Spoonacular diet / intolerance params
HEALTH_FILTER_MAP: dict[str, dict] = {
    "vegetarian":  {"diet": "vegetarian"},
    "vegan":       {"diet": "vegan"},
    "gluten-free": {"intolerances": "gluten"},
    "ketogenic":   {"diet": "ketogenic"},
    "keto":        {"diet": "ketogenic"},
    "paleo":       {"diet": "paleo"},
    "dairy-free":  {"intolerances": "dairy"},
    "low-carb":    {"diet": "low carb"},
    "whole30":     {"diet": "whole30"},
    "pescetarian": {"diet": "pescetarian"},
    "nut-free":    {"intolerances": "tree nut,peanut"},
}


def _strip_html(text: str) -> str:
    """Remove HTML tags and decode basic entities."""
    if not text:
        return ""
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"&amp;", "&", text)
    text = re.sub(r"&lt;", "<", text)
    text = re.sub(r"&gt;", ">", text)
    text = re.sub(r"&nbsp;", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _estimate_difficulty(ready_in: int, step_count: int) -> str:
    if ready_in <= 20 and step_count <= 5:
        return "Easy"
    elif ready_in <= 50 and step_count <= 12:
        return "Medium"
    return "Hard"


def _normalize_recipe(data: dict) -> dict:
    """
    Convert a Spoonacular recipe object into our internal RecipeResponse-compatible dict.
    Works whether nutrition is embedded (complexSearch with addRecipeNutrition=true)
    or nested under 'nutrition' key (information endpoint).
    """
    # ── Nutrition ─────────────────────────────────────────────────────────────
    nutrition_block = data.get("nutrition") or {}
    # complexSearch returns nutrients list directly; information endpoint wraps it
    raw_nutrients = nutrition_block.get("nutrients", [])
    nutrients: dict[str, float] = {}
    for n in raw_nutrients:
        nutrients[n.get("name", "").lower()] = n.get("amount", 0.0)

    def nut(name: str, fallback: float = 0.0) -> float:
        return round(float(nutrients.get(name.lower(), fallback)), 1)

    calories_val = int(nut("calories", data.get("calories", 0)))

    # ── Steps ─────────────────────────────────────────────────────────────────
    steps: list[dict] = []
    for inst in data.get("analyzedInstructions", []):
        for s in inst.get("steps", []):
            steps.append({
                "step_number": s.get("number", len(steps) + 1),
                "instruction": s.get("step", ""),
                "duration_minutes": (
                    s["length"]["number"] if s.get("length") and s["length"].get("unit") == "minutes" else None
                ),
                "tip": None,
            })
    # Fallback: split plain-text instructions on sentences
    if not steps and data.get("instructions"):
        plain = _strip_html(data["instructions"])
        sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", plain) if s.strip()]
        steps = [
            {"step_number": i + 1, "instruction": sent, "duration_minutes": None, "tip": None}
            for i, sent in enumerate(sentences[:20])
        ]

    # ── Ingredients ───────────────────────────────────────────────────────────
    ingredients: list[str] = []
    for ing in data.get("extendedIngredients", []):
        original = ing.get("original") or ing.get("name", "")
        if original:
            ingredients.append(original)

    # ── Cuisine / cuisine ─────────────────────────────────────────────────────
    cuisines = data.get("cuisines", [])
    cuisine = cuisines[0].title() if cuisines else "International"

    # ── Tags (diets + dishTypes) ───────────────────────────────────────────────
    diets = data.get("diets", [])
    dish_types = data.get("dishTypes", [])
    tags = list(dict.fromkeys(diets + dish_types))  # preserve order, deduplicate

    # ── Timing ────────────────────────────────────────────────────────────────
    ready_in = data.get("readyInMinutes", 30) or 30
    prep_time = data.get("preparationMinutes") or max(5, ready_in // 3)
    cook_time = data.get("cookingMinutes") or max(5, ready_in - prep_time)

    # ── Rating ────────────────────────────────────────────────────────────────
    score = data.get("spoonacularScore") or 75.0
    rating = round(min(float(score) / 20.0, 5.0), 1)

    # ── Description ───────────────────────────────────────────────────────────
    raw_summary = data.get("summary", "")
    description = _strip_html(raw_summary)[:600] or data.get("title", "")

    return {
        "id": f"spoon_{data['id']}",
        "name": data.get("title", "Untitled"),
        "description": description,
        "image_url": data.get("image", ""),
        "cuisine": cuisine,
        "prep_time": int(prep_time),
        "cook_time": int(cook_time),
        "servings": data.get("servings", 4),
        "calories": calories_val,
        "tags": tags,
        "ingredients": ingredients,
        "difficulty": _estimate_difficulty(ready_in, len(steps)),
        "chef_name": "Spoonacular",
        "rating": rating,
        "review_count": data.get("aggregateLikes", 0),
        "created_at": None,
        "steps": steps,
        "nutrition": {
            "calories": calories_val,
            "protein": nut("protein"),
            "carbs": nut("carbohydrates"),
            "fat": nut("fat"),
            "fiber": nut("fiber"),
            "sodium": nut("sodium"),
            "sugar": nut("sugar"),
        },
        "is_saved": False,
        "source": "spoonacular",
        "spoonacular_id": data["id"],
    }


class SpoonacularService:
    """HTTP client for Spoonacular's Recipe API."""

    def __init__(self) -> None:
        settings = get_settings()
        self.api_key = settings.spoonacular_api_key

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _get(self, path: str, params: dict) -> dict | list | None:
        params = dict(params)
        params["apiKey"] = self.api_key
        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.get(f"{SPOONACULAR_BASE}{path}", params=params)
                r.raise_for_status()
                return r.json()
        except httpx.HTTPStatusError as exc:
            print(f"[Spoonacular] HTTP {exc.response.status_code} on {path}: {exc.response.text[:200]}")
            return None
        except Exception as exc:
            print(f"[Spoonacular] Error on {path}: {exc}")
            return None

    # ── Public methods ────────────────────────────────────────────────────────

    def search(
        self,
        query: str = "",
        cuisine: str = "",
        diet: str = "",
        intolerances: str = "",
        health_tags: list[str] | None = None,
        number: int = 20,
        offset: int = 0,
    ) -> dict:
        """
        Search Spoonacular with full recipe information + nutrition embedded.
        Returns {"results": [...], "totalResults": int}
        """
        params: dict = {
            "addRecipeInformation": "true",
            "addRecipeNutrition": "true",
            "number": number,
            "offset": offset,
            "fillIngredients": "true",
        }
        if query:
            params["query"] = query
        if cuisine:
            params["cuisine"] = cuisine

        # Merge explicit diet/intolerance params
        collected_diets: list[str] = [d for d in [diet] if d]
        collected_intolerances: list[str] = [i for i in [intolerances] if i]

        # Map app health tags to Spoonacular params
        for tag in (health_tags or []):
            mapping = HEALTH_FILTER_MAP.get(tag.lower(), {})
            if "diet" in mapping:
                collected_diets.append(mapping["diet"])
            if "intolerances" in mapping:
                collected_intolerances.extend(mapping["intolerances"].split(","))

        if collected_diets:
            params["diet"] = ",".join(dict.fromkeys(collected_diets))
        if collected_intolerances:
            params["intolerances"] = ",".join(dict.fromkeys(collected_intolerances))

        result = self._get("/recipes/complexSearch", params)
        if not result:
            return {"results": [], "totalResults": 0}

        normalized = [_normalize_recipe(r) for r in result.get("results", [])]
        return {"results": normalized, "totalResults": result.get("totalResults", 0)}

    def get_random(self, number: int = 12, tags: str = "") -> list[dict]:
        """Get random recipes with full nutrition."""
        params: dict = {
            "number": number,
            "addRecipeInformation": "true",
            "includeNutrition": "true",
        }
        if tags:
            params["tags"] = tags

        result = self._get("/recipes/random", params)
        if not result:
            return []
        return [_normalize_recipe(r) for r in result.get("recipes", [])]

    def get_by_id(self, spoonacular_id: int) -> Optional[dict]:
        """Fetch a single recipe by its Spoonacular numeric ID with full nutrition."""
        result = self._get(
            f"/recipes/{spoonacular_id}/information",
            {"includeNutrition": "true"},
        )
        return _normalize_recipe(result) if result else None

    def get_by_ingredients(self, ingredients: list[str], number: int = 15) -> list[dict]:
        """
        Find recipes that use the given ingredients (leftover mode).
        Uses findByIngredients then enriches the top results with full data.
        """
        if not ingredients:
            return []

        params: dict = {
            "ingredients": ",".join(ingredients),
            "number": number,
            "ranking": 2,    # maximize used ingredients
            "ignorePantry": "true",
        }
        result = self._get("/recipes/findByIngredients", params)
        if not result:
            return []

        enriched: list[dict] = []
        for r in (result or [])[:8]:  # cap at 8 to save API quota
            full = self.get_by_id(r["id"])
            if full:
                enriched.append(full)
        return enriched
