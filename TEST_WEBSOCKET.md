# WebSocket 403 Error - Debugging Guide

## Issue
Getting `403 Forbidden` during WebSocket handshake to `ws://127.0.0.1:8000/api/voice/ws`

## What I've Fixed

### 1. ✅ HTTP Middleware Skip for WebSockets
**File**: `backend/app/main.py` lines 31-39

```python
@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Skip WebSocket upgrade requests
    if request.headers.get("upgrade", "").lower() == "websocket":
        return await call_next(request)
    # ... rest of logging
```

This prevents the HTTP middleware from interfering with WebSocket upgrades.

## Testing Steps

### Step 1: Restart Backend
```bash
# Stop current backend (Ctrl+C)
cd "d:\New folder\cuisinee\cuisinee\backend"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Step 2: Test with wscat
```bash
wscat -c ws://127.0.0.1:8000/api/voice/ws
```

**Expected**: Connection succeeds, receives `{"type":"connected",...}`

**If still 403**: Continue to Step 3

### Step 3: Check Backend Logs

When you try to connect, the backend should show:
```
🔌 New WebSocket connection from 127.0.0.1
✅ WebSocket accepted from 127.0.0.1
```

**If you see nothing**: WebSocket request isn't reaching the endpoint
**If you see errors**: There's an exception during handshake

### Step 4: Test Without Authentication

Let me check if there's implicit authentication. Try this temporary test endpoint:

Add to `voice_live.py`:
```python
@router.get("/test-connection")
async def test_connection():
    return {"status": "ok", "message": "Voice endpoint reachable"}
```

Then test:
```bash
curl http://localhost:8000/api/voice/test-connection
```

Should return: `{"status":"ok",...}`

## Possible Causes of 403

### Cause 1: FastAPI Dependency Injection Error
The `Depends(get_db)` might be failing. Check if database connection works:
```bash
curl http://localhost:8000/api/recipes
```
If this returns 500/error, database is the problem.

### Cause 2: Missing WebSocket Support in uvicorn
Ensure uvicorn has websocket support:
```bash
pip install "uvicorn[standard]" websockets
```

### Cause 3: Port/Firewall Issue
Test if port is accessible:
```bash
# Test HTTP (should work)
curl http://127.0.0.1:8000/health

# Test with localhost instead of 127.0.0.1
wscat -c ws://localhost:8000/api/voice/ws
```

### Cause 4: CORS Still Blocking
Even though CORS is enabled, verify it's actually running:
Check `main.py` lines 54-60 are NOT commented out.

## Alternative: Bypass Dependencies Temporarily

To isolate the issue, create a simple test endpoint:

```python
@router.websocket("/ws-test")
async def websocket_test(websocket: WebSocket):
    """Minimal WebSocket test - no dependencies"""
    await websocket.accept()
    await websocket.send_json({"type": "test", "message": "Connection successful!"})
    await websocket.close()
```

Test:
```bash
wscat -c ws://127.0.0.1:8000/api/voice/ws-test
```

**If this works**: The issue is with the `Depends(get_db)` dependency
**If this fails**: The issue is with routing/middleware

## Solutions Based on Diagnosis

### Solution A: Database Dependency Issue
Replace:
```python
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
```

With:
```python
async def websocket_endpoint(websocket: WebSocket):
    # Create DB session manually
    db = SessionLocal()
    try:
        # ... existing code ...
    finally:
        db.close()
```

### Solution B: Authentication Middleware
If there's authentication middleware, add WebSocket exemption:
```python
# In main.py, before CORS
from starlette.middleware.base import BaseHTTPMiddleware

class WebSocketAuthExemption(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        # Skip auth for WebSocket
        if request.url.path.startswith("/api/voice/ws"):
            return await call_next(request)
        # ... existing auth logic ...
```

### Solution C: Use Different Prefix
If routing is the issue, change the endpoint path:
```python
# In voice_live.py
@router.websocket("/live")  # Instead of "/ws"

# Access at: ws://127.0.0.1:8000/api/voice/live
```

## Current Configuration

Your setup:
- **Router prefix**: `/voice` (in `voice_live.py`)
- **Include prefix**: `/api` (in `main.py`)
- **Endpoint**: `/ws`
- **Final URL**: `/api/voice/ws` ✅

ChefCode setup:
- **Router prefix**: None
- **Include prefix**: `/api/voice`
- **Endpoint**: `/live/connect`
- **Final URL**: `/api/voice/live/connect`

Both are valid, so routing isn't the issue.

## Next Steps

1. ✅ Restart backend with middleware fix
2. Test with wscat
3. Check backend logs
4. If still failing, try test endpoint without dependencies
5. Report back what you see in logs

Let me know what happens when you restart the backend!
