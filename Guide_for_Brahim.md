# 🍳 Cuisinee - Complete Guide for Brahim

**بسم الله الرحمن الرحيم**

Welcome to Cuisinee! This is an AI-powered cooking assistant for Mauritanian and MENA households. Here's everything you need to know to continue the project.

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [How to Run the App](#how-to-run-the-app)
4. [Project Structure](#project-structure)
5. [App Features & Logic Flow](#app-features--logic-flow)
6. [Database Schema](#database-schema)
7. [API Endpoints](#api-endpoints)
8. [Configuration](#configuration)
9. [Troubleshooting](#troubleshooting)
10. [What's Working & What Needs Attention](#whats-working--what-needs-attention)

---

## 🎯 Project Overview

**Cuisinee** is a full-stack cooking application that helps Mauritanian and MENA families:
- Discover authentic recipes from the region
- Filter recipes by health conditions (diabetes, hypertension, etc.)
- Find recipes based on leftover ingredients
- Get AI-powered cooking assistance through chat
- Save favorite recipes for later

**Tech Stack:**
- **Frontend**: Flutter (cross-platform: Web, Android, Windows, iOS)
- **Backend**: FastAPI (Python)
- **Database**: PostgreSQL (via Supabase)
- **AI**: Google Gemini API

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         USER                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER FRONTEND                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Providers  │  │   Screens   │  │   Widgets   │         │
│  │ (State Mgmt)│  │  (UI Pages) │  │(Reusable UI)│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                         │                                    │
│              ┌──────────┴──────────┐                        │
│              │    API Service      │ ◄── HTTP Requests       │
│              └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                              │
                     HTTP/REST API
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Routers   │  │   Services  │  │   Models    │         │
│  │(API Routes) │  │(Biz Logic)  │  │ (DB Schema) │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                         │                                    │
│              ┌──────────┴──────────┐                        │
│              │  SQLAlchemy + DB    │                        │
│              └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                              │
                     PostgreSQL Protocol
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE DATABASE                         │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │
│  │  profiles │ │  recipes  │ │recipe_stps│ │ nutrition │   │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### How Data Flows

1. **User opens app** → Frontend starts and calls `ApiService().init()` to load any stored auth token
2. **User browses recipes** → Frontend calls `GET /api/recipes` → Backend queries DB → Returns JSON
3. **User logs in** → Frontend sends credentials → Backend verifies → Returns JWT token → Frontend stores securely
4. **User saves recipe** → Frontend sends `POST /api/users/saved-recipes/{id}` with auth header → Backend creates record
5. **User asks AI** → Frontend sends message to `/api/chat` → Backend calls Gemini API → Returns response

---

## 🚀 How to Run the App

### Prerequisites

Before you start, install:
1. **Python 3.11+** - [python.org](https://python.org) (check "Add to PATH")
2. **Flutter 3.0+** - [flutter.dev](https://flutter.dev/docs/get-started/install)
3. **Chrome** - For web testing
4. **VS Code** (recommended) - With Flutter and Python extensions

### Step 1: Start the Backend

Open a terminal and run:

```powershell
# Navigate to backend
cd c:\Projects\cuisinee\backend

# First time only: create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\activate

# First time only: install dependencies
pip install -r requirements.txt

# Start the server
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see: `Uvicorn running on http://0.0.0.0:8000`

**Keep this terminal open!**

### Step 2: Start the Frontend

Open a **new terminal** and run:

```powershell
# Navigate to frontend
cd c:\Projects\cuisinee\frontend

# First time only: get dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# OR run on Windows desktop
flutter run -d windows

# OR run on Android (if device connected)
flutter run -d <device-id>
```

### Quick Start (After First Setup)

**Terminal 1 (Backend):**
```powershell
cd c:\Projects\cuisinee\backend
.\venv\Scripts\activate
python -m uvicorn app.main:app --reload --port 8000
```

**Terminal 2 (Frontend):**
```powershell
cd c:\Projects\cuisinee\frontend
flutter run -d chrome
```

---

## 📁 Project Structure

```
cuisinee/
├── backend/                    # Python FastAPI backend
│   ├── app/                    # Main application code
│   │   ├── main.py            # App entry point, CORS, routes
│   │   ├── config.py          # Environment configuration
│   │   ├── database.py        # Database connection
│   │   ├── models/            # SQLAlchemy database models
│   │   │   ├── recipe.py      # Recipe, RecipeStep, NutritionInfo
│   │   │   └── user.py        # User, SavedRecipe
│   │   ├── routers/           # API endpoints
│   │   │   ├── auth.py        # Login, register, logout
│   │   │   ├── recipes.py     # Recipe CRUD, search, filter
│   │   │   ├── users.py       # User profile, saved recipes
│   │   │   └── chat.py        # AI chat endpoint
│   │   ├── schemas/           # Pydantic validation schemas
│   │   └── services/          # Business logic
│   │       ├── auth_service.py    # Password hashing, JWT
│   │       └── ai_service.py      # Gemini AI integration
│   ├── static/                # Served static files (images)
│   ├── .env                   # Environment variables (SECRET!)
│   ├── .env.example           # Template for .env
│   ├── requirements.txt       # Python dependencies
│   └── schema.sql             # Database schema reference
│
├── frontend/                  # Flutter frontend
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── core/              # Shared code
│   │   │   ├── theme/         # Colors, typography, themes
│   │   │   ├── models/        # Data classes (Recipe, User, etc.)
│   │   │   ├── providers/     # State management (Provider)
│   │   │   ├── services/      # API communication
│   │   │   └── widgets/       # Reusable UI components
│   │   └── features/          # App screens by feature
│   │       ├── onboarding/    # Welcome screens
│   │       ├── auth/          # Login, signup
│   │       ├── home/          # Main dashboard
│   │       ├── recipes/       # Recipe list, detail, saved
│   │       ├── health_filters/# Health condition filtering
│   │       ├── leftover/      # Leftover ingredient finder
│   │       ├── chat/          # AI assistant chat
│   │       ├── cooking/       # Step-by-step cooking mode
│   │       └── profile/       # User settings
│   ├── assets/                # Images, fonts, icons
│   ├── pubspec.yaml           # Flutter dependencies
│   └── web/                   # Web-specific config
│
├── scripts/                   # Import/utility scripts (NOT FOR PRODUCTION)
│   ├── import_recipes.py      # Recipe import scripts
│   ├── smart_image_updater.py # Image management
│   └── data/                  # Raw data files
│
└── Guide_for_Brahim.md        # This file!
```

---

## 🔄 App Features & Logic Flow

### 1. Authentication Flow

```
User opens app
       │
       ▼
┌──────────────────┐
│ Check for stored │    ► Token exists? ──► Validate with /api/auth/me
│    auth token    │                              │
└──────────────────┘                   Valid?     │
       │                                 ▼        │
       │                          Go to Home    Invalid
       │                                          ▼
       ▼                                    Clear token
No token found                                  │
       │                                        │
       ▼                                        ▼
┌──────────────────┐                   ┌────────────────┐
│ Show Onboarding  │ ───────────────►  │  Login/Signup  │
└──────────────────┘                   └────────────────┘
                                              │
                                              ▼
                                        Send to backend
                                              │
                                              ▼
                                        Receive JWT token
                                              │
                                              ▼
                                        Store securely
                                              │
                                              ▼
                                         Go to Home
```

**Key Files:**
- `frontend/lib/core/services/api_service.dart` - Token storage & API calls
- `frontend/lib/core/providers/user_provider.dart` - User state management
- `backend/app/routers/auth.py` - Auth endpoints
- `backend/app/services/auth_service.py` - Password hashing, JWT creation

### 2. Recipe Loading & Display

```
Home Screen loads
       │
       ▼
RecipeProvider.loadRecipes()
       │
       ▼
ApiService.getRecipes(page: 1)
       │
       ▼
GET /api/recipes?page=1&per_page=20
       │
       ▼
Backend queries database
       │
       ▼
Returns paginated recipes with:
  - Recipe details
  - Cooking steps
  - Nutrition info
  - is_saved flag (if logged in)
       │
       ▼
Frontend displays in grid/list
       │
       ▼
User scrolls to bottom?
       │
       ▼
loadMoreRecipes() ► GET page=2,3,4...
```

**Key Files:**
- `frontend/lib/core/providers/recipe_provider.dart` - Recipe state & pagination
- `frontend/lib/core/models/recipe_model.dart` - Recipe data class
- `backend/app/routers/recipes.py` - Recipe API endpoints

### 3. Health Filter Logic

```
User taps "Health Filters" on home
              │
              ▼
     Health Filters Screen
              │
   ┌──────────┴──────────┐
   │     Available Tags:  │
   │ □ Diabetes-Friendly  │
   │ □ Heart-Healthy      │
   │ □ Low-Sodium         │
   │ □ High-Fiber         │
   │ □ Gluten-Free        │
   └──────────────────────┘
              │
      User selects tags
              │
              ▼
RecipeProvider.toggleHealthFilter()
              │
              ▼
getRecipesByTagsFromApi()
              │
              ▼
GET /api/recipes/tags?tags=Diabetes-Friendly&tags=Heart-Healthy
              │
              ▼
Backend filters recipes where
recipe.tags CONTAINS ANY selected tags
              │
              ▼
Display filtered results
```

**Logic:** Recipes have a `tags` array like `["Diabetes-Friendly", "High-Fiber"]`. The filter returns any recipe that has **at least one** of the selected tags.

### 4. Leftover Mode Logic

```
User enters ingredients they have
 (e.g., "chicken, rice, onion")
              │
              ▼
RecipeProvider.addLeftoverIngredient()
              │
              ▼
getRecipesByLeftoversFromApi()
              │
              ▼
GET /api/recipes/leftovers?ingredients=chicken&ingredients=rice
              │
              ▼
Backend algorithm:
  1. Get all recipes
  2. For each recipe:
     - Count how many user ingredients match recipe ingredients
     - Match = user ingredient is SUBSTRING of recipe ingredient
  3. Include if matches >= 2 OR matches >= all user ingredients
  4. Sort by match count (most matches first)
  5. Return top 20
              │
              ▼
Display matching recipes
```

**Example:** If user has ["chicken", "rice"], a recipe with ingredients ["chicken breast", "jasmine rice", "garlic"] would match 2 ingredients.

### 5. AI Chat Flow

```
User types message in chat
           │
           ▼
ApiService.chat(message, history)
           │
           ▼
POST /api/chat
{
  "message": "How do I make Thieboudienne?",
  "conversation_history": [
    {"content": "Hello", "is_user": true},
    {"content": "Hi! How can I help?", "is_user": false}
  ]
}
           │
           ▼
AIService.chat()
           │
           ▼
Gemini API with system prompt:
"You are Cuisinee, a friendly cooking assistant
 specializing in Mauritanian/MENA cuisine..."
           │
           ▼
AI generates response
           │
           ▼
Return to frontend
           │
           ▼
Display in chat bubble
```

**Fallback:** If Gemini API key is missing or fails, the backend has hardcoded responses for common topics like "thieboudienne", "healthy", "substitute", "diabetes".

### 6. Save Recipe Logic

```
User taps heart icon on recipe card
              │
              ▼
RecipeProvider.toggleSaveRecipe()
              │
              ▼
Optimistic update (immediately show as saved)
              │
              ▼
    Is user logged in?
         │         │
        YES       NO
         │         │
         ▼         ▼
   POST/DELETE   Done (local only)
   /api/users/saved-recipes/{id}
         │
         ▼
   Success?
    │      │
   YES    NO → Revert optimistic update
    │
    ▼
   Done
```

**Note:** Saving works locally even without login, but won't sync to other devices.

---

## 🗄️ Database Schema

### Tables Overview

| Table | Purpose |
|-------|---------|
| `profiles` | User accounts |
| `recipes` | Recipe information |
| `recipe_steps` | Cooking instructions |
| `nutrition_info` | Nutritional data |
| `saved_recipes` | User ↔ Recipe relationship |

### profiles (Users)
```sql
id              UUID PRIMARY KEY
email           VARCHAR(255) UNIQUE NOT NULL
password_hash   VARCHAR(255) NOT NULL
name            VARCHAR(255)
health_filters  TEXT[]  -- e.g., ["Diabetes-Friendly"]
allergies       TEXT[]
cooking_streak  INTEGER DEFAULT 0
created_at      TIMESTAMPTZ
```

### recipes
```sql
id          UUID PRIMARY KEY
name        VARCHAR(255) NOT NULL
description TEXT
image_url   VARCHAR(500)
cuisine     VARCHAR(100) NOT NULL  -- "Mauritanian", "Moroccan", etc.
prep_time   INTEGER  -- minutes
cook_time   INTEGER  -- minutes
servings    INTEGER DEFAULT 4
calories    INTEGER
tags        TEXT[]  -- ["Diabetes-Friendly", "High-Fiber"]
ingredients TEXT[]  -- ["2 lbs fish", "1 cup rice"]
difficulty  VARCHAR(50) DEFAULT 'Medium'
rating      DECIMAL(2,1) DEFAULT 4.5
```

### recipe_steps
```sql
recipe_id         UUID FOREIGN KEY → recipes
step_number       INTEGER
instruction       TEXT
duration_minutes  INTEGER
tip               TEXT  -- Optional cooking tip
```

### nutrition_info
```sql
recipe_id  UUID PRIMARY KEY FOREIGN KEY → recipes
calories   INTEGER
protein    DECIMAL(5,2)
carbs      DECIMAL(5,2)
fat        DECIMAL(5,2)
fiber      DECIMAL(5,2)
sodium     DECIMAL(5,2)
sugar      DECIMAL(5,2)
```

---

## 🔌 API Endpoints

### Authentication
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register` | No | Create new account |
| POST | `/api/auth/login` | No | Login, get JWT token |
| GET | `/api/auth/me` | Yes | Get current user |

### Recipes
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/recipes` | No | List recipes (paginated) |
| GET | `/api/recipes/{id}` | No | Get single recipe |
| GET | `/api/recipes/search?q=...` | No | Search by name/description |
| GET | `/api/recipes/cuisine/{cuisine}` | No | Filter by cuisine |
| GET | `/api/recipes/tags?tags=...` | No | Filter by health tags |
| GET | `/api/recipes/leftovers?ingredients=...` | No | Find by ingredients |

### Users
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/users/profile` | Yes | Get user profile |
| PUT | `/api/users/profile` | Yes | Update profile |
| GET | `/api/users/saved-recipes` | Yes | Get saved recipes |
| POST | `/api/users/saved-recipes/{id}` | Yes | Save a recipe |
| DELETE | `/api/users/saved-recipes/{id}` | Yes | Unsave a recipe |

### AI Chat
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/chat` | No | Send message to AI |
| GET | `/api/chat/health` | No | Check AI availability |

### Interactive API Docs
With backend running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## ⚙️ Configuration

### Backend Environment Variables

File: `backend/.env` (create from `.env.example`)

```env
# Database (Supabase)
DATABASE_URL=postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres

# Security - CHANGE THIS!
SECRET_KEY=generate-using-python-c-import-secrets-print-secrets-token-urlsafe-64

# CORS - allowed frontend origins
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# AI (Get from: https://aistudio.google.com/app/apikey)
GEMINI_API_KEY=your-gemini-api-key
```

**⚠️ NEVER commit the `.env` file to git!**

### Frontend API URL

File: `frontend/lib/core/services/api_service.dart`

```dart
static const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000/api',  // Change for production
);
```

To use different URL:
```powershell
flutter run -d chrome --dart-define=API_URL=https://api.cuisinee.com/api
```

---

## 🔧 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| Frontend shows "Connection refused" | Backend not running. Start backend first! |
| Backend "Can't connect to database" | Check `DATABASE_URL` in `.env` |
| "500 Error" on registration | Check backend terminal for stack trace |
| AI chat not responding | Verify `GEMINI_API_KEY` in `.env` |
| CORS errors in browser console | Check `ALLOWED_ORIGINS` includes frontend URL |
| Flutter build fails | Run `flutter clean` then `flutter pub get` |

### Debug Steps

1. **Check Backend Health:**
   ```
   http://localhost:8000/health
   ```
   Should return: `{"status": "healthy"}`

2. **Check API Docs:**
   ```
   http://localhost:8000/docs
   ```
   Test endpoints directly here

3. **Check Backend Logs:**
   Watch the terminal where backend runs - errors appear there

4. **Check Frontend Console:**
   Press F12 in Chrome → Console tab

---

## ✅ What's Working & What Needs Attention

### ✅ Working Features

| Feature | Status | Notes |
|---------|--------|-------|
| User Registration/Login | ✅ Working | JWT-based auth |
| Recipe Browsing | ✅ Working | Paginated, infinite scroll |
| Recipe Search | ✅ Working | By name/description |
| Health Tag Filtering | ✅ Working | Multi-select tags |
| Leftover Mode | ✅ Working | Ingredient matching |
| Save/Unsave Recipes | ✅ Working | Syncs when logged in |
| AI Chat | ✅ Working | Needs Gemini API key |
| Light/Dark Theme | ✅ Working | User preference |
| Recipe Details | ✅ Working | Steps, nutrition, tips |

### ⚠️ Needs Attention

| Item | Priority | Details |
|------|----------|---------|
| Production deployment | High | See `PRODUCTION_CHECKLIST.md` |
| Rate limiting | High | Add before going live |
| Unit tests | Medium | None currently |
| Image loading fallbacks | Medium | Some images may fail |
| Offline support | Low | App requires internet |

### 📂 Scripts Folder

The `scripts/` folder contains utility scripts I used to:
- Import recipes from JSON files
- Generate/update recipe images using AI
- Analyze and fix data issues

**You don't need these for normal development!** They were one-time data population tools. The database already has the recipes loaded.

---

## 🎉 Final Notes

The core app is functional! Focus on:
1. Testing the complete user flow
2. Fixing any bugs you find
3. Preparing for production deployment

If you need to add more recipes, check the scripts folder - but coordinate with me first since they require API keys.

**You've got this! 💪**

*- Mariem*

---

**الله يوفقك!** 🤲
