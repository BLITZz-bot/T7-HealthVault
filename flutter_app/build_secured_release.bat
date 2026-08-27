@echo off
REM ==============================================================================
REM T7 HealthVault - Secured & Obfuscated Release Build Script (Windows)
REM Copyright (c) 2026 M M Bharath / T7 HealthVault. All Rights Reserved.
REM ==============================================================================

echo [T7 HealthVault] Starting Secured Production Release Build...
echo [T7 HealthVault] 1. Enabling Flutter Code Obfuscation
echo [T7 HealthVault] 2. Splitting and isolating debug symbol maps
echo [T7 HealthVault] 3. Applying Android R8 bytecode minification and shrinking
echo.

set SYMBOL_DIR=build\app\outputs\symbols

if not exist "%SYMBOL_DIR%" mkdir "%SYMBOL_DIR%"

echo Cleaning previous build artifacts...
call flutter clean
call flutter pub get

echo.
echo Building secured APK (Obfuscated)...
call flutter build apk --release --obfuscate --split-debug-info="%SYMBOL_DIR%"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed! Check the console output above.
    exit /b %ERRORLEVEL%
)

echo.
echo ==============================================================================
echo [SUCCESS] Secured APK successfully built!
echo Output APK: flutter_app\build\app\outputs\flutter-apk\app-release.apk
echo Protected Symbols: flutter_app\%SYMBOL_DIR%
echo ==============================================================================
