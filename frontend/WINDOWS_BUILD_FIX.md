# Windows Flutter Build - ATL Fix Required

## Issue
The Windows Flutter build fails with:
```
error C1083: Cannot open include file: 'atlstr.h': No such file or directory
```

This happens because `flutter_secure_storage_windows` requires the ATL (Active Template Library) 
which is not included in the minimal Visual Studio Build Tools installation.

## Solution 1: Install ATL Components (Recommended)

1. Open **Visual Studio Installer**
2. Find **Visual Studio Build Tools 2022**
3. Click **Modify**
4. Go to **Individual components** tab
5. Search for and check:
   - ✅ **C++ ATL for latest v143 build tools (x86 & x64)**
   - ✅ **C++ MFC for latest v143 build tools (x86 & x64)** (optional but recommended)
6. Click **Modify** to install

After installation, run:
```bash
flutter clean
flutter pub get
flutter build windows
```

## Solution 2: Use Alternative Storage (If ATL installation not possible)

Replace `flutter_secure_storage` with `shared_preferences` for non-sensitive data
or use a different storage implementation for Windows.

In `pubspec.yaml`, add:
```yaml
dependencies:
  # ... other deps
  shared_preferences: ^2.2.2  # For non-sensitive preferences
```

Then modify `api_service.dart` to use platform-specific storage:
- Use `flutter_secure_storage` on mobile/web
- Use `shared_preferences` on Windows (less secure but works)

## Solution 3: Use flutter_secure_storage with Windows workaround

Some users have reported success with:
```bash
# Run Visual Studio Developer Command Prompt as Administrator
# Then run flutter build from there
"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
cd C:\Projects\cuisinee\frontend
flutter build windows
```

## Current Status
- **Web**: ✅ Working
- **Android**: Should work (untested)
- **Windows**: ❌ Requires ATL installation

## Notes
This is a known issue with `flutter_secure_storage` on Windows:
- GitHub Issue: https://github.com/mogol/flutter_secure_storage/issues/536
- The plugin uses ATL for secure credential storage on Windows
