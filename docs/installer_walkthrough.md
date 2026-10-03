# 📦 LarisAI: Production Build & Installer Walkthrough

> **Scope**: Complete guide to building, packaging, and distributing LarisAI APK (Android) and EXE/Zip (Windows Desktop).  
> **Last Updated**: October 2026

---

## 📋 Table of Contents
1. [Prerequisites & Environment Variables](#1-prerequisites--environment-variables)
2. [Building the Android APK](#2-building-the-android-apk)
3. [Building the Windows Desktop App](#3-building-the-windows-desktop-app)
4. [Packaging the Windows App (Portable ZIP & Inno Setup EXE)](#4-packaging-the-windows-app)
5. [Automated Build Script (PowerShell)](#5-automated-build-script)
6. [Distribution Checklist](#6-distribution-checklist)

---

## ⚙️ 1. Prerequisites & Environment Variables

Because the project lives on drive `D:\`, Flutter pub cache should be redirected to avoid cross-drive compilation errors with Kotlin:

```powershell
# Set pub cache location (Required in Windows PowerShell)
$env:PUB_CACHE = "D:\flutter_pub_cache"
```

Verify your Flutter environment:
```powershell
flutter doctor
```

---

## 📱 2. Building the Android APK

### Option A: Universal Release APK (Recommended for WhatsApp / Drive sharing)
This builds a single APK containing all CPU architectures (`armeabi-v7a`, `arm64-v8a`, `x86_64`). Any customer or merchant can download and install it immediately.

```powershell
cd d:\porto\larisAi\LarisAi-Mobile
$env:PUB_CACHE = "D:\flutter_pub_cache"
flutter build apk --release
```

- **Output Path**:  
  `d:\porto\larisAi\LarisAi-Mobile\build\app\outputs\flutter-apk\app-release.apk`
- **Typical Size**: ~40 - 55 MB

### Option B: Split ABI APKs (Smaller file size for bandwidth-sensitive devices)
```powershell
flutter build apk --split-per-abi
```

- **Output Folder**: `build\app\outputs\flutter-apk\`
- **Files Generated**:
  - `app-arm64-v8a-release.apk` (Recommended for modern 64-bit Android phones, ~22 MB)
  - `app-armeabi-v7a-release.apk` (For older 32-bit phones, ~20 MB)

---

## 💻 3. Building the Windows Desktop App

### Step 1: Compile the Release Binary
Make sure Windows Developer Mode is enabled on your PC (Settings > System > For Developers > Developer Mode = ON).

```powershell
cd d:\porto\larisAi\LarisAi-Mobile
$env:PUB_CACHE = "D:\flutter_pub_cache"
flutter build windows --release
```

- **Output Folder**:  
  `d:\porto\larisAi\LarisAi-Mobile\build\windows\x64\runner\Release\`

### What is inside the `Release` folder?
- `larisai_mobile.exe`: The main application launcher.
- `flutter_windows.dll`: Flutter desktop rendering engine.
- `data/`: App assets (logos, images, SQLite database drivers, fonts).
- Plugin DLLs: `file_picker_windows_plugin.dll`, `url_launcher_windows_plugin.dll`, etc.

> ⚠️ **Important**: `larisai_mobile.exe` cannot run in isolation without its neighboring `.dll` files and `data` folder. Always distribute the complete bundle.

---

## 🎁 4. Packaging the Windows App

### Method A: Portable ZIP Bundle (Zero Installation Required)
Compress the compiled `Release` folder into a single `.zip` file:

```powershell
# Create distribution directory
New-Item -ItemType Directory -Force -Path "d:\porto\larisAi\LarisAi-Mobile\build\dist"

# Compress Release directory into ZIP
Compress-Archive -Path "d:\porto\larisAi\LarisAi-Mobile\build\windows\x64\runner\Release\*" `
  -DestinationPath "d:\porto\larisAi\LarisAi-Mobile\build\dist\LarisAI_Windows_x64_v1.0.0.zip" -Force
```

**User Instructions**:
1. User downloads `LarisAI_Windows_x64_v1.0.0.zip`.
2. Right-click ➔ **Extract All**.
3. Double-click `larisai_mobile.exe` to run. (Can create shortcut to Desktop).

---

### Method B: Single-File Setup Wizard (.exe Installer via Inno Setup)

1. Download **Inno Setup** (Free): https://jrsoftware.org/isinfo.php
2. Use the provided script file: `windows/installer.iss`.
3. Compile via command line or Inno Setup GUI:
   ```cmd
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer.iss
   ```
4. Output: `build\dist\LarisAI_Setup_v1.0.0.exe`.

---

## 🚀 5. Automated Build Script

You can run this all-in-one PowerShell script to build and package both Android and Windows with one command:

```powershell
# Set Cache & Directory
$env:PUB_CACHE = "D:\flutter_pub_cache"
cd d:\porto\larisAi\LarisAi-Mobile

Write-Host "🔨 [1/3] Building Android APK..." -ForegroundColor Cyan
flutter build apk --release

Write-Host "💻 [2/3] Building Windows Release..." -ForegroundColor Cyan
flutter build windows --release

Write-Host "📦 [3/3] Creating Distribution Package..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "build\dist" | Out-Null
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "build\dist\LarisAI_Mobile_v1.0.0.apk" -Force
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "build\dist\LarisAI_Windows_x64_v1.0.0.zip" -Force

Write-Host "✅ All installers ready in: d:\porto\larisAi\LarisAi-Mobile\build\dist\" -ForegroundColor Green
```

---

## 🌐 6. Distribution Checklist

When sending the app to merchants/clients:

1. **WhatsApp Distribution**:
   - Send `LarisAI_Mobile_v1.0.0.apk` directly via WhatsApp Document attachment.
   - For PC, send the download link (Google Drive / Weboz Store: `weboz.my.id/larisai`).
2. **License Activation**:
   - When the user opens the app, guide them to: **Settings > Lisensi**.
   - Copy their unique **Machine ID** (e.g., `LRS-A1B2-C3D4-E5F6`).
   - Generate their SHA-256 Serial Key and provide it for instant activation.
