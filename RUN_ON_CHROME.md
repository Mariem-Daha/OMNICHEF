# 🚀 Quick Start - Run on Chrome (No NuGet Needed!)

## ⚡ **2-Minute Setup**

### **Step 1: Start Backend**

Open PowerShell/Terminal:
```bash
cd "d:\New folder\cuisinee\cuisinee\backend"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Wait for:
```
INFO:     Application startup complete.
```

**Keep this terminal open!**

---

### **Step 2: Start Frontend on Chrome**

Open **another** PowerShell/Terminal:
```bash
cd "d:\New folder\cuisinee\cuisinee\frontend"
flutter run -d chrome
```

Chrome will open automatically with your app!

---

## ✅ **Test the Voice Assistant**

1. **Navigate to Voice Assistant** screen in the app
2. **Grant microphone permission** when prompted
3. **Click the microphone button**
4. **Say**: "Hello, find me a recipe for couscous"
5. **Listen** for AI response

---

## 🔍 **Check WebSocket Connection**

### **In Chrome**:
1. Press **F12** to open DevTools
2. Go to **Console** tab
3. Look for:
   ```
   ✅ Gemini Live Service initialized
   🔌 Connecting to WebSocket...
   ✅ WebSocket connected
   💚 Connection confirmed
   ```

### **In Backend Terminal**:
Look for:
```
🔌 New WebSocket connection from 127.0.0.1
✅ WebSocket accepted
✨ Created session: live_...
✅ Connected to Gemini Live API
📤 Sent connection confirmation
```

---

## 🎯 **What Works on Chrome**

| Feature | Status |
|---------|--------|
| Voice Input (Microphone) | ✅ Works |
| Voice Output (Speaker) | ✅ Works |
| WebSocket Connection | ✅ Works |
| AI Chat | ✅ Works |
| Recipe Search | ✅ Works |
| Timer Functions | ✅ Works |
| Multilingual (AR/FR/EN) | ✅ Works |

---

## ❌ **If WebSocket Still Shows 403**

The middleware fix requires backend restart!

1. **Stop backend** (Ctrl+C)
2. **Start fresh**:
   ```bash
   cd "d:\New folder\cuisinee\cuisinee\backend"
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
3. **Refresh browser** (F5)

---

## 🧪 **Test Commands**

### **Test 1: Health Check**
```bash
curl http://localhost:8000/health
```

### **Test 2: Voice Router**
```bash
curl http://localhost:8000/api/voice/test
```

**Expected**:
```json
{
  "status": "ok",
  "message": "Voice router is reachable"
}
```

### **Test 3: WebSocket (if you have wscat)**
```bash
wscat -c ws://localhost:8000/api/voice/ws-test
```

**Expected**:
```
Connected
< {"type":"test","message":"WebSocket connection successful!"}
```

---

## 💬 **Voice Test Scenarios**

### **Test 1: Simple Greeting**
**Say**: "Hello, how are you?"
**Expected**: AI responds in English

### **Test 2: Recipe Search**
**Say**: "Find me a recipe for tagine"
**Expected**: AI searches and speaks results

### **Test 3: Timer**
**Say**: "Set a timer for 10 minutes"
**Expected**: AI confirms timer set

### **Test 4: Arabic**
**Say**: "ابحث عن وصفة كسكس"
**Expected**: AI responds in Arabic

### **Test 5: French**
**Say**: "Trouve-moi une recette"
**Expected**: AI responds in French

---

## 📊 **Performance Expectations**

| Metric | Target | What to Watch |
|--------|--------|---------------|
| Connection | < 2s | Chrome console logs |
| First Response | < 3s | Time to hear AI voice |
| Audio Quality | Clear | No distortion/static |
| Latency | < 1s | Response feels natural |

---

## 🐛 **Troubleshooting**

### **Issue 1: "Microphone permission denied"**
**Fix**: Click browser address bar → Click 🔒 lock icon → Allow microphone

### **Issue 2: "No audio playback"**
**Fix**: Check volume, unmute browser tab, check browser console for errors

### **Issue 3: "WebSocket failed to connect"**
**Fix**:
1. Backend is running?
2. Backend restarted after middleware fix?
3. URL is `ws://127.0.0.1:8000/api/voice/ws`?

### **Issue 4: "CORS error"**
**Fix**: Already fixed in `main.py` - restart backend

---

## 🎉 **Success Indicators**

You'll know it's working when:

✅ **Backend logs**:
```
🔌 New WebSocket connection
✅ WebSocket accepted
✅ Connected to Gemini Live API
🔧 Function call: find_recipe(...)
💬 Gemini: I found 3 recipes...
🔊 Sent audio to client
```

✅ **Browser console**:
```
✅ WebSocket connected
💚 Connection confirmed
Received: {"type":"transcript","text":"..."}
```

✅ **User experience**:
- You speak → AI understands
- AI speaks back clearly
- Recipe search works
- Natural conversation flow

---

## 📁 **Files I Created for You**

1. **[NUGET_INSTALL_GUIDE.md](NUGET_INSTALL_GUIDE.md)** - If you want Windows native later
2. **[install_nuget.ps1](install_nuget.ps1)** - Automated NuGet installer
3. **[WEBSOCKET_403_FIX.md](WEBSOCKET_403_FIX.md)** - Complete troubleshooting
4. **[AI_ASSISTANT_FIX_SUMMARY.md](AI_ASSISTANT_FIX_SUMMARY.md)** - All technical fixes
5. **[QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)** - General startup guide
6. **[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** - Comprehensive tests

---

## 🚀 **Run These Commands NOW**

### **Terminal 1 (Backend)**:
```bash
cd "d:\New folder\cuisinee\cuisinee\backend"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### **Terminal 2 (Frontend)**:
```bash
cd "d:\New folder\cuisinee\cuisinee\frontend"
flutter run -d chrome
```

### **Then**:
- Open browser DevTools (F12)
- Navigate to voice assistant
- Grant mic permission
- Speak to test!

---

**That's it! Chrome doesn't need NuGet, so you can test the WebSocket fix immediately!** 🎉

Let me know what you see in the console! 🔍
