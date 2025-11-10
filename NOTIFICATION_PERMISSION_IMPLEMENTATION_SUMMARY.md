# Notification Permission Implementation Summary

## Overview
This implementation adds functionality to redirect users to device notification settings when they enable notifications in the profile page but haven't granted notification permissions yet.

## Changes Made

### 1. Added Dependencies
- Added `permission_handler: ^11.3.1` to pubspec.yaml

### 2. Updated Profile Page
Modified `lib/pages/profile_page.dart`:

1. Added import for permission_handler:
   ```dart
   import 'package:permission_handler/permission_handler.dart';
   ```

2. Enhanced the `_setNotificationsEnabled` method to:
   - Check notification permission status when enabling notifications
   - Show a dialog explaining why notification permissions are needed
   - Redirect user to device settings if they choose to enable notifications but permissions haven't been granted

## Implementation Details

When a user toggles the notification switch to "on" in the profile page:

1. The app checks if notification permissions have been granted using `Permission.notification.status`
2. If permissions are denied or permanently denied:
   - A dialog is shown explaining why notification permissions are needed
   - If the user chooses "Go to Settings", they are redirected to device notification settings using `openAppSettings()`
   - The app notifications are not enabled in this case
3. If permissions are already granted:
   - Notifications are enabled as normal

## User Flow

1. User opens Profile page
2. User toggles "App Notifications" switch to ON
3. If notification permissions haven't been granted:
   - Dialog appears: "Notification Permission Required"
   - Message: "To receive notifications, you need to enable notification permissions in your device settings. Would you like to go to settings now?"
   - User can choose "Cancel" or "Go to Settings"
   - If "Go to Settings" is chosen, user is redirected to device notification settings
4. If notification permissions are already granted:
   - Notifications are enabled immediately

## Testing

To test this implementation:
1. Install the app on a device
2. Deny notification permissions during initial setup
3. Go to Profile page
4. Toggle "App Notifications" to ON
5. Verify that the permission dialog appears
6. Choose "Go to Settings"
7. Verify that device notification settings open