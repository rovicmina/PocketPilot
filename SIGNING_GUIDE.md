# Android App Signing Guide for PocketPilot

## Overview
This guide explains how to set up proper signing keys for releasing your Flutter app to the Google Play Store.

## Step 1: Generate a Keystore

Run the following command in your terminal:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

This command will:
- Create a keystore file named `upload-keystore.jks` in your home directory
- Use RSA algorithm with 2048-bit key size
- Set validity to 10000 days
- Create a key alias named `upload`

You'll be prompted to enter:
1. Keystore password
2. Key password
3. Your personal information (name, organization, etc.)

## Step 2: Create key.properties File

Create a file named `key.properties` in the `android/` directory of your project (at the same level as the [app](file:///c%3A/Users/fskrf/Desktop/PocketPilot/android/app) directory) with the following content:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

Replace the placeholder values with the actual passwords and file path you used when generating the keystore.

## Step 3: Update build.gradle Files

### Update android/build.gradle

Add the following code at the top of the file (after the existing content):

```gradle
// Load keystore properties file
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

### Update android/app/build.gradle

In the `android` section, add a signing config:

```gradle
signingConfigs {
    release {
        if (keystorePropertiesFile.exists()) {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        } else {
            // Fallback to debug signing if key.properties not found
            signingConfig signingConfigs.debug
        }
    }
}
```

Then, in the `buildTypes` section, update the release configuration:

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

## Step 4: Add key.properties to .gitignore

Add `key.properties` to your [.gitignore](file:///c%3A/Users/fskrf/Desktop/PocketPilot/.gitignore) file to prevent accidentally committing sensitive information:

```
# Android signing
key.properties
```

## Step 5: Build Release APK

After setting up signing, you can build your release APK:

```bash
flutter build apk --release
```

Or build split ABI APKs for smaller downloads:

```bash
flutter build apk --split-per-abi
```

## Troubleshooting

### Keytool Command Not Found
If you get a "keytool command not found" error, make sure you have Java JDK installed and that the `keytool` command is in your PATH.

### Signing Configuration Not Found
If you get signing errors, make sure:
1. The `key.properties` file is in the correct location
2. The paths in `key.properties` are correct
3. The passwords are correct
4. The keystore file exists at the specified location

### Build Failures
If the build fails after adding signing configuration:
1. Run `flutter clean` and try again
2. Check that all file paths are correct
3. Verify that passwords are properly escaped if they contain special characters