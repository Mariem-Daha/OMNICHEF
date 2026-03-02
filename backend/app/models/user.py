"""User database models."""

import uuid
from sqlalchemy import Column, String, Integer, Text, Boolean, ARRAY, ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class User(Base):
    """User profile table."""
    
    __tablename__ = "profiles"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255))
    avatar_url = Column(String(500))
    age_range = Column(String(20), default="25-34")
    cooking_skill = Column(String(50), default="Intermediate")
    health_filters = Column(ARRAY(String), default=[])
    disliked_ingredients = Column(ARRAY(String), default=[])
    taste_preferences = Column(ARRAY(String), default=[])
    allergies = Column(ARRAY(String), default=[])
    cooking_streak = Column(Integer, default=0)
    recipes_cooked = Column(Integer, default=0)
    last_cooking_date = Column(TIMESTAMP(timezone=True))
    has_completed_health_quiz = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # Relationships
    saved_recipes = relationship("SavedRecipe", back_populates="user", cascade="all, delete-orphan")


class SavedRecipe(Base):
    """Junction table for user's saved recipes."""
    
    __tablename__ = "saved_recipes"
    
    user_id = Column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True)
    recipe_id = Column(UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), primary_key=True)
    saved_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="saved_recipes")
    recipe = relationship("Recipe", back_populates="saved_by")
