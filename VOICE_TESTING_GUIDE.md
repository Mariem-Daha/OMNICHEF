# Voice Assistant Testing Guide

## How to Test the Fixed Voice Assistant

### Step 1: Start the Backend
```bash
cd backend
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Wait for:
```
INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:8000
```

### Step 2: Start the Frontend
```bash
cd frontend
flutter run
```

### Step 3: Open Voice Mode
1. Launch the app
2. Navigate to voice assistant mode
3. Wait for "Ready" state

---

## Expected Behavior

### ✅ Correct Flow:

**Opening:**
```
[Connecting...] → [Ready]
```

**First Interaction:**
```
1. Tap orb → [Listening...] (pulsing animation)
2. Speak: "Show me pasta recipes"
3. Tap orb again → [Thinking...]
4. Backend processes
5. [Speaking...] → AI responds
6. [Ready] → Waiting for next input
```

**Using Suggestion Chips:**
```
1. Tap "Show me Thieboudienne recipe"
2. [Thinking...] → Processes immediately
3. [Speaking...] → Responds with recipe card
4. [Ready]
```

---

## What You Should See (No Errors)

### ✅ Console Output:
```
🎤 Initializing Gemini Live Service...
🌐 Platform: Native
✅ Audio player initialized
✅ Gemini Live Service initialized
🔌 Connecting to Gemini Live API: ws://127.0.0.1:8000/api/voice/ws
✅ WebSocketChannel created
✅ Received connected confirmation from server
✅ Session connected: live_20260213_xxxxx
✅ Connected to Gemini Live API
🎤 Starting audio streaming...
✅ Audio streaming started
🛑 Stopping audio streaming...
✅ Audio streaming stopped
✅ Turn complete - playing buffered audio
🔊 Playing audio on UI thread (xxxxx bytes, 24000Hz)
✅ Audio playback complete
```

### ❌ What Should NOT Appear:
```
❌ Another exception was thrown: Null check operator used on a null value
❌ Platform channel error
❌ Lost connection to device
```

---

## Testing Checklist

### Basic Functionality
- [ ] App launches without crashes
- [ ] Voice mode connects to backend
- [ ] Orb animation plays smoothly
- [ ] Tap orb → mic starts (pulsing effect)
- [ ] Tap orb again → mic stops
- [ ] State changes visible in header badge

### Conversation Flow
- [ ] Speak request → AI responds
- [ ] Mic STOPS after response (no infinite loop)
- [ ] Can tap orb to start next question
- [ ] Suggestion chips work (send text requests)

### Audio Playback
- [ ] AI voice response plays clearly
- [ ] No audio threading errors in console
- [ ] No crackling or distortion
- [ ] Playback completes and state returns to "Ready"

### Function Calling
- [ ] "Show me [recipe name]" → Recipe card appears
- [ ] "Set timer for X minutes" → Timer card appears
- [ ] Function results display correctly

### Error Handling
- [ ] Disconnect/reconnect works
- [ ] Errors shown in SnackBar (not crashes)
- [ ] Can recover from errors

---

## Common Issues & Solutions

### Issue: "Microphone permission not granted"
**Solution:**
- Check device/emulator microphone permissions
- Grant permission when prompted
- Restart app if needed

### Issue: "Connection timeout"
**Solution:**
- Ensure backend is running on `http://127.0.0.1:8000`
- Check firewall settings
- For Android emulator, use `10.0.2.2:8000` instead
- For iOS simulator, use `localhost:8000`

### Issue: No audio playback
**Solution:**
- Check device volume
- Ensure audio player permissions granted
- Check backend logs for Gemini API errors

### Issue: Mic doesn't start
**Solution:**
- Check state is "Ready" before tapping
- Check console for recorder initialization errors
- Verify microphone permissions

---

## Platform-Specific Notes

### Android Emulator
- Use `ws://10.0.2.2:8000/api/voice/ws` instead of localhost
- Enable microphone in emulator settings

### iOS Simulator
- Microphone works on real devices only
- Use text suggestion chips for testing on simulator

### Web
- Browser will request microphone permission
- Use Chrome/Edge for best compatibility
- Check browser console for CORS errors

### Windows/macOS Desktop
- Microphone permission required at OS level
- Check system preferences if recording fails

---

## Debugging Commands

### Check Backend Status
```bash
curl http://127.0.0.1:8000/api/voice/test
# Should return: {"status":"ok","message":"Voice router is working"}
```

### Check Gemini Live Status
```bash
curl http://127.0.0.1:8000/api/voice/live/status
# Returns API configuration and status
```

### Check Active Sessions
```bash
curl http://127.0.0.1:8000/api/voice/live/sessions
# Shows currently connected WebSocket sessions
```

---

## Performance Expectations

### Latency:
- **User speaks** → **Mic stops**: Instant
- **Mic stops** → **AI starts speaking**: 1-3 seconds
- **Total round trip**: 2-5 seconds

### Audio Quality:
- **Input**: 16kHz PCM mono
- **Output**: 24kHz PCM mono (converted to WAV)
- **No distortion or crackling**

### State Transitions:
- **All state changes should be smooth and instant**
- **No flickering or UI glitches**

---

## Example Test Scenarios

### Scenario 1: Recipe Search
```
You: "Show me Thieboudienne recipe"
AI: [Displays recipe card with image]
    "Here's the Thieboudienne recipe."
State: Ready → Ready for next question
```

### Scenario 2: Timer
```
You: "Set a timer for 20 minutes"
AI: [Displays timer card with countdown]
    "Timer set for 20 minutes."
State: Ready → Ready for next question
```

### Scenario 3: Multi-turn Conversation
```
You: "What can I cook with carrots?"
AI: [Displays recipe grid]
    "Found 8 recipes with carrots."

[Tap orb again]

You: "Show me the first one"
AI: [Displays specific recipe card]
    "Opening Carrot Ginger Soup."
```

---

## Success Criteria

### ✅ All Tests Pass When:
1. No crashes or null pointer errors
2. No audio threading errors
3. Smooth conversation flow
4. Mic stops after AI responds (no infinite loop)
5. Audio playback works on UI thread
6. User has full control (tap to speak)
7. Error messages are clear and helpful
8. State transitions are smooth

---

## Next: Implementing the AI Product Architecture

Once basic functionality is confirmed, refer to the AI Product Architect plan to implement:

1. **Intent-based output schema**
2. **Tool-first architecture**
3. **UI component mapping**
4. **Structured response format**
5. **Auto-close behavior**

See the original architecture document for the full production-level design.
