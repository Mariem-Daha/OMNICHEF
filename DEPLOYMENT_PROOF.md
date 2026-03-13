# Cuisinee — Automated Cloud Run Deployment

## Live Service

| | |
|---|---|
| **Service URL** | https://omnichef-backend-your-cloud-run-url |
| **API Docs** | https://omnichef-backend-your-cloud-run-url/docs |
| **Health Check** | https://omnichef-backend-your-cloud-run-url/health |
| **Project** | `your-gcp-project-id` |
| **Region** | `us-central1` |
| **Deployed** | March 11, 2026 at 23:20 UTC |
| **Revision** | `omnichef-backend-00001` |

### Health Check Response (live)
```json
HTTP 200 OK
{"status":"ok","service":"cuisinee-api"}
```

---

## What Was Automated

The entire deployment pipeline runs with a single command:

```powershell
.\deploy.ps1 -UseCloudBuild
```

### Pipeline Steps (fully automated)

```
1. Prerequisite validation        → gcloud + Docker CLI check
2. GCP API enablement             → Cloud Run, Artifact Registry, Cloud Build, Vertex AI
3. Artifact Registry setup        → create repo if absent (idempotent)
4. Docker image build             → Google Cloud Build (no local Docker daemon needed)
5. Image push                     → us-central1-docker.pkg.dev/your-gcp-project-id/cuisinee/
6. Environment variables          → read from backend/.env + base64-encode service-account JSON
7. Cloud Run deployment           → gcloud run deploy with all config
8. Service URL printed            → ready for Flutter app configuration
```

---

## Cloud Build — Image Build Log

**Build ID:** `c7bfa026-ae79-4de0-9b24-37bfeae59db4`  
**Status:** `SUCCESS`  
**Duration:** `2m 11s`  
**Console:** https://console.cloud.google.com/cloud-build/builds/c7bfa026-ae79-4de0-9b24-37bfeae59db4?project=684753541076

**Images pushed to Artifact Registry:**
```
us-central1-docker.pkg.dev/your-gcp-project-id/cuisinee/cuisinee-backend:1e941f3
us-central1-docker.pkg.dev/your-gcp-project-id/cuisinee/cuisinee-backend:latest
```

---

## Cloud Run Service Configuration

```
Service name  : omnichef-backend
Image         : us-central1-docker.pkg.dev/your-gcp-project-id/cuisinee/cuisinee-backend:latest
Region        : us-central1
Platform      : managed (serverless)
Port          : 8080
Memory        : 1 GiB
CPU           : 1 vCPU
Min instances : 0  (scales to zero)
Max instances : 10
Timeout       : 3600s
Concurrency   : 80 requests/instance
Auth          : public (unauthenticated)
Traffic       : 100% → omnichef-backend-00001
```

---

## Infrastructure as Code Files

| File | Purpose |
|------|---------|
| [`deploy.ps1`](deploy.ps1) | Master deployment script — full pipeline in one command |
| [`cloudbuild.yaml`](cloudbuild.yaml) | Cloud Build config — Docker build + push to Artifact Registry |
| [`backend/Dockerfile`](backend/Dockerfile) | Multi-stage Docker image (Python 3.11 slim, non-root user) |
| [`backend/cloudrun.env.yaml.example`](backend/cloudrun.env.yaml.example) | Environment variable template |

---

## Automated Environment Variable Injection

Secrets and config are never hard-coded. The script reads `backend/.env` at deploy time and injects:

- `DATABASE_URL` — PostgreSQL connection string
- `SECRET_KEY` — JWT signing key
- `GEMINI_API_KEY` — Google Gemini AI key
- `VERTEX_PROJECT_ID` / `VERTEX_LOCATION` — Vertex AI config
- `SEARCH_ENGINE_ID` — Google Custom Search
- `GOOGLE_CREDENTIALS_JSON` — Service account JSON (base64-encoded, decoded at container startup)

---

## Re-deploy in One Command

```powershell
# From workspace root
.\deploy.ps1 -UseCloudBuild

# With explicit project override
.\deploy.ps1 -ProjectId your-gcp-project-id -Region us-central1 -UseCloudBuild
```

> No Docker Desktop required on the developer machine — Cloud Build handles the image build in GCP.
