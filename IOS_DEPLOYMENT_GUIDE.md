# PocketPilot iOS Deployment Guide

## Overview
This guide provides instructions for building and deploying the PocketPilot app for iOS devices. Since iOS builds require Xcode which only runs on macOS, this process must be completed on a Mac computer.

## Prerequisites
1. Mac computer with macOS 12.0 or later
2. Xcode 14.0 or later installed
3. Apple Developer account
4. Flutter SDK installed on the Mac
5. The latest PocketPilot project code

## iOS Project Preparation (Already Done)

The iOS project has been prepared with the following configurations:

### Version Information
- Bundle Version (Build Number): 12
- Bundle Version String (Short Version): 1.0.5
- Minimum iOS Deployment Target: 12.0

### Configuration Files Updated
1. [ios/Flutter/Generated.xcconfig](file:///c:/Users/fskrf/Documents/Project/PocketPilot/ios/Flutter/Generated.xcconfig) - Updated build number to 12
2. [ios/Runner/Info.plist](file:///c:/Users/fskrf/Documents/Project/PocketPilot/ios/Runner/Info.plist) - Configured with proper bundle identifiers and versioning
3. Xcode project file - Configured with proper build settings

## Steps to Build iOS App on macOS

### 1. Transfer Project to macOS
Transfer the entire PocketPilot project to your Mac computer using one of these methods:
- Git clone/pull from your repository
- Copy the project folder via external drive
- Use cloud storage (Google Drive, Dropbox, etc.)

### 2. Install Dependencies
Open Terminal and navigate to the project directory, then run:
```bash
cd /path/to/pocketpilot
flutter pub get
cd ios
pod install
```

### 3. Open Project in Xcode
```bash
open ios/Runner.xcworkspace
```

### 4. Configure Signing
1. In Xcode, select the Runner project in the left sidebar
2. Select the Runner target
3. Go to the "Signing & Capabilities" tab
4. Select your Apple Developer team
5. Ensure the Bundle Identifier is set to `com.pocketpilot.app`
6. Xcode should automatically manage signing certificates

### 5. Build the iOS App
You can build the iOS app in different ways depending on your needs:

#### For Testing on Device
1. Connect your iOS device to the Mac
2. Select your device from the device dropdown in Xcode
3. Click the "Run" button (or press Cmd+R) to build and install on the device

#### For Creating an IPA File
1. In Xcode, go to Product > Archive
2. After the archive process completes, the Organizer window will open
3. Select the newly created archive and click "Distribute App"
4. Choose "Development" or "App Store Connect" based on your needs
5. Follow the prompts to export the IPA file

#### Using Flutter Commands (Alternative)
From the project root directory, you can also use Flutter commands:
```bash
# Build for iOS simulator
flutter build ios --simulator

# Build for iOS device (requires code signing)
flutter build ios --release
```

## iOS App Distribution Options

### 1. App Store Distribution
To distribute through the App Store:
1. Create an app record in App Store Connect
2. Archive and upload the app using Xcode Organizer
3. Complete the app store listing information
4. Submit for review

### 2. Ad Hoc Distribution
To distribute to specific devices:
1. Register devices in your Apple Developer account
2. Create an Ad Hoc provisioning profile
3. Archive and export the app using the Ad Hoc profile
4. Distribute the IPA file to registered devices

### 3. Enterprise Distribution
For internal distribution within an organization:
1. Enroll in the Apple Developer Enterprise Program
2. Create an Enterprise provisioning profile
3. Archive and export using the Enterprise profile
4. Distribute through your organization's internal systems

## Troubleshooting

### Common Issues
1. **Pod Installation Errors**: Run `pod repo update` and then `pod install` in the ios directory
2. **Signing Errors**: Ensure your Apple Developer account is properly configured in Xcode
3. **Missing Flutter Plugins**: Run `flutter pub get` and then `cd ios && pod install`

### Build Settings
If you encounter build issues, check these settings in Xcode:
- iOS Deployment Target: Should be 12.0 or higher
- Valid Architectures: Should include arm64 for devices
- Swift Language Version: Should be 5.0

## App Store Requirements

### App Information
- App Name: PocketPilot
- Bundle ID: com.pocketpilot.app
- Version: 1.0.5
- Build: 12

### Metadata
Prepare the following for App Store submission:
1. App description
2. Keywords
3. Screenshots (iPhone and iPad)
4. App icon (1024x1024)
5. Privacy policy URL

### Compliance
Ensure the app complies with App Store guidelines:
- No private API usage
- Proper handling of user data and privacy
- No misleading content
- Stable performance without crashes

## Next Steps
1. Transfer the project to a Mac computer
2. Follow the build instructions above
3. Test the app on iOS devices
4. Prepare App Store listing materials
5. Submit to App Store Connect for review

## Support
For additional help with iOS deployment, refer to the Flutter documentation:
https://docs.flutter.dev/deployment/ios