"""Global recipe endpoints — Spoonacular API proxy + image proxy."""

import httpx
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse

from ..config import get_settings

router = APIRouter()

SPOONACULAR_BASE = "https://api.spoonacular.com"


def _api_key() -> str:
    key = get_settings().spoonacular_api_key
    if not key:
        raise HTTPException(status_code=503, detail="Spoonacular API key not configured")
    return key


def _map_recipe(r: dict) -> dict:
    """Normalize a Spoonacular recipe dict into our Recipe schema shape."""
    nutrition = {}
    if "nutrition" in r:
        nutrients = {n["name"].lower(): n for n in r["nutrition"].get("nutrients", [])}
        nutrition = {
            "calories": nutrients.get("calories", {}).get("amount"),
            "protein": nutrients.get("protein", {}).get("amount"),
            "carbs": nutrients.get("carbohydrates", {}).get("amount"),
            "fat": nutrients.get("fat", {}).get("amount"),
            "fiber": nutrients.get("fiber", {}).get("amount"),
            "sodium": nutrients.get("sodium", {}).get("amount"),
            "sugar": nutrients.get("sugar", {}).get("amount"),
        }

    steps = []
    if "analyzedInstructions" in r:
        for block in r["analyzedInstructions"]:
            for s in block.get("steps", []):
                steps.append({
                    "step_number": s.get("number", 0),
                    "instruction": s.get("step", ""),
                    "duration_minutes": None,
                    "tip": None,
                })

    ingredients = []
    for ing in r.get("extendedIngredients", r.get("usedIngredients", [])):
        ingredients.append(ing.get("original") or ing.get("name") or "")

    tags = []
    if r.get("vegetarian"):
        tags.append("vegetarian")
    if r.get("vegan"):
        tags.append("vegan")
    if r.get("glutenFree"):
        tags.append("gluten-free")
    if r.get("dairyFree"):
        tags.append("dairy-free")
    diets = r.get("diets", [])
    tags.extend(diets)

    return {
        "id": str(r.get("id", "")),
        "name": r.get("title", ""),
        "description": r.get("summary", "")[:300] if r.get("summary") else "",
        "image_url": r.get("image", ""),
        "cuisine": (r.get("cuisines") or ["International"])[0],
        "prep_time": r.get("preparationMinutes") or 0,
        "cook_time": r.get("cookingMinutes") or r.get("readyInMinutes") or 0,
        "servings": r.get("servings") or 4,
        "calories": int(nutrition.get("calories") or 0),
        "tags": list(set(tags)),
        "ingredients": ingredients,
        "difficulty": "medium",
        "chef_name": "Spoonacular",
        "rating": round(r.get("spoonacularScore", 80) / 20, 1),
        "review_count": r.get("aggregateLikes", 0),
        "created_at": None,
        "steps": steps,
        "nutrition": nutrition if any(nutrition.values()) else None,
        "is_saved": False,
    }


@router.get("/random")
async def get_random_global_recipes(
    number: int = Query(12, ge=1, le=20),
    tags: str = Query(""),
):
    """Return random recipes from Spoonacular."""
    params = {
        "apiKey": _api_key(),
        "number": number,
        "addRecipeNutrition": True,
        "addRecipeInstructions": True,
    }
    if tags:
        params["tags"] = tags

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(f"{SPOONACULAR_BASE}/recipes/random", params=params)
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="Spoonacular error")

    data = resp.json()
    return [_map_recipe(r) for r in data.get("recipes", [])]


@router.get("/search")
async def search_global_recipes(
    query: str = Query("", alias="query"),
    cuisine: str = Query(""),
    diet: str = Query(""),
    intolerances: str = Query(""),
    number: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    """Search Spoonacular recipes."""
    params = {
        "apiKey": _api_key(),
        "query": query,
        "number": number,
        "offset": offset,
        "addRecipeNutrition": True,
        "addRecipeInstructions": True,
        "fillIngredients": True,
    }
    if cuisine:
        params["cuisine"] = cuisine
    if diet:
        params["diet"] = diet
    if intolerances:
        params["intolerances"] = intolerances

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(f"{SPOONACULAR_BASE}/recipes/complexSearch", params=params)
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="Spoonacular error")

    data = resp.json()
    return {
        "results": [_map_recipe(r) for r in data.get("results", [])],
        "totalResults": data.get("totalResults", 0),
    }


@router.get("/leftovers")
async def get_global_leftovers(
    ingredients: list[str] = Query(...),
    number: int = Query(12, ge=1, le=20),
):
    """Find Spoonacular recipes by ingredients."""
    params = {
        "apiKey": _api_key(),
        "ingredients": ",".join(ingredients),
        "number": number,
        "ranking": 1,
        "ignorePantry": True,
    }

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(f"{SPOONACULAR_BASE}/recipes/findByIngredients", params=params)
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="Spoonacular error")

    # findByIngredients returns minimal info — enrich with bulk info
    matches = resp.json()
    if not matches:
        return []

    ids = ",".join(str(m["id"]) for m in matches)
    async with httpx.AsyncClient(timeout=15) as client:
        info_resp = await client.get(
            f"{SPOONACULAR_BASE}/recipes/informationBulk",
            params={"apiKey": _api_key(), "ids": ids, "includeNutrition": True},
        )
    if info_resp.status_code != 200:
        # Fall back to minimal data
        return [_map_recipe(m) for m in matches]

    return [_map_recipe(r) for r in info_resp.json()]


@router.get("/{spoonacular_id}")
async def get_global_recipe_by_id(spoonacular_id: int):
    """Get a single Spoonacular recipe by numeric ID."""
    params = {
        "apiKey": _api_key(),
        "includeNutrition": True,
    }
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(
            f"{SPOONACULAR_BASE}/recipes/{spoonacular_id}/information", params=params
        )
    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail="Spoonacular error")

    return _map_recipe(resp.json())


@router.get("/image-proxy")
async def proxy_image(url: str = Query(...)):
    """
    Proxy external recipe images to avoid CORS issues on web.
    The Flutter frontend should request  /api/recipes/global/image-proxy?url=<encoded-url>
    instead of loading images directly.
    """
    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client:
            resp = await client.get(
                url,
                headers={"User-Agent": "Mozilla/5.0 (compatible; OmniChef/1.0)"},
            )
        content_type = resp.headers.get("content-type", "image/jpeg")
        return StreamingResponse(
            iter([resp.content]),
            media_type=content_type,
            headers={"Cache-Control": "public, max-age=86400"},
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Could not fetch image: {exc}")
