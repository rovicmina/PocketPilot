#!/usr/bin/env python3
"""
Verification script to check that all required files for Google Play publishing are present.
"""

import os
import sys

def check_file_exists(filepath):
    """Check if a file exists and return status emoji"""
    if os.path.exists(filepath):
        return "✅"
    else:
        return "❌"

def main():
    print("=" * 60)
    print("GOOGLE PLAY PUBLISHING FILES VERIFICATION")
    print("=" * 60)
    print()
    
    # List of required files
    required_files = [
        ("Privacy Policy", "PRIVACY_POLICY.md"),
        ("Terms of Service", "TERMS_OF_SERVICE.md"),
        ("Data Safety Disclosure", "DATA_SAFETY_DISCLOSURE.md"),
        ("Store Listing", "STORE_LISTING.md"),
        ("Release Notes", "RELEASE_NOTES.md"),
        ("Content Rating Questionnaire", "CONTENT_RATING_QUESTIONNAIRE.md"),
        ("Promotional Assets Guide", "PROMOTIONAL_ASSETS_GUIDE.md"),
        ("Google Play Publishing Checklist", "GOOGLE_PLAY_PUBLISHING_CHECKLIST.md"),
        ("Support Documentation", "SUPPORT_DOCUMENTATION.md"),
        ("Build Script", "build_release.bat"),
        ("Signing Guide", "SIGNING_GUIDE.md"),
        ("App Icon", "assets/logo.png"),
        ("Keystore File", "pocketpilot-key.jks"),
        ("Feature Graphic", "promotional-assets/feature-graphic.png"),
        ("Promotional Assets README", "promotional-assets/README.md"),
        ("Screenshots README", "promotional-assets/screenshots/README.md"),
        ("Video README", "promotional-assets/video/README.md"),
        ("Feature Graphic Generator", "generate_feature_graphic.py"),
        ("Screenshot Helper", "take_screenshots.py"),
        ("Screenshot Helper Batch", "take_screenshots.bat"),
        ("Complete File List", "GOOGLE_PLAY_PUBLISHING_FILE_LIST.md"),
        ("Final Checklist", "FINAL_PUBLISHING_CHECKLIST.md"),
        ("Publishing Summary", "GOOGLE_PLAY_PUBLISHING_SUMMARY.md"),
        ("Promotional Assets Checklist", "PROMOTIONAL_ASSETS_CHECKLIST.md")
    ]
    
    # Check each file
    all_files_present = True
    print("Checking required files:")
    print("-" * 40)
    
    for name, filepath in required_files:
        status = check_file_exists(filepath)
        print(f"{status} {name}: {filepath}")
        if status == "❌":
            all_files_present = False
    
    print()
    print("-" * 40)
    if all_files_present:
        print("✅ ALL REQUIRED FILES ARE PRESENT")
        print()
        print("Next steps:")
        print("1. Create screenshots of your app")
        print("2. (Optional) Create a promo video")
        print("3. Build your release version with build_release.bat")
        print("4. Upload all assets to Google Play Console")
        print("5. Submit your app for review")
    else:
        print("❌ SOME FILES ARE MISSING")
        print("Please check the list above and ensure all required files are present.")
    
    print()
    print("For detailed instructions, see GOOGLE_PLAY_PUBLISHING_FILE_LIST.md")

if __name__ == "__main__":
    main()