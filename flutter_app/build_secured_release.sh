#!/bin/bash
# ==============================================================================
# T7 HealthVault - Secured & Obfuscated Release Build Script (Unix/macOS)
# Copyright (c) 2026 M M Bharath / T7 HealthVault. All Rights Reserved.
# ==============================================================================

set -e

echo "=============================================================================="
echo " [T7 HealthVault] Starting Secured Production Release Build"
echo " 1. Flutter Code Obfuscation (--obfuscate)"
echo " 2. Isolated Debug Symbols (--split-debug-info)"
echo " 3. Android R8 / ProGuard Minification & Resource Shrinking"
echo "=============================================================================="

SYMBOL_DIR="build/app/outputs/symbols"
mkdir -p "$SYMBOL_DIR"

echo "Cleaning previous build..."
flutter clean
flutter pub get

echo "Compiling Obfuscated Release APK..."
flutter build apk --release --obfuscate --split-debug-info="$SYMBOL_DIR"

echo ""
echo "=============================================================================="
echo "[SUCCESS] Secured APK successfully built!"
echo "APK Location: flutter_app/build/app/outputs/flutter-apk/app-release.apk"
echo "Symbol Maps:  flutter_app/$SYMBOL_DIR"
echo "=============================================================================="
