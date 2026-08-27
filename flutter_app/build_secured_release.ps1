# ==============================================================================
# T7 HealthVault - Secured & Obfuscated Release Build Script (PowerShell)
# Copyright (c) 2026 M M Bharath / T7 HealthVault. All Rights Reserved.
# ==============================================================================

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " [T7 HealthVault] Starting Secured Production Release Build" -ForegroundColor Green
Write-Host " 1. Flutter Code Obfuscation (--obfuscate)" -ForegroundColor Yellow
Write-Host " 2. Isolated Debug Symbols (--split-debug-info)" -ForegroundColor Yellow
Write-Host " 3. Android R8 / ProGuard Minification & Resource Shrinking" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan

$SymbolDir = "build/app/outputs/symbols"
if (!(Test-Path -Path $SymbolDir)) {
    New-Item -ItemType Directory -Path $SymbolDir -Force | Out-Null
}

Write-Host "Cleaning previous build..." -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host "Compiling Obfuscated Release APK..." -ForegroundColor Cyan
flutter build apk --release --obfuscate --split-debug-info="$SymbolDir"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[SUCCESS] Secured APK successfully built!" -ForegroundColor Green
    Write-Host "APK Location: flutter_app/build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor White
    Write-Host "Symbol Maps:  flutter_app/$SymbolDir" -ForegroundColor White
} else {
    Write-Host "`n[ERROR] Build encountered errors. Please check the logs." -ForegroundColor Red
}
