#!/bin/bash

# PocketPilot iOS Build Script
# This script should be run on macOS with Xcode installed

echo "PocketPilot iOS Build Script"
echo "============================"
echo

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "Error: This script must be run on macOS with Xcode installed."
  echo "iOS builds cannot be created on Windows or Linux."
  exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
  echo "Error: Flutter is not installed or not in PATH."
  echo "Please install Flutter and try again."
  exit 1
fi

echo "Building PocketPilot for iOS..."
echo

# Get Flutter packages
echo "1. Getting Flutter packages..."
flutter pub get

# Navigate to iOS directory and install pods
echo "2. Installing iOS pods..."
cd ios
pod install
cd ..

# Build for iOS simulator (for testing)
echo "3. Building for iOS simulator..."
flutter build ios --simulator

echo
echo "Build completed successfully!"
echo
echo "To build for device distribution, use Xcode:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select your signing team in the Runner target"
echo "3. Build and archive the app using Product > Archive"
echo
