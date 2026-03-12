"""Cuisinee API - FastAPI Application Entry Point."""

from pathlib import Path
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from .config import get_settings, bootstrap_gcp_credentials
from .database import engine, Base
from .routers import auth, recipes, users, chat, voice_live, vision, global_recipes

# ── Bootstrap GCP credentials FIRST (before any client is created) ───────────
settings = get_settings()
bootstrap_gcp_credentials(settings)

# Create tables on startup (don't crash if DB is temporarily unreachable)
try:
    Base.metadata.create_all(bind=engine)
except Exception as _db_err:
    print(f"[startup] WARNING: Could not create DB tables: {_db_err}")
    print("[startup] Server will start anyway – DB tables will be created on first successful connection.")

# Create FastAPI app
app = FastAPI(
    title="Cuisinee API",
    description="Backend API for Cuisinee - AI-Powered Cooking Assistant",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Debug middleware - Skip WebSocket connections
@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Skip WebSocket upgrade requests
    if request.headers.get("upgrade", "").lower() == "websocket":
        return await call_next(request)

    print(f"Request: {request.method} {request.url}")
    print(f"Headers: {request.headers}")
    response = await call_next(request)
    print(f"Response status: {response.status_code}")
    return response



# Build allowed origins
# Explicitly include common development origins
allowed_origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:5000",
    "http://localhost:8000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8000",
]

# CORS middleware - MUST be enabled for WebSocket connections
app.add_middleware(
   CORSMiddleware,
   allow_origins=["*"],  # Allow all origins for development - restrict in production
   allow_credentials=False,  # Must be False when using wildcard origins
   allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
   allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(recipes.router, prefix="/api/recipes", tags=["Recipes"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(chat.router, prefix="/api/chat", tags=["AI Chat"])
app.include_router(voice_live.router, prefix="/api", tags=["Voice Assistant"])
app.include_router(vision.router, prefix="/api", tags=["Vision AI"])
app.include_router(global_recipes.router, prefix="/api/recipes/global", tags=["Global Recipes"])

# Mount static files for serving AI-generated recipe images
static_path = Path(__file__).parent.parent / "static"
static_path.mkdir(exist_ok=True)
(static_path / "recipe_images").mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_path)), name="static")


@app.get("/")
def root():
    """API root endpoint."""
    return {
        "name": "Cuisinee API",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "cuisinee-api"}

@app.websocket("/ws-echo")
async def echo_endpoint(websocket: WebSocket):
    await websocket.accept()
    await websocket.send_text("Hello")
    await websocket.close()
