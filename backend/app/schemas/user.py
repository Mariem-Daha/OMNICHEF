"""Pydantic schemas for User and Auth API."""

from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field


# Auth Schemas
class UserLogin(BaseModel):
    """Login request schema."""
    
    email: EmailStr
    password: str = Field(..., min_length=6)


class UserRegister(BaseModel):
    """Registration request schema."""
    
    email: EmailStr
    password: str = Field(..., min_length=6)
    name: str = Field(..., min_length=1, max_length=255)


class Token(BaseModel):
    """JWT token response."""
    
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Data extracted from JWT token."""
    
    user_id: UUID | None = None


# User Schemas
class UserBase(BaseModel):
    """Base user schema."""
    
    name: str | None = None
    avatar_url: str | None = None
    age_range: str = "25-34"
    cooking_skill: str = "Intermediate"
    health_filters: list[str] = []
    disliked_ingredients: list[str] = []
    taste_preferences: list[str] = []
    allergies: list[str] = []


class UserUpdate(UserBase):
    """Schema for updating user profile."""
    pass


class UserResponse(UserBase):
    """User profile response."""
    
    id: UUID
    email: str
    cooking_streak: int = 0
    recipes_cooked: int = 0
    has_completed_health_quiz: bool = False
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserWithToken(BaseModel):
    """User response with auth token for login/register."""
    
    user: UserResponse
    token: Token
