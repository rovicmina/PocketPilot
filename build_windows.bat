@echo off
setlocal enabledelayedexpansion

echo PocketPilot Windows Build Script
echo ===============================

echo Current version: 1.0.5+16
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
echo 1. Build Windows Debug
echo 2. Build Windows Release
echo 3. Run on Windows (Debug)
echo.

set /p choice="Enter your choice (1, 2, or 3): "
if "%choice%"=="3" (
  echo Running on Windows (Debug)...
  goto run_windows
) else if "%choice%"=="2" (
  echo Building Windows Release...
  goto build_release
) else (
  echo Building Windows Debug...
  goto build_debug
)

:build_debug
echo Building Windows debug executable...
set LINK=/IGNORE:4099
flutter build windows --debug
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Windows debug build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)
echo Windows debug build completed successfully!
echo Output: build\windows\x64\runner\Debug\
goto end

:build_release
echo Building Windows release executable...
set LINK=/IGNORE:4099
flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Windows release build failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)
echo Windows release build completed successfully!
echo Output: build\windows\x64\runner\Release\
echo.
echo To run the release build, execute:
echo build\windows\x64\runner\Release\pocketpilot.exe
goto end

:run_windows
echo Running on Windows (Debug)...
flutter run -d windows
if %ERRORLEVEL% NEQ 0 (
  echo ERROR: Failed to run on Windows with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)
goto end

:end
echo Windows build process finished.