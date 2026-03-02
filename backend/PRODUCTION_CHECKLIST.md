# Cuisinee Backend - Production Implementation Checklist

> Last Updated: 2026-01-06
> Status: Development Complete - Production Prep Pending

---

## 🚀 Pre-Production Checklist

### 1. Security Hardening

- [ ] **Generate Strong SECRET_KEY**
  ```bash
  python -c "import secrets; print(secrets.token_urlsafe(64))"
  ```
  
- [ ] **Update .env with production values**
  ```env
  SECRET_KEY=<generated-64-char-key>
  DATABASE_URL=<production-supabase-url>
  ALLOWED_ORIGINS=https://yourdomain.com
  ```

- [ ] **Add Rate Limiting**
  ```python
  # Install: pip install slowapi
  from slowapi import Limiter
  from slowapi.util import get_remote_address
  
  limiter = Limiter(key_func=get_remote_address)
  app.state.limiter = limiter
  
  @app.get("/api/auth/login")
  @limiter.limit("5/minute")
  def login(...):
  ```

- [ ] **Add Request Validation Middleware**
  - Validate Content-Length headers
  - Add request size limits

- [ ] **Enable HTTPS Only**
  - Configure SSL certificates
  - Force HTTPS redirects

### 2. Database Optimizations

- [ ] **Upgrade Tags Filtering (High Priority)**
  
  Current implementation uses Python-side filtering. For production with many recipes:
  
  ```python
  # Replace in app/routers/recipes.py - get_recipes_by_tags()
  from sqlalchemy import text
  
  @router.get("/tags", response_model=list[RecipeResponse])
  def get_recipes_by_tags(
      tags: list[str] = Query(...),
      db: Session = Depends(get_db),
      current_user: User | None = Depends(get_current_user),
  ):
      """Get recipes that have any of the specified health tags."""
      # Use raw SQL for PostgreSQL array overlap (production-optimized)
      tags_array = "{" + ",".join(tags) + "}"
      recipes = (
          db.query(Recipe)
          .options(joinedload(Recipe.steps), joinedload(Recipe.nutrition))
          .filter(text(f"tags && :tags_param"))
          .params(tags_param=tags_array)
          .all()
      )
      return [recipe_to_response(r, current_user) for r in recipes]
  ```

- [ ] **Add Connection Pooling**
  ```python
  # In app/database.py - already configured, verify pool sizes for production
  engine = create_engine(
      settings.database_url,
      pool_pre_ping=True,
      pool_size=10,        # Increase for production
      max_overflow=20,     # Increase for production
      pool_recycle=3600,   # Recycle connections every hour
  )
  ```

- [ ] **Add Database Migrations**
  ```bash
  pip install alembic
  alembic init migrations
  # Configure and create migration scripts
  ```

### 3. Logging & Monitoring

- [ ] **Add Structured Logging**
  ```python
  # Install: pip install structlog
  import structlog
  
  structlog.configure(
      processors=[
          structlog.stdlib.filter_by_level,
          structlog.processors.TimeStamper(fmt="iso"),
          structlog.processors.JSONRenderer()
      ],
  )
  
  logger = structlog.get_logger()
  ```

- [ ] **Add Health Check Improvements**
  ```python
  @app.get("/health")
  def health_check(db: Session = Depends(get_db)):
      """Comprehensive health check."""
      try:
          db.execute(text("SELECT 1"))
          db_status = "healthy"
      except Exception as e:
          db_status = f"unhealthy: {e}"
      
      return {
          "status": "healthy" if db_status == "healthy" else "degraded",
          "database": db_status,
          "version": "1.0.0",
          "timestamp": datetime.utcnow().isoformat()
      }
  ```

- [ ] **Add Error Tracking**
  - Integrate Sentry or similar
  ```python
  # pip install sentry-sdk[fastapi]
  import sentry_sdk
  sentry_sdk.init(dsn="your-sentry-dsn")
  ```

### 4. Performance Optimizations

- [ ] **Add Response Caching**
  ```python
  # pip install fastapi-cache2[redis]
  from fastapi_cache import FastAPICache
  from fastapi_cache.backends.redis import RedisBackend
  from fastapi_cache.decorator import cache
  
  @router.get("/recipes")
  @cache(expire=300)  # Cache for 5 minutes
  async def list_recipes(...):
  ```

- [ ] **Add Gzip Compression**
  ```python
  from fastapi.middleware.gzip import GZipMiddleware
  app.add_middleware(GZipMiddleware, minimum_size=1000)
  ```

- [ ] **Optimize Database Queries**
  - Add indexes for frequently queried fields
  - Use `.only()` to select specific columns
  - Implement pagination limits

### 5. Dependency Updates

- [ ] **Fix Passlib/Bcrypt Compatibility**
  
  Current fix uses direct bcrypt. Long-term options:
  
  Option A: Wait for passlib update
  ```bash
  # When available:
  pip install passlib[bcrypt]>=1.8.0
  ```
  
  Option B: Keep direct bcrypt (current implementation)
  ```python
  # Already implemented in auth_service.py - no changes needed
  import bcrypt
  
  def get_password_hash(password: str) -> str:
      salt = bcrypt.gensalt()
      return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
  
  def verify_password(plain_password: str, hashed_password: str) -> bool:
      return bcrypt.checkpw(
          plain_password.encode('utf-8'),
          hashed_password.encode('utf-8')
      )
  ```

- [ ] **Update requirements.txt for production**
  ```txt
  # Add production dependencies
  gunicorn==21.2.0
  uvloop==0.19.0  # Linux only - faster event loop
  httptools==0.6.1
  slowapi==0.1.9
  sentry-sdk[fastapi]==1.40.0
  structlog==24.1.0
  ```

### 6. Deployment Configuration

- [ ] **Create Dockerfile**
  ```dockerfile
  FROM python:3.11-slim
  
  WORKDIR /app
  
  COPY requirements.txt .
  RUN pip install --no-cache-dir -r requirements.txt
  
  COPY app ./app
  
  EXPOSE 8000
  
  CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8000"]
  ```

- [ ] **Create docker-compose.yml**
  ```yaml
  version: '3.8'
  services:
    api:
      build: .
      ports:
        - "8000:8000"
      environment:
        - DATABASE_URL=${DATABASE_URL}
        - SECRET_KEY=${SECRET_KEY}
        - ALLOWED_ORIGINS=${ALLOWED_ORIGINS}
      restart: unless-stopped
  ```

- [ ] **Configure Production Server**
  ```bash
  # Production command (Linux)
  gunicorn app.main:app \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --access-logfile - \
    --error-logfile -
  ```

### 7. Testing

- [ ] **Add Unit Tests**
  ```bash
  pip install pytest pytest-asyncio httpx
  ```

- [ ] **Add Integration Tests**
  - Test all API endpoints
  - Test authentication flows
  - Test edge cases

- [ ] **Add Load Testing**
  ```bash
  pip install locust
  # Create locustfile.py for load testing
  ```

---

## 🔧 Bugs Fixed (Reference)

### Bug #1: Registration Failure (bcrypt/passlib)
**File**: `app/services/auth_service.py`
**Fix**: Replaced `passlib.context.CryptContext` with direct `bcrypt` calls

### Bug #2: Tags Endpoint 500 Error
**File**: `app/routers/recipes.py`
**Fix**: Changed from `.overlap()` to Python-side filtering (upgrade to raw SQL for production)

---

## 📊 Current API Endpoints (All Working)

| Endpoint | Method | Auth Required |
|----------|--------|---------------|
| `/health` | GET | No |
| `/api/auth/register` | POST | No |
| `/api/auth/login` | POST | No |
| `/api/auth/me` | GET | Yes |
| `/api/recipes` | GET | No (enhanced with auth) |
| `/api/recipes/search` | GET | No |
| `/api/recipes/cuisine/{cuisine}` | GET | No |
| `/api/recipes/tags` | GET | No |
| `/api/recipes/leftovers` | GET | No |
| `/api/recipes/{id}` | GET | No |
| `/api/users/profile` | GET/PUT | Yes |
| `/api/users/saved-recipes` | GET/POST/DELETE | Yes |

---

## ✅ Production Readiness Score

| Category | Status | Score |
|----------|--------|-------|
| Core Functionality | Complete | 10/10 |
| Security | Basic | 6/10 |
| Performance | Development | 5/10 |
| Monitoring | Minimal | 3/10 |
| Testing | None | 0/10 |
| Documentation | Good | 8/10 |

**Overall**: Ready for staging, needs hardening for production.

---

## 🗓️ Recommended Production Timeline

1. **Week 1**: Security hardening + rate limiting
2. **Week 2**: Database optimizations + migrations
3. **Week 3**: Logging, monitoring, error tracking
4. **Week 4**: Testing + load testing
5. **Week 5**: Docker + deployment scripts
6. **Week 6**: Staging deployment + final testing
