import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_service.dart';
import '../models/user.dart' as app_user;

class ProfileSyncService {

  /// Upload profile picture to local storage (FREE - no Firebase Storage needed)
  static Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      debugPrint('Saving profile picture locally for user: $userId');
      debugPrint('Image file path: ${imageFile.path}');
      debugPrint('Image file size: ${await imageFile.length()} bytes');

      // Check if file exists and is readable
      if (!await imageFile.exists()) {
        debugPrint('Save failed: Image file does not exist');
        return null;
      }

      // Validate file size (max 10MB)
      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        debugPrint('Save failed: Image file too large ($fileSize bytes)');
        return null;
      }

      // Save image to local app directory (FREE)
      final String savedImagePath = await _saveImageToLocalDirectory(imageFile, userId);
      
      // Update user document with local file path
      final updateSuccess = await FirebaseService.updateUserProfileImage(savedImagePath);
      if (!updateSuccess) {
        debugPrint('Warning: Failed to update user document with new image path');
        // Don't return null here as the local save was successful
      }
      
      debugPrint('Profile picture saved locally successfully: $savedImagePath');
      return savedImagePath;
      
    } catch (e) {
      debugPrint('Error saving profile picture locally: $e');
      return null;
    }
  }

  /// Save image to local app directory (FREE - no cloud storage needed)
  static Future<String> _saveImageToLocalDirectory(File imageFile, String userId) async {
    try {
      // Get app directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String profileImagesDir = '${appDir.path}/profile_images';
      
      // Create profile images directory if it doesn't exist
      final Directory profileDir = Directory(profileImagesDir);
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }
      
      // Generate unique filename
      final String fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = '$profileImagesDir/$fileName';
      
      // Copy file to app directory
      final File savedFile = await imageFile.copy(savedPath);
      
      debugPrint('Image saved locally to: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      throw Exception('Failed to save image locally: $e');
    }
  }



  /// Get profile picture (local storage only - FREE)
  static Future<File?> getProfilePicture(app_user.User user) async {
    if (user.profileImagePath == null || user.profileImagePath!.isEmpty) {
      debugPrint('No profile image path found for user');
      return null;
    }

    // Check if it's a local file path and file exists
    final localFile = File(user.profileImagePath!);
    if (await localFile.exists()) {
      debugPrint('Profile picture found: ${user.profileImagePath}');
      return localFile;
    }
    
    // File doesn't exist - clear the path from user document
    debugPrint('Profile picture file not found: ${user.profileImagePath}');
    debugPrint('Attempting to clear invalid profile image path from user document');
    
    try {
      await FirebaseService.updateUserProfileImage(null);
      debugPrint('Invalid profile image path cleared from user document');
    } catch (e) {
      debugPrint('Failed to clear invalid profile image path: $e');
    }
    
    return null;
  }

  /// Delete profile picture from local storage (FREE)
  static Future<bool> deleteProfilePicture(String userId) async {
    try {
      // Get current user to find existing profile image
      final user = await FirebaseService.getUser();
      if (user?.profileImagePath != null) {
        final localFile = File(user!.profileImagePath!);
        if (await localFile.exists()) {
          await localFile.delete();
        }
      }
      
      // Update user document to remove profile image path
      await FirebaseService.updateUserProfileImage(null);
      
      // Clear local cache
      await _clearLocalProfileImages(userId);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting profile picture: $e');
      return false;
    }
  }

  /// Clear local profile images for a specific user
  static Future<void> _clearLocalProfileImages(String userId) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String profileImagesDir = '${appDir.path}/profile_images';
      final Directory profileDir = Directory(profileImagesDir);
      
      if (await profileDir.exists()) {
        final List<FileSystemEntity> files = profileDir.listSync();
        for (final file in files) {
          if (file is File && file.path.contains('profile_$userId')) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing user profile images: $e');
    }
  }

  /// Clear all local profile images (useful for logout)
  static Future<void> clearAllCache() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String profileImagesDir = '${appDir.path}/profile_images';
      final Directory profileDir = Directory(profileImagesDir);
      
      if (await profileDir.exists()) {
        await profileDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing all profile images: $e');
    }
  }

  /// Sync profile preferences across devices
  static Future<void> syncProfilePreferences() async {
    try {
      final user = await FirebaseService.getUser();
      if (user == null) return;

      // Ensure profile picture is available locally
      await getProfilePicture(user);
      
      debugPrint('Profile preferences synced successfully');
    } catch (e) {
      debugPrint('Error syncing profile preferences: $e');
    }
  }

  /// Check local storage permissions and space
  static Future<Map<String, dynamic>> diagnoseStorageIssues() async {
    try {
      final authStatus = await FirebaseService.getAuthStatus();
      final Map<String, dynamic> diagnosis = {
        'authenticated': authStatus['authenticated'],
        'userId': authStatus['userId'],
        'localStorageAvailable': false,
        'canWrite': false,
        'error': null,
      };

      if (!authStatus['authenticated']) {
        diagnosis['error'] = 'User not authenticated';
        return diagnosis;
      }

      final userId = authStatus['userId'];
      if (userId == null) {
        diagnosis['error'] = 'No user ID available';
        return diagnosis;
      }

      // Test local storage access
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        diagnosis['localStorageAvailable'] = true;
        
        // Test write permissions
        final String testDir = '${appDir.path}/test_storage';
        final Directory testDirectory = Directory(testDir);
        await testDirectory.create(recursive: true);
        
        final String testFilePath = '$testDir/test_file.txt';
        final File testFile = File(testFilePath);
        await testFile.writeAsString('Local storage test - ${DateTime.now().toIso8601String()}');
        
        diagnosis['canWrite'] = true;
        
        // Clean up test file and directory
        if (await testFile.exists()) {
          await testFile.delete();
        }
        if (await testDirectory.exists()) {
          await testDirectory.delete();
        }
      } catch (e) {
        diagnosis['error'] = 'Local storage test failed: $e';
        debugPrint('Local storage test failed: $e');
      }

      return diagnosis;
    } catch (e) {
      return {
        'authenticated': false,
        'localStorageAvailable': false,
        'canWrite': false,
        'error': 'Diagnosis failed: ${e.toString()}',
      };
    }
  }
}