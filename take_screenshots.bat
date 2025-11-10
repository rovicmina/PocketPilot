@echo off
echo PocketPilot Screenshot Capture Helper
echo ====================================

echo This script provides guidance for capturing screenshots for Google Play Store.
echo.

echo METHOD 1: Using Android Emulator Controls
echo ----------------------------------------
echo 1. Start your Android emulator with the PocketPilot app
echo 2. Navigate to the screen you want to capture
echo 3. Press Ctrl + Shift + S (or click the camera icon in emulator toolbar)
echo 4. Save the screenshot to your computer
echo 5. Move the screenshot to promotional-assets\screenshots\
echo.

echo METHOD 2: Using ADB Commands
echo --------------------------
echo 1. Make sure your emulator is running
echo 2. Open Command Prompt or PowerShell
echo 3. Run the following commands:
echo    adb shell screencap -p /sdcard/screenshot.png
echo    adb pull /sdcard/screenshot.png
echo 4. Rename and move the screenshot to promotional-assets\screenshots\
echo.

echo SUGGESTED SCREENSHOTS FOR POCKETPILOT:
echo -------------------------------------
echo 1. Home dashboard with budget overview
echo 2. Expense tracking interface
echo 3. Financial charts and insights
echo 4. Budget creation screen
echo 5. Calendar view of expenses
echo.

echo SCREENSHOT REQUIREMENTS:
echo -----------------------
echo - Minimum 2 screenshots required
echo - Recommended 4-8 screenshots
echo - Phone screenshots in portrait orientation
echo - Dimensions: Minimum 320px, Maximum 3840px
echo - Format: PNG or JPEG
echo - High quality and representative of app features
echo.

echo For more detailed instructions, run: python take_screenshots.py
echo Or see: promotional-assets\screenshots\README.md