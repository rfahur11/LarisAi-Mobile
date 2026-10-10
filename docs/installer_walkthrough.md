# 📦 LarisAI: Production Build, Windows Desktop & Installer Walkthrough

> **Scope**: Complete end-to-end guide to running on Windows PC, compiling Release binaries, packaging single-file `.exe` setup installers (Inno Setup), portable ZIPs, and Android APKs.  
> **Last Updated**: October 2026  
> **Platform**: Windows 10/11 (x64) & Android (arm64/universal)

---

## 📋 Table of Contents
1. [Prerequisites & Environment Verification](#1-prerequisites--environment-verification)
2. [Running & Debugging on Windows / PC](#2-running--debugging-on-windows--pc)
3. [Building the Windows Desktop Release Binary](#3-building-the-windows-desktop-release-binary)
4. [Building the Standalone Setup Wizard (.exe Installer)](#4-building-the-standalone-setup-wizard-exe-installer)
5. [Automated 1-Click Build Scripts](#5-automated-1-click-build-scripts)
6. [Building the Android APK](#6-building-the-android-apk)
7. [Windows Gotchas & Troubleshooting](#7-windows-gotchas--troubleshooting)
8. [Merchant Distribution & Licensing Runbook](#8-merchant-distribution--licensing-runbook)

---

## ⚙️ 1. Prerequisites & Environment Verification

### A. Redirect Flutter Pub Cache (Crucial for D:\ Drive)
Because the workspace resides on drive `D:\`, redirect `$env:PUB_CACHE` in PowerShell to prevent cross-drive caching delays and permission collisions:

```powershell
$env:PUB_CACHE = "D:\flutter_pub_cache"
```

### B. Visual Studio C++ Workload
Building Windows desktop applications with Flutter requires Visual Studio 2022 / Community with the **Desktop development with C++** workload.

Verify via `flutter doctor`:
```powershell
flutter doctor -v
```
You should see:
```text
[√] Visual Studio - develop Windows apps (Visual Studio Community 2022/2026)
    • Visual Studio Community
    • Desktop development with C++
```

### C. Enable Windows Developer Mode
Ensure Developer Mode is active on Windows:
- Press `Win + I` ➔ **System** (or **Privacy & security**) ➔ **For developers** ➔ **Developer Mode = ON**.

### D. Inno Setup 6 (Installer Generator)
Inno Setup is used to compile the standalone `LarisAI_Kasir_Windows_Setup_v1.0.0.exe` wizard installer.

**Option 1: 1-Line CLI Install via Winget (Recommended)**:
```powershell
winget install --id JRSoftware.InnoSetup -e --silent --accept-source-agreements --accept-package-agreements
```
*Note: Winget installs Inno Setup to: `$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe`.*

**Option 2: Manual Download**:
Download and install Inno Setup 6 from the official site: https://jrsoftware.org/isinfo.php.

---

## 💻 2. Running & Debugging on Windows / PC

You can test and run LarisAI directly as a native Windows desktop app during development:

### A. Run in Development Mode (with Hot Reload)
#### ⚡ 1-Line PowerShell:
```powershell
cd d:\porto\larisAi\LarisAi-Mobile; $env:PUB_CACHE = "D:\flutter_pub_cache"; flutter run -d windows
```

- **Hot Reload**: Press `r` in the terminal for instant UI updates.
- **Hot Restart**: Press `R` in the terminal to reset state and re-initialize services.
- **Responsive Window**: Drag to resize between Mobile portrait and Desktop/Tablet POS layout.

### B. Directly Launching the Compiled Release Binary
Once built, you can run the executable directly without Flutter or VS Code:
```powershell
.\build\windows\x64\runner\Release\larisai_mobile.exe
```

---

## 🔨 3. Building the Windows Desktop Release Binary

To compile the optimized, production AOT (Ahead-Of-Time) binary for 64-bit Windows:

#### ⚡ 1-Line PowerShell:
```powershell
cd d:\porto\larisAi\LarisAi-Mobile; $env:PUB_CACHE = "D:\flutter_pub_cache"; flutter build windows --release
```

### Structure of the Compiled Release Folder:
The output is created at: `d:\porto\larisAi\LarisAi-Mobile\build\windows\x64\runner\Release\`

| File / Folder | Purpose |
| :--- | :--- |
| `larisai_mobile.exe` | Main application executable binary |
| `flutter_windows.dll` | Flutter desktop rendering engine (Skia/Impeller) |
| `sqlite3.dll` | Embedded SQLite C engine for offline local storage |
| `pdfium.dll` & `printing_plugin.dll` | Thermal receipt rendering & PDF printing engine |
| `share_plus_plugin.dll` | Windows native file & receipt sharing handler |
| `url_launcher_windows_plugin.dll` | Browser launcher for documentation & links |
| `data/` | App assets, Flutter blobs, fonts, shaders, and icons |

> ⚠️ **Important Architecture Rule**: `larisai_mobile.exe` **cannot** run in isolation if copied alone to another computer. It requires the accompanying `.dll` files and `data/` folder. This is why you must package it into a Setup Wizard (`.exe`) or a Portable ZIP!

---

## 🚀 4. Building the Standalone Setup Wizard (.exe Installer)

The project includes a pre-configured Inno Setup script at: `windows/installer.iss`.

### Features of the Installer:
- 🛡️ **Single Self-Contained `.exe` File**: Easy to download and send via Google Drive, Telegram, or flash drive.
- 🗜️ **Ultra Compression (LZMA2)**: Compresses the ~35 MB build folder down to **~14.7 MB**.
- 🖥️ **Desktop & Start Menu Shortcuts**: Automatically adds desktop icons and Start Menu entries with high-resolution app branding (`app_icon.ico`).
- 🧹 **Integrated Uninstaller**: Cleanly registers in Windows Settings / Control Panel (**Installed Apps / Add or Remove Programs**).
- 🚀 **Auto Launch**: Automatically offers to start LarisAI Kasir upon setup completion.

### Compiling the Installer via CLI (1-Line Commands):

> [!NOTE]
> **PowerShell 1-Line Syntax**: In Windows PowerShell, multiple commands are chained using `;` (semicolon), **not** `&`. (In PowerShell, `&` is the call operator used before quoted executable paths).

#### ⚡ 1-Line PowerShell (Recommended - Works from any folder):
```powershell
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" "d:\porto\larisAi\LarisAi-Mobile\windows\installer.iss"
```

#### ⚡ 1-Line PowerShell with `cd`:
```powershell
cd d:\porto\larisAi\LarisAi-Mobile; & "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" windows\installer.iss
```

#### If Inno Setup was installed in Program Files:
```powershell
cd d:\porto\larisAi\LarisAi-Mobile; & "C:\Program Files\Inno Setup 6\ISCC.exe" windows\installer.iss
```

#### ⚡ 1-Line for Classic CMD (Command Prompt):
```cmd
cd /d d:\porto\larisAi\LarisAi-Mobile && "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" windows\installer.iss
```

### Resulting Output:
```text
build\dist\LarisAI_Kasir_Windows_Setup_v1.0.0.exe (~14.7 MB)
```

---

## ⚡ 5. Automated 1-Click Build Scripts

We have provided ready-to-run automation scripts in `scripts/`:

### A. Windows Only (Build Binary + EXE Installer + Portable ZIP)
Run the dedicated Windows packaging script:
```powershell
cd d:\porto\larisAi\LarisAi-Mobile
.\scripts\build_windows_installer.ps1
```
This script automatically:
1. Detects `ISCC.exe` across user and system directories (and attempts auto-install via winget if missing).
2. Runs `flutter build windows --release`.
3. Compiles `LarisAI_Kasir_Windows_Setup_v1.0.0.exe`.
4. Creates `LarisAI_Windows_x64_Portable_v1.0.0.zip`.
5. Prints a table of ready-to-distribute packages.

### B. All-in-One Multi-Platform Script (Android + Windows)
To build both Android APK and Windows packages in one execution:

```powershell
$env:PUB_CACHE = "D:\flutter_pub_cache"
cd d:\porto\larisAi\LarisAi-Mobile

Write-Host "📱 [1/3] Building Android Universal APK..." -ForegroundColor Cyan
flutter build apk --release

Write-Host "💻 [2/3] Building Windows Desktop Release..." -ForegroundColor Cyan
flutter build windows --release

Write-Host "📦 [3/3] Generating Setup Wizard and Packages..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "build\dist" | Out-Null
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "build\dist\LarisAI_Mobile_Universal_v1.0.0.apk" -Force

# Compile Inno Setup
$iscc = if (Test-Path "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") { "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" } else { "C:\Program Files\Inno Setup 6\ISCC.exe" }
& "$iscc" "windows\installer.iss"

# Portable ZIP
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "build\dist\LarisAI_Windows_x64_Portable_v1.0.0.zip" -Force

Write-Host "✅ All distribution packages ready in: build\dist\" -ForegroundColor Green
```

---

## 📱 6. Building the Android APK

### Option A: Universal Release APK (Recommended for WhatsApp sharing)
Contains all CPU architectures (`armeabi-v7a`, `arm64-v8a`, `x86_64`) so merchants on any Android smartphone or tablet can install it directly.

#### ⚡ 1-Line PowerShell:
```powershell
cd d:\porto\larisAi\LarisAi-Mobile; $env:PUB_CACHE = "D:\flutter_pub_cache"; flutter build apk --release
```
- **Output**: `build\app\outputs\flutter-apk\app-release.apk` (~45 MB)

### Option B: Split ABI APKs (Smaller file size)
```powershell
flutter build apk --split-per-abi
```
- Modern 64-bit phones: `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (~22 MB)

---

## ⚠️ 7. Windows Gotchas & Troubleshooting

### 1. "Windows protected your PC" (SmartScreen Warning)
- **Cause**: Windows SmartScreen flags newly compiled executables that do not yet have a commercial EV Code Signing Certificate.
- **Solution for Merchants/Users**:
  1. Click **More info** (*Informasi selengkapnya*).
  2. Click **Run anyway** (*Tetap jalankan*).
  3. The installer runs normally. Once installed, future launches do not show this prompt.

### 2. Windows Defender Firewall Prompt (LAN Mode)
- **Cause**: When connecting to or hosting a Dev LAN server on port 8080 or making network API calls, Windows may display a firewall prompt.
- **Solution**:
  - Tick the checkbox **Private networks, such as my home or work network** (*Jaringan privat*).
  - Click **Allow access** (*Izinkan akses*).

### 3. Visual Studio C++ Toolchain Missing
- **Error**: `Visual Studio is missing necessary components to build Windows desktop applications`.
- **Solution**:
  1. Open **Visual Studio Installer**.
  2. Click **Modify** on your Visual Studio 2022 instance.
  3. Under Workloads, ensure **Desktop development with C++** is checked.
  4. Ensure **MSVC v143 - VS 2022 C++ x64/x86 build tools** and **Windows 10/11 SDK** are selected on the right panel.
  5. Click **Modify** and restart your PowerShell terminal.

### 4. Portable Version File Locking
- When updating a portable ZIP installation, ensure `larisai_mobile.exe` is completely closed before overwriting files to prevent `File in use` errors.

---

## 📋 8. Merchant Distribution & Licensing Runbook

| Distribution Channel | Target File | Recommended Delivery |
| :--- | :--- | :--- |
| **Windows PC Kasir (Standard)** | `LarisAI_Kasir_Windows_Setup_v1.0.0.exe` | Google Drive / Direct Website Download / USB Flash Drive |
| **Windows PC Kasir (No Admin)** | `LarisAI_Windows_x64_Portable_v1.0.0.zip` | Extract and run `larisai_mobile.exe` without installation |
| **Android Smartphone / Tablet** | `LarisAI_Mobile_Universal_v1.0.0.apk` | WhatsApp Document attachment / Direct Download |

### License Activation Flow:
1. Merchant installs and opens LarisAI on their PC or Android device.
2. Go to **Settings > Lisensi**.
3. Merchant provides their unique **Machine ID** (e.g., `LRS-A1B2-C3D4-E5F6`).
4. Generate the SHA-256 Serial Key and provide it to the merchant for permanent offline/cloud activation.
