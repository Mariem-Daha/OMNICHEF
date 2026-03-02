"""Recipe database models."""

import uuid
from sqlalchemy import Column, String, Integer, Text, DECIMAL, ARRAY, ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class Recipe(Base):
    """Recipe table model."""
    
    __tablename__ = "recipes"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text)
    image_url = Column(String(500))
    cuisine = Column(String(100), nullable=False, index=True)
    prep_time = Column(Integer)  # minutes
    cook_time = Column(Integer)  # minutes
    servings = Column(Integer, default=4)
    calories = Column(Integer)
    tags = Column(ARRAY(String), default=[])
    ingredients = Column(ARRAY(String), default=[])
    difficulty = Column(String(50), default="Medium")
    chef_name = Column(String(255))
    rating = Column(DECIMAL(2, 1), default=4.5)
    review_count = Column(Integer, default=0)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # Relationships
    steps = relationship("RecipeStep", back_populates="recipe", cascade="all, delete-orphan", order_by="RecipeStep.step_number")
    nutrition = relationship("NutritionInfo", back_populates="recipe", uselist=False, cascade="all, delete-orphan")
    saved_by = relationship("SavedRecipe", back_populates="recipe", cascade="all, delete-orphan")


class RecipeStep(Base):
    """Recipe cooking steps."""
    
    __tablename__ = "recipe_steps"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    recipe_id = Column(UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    step_number = Column(Integer, nullable=False)
    instruction = Column(Text, nullable=False)
    duration_minutes = Column(Integer)
    tip = Column(Text)
    
    # Relationships
    recipe = relationship("Recipe", back_populates="steps")


class NutritionInfo(Base):
    """Nutritional information for a recipe."""
    
    __tablename__ = "nutrition_info"
    
    recipe_id = Column(UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), primary_key=True)
    calories = Column(Integer)
    protein = Column(DECIMAL(5, 2))
    carbs = Column(DECIMAL(5, 2))
    fat = Column(DECIMAL(5, 2))
    fiber = Column(DECIMAL(5, 2))
    sodium = Column(DECIMAL(5, 2))
    sugar = Column(DECIMAL(5, 2))
    
    # Relationships
    recipe = relationship("Recipe", back_populates="nutrition")
