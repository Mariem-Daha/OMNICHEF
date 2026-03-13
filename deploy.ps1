#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Cuisinee backend to Google Cloud Run.

.DESCRIPTION
    Full deployment pipeline:
      1.  Validates prerequisites (gcloud, docker)
      2.  Enables required GCP APIs
      3.  Creates Artifact Registry repository (idempotent)
      4.  Reads local .env and encodes service-account credentials as base64
      5.  Builds the Docker image locally OR via Cloud Build
      6.  Pushes image to Artifact Registry
      7.  Deploys to Cloud Run with all environment variables

.PARAMETER ProjectId
    GCP project ID (default: read from gcloud config or .env VERTEX_PROJECT_ID)

.PARAMETER Region
    GCP region (default: us-central1)

.PARAMETER ServiceName
    Cloud Run service name (default: cuisinee-backend)

.PARAMETER UseCloudBuild
    Build the image using Cloud Build instead of local Docker Desktop.

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -ProjectId your-gcp-project-id -Region us-central1
    .\deploy.ps1 -UseCloudBuild
#>
param(
    [string]$ProjectId    = "",
    [string]$Region       = "us-central1",
    [string]$ServiceName  = "omnichef-backend",
    [switch]$UseCloudBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─── Helpers ─────────────────────────────────────────────────────────────────
function Info  { param($m) Write-Host "  [INFO]  $m" -ForegroundColor Cyan   }
function Ok    { param($m) Write-Host "  [ OK ]  $m" -ForegroundColor Green  }
function Warn  { param($m) Write-Host "  [WARN]  $m" -ForegroundColor Yellow }
function Fail  { param($m) Write-Host "  [FAIL]  $m" -ForegroundColor Red; exit 1 }
function Step  { param($m) Write-Host "`n---  $m" -ForegroundColor White }

function Require-Command($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Fail "Required tool not found: '$cmd'. Please install it and retry."
    }
}

# ─── Locate workspace root ───────────────────────────────────────────────────
# deploy.ps1 lives IN the workspace root (cuisinee/), so the workspace root
# IS the script's directory — NOT its parent.
$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot = $ScriptDir
$BackendDir    = Join-Path $WorkspaceRoot "backend"
$EnvFile       = Join-Path $BackendDir ".env"
$CredFile      = Join-Path $WorkspaceRoot "gcp-service-account.json"

# ─── Prerequisites ────────────────────────────────────────────────────────────
Step "Checking prerequisites"
Require-Command "gcloud"
if (-not $UseCloudBuild) { Require-Command "docker" }
Ok "All prerequisites found."

# ─── Determine Project ID ─────────────────────────────────────────────────────
Step "Resolving GCP project"
if (-not $ProjectId) {
    # Try reading from .env first
    if (Test-Path $EnvFile) {
        $envLine = Select-String -Path $EnvFile -Pattern "^VERTEX_PROJECT_ID\s*=" | Select-Object -First 1
        if ($envLine) {
            $ProjectId = ($envLine.Line -split "=", 2)[1].Trim().Trim('"').Trim("'")
        }
    }
}
if (-not $ProjectId) {
    $ProjectId = (gcloud config get-value project 2>$null).Trim()
}
if (-not $ProjectId) {
    Fail "Cannot determine project ID. Pass -ProjectId or set VERTEX_PROJECT_ID in backend/.env"
}
Info "Project  : $ProjectId"
Info "Region   : $Region"
Info "Service  : $ServiceName"

# Set the active project
gcloud config set project $ProjectId --quiet 2>$null

# ─── Read .env values ─────────────────────────────────────────────────────────
Step "Reading backend/.env"
$envVars = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2) {
                $envVars[$parts[0].Trim()] = $parts[1].Trim().Trim('"').Trim("'")
            }
        }
    }
    Ok "Loaded $($envVars.Count) variables from .env"
} else {
    Warn ".env not found at $EnvFile — using defaults only"
}

# ─── Encode service-account credentials ──────────────────────────────────────
Step "Encoding GCP service-account credentials"
$credB64 = ""
if (Test-Path $CredFile) {
    $credBytes = [System.IO.File]::ReadAllBytes($CredFile)
    $credB64   = [Convert]::ToBase64String($credBytes)
    Ok "Credentials encoded ($($credBytes.Length) bytes → base64)"
} else {
    Warn "Service-account JSON not found at $CredFile"
    Warn "Vertex AI will rely on the Cloud Run service account (ADC)."
    Warn "Make sure it has the 'Vertex AI User' role."
}

# ─── Enable required GCP APIs ────────────────────────────────────────────────
Step "Enabling required GCP APIs (this may take ~2 minutes on a fresh project)"
$apis = @(
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "aiplatform.googleapis.com"
)
gcloud services enable @apis --project $ProjectId --quiet
Ok "APIs enabled."

# ─── Create Artifact Registry repository ─────────────────────────────────────
Step "Setting up Artifact Registry"
$repoExists = gcloud artifacts repositories describe cuisinee `
    --location $Region --project $ProjectId `
    --format "value(name)" 2>$null
if (-not $repoExists) {
    gcloud artifacts repositories create cuisinee `
        --repository-format docker `
        --location $Region `
        --description "Cuisinee container images" `
        --project $ProjectId --quiet
    Ok "Repository 'cuisinee' created."
} else {
    Ok "Repository 'cuisinee' already exists."
}

# Configure docker auth for Artifact Registry
gcloud auth configure-docker "${Region}-docker.pkg.dev" --quiet
Ok "Docker auth configured."

# ─── Image tag ───────────────────────────────────────────────────────────────
$gitSha = (git -C $WorkspaceRoot rev-parse --short HEAD 2>$null)
if (-not $gitSha) { $gitSha = (Get-Date -Format 'yyyyMMddHHmm') }

$ImageBase = "${Region}-docker.pkg.dev/${ProjectId}/cuisinee/${ServiceName}"
$ImageTag  = "${ImageBase}:${gitSha}"
$ImageLatest = "${ImageBase}:latest"

# ─── Build & push image ───────────────────────────────────────────────────────
if ($UseCloudBuild) {
    Step "Building image with Cloud Build"
    gcloud builds submit $WorkspaceRoot `
        --config "$WorkspaceRoot/cloudbuild.yaml" `
        --substitutions "_SERVICE_NAME=$ServiceName,_REGION=$Region,_IMAGE_TAG=$gitSha" `
        --project $ProjectId
    Ok "Cloud Build finished."
} else {
    Step "Building Docker image locally"
    docker build `
        --tag $ImageTag `
        --tag $ImageLatest `
        --file "$BackendDir/Dockerfile" `
        $BackendDir
    Ok "Image built: $ImageTag"

    Step "Pushing image to Artifact Registry"
    docker push $ImageTag
    docker push $ImageLatest
    Ok "Image pushed."
}

# ─── Build env-vars string for gcloud ────────────────────────────────────────
Step "Preparing Cloud Run environment variables"

# Merge .env values + deploy-time overrides (PS 5.1 compatible — no ?? operator)
function Get-EnvVar { param($key, $default="") if ($envVars.ContainsKey($key) -and $envVars[$key]) { return $envVars[$key] } return $default }
$runEnv = @{
    DATABASE_URL                 = Get-EnvVar "DATABASE_URL"
    SECRET_KEY                   = Get-EnvVar "SECRET_KEY" "cuisinee-secret-$(Get-Random)"
    ALGORITHM                    = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES  = "1440"
    ALLOWED_ORIGINS              = "*"
    GEMINI_API_KEY               = Get-EnvVar "GEMINI_API_KEY"
    VERTEX_PROJECT_ID            = $ProjectId
    VERTEX_LOCATION              = $Region
    SEARCH_ENGINE_ID             = Get-EnvVar "SEARCH_ENGINE_ID"
}
if ($credB64) {
    $runEnv["GOOGLE_CREDENTIALS_JSON"] = $credB64
}

# Build a comma-delimited KEY=VALUE string (values must not contain commas)
# For long/special values, write a temp YAML env-vars file instead.
$tmpEnvYaml = Join-Path $env:TEMP "cuisinee_cloudrun_env.yaml"
$yamlLines  = $runEnv.GetEnumerator() | ForEach-Object {
    $val = $_.Value -replace '"', '\"'
    "$($_.Key): `"$val`""
}
$yamlLines | Set-Content -Path $tmpEnvYaml -Encoding UTF8
Info "Env-vars YAML written to $tmpEnvYaml"

# ─── Deploy to Cloud Run ──────────────────────────────────────────────────────
Step "Deploying to Cloud Run"
gcloud run deploy $ServiceName `
    --image          $ImageTag `
    --region         $Region `
    --platform       managed `
    --allow-unauthenticated `
    --port           8080 `
    --memory         1Gi `
    --cpu            1 `
    --min-instances  0 `
    --max-instances  10 `
    --timeout        3600 `
    --concurrency    80 `
    --env-vars-file  $tmpEnvYaml `
    --project        $ProjectId `
    --quiet

# ─── Print service URL ────────────────────────────────────────────────────────
Step "Deployment complete!"
$serviceUrl = gcloud run services describe $ServiceName `
    --region $Region --project $ProjectId `
    --format "value(status.url)" 2>$null

Ok "Service URL : $serviceUrl"
Ok "API docs    : $serviceUrl/docs"
Ok "Health check: $serviceUrl/health"

Write-Host "`n  Update your Flutter app with this base URL:" -ForegroundColor Magenta
Write-Host "  $serviceUrl" -ForegroundColor Yellow
