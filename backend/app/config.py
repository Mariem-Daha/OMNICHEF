"""Application configuration using Pydantic Settings."""

import base64
import json
import os
import tempfile
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Database
    database_url: str = "postgresql://localhost:5432/cuisinee"
    
    # JWT Authentication
    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440  # 24 hours
    
    # CORS
    allowed_origins: str = "*"
    
    # AI Services
    gemini_api_key: str = ""

    # Vertex AI (used for Gemini Live API)
    vertex_project_id: str = ""
    vertex_location: str = "us-central1"

    # Path to service-account JSON — set automatically if GOOGLE_CREDENTIALS_JSON is provided.
    # On Cloud Run, leave blank and rely on ADC (attached service account) or
    # provide the file content as GOOGLE_CREDENTIALS_JSON (base64-encoded JSON).
    google_application_credentials: str = ""

    # Base64-encoded service-account JSON for Cloud Run deployments.
    # When set, the file is decoded to /tmp/gcp-credentials.json at startup.
    google_credentials_json: str = ""

    # Google Custom Search API (for recipe images)
    search_api: str = ""  # Google Custom Search API key
    search_engine_id: str = ""  # Custom Search Engine ID (cx)

    # Spoonacular (global recipe search)
    spoonacular_api_key: str = ""
    
    @property
    def cors_origins(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        return [origin.strip() for origin in self.allowed_origins.split(",")]
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8-sig"  # Handle BOM
        extra = "ignore"  # Ignore unexpected fields


def bootstrap_gcp_credentials(settings: "Settings") -> None:
    """
    Write GCP credentials to a temp file if GOOGLE_CREDENTIALS_JSON is set.
    Must be called once at application startup before any GCP client is created.
    """
    if settings.google_credentials_json:
        try:
            cred_bytes = base64.b64decode(settings.google_credentials_json)
            # Validate it's real JSON before writing
            json.loads(cred_bytes)
            cred_path = "/tmp/gcp-credentials.json"
            with open(cred_path, "wb") as f:
                f.write(cred_bytes)
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = cred_path
            print(f"[config] GCP credentials decoded → {cred_path}")
        except Exception as e:
            print(f"[config] WARNING: Failed to decode GOOGLE_CREDENTIALS_JSON: {e}")
    elif settings.google_application_credentials:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.google_application_credentials
        print(f"[config] Using GOOGLE_APPLICATION_CREDENTIALS={settings.google_application_credentials}")


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
