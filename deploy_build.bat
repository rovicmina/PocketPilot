@echo off
setlocal enabledelayedexpansion

echo PocketPilot Deployment Build Script
echo ====================================

echo Current version: 1.0.5+11
echo.

echo 1. Cleaning previous builds...
flutter clean
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Flutter clean failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo 2. Getting dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Flutter pub get failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo 3. Building release APK with split ABIs...
flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: APK build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo 4. Building universal APK...
flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Universal APK build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo 5. Building Android App Bundle (AAB) for Play Store...
flutter build appbundle --release --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: AAB build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo.
echo Build completed successfully!
echo.
echo Generated files:
echo - build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo - build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
echo - build\app\outputs\flutter-apk\app-release.apk
echo - build\app\outputs\bundle\release\app-release.aab
echo.
echo For Play Store deployment, use the AAB file.
echo For direct APK installation, use the split ABI APKs for smaller downloads.
echo.