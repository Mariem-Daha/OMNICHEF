# Microphone Not Opening - Diagnostic Protocol

## Issue

Mic doesn't open when you tap the orb → No audio input → No response

## Diagnosis Added

I've added comprehensive logging to track exactly what's failing.

---

## Run This Test

### Step 1: Clear Previous Logs
```bash
cd frontend
flutter clean
flutter pub get
```

### Step 2: Run with Verbose Logging
```bash
flutter run -v
```

### Step 3: Reproduce the Issue

1. App opens
2. Open voice mode
3. **Wait for greeting to finish**
4. **Look at current state displayed in UI** (should say "READY")
5. **Tap the orb**
6. **Watch console output**

---

## Expected Log Sequence

### On App Start:
```
🎤 Initializing Gemini Live Service...
🌐 Platform: Native
✅ Audio player initialized
✅ Gemini Live Service initialized
🔌 Connecting to Gemini Live API: ws://127.0.0.1:8000/api/voice/ws
✅ WebSocketChannel created
✅ Received connected confirmation from server
✅ Session connected: live_20260213_xxxxx
🔄 DEBUG: State after connection: connected
```

**Expected UI state:** "READY"

---

### When You Tap Orb:
```
🎯 DEBUG: Orb tapped - Current state: connected
🎯 DEBUG: isConnected: true
🎤 DEBUG: Attempting to start listening...
🔍 DEBUG: startListening() called
🔍 DEBUG: isConnected = true
🔍 DEBUG: current state = connected
🔍 DEBUG: recorder = initialized
🔍 DEBUG: channel = exists
🔍 DEBUG: sessionId = live_20260213_xxxxx
✅ All checks passed - starting recorder...
🎤 Starting audio streaming...
✅ Audio streaming started
🎤 DEBUG: Start listening result: true
```

**Expected UI state:** "LISTENING..."

---

## What to Check

### Check 1: State After Connection

**Look for this log:**
```
✅ Session connected: live_20260213_xxxxx
🔄 DEBUG: State after connection: connected
```

**If you see "connected":** ✅ Connection works

**If you see something else:** ❌ State problem - share the exact state

---

### Check 2: When You Tap Orb

**Look for this:**
```
🎯 DEBUG: Orb tapped - Current state: ???
```

**Possible states:**

#### ✅ State: "connected" → GOOD
Mic should start. If it doesn't, check next logs.

#### ❌ State: "speaking" → PROBLEM
Greeting never finished. Audio playback stuck.

**Solution:** Check if audio playback callback is firing.

#### ❌ State: "disconnected" → PROBLEM
Connection lost.

**Solution:** Backend crashed or connection dropped.

#### ❌ State: "listening" → PROBLEM
Already listening (shouldn't happen).

**Solution:** State management bug.

---

### Check 3: Recorder Status

**Look for:**
```
🔍 DEBUG: recorder = ???
```

**Possible values:**

#### ✅ "initialized" → GOOD
Recorder is ready.

#### ❌ "NULL" → PROBLEM
Recorder failed to initialize.

**Solution:**
- Check microphone permissions
- Windows: Settings → Privacy → Microphone → Allow desktop apps
- Restart app after granting permission

---

### Check 4: Connection Status

**Look for:**
```
🔍 DEBUG: isConnected = ???
```

**If false:**
- Backend not running
- WebSocket connection failed
- Network issue

**Check backend is running:**
```bash
curl http://127.0.0.1:8000/api/voice/test
```

Should return: `{"status":"ok"}`

---

### Check 5: Why Mic Blocked

**If you see this:**
```
❌ BLOCKED: Not connected to server
```
**Problem:** WebSocket not connected
**Solution:** Restart backend, check connection logs

---

**If you see this:**
```
❌ BLOCKED: Invalid state: speaking (must be connected)
```
**Problem:** Greeting audio still playing or stuck
**Solution:** Audio playback callback not firing

---

**If you see this:**
```
❌ BLOCKED: Recorder not initialized
```
**Problem:** Microphone initialization failed
**Solution:** Check permissions, restart app

---

## Common Causes

### Cause 1: Audio Playback Never Completes

**Symptom:**
- Greeting plays
- State stays "speaking" forever
- Orb tap shows: `Invalid state: speaking`

**Why:**
- `onAudioPlaybackComplete()` callback never fires
- State stuck in "speaking"

**Fix:**
Look for this log after greeting plays:
```
🔄 DEBUG: onAudioPlaybackComplete() called
🔄 DEBUG: State changed to connected after audio playback
```

**If missing:**
- Audio player crashed
- Callback not wired correctly
- Audio data empty

---

### Cause 2: State Never Becomes "Connected"

**Symptom:**
- Connection happens
- State shows: "disconnected" or "connecting"
- Never transitions to "connected"

**Why:**
- Backend not sending "connected" message
- Frontend not receiving it
- WebSocket message handler broken

**Fix:**
Check backend logs for:
```
📤 Sent connection confirmation: live_20260213_xxxxx
```

If missing, backend WebSocket handler has issue.

---

### Cause 3: Recorder Initialization Failed

**Symptom:**
- Everything connects
- State is "connected"
- But `recorder = NULL`

**Why:**
- Microphone permission denied
- Platform-specific recorder creation failed
- Audio driver issue

**Fix:**
Check logs for:
```
🎤 Initializing Gemini Live Service...
✅ Audio player initialized
```

**If you see:**
```
❌ Recorder initialization failed
⚠️ Continuing without recorder...
```

**Solution:** Microphone not available
- Grant permissions
- Check device has microphone
- Restart app

---

### Cause 4: Greeting Never Sent

**Symptom:**
- No greeting at all
- State immediately "connected"
- Mic still doesn't work

**Why:**
- Backend not sending initial greeting
- System prompt not configured to greet

**This is GOOD:** State machine is working
**Problem is elsewhere:** Check recorder

---

## What to Share With Me

Copy and paste these sections from your console:

### 1. Initialization Logs
```
[Paste everything from "🎤 Initializing" to "✅ Session connected"]
```

### 2. Orb Tap Logs
```
[Paste everything from "🎯 DEBUG: Orb tapped" onwards]
```

### 3. Current State When Tapping
```
What does the UI badge show when you tap?
- "READY"?
- "SPEAKING..."?
- "CONNECTED"?
- Something else?
```

### 4. Any Errors
```
[Paste any red error messages or ❌ logs]
```

---

## Quick Diagnostic Commands

### Test 1: Backend Running?
```bash
curl http://127.0.0.1:8000/api/voice/test
```
**Expected:** `{"status":"ok"}`

### Test 2: Check Recorder
In your Flutter console, after app starts, look for:
```
🔍 DEBUG: recorder = initialized
```

### Test 3: Check Permissions (Windows)
```powershell
# Check if app has mic permission
Get-AppxPackage -AllUsers | Select Name, PackageFullName
```

Then:
Settings → Privacy → Microphone → ON

---

## Next Steps

1. **Run the app**
2. **Copy the logs** (especially the 🎯 DEBUG and 🔍 DEBUG lines)
3. **Paste them here**
4. I'll tell you exactly which condition is failing

---

## Predicted Issues

Based on "greeting plays but mic doesn't open", I predict:

**90% chance:** State stuck in "speaking" because `onAudioPlaybackComplete()` not firing

**8% chance:** Recorder is null (permissions issue)

**2% chance:** Connection issue (but greeting worked, so unlikely)

**Share the logs and I'll confirm.**
