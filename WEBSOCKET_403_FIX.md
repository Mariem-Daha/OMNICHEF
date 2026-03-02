# 🔧 WebSocket 403 Forbidden - Complete Fix Guide

## 🎯 The Problem
WebSocket connection to `ws://127.0.0.1:8000/api/voice/ws` is failing with:
```
Error during WebSocket handshake: Unexpected response code: 403
```

## ✅ Fixes Applied

### Fix 1: HTTP Middleware WebSocket Skip
**File**: `backend/app/main.py` (lines 31-39)

**Problem**: HTTP middleware was processing WebSocket upgrade requests.

**Solution**:
```python
@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Skip WebSocket upgrade requests
    if request.headers.get("upgrade", "").lower() == "websocket":
        return await call_next(request)
    # ... rest of middleware
```

### Fix 2: Test Endpoints Added
**File**: `backend/app/routers/voice_live.py`

**Added**:
1. **`GET /api/voice/test`** - HTTP test endpoint
2. **`WS /api/voice/ws-test`** - Minimal WebSocket test (no dependencies)

## 🚀 Testing Instructions

### Step 1: Restart Backend

**IMPORTANT**: You must restart the backend for the middleware fix to take effect!

```bash
# 1. Stop current backend process (Ctrl+C in terminal)

# 2. Navigate to backend directory
cd "d:\New folder\cuisinee\cuisinee\backend"

# 3. Start fresh
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Wait for**:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

---

### Step 2: Test HTTP Connectivity

Open new terminal:

```bash
# Test 1: Root health
curl http://localhost:8000/health

# Test 2: Voice router
curl http://localhost:8000/api/voice/test
```

**Expected Response** (Test 2):
```json
{
  "status": "ok",
  "message": "Voice router is reachable",
  "endpoints": {
    "websocket_test": "/api/voice/ws-test",
    "websocket_main": "/api/voice/ws",
    "status": "/api/voice/live/status"
  }
}
```

✅ **If this works**: Router is accessible, proceed to Step 3
❌ **If this fails**: There's a bigger routing issue

---

### Step 3: Test Minimal WebSocket (No Dependencies)

Install wscat if needed:
```bash
npm install -g wscat
```

Test the minimal WebSocket:
```bash
wscat -c ws://localhost:8000/api/voice/ws-test
```

**Expected**:
```
Connected (press CTRL+C to quit)
< {"type":"test","message":"WebSocket connection successful!","url":"/api/voice/ws-test"}
Disconnected
```

**Backend Logs Should Show**:
```
✅ Test WebSocket connection successful
```

✅ **If this works**: WebSocket routing is fine, issue is with dependencies
❌ **If this fails**: There's a WebSocket configuration issue

---

### Step 4: Test Main WebSocket (With Dependencies)

```bash
wscat -c ws://localhost:8000/api/voice/ws
```

**Expected**:
```
Connected
< {"type":"connected","session_id":"live_20260213_..."}
```

**Backend Logs Should Show**:
```
🔌 New WebSocket connection from 127.0.0.1
✅ WebSocket accepted from 127.0.0.1
✨ Created session: live_...
✅ Gemini client initialized
🔌 Connecting to Gemini Live API...
✅ Connected to Gemini Live API
📤 Sent connection confirmation
```

✅ **If this works**: Everything is fixed! Proceed to test frontend
❌ **If this fails**: Database dependency issue (see Step 5)

---

### Step 5: If Main WebSocket Still Fails (Database Issue)

The `Depends(get_db)` might be causing the 403. Let's bypass it temporarily.

**Edit** `backend/app/routers/voice_live.py` line 507:

**Change from**:
```python
@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
```

**To**:
```python
@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    # Manual DB session creation (bypasses FastAPI dependency)
    from ..database import SessionLocal
    db = SessionLocal()
    try:
```

**And at the end of the function** (line ~554), **change**:
```python
    except Exception as e:
        logger.error(f"❌ WebSocket error: {e}")
        traceback.print_exc()
        try:
            await websocket.close(code=1011, reason=f"Server error: {str(e)}")
        except:
            pass
```

**To**:
```python
    except Exception as e:
        logger.error(f"❌ WebSocket error: {e}")
        traceback.print_exc()
        try:
            await websocket.close(code=1011, reason=f"Server error: {str(e)}")
        except:
            pass
    finally:
        db.close()  # Clean up manual DB session
```

Then restart backend and test again.

---

## 📋 Diagnosis Checklist

### ✅ Tests to Run

- [ ] Backend starts without errors
- [ ] `curl http://localhost:8000/health` works
- [ ] `curl http://localhost:8000/api/voice/test` works
- [ ] `wscat -c ws://localhost:8000/ws-echo` works (the echo test from main.py)
- [ ] `wscat -c ws://localhost:8000/api/voice/ws-test` works (minimal test)
- [ ] `wscat -c ws://localhost:8000/api/voice/ws` works (main endpoint)

### ❌ If Still Failing After All Steps

**Check These**:

1. **WebSocket Support**: Ensure uvicorn has WebSocket support
   ```bash
   pip install "uvicorn[standard]" websockets
   ```

2. **Firewall**: Windows Firewall might be blocking WebSocket
   - Try: `wscat -c ws://localhost:8000/ws-echo`
   - If this fails too, it's firewall/port issue

3. **Browser vs Command Line**: Test in both
   - Command: `wscat`
   - Browser: Use your Flutter app

4. **Port Conflict**: Another service using port 8000
   ```bash
   # Windows
   netstat -ano | findstr :8000

   # Try different port
   uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
   ```

5. **Python/Uvicorn Version**:
   ```bash
   python --version  # Should be 3.8+
   pip show uvicorn  # Should be 0.20.0+
   pip show fastapi  # Should be 0.100.0+
   pip show websockets  # Should be 12.0+
   ```

---

## 🎯 Expected Results by Step

| Step | Test | Expected | Indicates |
|------|------|----------|-----------|
| 1 | Backend starts | No errors | ✅ Backend OK |
| 2 | HTTP endpoints | 200 OK | ✅ Routing OK |
| 3 | Minimal WS | Connected | ✅ WebSocket OK |
| 4 | Main WS | Connected | ✅ Dependencies OK |
| 5 | Manual DB | Connected | ✅ Full Fix |

---

## 🔄 Frontend Testing

Once backend WebSocket works with wscat, test frontend:

1. **Restart Frontend**:
   ```bash
   # Stop current (Ctrl+C)
   cd "d:\New folder\cuisinee\cuisinee\frontend"
   flutter run -d chrome  # or your device
   ```

2. **Check Console**: Open browser DevTools (F12)

3. **Expected Logs**:
   ```
   🎤 Initializing Gemini Live Service...
   ✅ Gemini Live Service initialized
   🔌 Connecting to WebSocket...
   ✅ WebSocket connected
   💚 Connection confirmed
   ```

4. **Test Voice**: Click microphone, speak, hear response

---

## 💡 Common Patterns

### Pattern A: wscat works, Flutter fails
**Cause**: Frontend WebSocket URL is wrong
**Fix**: Check `gemini_live_service.dart` line ~183
```dart
final wsUrl = serverUrl.replaceFirst('http', 'ws');
// Should be: ws://127.0.0.1:8000/api/voice/ws
```

### Pattern B: Both fail with 403
**Cause**: Middleware or authentication blocking
**Fix**: Already applied - restart backend with middleware fix

### Pattern C: Minimal works, main fails
**Cause**: Database dependency issue
**Fix**: Use manual DB session (Step 5)

### Pattern D: All fail
**Cause**: WebSocket support missing or port blocked
**Fix**: Reinstall packages, check firewall

---

## 🎬 Quick Command Summary

```bash
# 1. Restart Backend
cd "d:\New folder\cuisinee\cuisinee\backend"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 2. Test HTTP (in new terminal)
curl http://localhost:8000/api/voice/test

# 3. Test Minimal WebSocket
wscat -c ws://localhost:8000/api/voice/ws-test

# 4. Test Main WebSocket
wscat -c ws://localhost:8000/api/voice/ws

# 5. Test Frontend
cd ../frontend
flutter run -d chrome
```

---

## ✨ Success Criteria

Your WebSocket is working when:

1. ✅ wscat connects without 403 error
2. ✅ Receives `{"type":"connected"}` message
3. ✅ Backend logs show session creation
4. ✅ Frontend connects successfully
5. ✅ Voice input/output works

---

## 📞 Report Back

After testing, please share:

1. **Which step failed/succeeded**?
2. **Backend logs** when you try to connect
3. **Frontend console logs** (F12)
4. **Error messages** (if any)

This will help me provide the exact fix needed!

---

*WebSocket 403 Fix Guide - Generated 2026-02-13*
*Middleware fix applied, test endpoints added*
