# PocketPilot Build Script
# This script automates the build process for Android APK and AAB files

Write-Host "Starting PocketPilot build process..." -ForegroundColor Green

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build universal APK
Write-Host "Building universal APK..." -ForegroundColor Yellow
flutter build apk --release --no-tree-shake-icons

# Build split APKs
Write-Host "Building split APKs..." -ForegroundColor Yellow
flutter build apk --release --split-per-abi --no-tree-shake-icons

# Build AAB
Write-Host "Building AAB..." -ForegroundColor Yellow
flutter build appbundle --release --no-tree-shake-icons

Write-Host "Build process completed successfully!" -ForegroundColor Green
Write-Host "Generated files:" -ForegroundColor Cyan
Write-Host "  - Universal APK: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Cyan
Write-Host "  - ARMv7 APK: build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk" -ForegroundColor Cyan
Write-Host "  - ARM64 APK: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" -ForegroundColor Cyan
Write-Host "  - x86_64 APK: build/app/outputs/flutter-apk/app-x86_64-release.apk" -ForegroundColor Cyan
Write-Host "  - AAB: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Cyan
