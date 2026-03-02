"""SQL schema for Supabase database setup."""

-- Run this in Supabase SQL Editor

-- Recipes table
CREATE TABLE IF NOT EXISTS recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    image_url VARCHAR(500),
    cuisine VARCHAR(100) NOT NULL,
    prep_time INTEGER,
    cook_time INTEGER,
    servings INTEGER DEFAULT 4,
    calories INTEGER,
    tags TEXT[] DEFAULT '{}',
    ingredients TEXT[] DEFAULT '{}',
    difficulty VARCHAR(50) DEFAULT 'Medium',
    chef_name VARCHAR(255),
    rating DECIMAL(2,1) DEFAULT 4.5,
    review_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recipe steps
CREATE TABLE IF NOT EXISTS recipe_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE NOT NULL,
    step_number INTEGER NOT NULL,
    instruction TEXT NOT NULL,
    duration_minutes INTEGER,
    tip TEXT,
    UNIQUE(recipe_id, step_number)
);

-- Nutrition info
CREATE TABLE IF NOT EXISTS nutrition_info (
    recipe_id UUID PRIMARY KEY REFERENCES recipes(id) ON DELETE CASCADE,
    calories INTEGER,
    protein DECIMAL(5,2),
    carbs DECIMAL(5,2),
    fat DECIMAL(5,2),
    fiber DECIMAL(5,2),
    sodium DECIMAL(5,2),
    sugar DECIMAL(5,2)
);

-- User profiles
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    avatar_url VARCHAR(500),
    age_range VARCHAR(20) DEFAULT '25-34',
    cooking_skill VARCHAR(50) DEFAULT 'Intermediate',
    health_filters TEXT[] DEFAULT '{}',
    disliked_ingredients TEXT[] DEFAULT '{}',
    taste_preferences TEXT[] DEFAULT '{}',
    allergies TEXT[] DEFAULT '{}',
    cooking_streak INTEGER DEFAULT 0,
    recipes_cooked INTEGER DEFAULT 0,
    last_cooking_date TIMESTAMPTZ,
    has_completed_health_quiz BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Saved recipes junction table
CREATE TABLE IF NOT EXISTS saved_recipes (
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
    saved_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, recipe_id)
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_recipes_cuisine ON recipes(cuisine);
CREATE INDEX IF NOT EXISTS idx_recipes_name ON recipes(name);
CREATE INDEX IF NOT EXISTS idx_recipes_tags ON recipes USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_recipe_steps_recipe ON recipe_steps(recipe_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_saved_recipes_user ON saved_recipes(user_id);
