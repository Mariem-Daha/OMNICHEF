# 🔧 NuGet Installation Guide for Windows

## 📋 **You Have 3 Options**

---

## **Option 1: Install NuGet (Use the Script I Created)** ✅

I've created an automated installation script for you.

### **Steps**:

1. **Open PowerShell as Administrator**
   - Press `Win + X`
   - Click "Windows PowerShell (Admin)" or "Terminal (Admin)"

2. **Run the installation script**:
   ```powershell
   cd "d:\New folder\cuisinee\cuisinee"
   .\install_nuget.ps1
   ```

3. **Close ALL terminals** (important for PATH to update)

4. **Open new terminal and test**:
   ```bash
   nuget help
   # Should show NuGet help
   ```

5. **Build Windows app**:
   ```bash
   cd "d:\New folder\cuisinee\cuisinee\frontend"
   flutter clean
   flutter run -d windows
   ```

---

## **Option 2: Run on Chrome (FASTEST - No NuGet Needed)** 🚀

Bypass NuGet completely and test immediately:

```bash
cd "d:\New folder\cuisinee\cuisinee\frontend"
flutter run -d chrome
```

**Advantages**:
- ✅ No installation needed
- ✅ Works right now
- ✅ Same functionality (voice works on Chrome)
- ✅ Easier debugging (F12 DevTools)

---

## **Option 3: Temporarily Disable flutter_tts**

I can comment out `flutter_tts` from your dependencies so Windows build works immediately.

### **Manual Steps**:

1. **Edit** `frontend/pubspec.yaml`
2. **Find line 26**: `flutter_tts: ^4.2.5`
3. **Change to**: `# flutter_tts: ^4.2.5` (add # at start)
4. **Run**:
   ```bash
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

### **Note**:
- You won't have text-to-speech on Windows
- Voice input will still work
- You can re-enable it later after installing NuGet

---

## 🎯 **My Recommendation**

### **For IMMEDIATE Testing**:
```bash
flutter run -d chrome
```
This lets you test the WebSocket 403 fix **right now** without any installation.

### **For Windows Native** (later):
1. Run the `install_nuget.ps1` script I created
2. Restart terminal
3. `flutter run -d windows`

---

## 📝 **What Each Option Gives You**

| Feature | Chrome | Windows (with NuGet) | Windows (no TTS) |
|---------|--------|----------------------|------------------|
| Voice Input | ✅ | ✅ | ✅ |
| Voice Output | ✅ | ✅ | ❌ |
| WebSocket | ✅ | ✅ | ✅ |
| AI Chat | ✅ | ✅ | ✅ |
| Native Performance | ❌ | ✅ | ✅ |
| Easy Debugging | ✅ | ❌ | ❌ |
| Installation Time | 0 min | 5 min | 2 min |

---

## 🚀 **Quick Commands**

### **Test on Chrome NOW**:
```bash
cd "d:\New folder\cuisinee\cuisinee\frontend"
flutter run -d chrome
```

### **Install NuGet (PowerShell Admin)**:
```powershell
cd "d:\New folder\cuisinee\cuisinee"
.\install_nuget.ps1
```

### **After NuGet is Installed**:
```bash
# Close terminal, open new one
cd "d:\New folder\cuisinee\cuisinee\frontend"
flutter clean
flutter run -d windows
```

---

## 🔍 **Verify NuGet Installation**

After running the script, test:
```bash
nuget help
```

**Expected output**:
```
NuGet Version: x.x.x
usage: NuGet <command> [args] [options]
...
```

---

## ❌ **If Script Fails**

### **Error: "Execution Policy"**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **Error: "Access Denied"**
Make sure you're running PowerShell **as Administrator**

### **Error: "Cannot download"**
Check internet connection or download manually from:
https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

Then:
1. Save to `C:\nuget\nuget.exe`
2. Add `C:\nuget` to PATH manually in System Environment Variables

---

## 💡 **Why Does flutter_tts Need NuGet?**

`flutter_tts` (text-to-speech plugin) has Windows native code that requires:
- NuGet package manager (to download C++ libraries)
- Visual Studio Build Tools (usually included with Flutter)

Chrome doesn't need this because it uses Web Speech API built into the browser.

---

## ✅ **Next Steps After Installation**

Once NuGet is installed or you're running on Chrome:

1. **Make sure backend is running**:
   ```bash
   cd "d:\New folder\cuisinee\cuisinee\backend"
   uvicorn app.main:app --reload
   ```

2. **Run frontend**:
   ```bash
   cd "d:\New folder\cuisinee\cuisinee\frontend"
   flutter run -d chrome  # or -d windows
   ```

3. **Test WebSocket connection** - check browser console (F12)

4. **Test voice assistant** - click microphone and speak!

---

**Choose your path and let me know how it goes!** 🎉
