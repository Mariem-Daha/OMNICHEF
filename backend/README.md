# Cuisinee Backend API

FastAPI backend for the Cuisinee cooking assistant app.

## Setup

1. Create a Python virtual environment:
```bash
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
copy .env.example .env
# Edit .env with your Supabase database URL
```

4. Run the database schema in Supabase SQL Editor (see `schema.sql`)

5. Seed the database:
```bash
python seed_recipes.py
```

6. Start the server:
```bash
uvicorn app.main:app --reload
```

## API Endpoints

- **Docs**: http://localhost:8000/docs
- **Health**: http://localhost:8000/health

### Recipes
- `GET /api/recipes` - List all recipes
- `GET /api/recipes/{id}` - Get recipe by ID
- `GET /api/recipes/search?q=` - Search recipes
- `GET /api/recipes/cuisine/{cuisine}` - Filter by cuisine
- `GET /api/recipes/tags?tags=` - Filter by health tags
- `GET /api/recipes/leftovers?ingredients=` - Match by ingredients

### Auth
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login (returns JWT)
- `GET /api/auth/me` - Get current user

### Users
- `GET /api/users/profile` - Get profile
- `PUT /api/users/profile` - Update profile
- `GET /api/users/saved-recipes` - Get saved recipes
- `POST /api/users/saved-recipes/{id}` - Save recipe
- `DELETE /api/users/saved-recipes/{id}` - Unsave recipe
