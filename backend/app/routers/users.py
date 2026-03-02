"""User profile and saved recipes API endpoints."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models.user import User, SavedRecipe
from ..models.recipe import Recipe
from ..schemas.user import UserResponse, UserUpdate
from ..schemas.recipe import RecipeResponse
from ..services.auth_service import get_current_user_required
from .recipes import recipe_to_response

router = APIRouter()


@router.get("/profile", response_model=UserResponse)
def get_profile(current_user: User = Depends(get_current_user_required)):
    """Get current user's profile."""
    return current_user


@router.put("/profile", response_model=UserResponse)
def update_profile(
    profile_data: UserUpdate,
    current_user: User = Depends(get_current_user_required),
    db: Session = Depends(get_db),
):
    """Update current user's profile."""
    # Update fields
    for field, value in profile_data.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)
    
    db.commit()
    db.refresh(current_user)
    
    return current_user


@router.get("/saved-recipes", response_model=list[RecipeResponse])
def get_saved_recipes(
    current_user: User = Depends(get_current_user_required),
    db: Session = Depends(get_db),
):
    """Get all recipes saved by current user."""
    saved = (
        db.query(SavedRecipe)
        .filter(SavedRecipe.user_id == current_user.id)
        .options(joinedload(SavedRecipe.recipe).joinedload(Recipe.steps))
        .options(joinedload(SavedRecipe.recipe).joinedload(Recipe.nutrition))
        .all()
    )
    
    return [recipe_to_response(sr.recipe, current_user) for sr in saved]


@router.post("/saved-recipes/{recipe_id}", status_code=status.HTTP_201_CREATED)
def save_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user_required),
    db: Session = Depends(get_db),
):
    """Save a recipe to user's collection."""
    # Check recipe exists
    recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    if not recipe:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recipe not found",
        )
    
    # Check not already saved
    existing = (
        db.query(SavedRecipe)
        .filter(SavedRecipe.user_id == current_user.id, SavedRecipe.recipe_id == recipe_id)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Recipe already saved",
        )
    
    # Save recipe
    saved = SavedRecipe(user_id=current_user.id, recipe_id=recipe_id)
    db.add(saved)
    db.commit()
    
    return {"message": "Recipe saved"}


@router.delete("/saved-recipes/{recipe_id}")
def unsave_recipe(
    recipe_id: UUID,
    current_user: User = Depends(get_current_user_required),
    db: Session = Depends(get_db),
):
    """Remove a recipe from user's saved collection."""
    saved = (
        db.query(SavedRecipe)
        .filter(SavedRecipe.user_id == current_user.id, SavedRecipe.recipe_id == recipe_id)
        .first()
    )
    
    if not saved:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Saved recipe not found",
        )
    
    db.delete(saved)
    db.commit()
    
    return {"message": "Recipe removed from saved"}
