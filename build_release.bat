@echo off
echo PocketPilot Release Build Script
echo ================================

echo 1. Cleaning previous builds...
flutter clean

echo 2. Getting dependencies...
flutter pub get

echo 3. Building release APK with split ABIs...
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-tree-shake-icons

echo 4. Building universal APK...
flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons

echo.
echo Build completed successfully!
echo.
echo Generated files:
echo - build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo - build\app\outputs\flutter-apk\app-release.apk
echo.
echo For Play Store deployment, use the split ABI APKs for smaller downloads.