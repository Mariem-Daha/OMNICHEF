# ── Stage 1: Build dependencies ──────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build tools for native extensions (psycopg2, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: Runtime image ────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY app/ ./app/
COPY static/ ./static/

# Pre-create static dirs so they always exist
RUN mkdir -p ./static/recipe_images

# Non-root user for security
RUN useradd -m -u 1000 cuisinee && chown -R cuisinee:cuisinee /app
USER cuisinee

# Cloud Run listens on PORT (default 8080)
ENV PORT=8080
EXPOSE 8080

# Startup: decode credentials JSON from env var if provided,
# then launch Uvicorn.  Cloud Run sets PORT automatically.
CMD ["/bin/sh", "-c", "\
  if [ -n \"$GOOGLE_CREDENTIALS_JSON\" ]; then \
    echo \"$GOOGLE_CREDENTIALS_JSON\" | base64 -d > /tmp/gcp-credentials.json && \
    export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-credentials.json && \
    echo 'GCP credentials written to /tmp/gcp-credentials.json'; \
  fi; \
  exec uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 1 --loop asyncio \
"]
