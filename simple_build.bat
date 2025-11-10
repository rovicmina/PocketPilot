@echo off
setlocal enabledelayedexpansion

echo PocketPilot Simple Build Script
echo ===============================

echo Current version: 1.0.4+7
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

echo.
echo Choose build option:
echo 1. Build APK only
echo 2. Build AAB only
echo 3. Build both APK and AAB
echo.

choice /c 123 /m "Select option"
if %ERRORLEVEL% == 3 (
  echo Building both APK and AAB...
  goto build_both
) else if %ERRORLEVEL% == 2 (
  echo Building AAB only...
  goto build_aab
) else (
  echo Building APK only...
  goto build_apk
)

:build_apk
echo Building release APK...
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: APK build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)
echo APK build completed successfully!
echo Output: build\app\outputs\flutter-apk\
goto end

:build_aab
echo Building Android App Bundle (AAB) for Play Store...
flutter build appbundle --release --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: AAB build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)
echo AAB build completed successfully!
echo Output: build\app\outputs\bundle\release\app-release.aab
goto end

:build_both
echo Building release APK...
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: APK build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo Building Android App Bundle (AAB) for Play Store...
flutter build appbundle --release --no-tree-shake-icons
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: AAB build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo.
echo Both builds completed successfully!
echo.
echo Generated files:
echo - build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo - build\app\outputs\bundle\release\app-release.aab
echo.

:end
echo Build process finished.