# PocketPilot - Your Personal Financial Guide

PocketPilot is a Flutter-based personal finance application that helps users track budgets, expenses, and financial goals.

## About

PocketPilot is designed to simplify personal finance management with an intuitive interface and smart budgeting features. The app allows users to:
- Track daily expenses
- Visualize spending patterns with interactive charts
- Receive financial insights
- Monitor financial improvement

## Features

- **Smart Budgeting**: Create personalized budgets based on your income and spending patterns
- **Expense Tracking**: Easily log daily expenses with categorization
- **Financial Insights**: Visualize your spending habits with interactive charts
- **Smart Notifications**: Get timely alerts when approaching budget limits
- **Calendar Integration**: View spending patterns over time
- **Secure & Private**: Your financial data is encrypted and secure

## Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Android Studio or VS Code
- Android device or emulator (API level 23 or higher)
- Windows 10/11 for Windows desktop support

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect an Android device or start an emulator
4. Run `flutter run` to build and deploy the app

## Access on Google Play

PocketPilot is available on Google Play for Android devices.

To install:
- Open the Google Play Store on your Android device.
- Search for "PocketPilot" by "PocketPilot App" (ensure the publisher name matches).
- Tap "Install" to download and install the app.
- Open the app and follow the on-screen instructions to set up your profile and budgets.

If you have a direct link from our website or marketing materials:
- Tap the link on your device to be taken directly to the PocketPilot Google Play Store listing.
- Confirm the app name and publisher before installing.

## Deployment Files

This repository includes all necessary files for Google Play Store deployment:

- `PRIVACY_POLICY.md` - App privacy policy
- `TERMS_OF_SERVICE.md` - Terms of service
- `STORE_LISTING.md` - Google Play Store listing content
- `DATA_SAFETY_DISCLOSURE.md` - Data safety disclosure for Google Play
- `CONTENT_RATING_QUESTIONNAIRE.md` - Content rating questionnaire
- `PROMOTIONAL_ASSETS_GUIDE.md` - Guide for creating promotional assets
- `RELEASE_NOTES.md` - Release notes for the current version
- `GOOGLE_PLAY_PUBLISHING_CHECKLIST.md` - Complete checklist for publishing
- `SUPPORT_DOCUMENTATION.md` - User support documentation

For a complete list of all files generated for Google Play publishing, see [GOOGLE_PLAY_PUBLISHING_FILE_LIST.md](GOOGLE_PLAY_PUBLISHING_FILE_LIST.md).

## Promotional Assets

The `promotional-assets/` directory contains all visual assets required for Google Play Store:

- `feature-graphic.png` - Feature graphic (1024x500 pixels)
- `screenshots/` - Directory for app screenshots (to be created)
- `video/` - Directory for optional promo video (to be created)

See `PROMOTIONAL_ASSETS_GUIDE.md` for detailed requirements and `promotional-assets/README.md` for current status.

## Building for Release

To build the app for release, you can use either the command line or the provided deployment scripts:

### Using Deployment Scripts (Recommended)

```bash
# For Windows users
simple_build.bat

# Windows desktop support
build_windows.bat

# Or the full deployment script (builds all formats)
deploy_build.bat
```

### Using Command Line

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# Build Android App Bundle (for Play Store)
flutter build appbundle --release

# Build APK (for direct installation)
flutter build apk --release

# Build Windows desktop app
flutter build windows --release
```

**Note**: Version 1.0.5+16 has been successfully built and is ready for Google Play Store submission.
See [FINAL_DEPLOYMENT_STATUS.md](FINAL_DEPLOYMENT_STATUS.md) for details on the latest deployment.


## License

This project is licensed under the MIT License - see the LICENSE file for details.