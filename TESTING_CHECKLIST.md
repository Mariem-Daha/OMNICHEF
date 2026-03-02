# ✅ Cuisinee AI Assistant - Testing Checklist

Use this checklist to verify your AI assistant is working perfectly.

---

## 🔧 Phase 1: Backend Verification

### ✅ 1.1 Server Startup
```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Check**:
- [ ] Server starts without errors
- [ ] No `ModuleNotFoundError`
- [ ] No `GEMINI_API_KEY` warnings
- [ ] Listens on port 8000

**Expected Log**:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

---

### ✅ 1.2 Health Endpoints

**Test 1: Root Endpoint**
```bash
curl http://localhost:8000/
```
**Expected**:
```json
{
  "name": "Cuisinee API",
  "version": "1.0.0",
  "docs": "/docs"
}
```
- [ ] Returns 200 OK
- [ ] JSON is valid

---

**Test 2: Health Check**
```bash
curl http://localhost:8000/health
```
**Expected**: 200 OK (may be null/empty body)
- [ ] Returns 200 OK

---

**Test 3: Voice Live Status**
```bash
curl http://localhost:8000/api/voice/live/status
```
**Expected**:
```json
{
  "status": "ready",
  "model": "models/gemini-2.0-flash-exp",
  "available": true,
  "sessions": {
    "active": 0,
    "max": 50,
    "utilization_percent": 0.0
  },
  "voice_config": {
    "current_voice": "Puck",
    "available_voices": ["Puck", "Aoede", "Charon", "Kore", "Fenrir"],
    "polyglot_support": true,
    "languages": ["Arabic", "French", "English"]
  },
  "audio_config": {
    "input_sample_rate": 16000,
    "output_sample_rate": 24000,
    "input_format": "PCM 16-bit mono",
    "output_format": "PCM 16-bit mono"
  }
}
```
- [ ] `status` is "ready"
- [ ] `available` is true
- [ ] `active` sessions is 0
- [ ] All fields present

---

**Test 4: API Documentation**

Open in browser:
```
http://localhost:8000/docs
```
- [ ] FastAPI Swagger UI loads
- [ ] See `/api/voice/ws` WebSocket endpoint
- [ ] See `/api/voice/live/status` GET endpoint
- [ ] See `/api/voice/live/sessions` GET endpoint
- [ ] See `/api/voice/live/metrics` GET endpoint

---

### ✅ 1.3 WebSocket Echo Test

**Install wscat** (if needed):
```bash
npm install -g wscat
```

**Test Echo Endpoint**:
```bash
wscat -c ws://localhost:8000/ws-echo
```
**Expected**:
```
Connected (press CTRL+C to quit)
< Hello
Disconnected
```
- [ ] Connection succeeds
- [ ] Receives "Hello" message
- [ ] Connection closes gracefully

---

### ✅ 1.4 CORS Configuration

**Check** [backend/app/main.py](backend/app/main.py) lines 54-61:

```python
# CORS middleware - MUST be enabled for WebSocket connections
app.add_middleware(
   CORSMiddleware,
   allow_origins=["*"],
   allow_credentials=False,
   allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
   allow_headers=["*"],
)
```

- [ ] CORS middleware is NOT commented out
- [ ] `allow_origins` includes "*" or your frontend URL
- [ ] `allow_credentials=False` (required with wildcard)

---

## 🎤 Phase 2: Voice WebSocket Connection

### ✅ 2.1 WebSocket Connection Test

**Using wscat**:
```bash
wscat -c ws://localhost:8000/api/voice/ws
```

**Expected**:
```
Connected (press CTRL+C to quit)
< {"type":"connected","session_id":"live_20260213_143022_a3f2b1"}
```

- [ ] Connection succeeds
- [ ] Receives `{"type":"connected"}` message
- [ ] `session_id` starts with "live_"

**Backend Logs Should Show**:
```
🔌 New WebSocket connection from 127.0.0.1
✅ WebSocket accepted from 127.0.0.1
✨ Created session: live_20260213_143022_a3f2b1
✅ Gemini client initialized for session: live_...
🔌 Connecting to Gemini Live API (attempt 1/3)...
✅ Connected to Gemini Live API: live_...
📦 Registered 2 tools
📤 Sent connection confirmation: live_...
```

- [ ] No errors in logs
- [ ] See emoji indicators (✅ 🔌 ✨ 📦)
- [ ] Session ID created
- [ ] Gemini API connected

---

### ✅ 2.2 Heartbeat Test

While WebSocket is connected, send:
```json
{"type":"ping"}
```

**Expected Response**:
```json
{"type":"pong"}
```

- [ ] Receives pong immediately
- [ ] No errors

---

### ✅ 2.3 Check Active Sessions

While WebSocket is connected, in another terminal:
```bash
curl http://localhost:8000/api/voice/live/sessions
```

**Expected**:
```json
{
  "active_sessions": ["live_20260213_143022_a3f2b1"],
  "count": 1,
  "stats": {
    "live_20260213_143022_a3f2b1": {
      "start_time": "2026-02-13T14:30:22",
      "duration_seconds": 5.3,
      "messages_sent": 1,
      "messages_received": 0,
      "functions_executed": 0,
      "errors": 0,
      "is_active": true
    }
  }
}
```

- [ ] `count` is 1
- [ ] Session ID matches
- [ ] `is_active` is true
- [ ] `errors` is 0

---

## 🎨 Phase 3: Frontend Integration

### ✅ 3.1 Frontend Startup

```bash
cd frontend
flutter run -d chrome  # or your device
```

- [ ] App compiles without errors
- [ ] App launches successfully
- [ ] No WebSocket errors in console yet

---

### ✅ 3.2 Microphone Permissions

**Navigate to Voice Assistant screen**

- [ ] Microphone permission prompt appears
- [ ] Grant permission
- [ ] No errors in console after granting

**Browser Console (F12) Should Show**:
```
🎤 Initializing Gemini Live Service...
🌐 Platform: Web
✅ Gemini Live Service initialized
🔌 Connecting to WebSocket: ws://127.0.0.1:8000/api/voice/ws
```

---

### ✅ 3.3 WebSocket Connection (Frontend)

**Frontend Console Should Show**:
```
✅ WebSocket connected
📨 Received: {"type":"connected","session_id":"live_..."}
🆔 Session ID: live_...
💚 Connection confirmed
```

**Backend Logs Should Show**:
```
🔌 New WebSocket connection from 127.0.0.1
✅ WebSocket accepted
✨ Created session: live_...
📤 Sent connection confirmation
```

- [ ] Frontend shows "Connected" state
- [ ] Backend logs show new session
- [ ] No errors on either side

---

## 🗣️ Phase 4: Voice Interaction Tests

### ✅ 4.1 Basic Voice Test

**Action**: Click microphone button and speak
**Say**: "Hello, can you hear me?"

**Check Frontend**:
- [ ] Microphone button changes color (listening state)
- [ ] Audio waveform/visualization appears
- [ ] State changes: connected → listening

**Check Backend Logs**:
```
🎤 Receiving audio chunks from client
📊 VAD: is_speech=True, energy=0.045
🔚 End of turn detected (1.8s silence)
💬 Gemini: Hello! Yes, I can hear you perfectly...
🔊 Sent 4800 bytes audio to client
✅ Turn complete
```

- [ ] Backend receives audio data
- [ ] VAD detects speech
- [ ] Gemini responds with text
- [ ] Audio is sent back to client

**Check Frontend**:
- [ ] State changes: listening → processing → speaking
- [ ] Transcript appears: "Gemini: Hello! Yes, I can hear you..."
- [ ] Audio plays from speakers
- [ ] State returns to: connected (ready for next input)

---

### ✅ 4.2 Recipe Search Test

**Say**: "Find me a recipe for couscous"

**Expected Flow**:

**Backend Logs**:
```
🔧 Function call: find_recipe({'query': 'couscous'})
📊 Searching database for: couscous
✅ Function executed: find_recipe → {'success': True, 'recipes': [...]}
💬 Gemini: I found 3 recipes for couscous. The first one is...
🔊 Sent audio to client
✅ Turn complete
```

**Frontend**:
- [ ] Transcript shows user input: "Find me a recipe for couscous"
- [ ] Transcript shows Gemini response
- [ ] Function execution notification appears (optional)
- [ ] Audio response plays
- [ ] Recipe cards/data displayed (if UI implements it)

---

### ✅ 4.3 Timer Test

**Say**: "Set a timer for 10 minutes"

**Backend Logs**:
```
🔧 Function call: set_timer({'minutes': 10})
✅ Function executed: set_timer → {'success': True, 'timer': {...}}
💬 Gemini: Timer set for 10 minutes
```

**Frontend**:
- [ ] Timer function executes
- [ ] Gemini confirms: "Timer set for 10 minutes"
- [ ] Timer widget appears (if implemented)

---

### ✅ 4.4 Multilingual Test

**Test Arabic**:
**Say**: "ابحث عن وصفة طاجين" (Search for tagine recipe)

**Expected**:
- [ ] Gemini understands Arabic
- [ ] Gemini responds IN Arabic
- [ ] Function executes correctly
- [ ] Audio has Arabic accent

**Test French**:
**Say**: "Trouve-moi une recette de couscous"

**Expected**:
- [ ] Gemini understands French
- [ ] Gemini responds IN French
- [ ] Function executes correctly
- [ ] Audio has French accent

---

## 🔍 Phase 5: Error Handling & Edge Cases

### ✅ 5.1 Connection Interruption

**Test**: Disconnect WiFi mid-conversation

**Expected**:
- [ ] Frontend shows error/disconnected state
- [ ] Frontend attempts reconnection (max 3 times)
- [ ] Backend logs disconnection gracefully

**Backend Logs**:
```
👋 Client disconnected: session_id
📊 Session stats: duration=45.2s, messages=12, functions=2, errors=0
```

**Reconnect WiFi**:
- [ ] Frontend reconnects automatically
- [ ] New session created
- [ ] Can continue conversation

---

### ✅ 5.2 Long Silence

**Test**: Start listening but don't speak for 30 seconds

**Expected**:
- [ ] No crashes
- [ ] Connection stays alive (heartbeat working)
- [ ] Silence detector doesn't false-trigger

---

### ✅ 5.3 Background Noise

**Test**: Speak with TV/music in background

**Expected**:
- [ ] VAD still detects speech
- [ ] Gemini understands (noise-robust)
- [ ] No audio corruption

---

### ✅ 5.4 Rapid Interruption (Barge-in)

**Test**: Start speaking while Gemini is responding

**Expected**:
- [ ] Gemini stops speaking
- [ ] New input is processed
- [ ] No audio overlap/corruption

**Backend Logs**:
```
⚡ User interrupt detected
```

---

### ✅ 5.5 Invalid Function Arguments

**Test**: Say something that triggers function with wrong data
**Say**: "Set a timer for banana minutes" (invalid)

**Expected**:
- [ ] Gemini handles gracefully
- [ ] Asks for clarification
- [ ] No backend crash

---

## 📊 Phase 6: Performance Validation

### ✅ 6.1 Latency Measurement

**Test**: Measure time from speaking to hearing response

**Target Metrics**:
- [ ] First audio chunk < 1000ms
- [ ] Complete response < 3000ms
- [ ] Function execution < 100ms

**Check Logs**:
```bash
curl http://localhost:8000/api/voice/live/metrics
```

Look for:
```json
{
  "status": "operational",
  "connection_quality": "good",
  ...
}
```

---

### ✅ 6.2 Memory Usage

**Test**: Have 10+ conversations in a row

**Check**:
- [ ] No memory leaks
- [ ] Backend RAM stable
- [ ] Frontend RAM stable
- [ ] Sessions cleanup properly

```bash
# Check sessions after each conversation
curl http://localhost:8000/api/voice/live/sessions
# Should show count=1 during, count=0 after disconnect
```

---

### ✅ 6.3 Concurrent Sessions

**Test**: Open 3 browser tabs with voice assistant

**Check**:
- [ ] All 3 connect successfully
- [ ] Independent sessions (different IDs)
- [ ] No cross-talk between sessions
- [ ] Backend handles load

```bash
curl http://localhost:8000/api/voice/live/sessions
# Should show count=3
```

---

## ✅ Final Checklist Summary

### Backend
- [x] Server starts without errors
- [x] Health endpoints respond correctly
- [x] CORS is enabled
- [x] WebSocket echo works
- [x] Voice WebSocket connects
- [x] Gemini API initializes

### Frontend
- [ ] App compiles and runs
- [ ] Microphone permission granted
- [ ] WebSocket connects
- [ ] Audio recording works
- [ ] Audio playback works
- [ ] State management correct

### Voice Interaction
- [ ] Basic greeting works
- [ ] Recipe search executes
- [ ] Timer setting executes
- [ ] Arabic works (with Arabic response)
- [ ] French works (with French response)
- [ ] English works (with English response)

### Error Handling
- [ ] Disconnection handled gracefully
- [ ] Reconnection works automatically
- [ ] Long silence doesn't break
- [ ] Background noise handled
- [ ] Interruption (barge-in) works

### Performance
- [ ] Response latency < 3s
- [ ] No memory leaks
- [ ] Concurrent sessions work
- [ ] Function execution < 100ms
- [ ] Audio quality is clear

---

## 🎯 Success Criteria

**Your AI assistant is production-ready when ALL of the following are true:**

1. ✅ **Connection**: WebSocket connects on first try
2. ✅ **Audio**: Clear input and output (no distortion)
3. ✅ **Functions**: Recipe search and timer work
4. ✅ **Languages**: Responds in same language as user
5. ✅ **Performance**: Response within 3 seconds
6. ✅ **Stability**: No crashes after 10 conversations
7. ✅ **Error Recovery**: Reconnects after network issue
8. ✅ **Logs**: Clean logs with emoji indicators

---

## 📝 Issue Tracking Template

If you find issues, document them using this format:

```markdown
### Issue: [Brief Description]

**Phase**: [Which phase from checklist]
**Test**: [Which specific test]

**Expected**:
[What should happen]

**Actual**:
[What actually happened]

**Frontend Logs**:
```
[Paste browser console output]
```

**Backend Logs**:
```
[Paste terminal output]
```

**Screenshots**: [If applicable]

**Reproducible**: [Always / Sometimes / Once]

**Impact**: [Critical / High / Medium / Low]
```

---

## 🔄 Regression Testing

After any code changes, re-run these quick tests:

**Quick Smoke Test** (2 minutes):
1. ✅ Health endpoint
2. ✅ WebSocket connection
3. ✅ One voice interaction
4. ✅ One function call

**Full Regression** (15 minutes):
Run entire checklist

---

## 📈 Performance Benchmarks

Compare your results to ChefCode production:

| Metric | ChefCode | Your Target | Your Actual |
|--------|----------|-------------|-------------|
| Connection Time | ~1.2s | < 2s | _____ |
| Audio Latency | 500-800ms | < 1s | _____ |
| Turn Completion | 1.5-2.5s | < 3s | _____ |
| Function Exec | 50-100ms | < 100ms | _____ |
| Memory Usage | Stable | Stable | _____ |
| Error Rate | < 1% | < 1% | _____ |

---

**Testing Checklist Complete!** 🎉

If all checks pass, your AI assistant is ready for production! 🚀

---

*Generated: 2026-02-13*
*Based on: ChefCode v2.2 Production Testing*
