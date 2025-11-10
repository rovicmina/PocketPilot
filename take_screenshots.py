#!/usr/bin/env python3
"""
Helper script to take screenshots from Android emulator for Google Play Store.
This script provides instructions for taking screenshots on different platforms.
"""

def print_screenshot_instructions():
    print("=" * 60)
    print("SCREENSHOT CAPTURE INSTRUCTIONS FOR ANDROID EMULATOR")
    print("=" * 60)
    print()
    
    print("METHOD 1: Using Android Studio Device Manager")
    print("-" * 40)
    print("1. Open Android Studio")
    print("2. Go to Device Manager (View > Tool Windows > Device Manager)")
    print("3. Start your emulator")
    print("4. Click the three dots (More Options) on the emulator panel")
    print("5. Select 'Screenshot' from the menu")
    print("6. Save the screenshot to promotional-assets/screenshots/")
    print()
    
    print("METHOD 2: Using ADB Command Line")
    print("-" * 40)
    print("1. Make sure ADB is in your PATH")
    print("2. Run this command to take a screenshot:")
    print("   adb shell screencap -p /sdcard/screenshot.png")
    print("3. Pull the screenshot to your computer:")
    print("   adb pull /sdcard/screenshot.png")
    print("4. Move the file to promotional-assets/screenshots/")
    print()
    
    print("METHOD 3: Using Emulator Controls")
    print("-" * 40)
    print("1. In the emulator, click the camera icon in the toolbar")
    print("2. Click 'Save' to save the screenshot")
    print("3. Move the file to promotional-assets/screenshots/")
    print()
    
    print("SCREENSHOT REQUIREMENTS FOR GOOGLE PLAY")
    print("-" * 40)
    print("- Minimum 2 screenshots required")
    print("- Recommended 4-8 screenshots")
    print("- Phone screenshots in portrait orientation")
    print("- Dimensions: Minimum 320px, Maximum 3840px")
    print("- Format: PNG or JPEG")
    print("- High quality and representative of app features")
    print()
    
    print("SUGGESTED SCREENSHOTS FOR POCKETPILOT")
    print("-" * 40)
    print("1. Home dashboard with budget overview")
    print("2. Expense tracking interface")
    print("3. Financial charts and insights")
    print("4. Budget creation screen")
    print("5. Calendar view of expenses")
    print()

if __name__ == "__main__":
    print_screenshot_instructions()