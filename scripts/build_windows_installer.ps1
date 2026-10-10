# ==============================================================================
# LarisAI Windows Installer & Release Packager
# ==============================================================================
# Builds Flutter Windows Desktop App and compiles single-file Setup EXE (Inno Setup)
# Output: build\dist\LarisAI_Kasir_Windows_Setup_v1.0.0.exe
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\.."

Set-Location $ProjectRoot

# Redirect pub cache to avoid cross-drive cache latency
$env:PUB_CACHE = "D:\flutter_pub_cache"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   LarisAI Kasir - Windows Build & Installer Generator   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Step 1: Check Inno Setup Compiler (ISCC.exe)
Write-Host "`n[1/4] Checking Inno Setup Compiler..." -ForegroundColor Yellow

$IsccPaths = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

$IsccExe = $null
foreach ($path in $IsccPaths) {
    if (Test-Path $path) {
        $IsccExe = $path
        break
    }
}

if (-not $IsccExe) {
    $whereIscc = (Get-Command "ISCC.exe" -ErrorAction SilentlyContinue)
    if ($whereIscc) {
        $IsccExe = $whereIscc.Source
    }
}

if (-not $IsccExe) {
    Write-Host "[!] Inno Setup not found. Attempting auto-installation via winget..." -ForegroundColor Yellow
    winget install --id JRSoftware.InnoSetup -e --silent --accept-source-agreements --accept-package-agreements
    
    foreach ($path in $IsccPaths) {
        if (Test-Path $path) {
            $IsccExe = $path
            break
        }
    }
}

if (-not $IsccExe) {
    Write-Host "[ERROR] Inno Setup compiler could not be located." -ForegroundColor Red
    Write-Host "Please install Inno Setup manually from https://jrsoftware.org/isinfo.php" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found Inno Setup: $IsccExe" -ForegroundColor Green

# Step 2: Build Flutter Windows Release
Write-Host "`n[2/4] Compiling Flutter Windows Desktop (Release)..." -ForegroundColor Yellow
flutter build windows --release

$ReleaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path "$ReleaseDir\larisai_mobile.exe")) {
    Write-Host "[ERROR] Compilation failed. $ReleaseDir\larisai_mobile.exe not found." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Flutter Windows compiled successfully." -ForegroundColor Green

# Step 3: Ensure Output Directory
Write-Host "`n[3/4] Preparing Distribution Directory..." -ForegroundColor Yellow
$DistDir = "build\dist"
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

# Step 4: Compile Inno Setup Script
Write-Host "`n[4/4] Compiling Setup Wizard (.exe Installer)..." -ForegroundColor Yellow
& "$IsccExe" "windows\installer.iss"

# Also create portable ZIP archive
Write-Host "`n[*] Creating Portable ZIP Bundle..." -ForegroundColor Yellow
$ZipTarget = "$DistDir\LarisAI_Windows_x64_Portable_v1.0.0.zip"
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipTarget -Force

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   SUCCESS! All Windows Distribution Packages Ready:     " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Get-ChildItem -Path $DistDir | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
