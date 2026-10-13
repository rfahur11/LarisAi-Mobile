# ==============================================================================
# LarisAI All-in-One Multi-Platform Packager (Android APK + Windows All)
# ==============================================================================
# Builds:
#  1. Android Universal APK (build\dist\LarisAI_Mobile_Universal_v1.0.0.apk)
#  2. Windows Desktop Release Binary (build\windows\x64\runner\Release)
#  3. Windows Setup Wizard Installer (build\dist\LarisAI_Kasir_Windows_Setup_v1.0.0.exe)
#  4. Windows Portable ZIP (build\dist\LarisAI_Windows_x64_Portable_v1.0.0.zip)
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\.."

Set-Location $ProjectRoot
$env:PUB_CACHE = "D:\flutter_pub_cache"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   LarisAI - Unified Multi-Platform Build All             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$DistDir = "$ProjectRoot\build\dist"

# Clean old artifacts in build\dist automatically
Write-Host "[*] Cleaning old artifacts in build\dist..." -ForegroundColor DarkGray
if (Test-Path $DistDir) {
    Remove-Item -Path "$DistDir\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

# ------------------------------------------------------------------------------
# 1. Android Release APK
# ------------------------------------------------------------------------------
Write-Host "`n[1/4] Compiling Android Universal Release APK..." -ForegroundColor Yellow
flutter build apk --release

$ApkSource = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $ApkSource) {
    Copy-Item $ApkSource "$DistDir\LarisAI_Mobile_Universal_v1.0.0.apk" -Force
    Write-Host "[OK] Android APK copied to $DistDir\LarisAI_Mobile_Universal_v1.0.0.apk" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Android APK build output not found." -ForegroundColor DarkYellow
}

# ------------------------------------------------------------------------------
# 2. Windows Desktop Release
# ------------------------------------------------------------------------------
Write-Host "`n[2/4] Compiling Windows Desktop Release Binary..." -ForegroundColor Yellow
flutter build windows --release

$ReleaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path "$ReleaseDir\larisai_mobile.exe")) {
    Write-Host "[ERROR] Windows desktop compilation failed." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Windows Desktop binary compiled." -ForegroundColor Green

# ------------------------------------------------------------------------------
# 3. Windows Setup Wizard (.exe Installer via Inno Setup)
# ------------------------------------------------------------------------------
Write-Host "`n[3/4] Compiling Windows Setup Wizard (.exe Installer)..." -ForegroundColor Yellow
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
    if ($whereIscc) { $IsccExe = $whereIscc.Source }
}

if ($IsccExe) {
    & "$IsccExe" "windows\installer.iss"
    Write-Host "[OK] Setup Wizard compiled." -ForegroundColor Green
} else {
    Write-Host "[!] Inno Setup compiler (ISCC.exe) not found. Skipping installer exe creation." -ForegroundColor DarkYellow
    Write-Host "    Install Inno Setup: winget install JRSoftware.InnoSetup" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 4. Windows Portable ZIP Archive
# ------------------------------------------------------------------------------
Write-Host "`n[4/4] Creating Windows Portable ZIP Archive..." -ForegroundColor Yellow
$ZipTarget = "$DistDir\LarisAI_Windows_x64_Portable_v1.0.0.zip"
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipTarget -Force
Write-Host "[OK] Portable ZIP created: $ZipTarget" -ForegroundColor Green

# ------------------------------------------------------------------------------
# Output Summary
# ------------------------------------------------------------------------------
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   ALL ARTIFACTS BUILT SUCCESSFULLY! Ready in:            " -ForegroundColor Green
Write-Host "   $DistDir" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

Get-ChildItem -Path $DistDir | Select-Object Name, @{Name="Size (MB)"; Expression={[math]::Round($_.Length / 1MB, 2)}}, @{Name="Full Path"; Expression={$_.FullName}} | Format-Table -AutoSize -Wrap

Write-Host "Ready-to-distribute files:" -ForegroundColor Cyan
Get-ChildItem -Path $DistDir | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host " [x] $($_.Name) ($sizeMB MB)" -ForegroundColor Green
    Write-Host "     Path: $($_.FullName)" -ForegroundColor Gray
}

