import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/profile_sync_service.dart';
import '../models/user.dart' as app_user;

class ProfileImageDiagnostics {
  /// Comprehensive diagnostic for profile image issues
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final Map<String, dynamic> results = {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': defaultTargetPlatform.toString(),
      'user_authenticated': false,
      'user_data_available': false,
      'profile_image_path_exists': false,
      'local_file_exists': false,
      'local_file_readable': false,
      'storage_permissions_ok': false,
      'errors': <String>[],
      'warnings': <String>[],
      'info': <String>[],
    };

    try {
      // Check authentication
      final authStatus = await FirebaseService.getAuthStatus();
      results['user_authenticated'] = authStatus['authenticated'] ?? false;
      results['user_id'] = authStatus['userId'];
      
      if (!results['user_authenticated']) {
        results['errors'].add('User not authenticated');
        return results;
      }

      // Check user data
      final app_user.User? user = await FirebaseService.getUser();
      results['user_data_available'] = user != null;
      
      if (user == null) {
        results['errors'].add('User data not available');
        return results;
      }

      results['profile_image_path'] = user.profileImagePath;
      results['profile_image_path_exists'] = user.profileImagePath != null && user.profileImagePath!.isNotEmpty;
      
      if (!results['profile_image_path_exists']) {
        results['info'].add('No profile image path set for user');
        return results;
      }

      // Check local file
      final File localFile = File(user.profileImagePath!);
      results['local_file_path'] = localFile.path;
      results['local_file_exists'] = await localFile.exists();
      
      if (!results['local_file_exists']) {
        results['warnings'].add('Profile image file does not exist: ${user.profileImagePath}');
        return results;
      }

      // Check file readability
      try {
        final int fileSize = await localFile.length();
        results['local_file_readable'] = true;
        results['file_size_bytes'] = fileSize;
        results['file_size_mb'] = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        
        if (fileSize == 0) {
          results['warnings'].add('Profile image file is empty');
        } else if (fileSize > 10 * 1024 * 1024) {
          results['warnings'].add('Profile image file is very large (${results['file_size_mb']} MB)');
        } else {
          results['info'].add('Profile image file size is reasonable (${results['file_size_mb']} MB)');
        }
      } catch (e) {
        results['errors'].add('Cannot read profile image file: $e');
      }

      // Check storage permissions
      final storageStatus = await ProfileSyncService.diagnoseStorageIssues();
      results['storage_diagnosis'] = storageStatus;
      results['storage_permissions_ok'] = storageStatus['canWrite'] ?? false;
      
      if (!results['storage_permissions_ok']) {
        results['errors'].add('Storage permissions issue: ${storageStatus['error']}');
      }

      // Test ProfileSyncService.getProfilePicture
      try {
        final File? retrievedImage = await ProfileSyncService.getProfilePicture(user);
        results['profile_sync_service_works'] = retrievedImage != null;
        
        if (retrievedImage == null) {
          results['warnings'].add('ProfileSyncService.getProfilePicture returned null');
        } else {
          results['info'].add('ProfileSyncService.getProfilePicture works correctly');
        }
      } catch (e) {
        results['errors'].add('ProfileSyncService.getProfilePicture failed: $e');
      }

    } catch (e) {
      results['errors'].add('Diagnostic failed: $e');
    }

    return results;
  }

  /// Print diagnostic results in a readable format
  static void printDiagnostics(Map<String, dynamic> results) {
    debugPrint('\n${'=' * 50}');
    debugPrint('PROFILE IMAGE DIAGNOSTICS');
    debugPrint('=' * 50);
    debugPrint('Timestamp: ${results['timestamp']}');
    debugPrint('Platform: ${results['platform']}');
    debugPrint('User Authenticated: ${results['user_authenticated']}');
    debugPrint('User Data Available: ${results['user_data_available']}');
    debugPrint('Profile Image Path Exists: ${results['profile_image_path_exists']}');
    
    if (results['profile_image_path'] != null) {
      debugPrint('Profile Image Path: ${results['profile_image_path']}');
    }
    
    debugPrint('Local File Exists: ${results['local_file_exists']}');
    debugPrint('Local File Readable: ${results['local_file_readable']}');
    debugPrint('Storage Permissions OK: ${results['storage_permissions_ok']}');
    
    if (results['file_size_mb'] != null) {
      debugPrint('File Size: ${results['file_size_mb']} MB');
    }

    if (results['errors'].isNotEmpty) {
      debugPrint('\nERRORS:');
      for (String error in results['errors']) {
        debugPrint('  ❌ $error');
      }
    }

    if (results['warnings'].isNotEmpty) {
      debugPrint('\nWARNINGS:');
      for (String warning in results['warnings']) {
        debugPrint('  ⚠️  $warning');
      }
    }

    if (results['info'].isNotEmpty) {
      debugPrint('\nINFO:');
      for (String info in results['info']) {
        debugPrint('  ℹ️  $info');
      }
    }

    debugPrint('${'=' * 50}\n');
  }

  /// Quick diagnostic check for UI widgets
  static Future<bool> isProfileImageAvailable() async {
    try {
      final user = await FirebaseService.getUser();
      if (user?.profileImagePath == null) return false;
      
      final file = File(user!.profileImagePath!);
      return await file.exists();
    } catch (e) {
      debugPrint('Profile image availability check failed: $e');
      return false;
    }
  }
}