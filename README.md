# OMNICHEF — AI-Powered Cooking Assistant

OMNICHEF is a full-stack AI cooking assistant built with Flutter (frontend) and FastAPI (backend). It helps users discover culturally authentic Mauritanian and MENA recipes, reduce food waste, and get real-time AI cooking guidance through voice and chat.

---

## Features

- **AI Chat & Voice Assistant** — Real-time cooking guidance powered by Gemini Live API (WebSocket)
- **Smart Recipe Discovery** — AI-powered suggestions based on ingredients, preferences, and health needs
- **Ingredient Vision** — Photograph your fridge; OMNICHEF identifies ingredients and suggests recipes
- **Low-Waste Cooking** — Input leftovers and get matching recipes
- **Health-Aware Filtering** — Filter by diabetes, hypertension, anemia, and more
- **Culturally Authentic Library** — Curated Mauritanian and MENA recipes
- **Personalized Profiles** — Taste preferences, dietary restrictions, saved recipes

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend | FastAPI (Python 3.11) |
| Database | PostgreSQL (Supabase) |
| AI | Google Gemini 2.5 Flash (Gemini Live + Vision) |
| Realtime | WebSocket (Gemini Live API) |
| Auth | JWT (python-jose) |
| Hosting | Google Cloud Run |

---

## Project Structure

```
omnichef/
├── frontend/          # Flutter app
│   └── lib/
│       ├── core/      # Theme, providers, models, services
│       └── features/  # Screens: home, chat, recipes, auth, profile
├── backend/           # FastAPI server
│   ├── app/
│   │   ├── routers/   # API endpoints
│   │   ├── models/    # SQLAlchemy models
│   │   ├── schemas/   # Pydantic schemas
│   │   ├── services/  # Business logic
│   │   └── config.py  # Settings (env vars)
│   ├── schema.sql     # Database schema
│   └── requirements.txt
└── scripts/           # One-off data scripts (seeding, image generation)
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.19
- Python 3.11+
- A [Supabase](https://supabase.com) project (PostgreSQL)
- A [Google Gemini API key](https://aistudio.google.com/app/apikey)

---

### Backend Setup

```bash
cd backend

# 1. Create and activate virtual environment
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
copy .env.example .env   # Windows
cp .env.example .env     # macOS/Linux
# Edit .env and fill in your values (see .env.example for all keys)

# 4. Apply database schema
# Run the contents of schema.sql in your Supabase SQL Editor

# 5. Start the server
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`.  
Interactive docs: `http://localhost:8000/docs`

---

### Frontend Setup

```bash
cd frontend

# 1. Get Flutter dependencies
flutter pub get

# 2. Set the backend URL
# Edit lib/core/services/api_service.dart → change baseUrl to your backend address

# 3. Run the app
flutter run                  # connected device / emulator
flutter run -d chrome        # web browser
flutter run -d windows       # Windows desktop
```

---

## Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in the values below.  
**Never commit `.env` to version control.**

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string (Supabase) |
| `SECRET_KEY` | JWT signing secret — generate with `python -c "import secrets; print(secrets.token_urlsafe(32))"` |
| `GEMINI_API_KEY` | Google Gemini API key |
| `VERTEX_PROJECT_ID` | GCP project ID (for Gemini Live via Vertex AI) |
| `VERTEX_LOCATION` | GCP region, e.g. `us-central1` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to GCP service account JSON (optional) |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins |

---

## API Endpoints

### Recipes
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/recipes` | List all recipes |
| GET | `/api/recipes/{id}` | Get recipe by ID |
| GET | `/api/recipes/search?q=` | Full-text search |
| GET | `/api/recipes/cuisine/{cuisine}` | Filter by cuisine |
| GET | `/api/recipes/leftovers?ingredients=` | Match by available ingredients |

### Auth
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login — returns JWT |
| GET | `/api/auth/me` | Current user (JWT required) |

### AI
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/vision/analyze` | Identify ingredients from image |
| WS | `/ws/companion` | Gemini Live voice session |

---

## Reproducible Testing

### 1. Backend Unit & Integration Tests

```bash
cd backend
# Activate your venv first
pip install -r requirements.txt

# Run the included test scripts (requires a running server on port 8000)
python test_ws_simple.py          # Basic WebSocket connectivity
python test_websocket.py          # Full voice companion WebSocket flow
python test_multiturn.py          # Multi-turn conversation test
```

### 2. API Smoke Tests (curl)

```bash
# Health check
curl http://localhost:8000/health

# Register a test user
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@omnichef.ai","password":"Test1234!","name":"Tester"}'

# List recipes
curl http://localhost:8000/api/recipes
```

### 3. Flutter Widget & Integration Tests

```bash
cd frontend

# Run all unit/widget tests
flutter test

# Run integration tests (requires a connected device or emulator)
flutter test integration_test/

# Analyze for lints and type errors
flutter analyze
```

### 4. End-to-End Demo Flow

1. Start the backend: `uvicorn app.main:app --reload` (inside `backend/`)
2. Launch the Flutter app: `flutter run` (inside `frontend/`)
3. Register a new account on the Sign Up screen
4. Navigate to **AI Chat** — type or speak a cooking question
5. Navigate to **Leftover Mode** — enter ingredients like `chicken, tomato`
6. Navigate to **Recipe Library** — browse and filter by health tag
7. Open any recipe → tap **Start Cooking** for step-by-step mode

---

## License

MIT License


## Features

### 🍽️ Smart Recipe Discovery
- AI-powered recipe suggestions based on your preferences
- Authentic Mauritanian and MENA recipes curated by real chefs
- Cultural recipe library with traditional dishes

### 💚 Health-Aligned Eating
- Filter recipes by health conditions (diabetes, hypertension, anemia)
- Nutritional information for every recipe
- Ingredient substitution suggestions for healthier options

### 🧅 Low-Waste Cooking
- Input leftover ingredients to get recipe suggestions
- Reduce food waste by cooking with what you have
- Smart matching algorithm finds recipes you can make

### 🤖 AI Cooking Assistant
- Chat-based interface for cooking guidance
- Step-by-step cooking mode with large, readable text
- Voice input for hands-free cooking

### 👤 Personalization
- Set taste preferences and disliked ingredients
- Health needs configuration
- Recent meals tracking

## Design Philosophy

- **Warm & Minimal**: Soft neutral colors with terracotta accent
- **Mobile-First**: Optimized for touch with large targets
- **Culturally Inspired**: Subtle MENA design elements
- **Accessible**: Clear typography, high contrast, voice support

## Color Palette

- **Primary**: Terracotta (#E07A5F)
- **Secondary**: Sand Gold (#F2CC8F)  
- **Accent**: Mint Green (#81B29A)
- **Background**: Warm White (#FAF8F5)

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter run`

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   ├── providers/
│   │   ├── theme_provider.dart
│   │   ├── user_provider.dart
│   │   └── recipe_provider.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── recipe_model.dart
│   │   └── chat_message.dart
│   ├── data/
│   │   └── dummy_recipes.dart
│   └── widgets/
│       ├── buttons.dart
│       ├── text_fields.dart
│       ├── recipe_cards.dart
│       ├── chips.dart
│       └── skeleton_loaders.dart
├── features/
│   ├── onboarding/
│   │   ├── screens/
│   │   │   └── onboarding_screen.dart
│   │   └── widgets/
│   │       └── onboarding_page.dart
│   ├── auth/
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── signup_screen.dart
│   ├── navigation/
│   │   └── main_navigation.dart
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── quick_action_card.dart
│   │       └── section_header.dart
│   ├── chat/
│   │   ├── screens/
│   │   │   └── chat_screen.dart
│   │   └── widgets/
│   │       ├── chat_bubble.dart
│   │       ├── voice_input_button.dart
│   │       └── cooking_step_card.dart
│   ├── recipes/
│   │   ├── screens/
│   │   │   ├── recipe_detail_screen.dart
│   │   │   ├── recipe_library_screen.dart
│   │   │   └── saved_recipes_screen.dart
│   │   └── widgets/
│   │       ├── ingredient_list.dart
│   │       ├── step_list.dart
│   │       └── nutrition_card.dart
│   ├── leftover/
│   │   └── screens/
│   │       └── leftover_screen.dart
│   ├── health_filters/
│   │   └── screens/
│   │       └── health_filters_screen.dart
│   └── profile/
│       └── screens/
│           └── profile_screen.dart
```

## Screens

1. **Onboarding** - Welcome screens explaining key features
2. **Login/Signup** - Authentication with email, Google, Apple
3. **Home Dashboard** - Daily suggestions, quick actions, recipe carousels
4. **AI Chat Assistant** - Conversational cooking help with voice input
5. **Recipe Detail** - Full recipe with ingredients, steps, nutrition
6. **Recipe Library** - Browse Mauritanian and MENA recipes
7. **Leftover Mode** - Find recipes from your ingredients
8. **Health Filters** - Filter by health conditions
9. **Profile** - User preferences and settings

## Dependencies

- `provider` - State management
- `google_fonts` - Typography
- `flutter_animate` - Animations
- `shimmer` - Skeleton loading
- `percent_indicator` - Progress indicators
- `cached_network_image` - Image caching

## License

MIT License
