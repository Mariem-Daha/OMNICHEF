"""Pydantic schemas for Recipe API."""

from datetime import datetime
from decimal import Decimal
from uuid import UUID
from pydantic import BaseModel, Field


class RecipeStepSchema(BaseModel):
    """Recipe step response schema."""
    
    step_number: int
    instruction: str
    duration_minutes: int | None = None
    tip: str | None = None
    
    class Config:
        from_attributes = True


class NutritionInfoSchema(BaseModel):
    """Nutrition info response schema."""
    
    calories: int | None = None
    protein: Decimal | None = None
    carbs: Decimal | None = None
    fat: Decimal | None = None
    fiber: Decimal | None = None
    sodium: Decimal | None = None
    sugar: Decimal | None = None
    
    class Config:
        from_attributes = True


class RecipeBase(BaseModel):
    """Base recipe schema with common fields."""
    
    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    image_url: str | None = None
    cuisine: str = Field(..., min_length=1, max_length=100)
    prep_time: int | None = None
    cook_time: int | None = None
    servings: int = 4
    calories: int | None = None
    tags: list[str] = []
    ingredients: list[str] = []
    difficulty: str = "Medium"
    chef_name: str | None = None


class RecipeCreate(RecipeBase):
    """Schema for creating a recipe."""
    
    steps: list[RecipeStepSchema] = []
    nutrition: NutritionInfoSchema | None = None


class RecipeResponse(RecipeBase):
    """Full recipe response schema."""
    
    id: UUID
    rating: Decimal = Decimal("4.5")
    review_count: int = 0
    created_at: datetime
    steps: list[RecipeStepSchema] = []
    nutrition: NutritionInfoSchema | None = None
    is_saved: bool = False  # Populated based on current user
    
    class Config:
        from_attributes = True


class RecipeListResponse(BaseModel):
    """Paginated recipe list response."""
    
    recipes: list[RecipeResponse]
    total: int
    page: int
    per_page: int
    pages: int
